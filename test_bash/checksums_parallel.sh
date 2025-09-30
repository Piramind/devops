#!/usr/bin/env bash
set -euo pipefail

# === Параметры ===
ROOT="${1:-.}"                 # что хешировать (директория)
OUT="${2:-checksums.txt}"      # файл с суммами
ALGO="${ALGO:-sha256sum}"      # sha256sum/md5sum/sha1sum ...
JOBS="${JOBS:-}"               # параллелизм; пусто => авто

# Авто-выбор количества потоков
if [[ -z "${JOBS}" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
  elif command -v sysctl >/dev/null 2>&1; then
    JOBS="$(sysctl -n hw.ncpu)"
  else
    JOBS=4
  fi
fi

# Проверка алгоритма
if ! command -v "${ALGO%% *}" >/dev/null 2>&1; then
  echo "Предупреждение: команда '$ALGO' не найдена. На Linux установите coreutils. На macOS можно использовать 'brew install coreutils' и ALGO=gsha256sum." >&2
fi

# Заголовок файла результатов
{
  echo "# algorithm: $ALGO"
  echo "# root: $(realpath "$ROOT")"
  echo "# generated: $(date '+%Y-%m-%d %H:%M:%S')"
} > "$OUT"

# Собираем список файлов (относительные пути)
tmp_list="$(mktemp)"
tmp_dir="$(mktemp -d)"
trap 'rm -f "$tmp_list"; rm -rf "$tmp_dir"; [[ -n "${prog_fifo:-}" ]] && rm -f "$prog_fifo" || true' EXIT

pushd "$ROOT" >/dev/null

# NUL-разделённый список
find . -type f -print0 > "$tmp_list"
TOTAL=$(tr -cd '\0' < "$tmp_list" | wc -c | awk '{print $1}')
echo "# files: $TOTAL" >> "$OUT"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "Нет файлов для обработки."
  popd >/dev/null
  exit 0
fi

echo "Файлов: $TOTAL, потоки: $JOBS, алгоритм: $ALGO"
echo "Выход: $OUT"
echo

# === Вариант 1: GNU parallel (лучший) ===
if command -v parallel >/dev/null 2>&1; then
  # --lb гарантирует целостность строк, --bar даёт прогресс
  # --null + :::: читают NUL-разделённый список из файла
  parallel --will-cite --null --lb -j "$JOBS" --bar "$ALGO" :::: "$tmp_list" >> "$OUT"
  popd >/dev/null
  echo -e "\nГотово. Суммы сохранены в $OUT"
  exit 0
fi

# === Вариант 2: xargs + pv (точный прогресс) ===
if command -v pv >/dev/null 2>&1; then
  prog_fifo="$(mktemp -u)"
  mkfifo "$prog_fifo"

  # Прогресс в stderr
  pv -l -s "$TOTAL" < "$prog_fifo" > /dev/stderr &
  pv_pid=$!

  # Каждый поток пишет в свой файл, затем сольём
  export ALGO tmp_dir
  xargs -0 -P "$JOBS" -I {} bash -c '
    set -euo pipefail
    f="$1"
    out="$tmp_dir/$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)-part.txt"
    "$ALGO" "$f" > "$out"
    printf "1\n" > "'"$prog_fifo"'"
  ' _ {} < "$tmp_list"

  # Закрываем pv
  exec 3>"$prog_fifo" || true
  exec 3>&-
  wait "$pv_pid" 2>/dev/null || true

  # Склейка результатов по алфавиту путей (стабильный порядок)
  # Замечание: sha256sum -c не требует сортировки, но так удобнее человеку.
  cat "$tmp_dir"/*-part.txt | sort >> "$OUT"

  popd >/dev/null
  echo -e "\nГотово. Суммы сохранены в $OUT"
  exit 0
fi

# === Вариант 3: чистый xargs (лёгкий прогресс, без pv) ===
# Пишем в отдельные части, чтобы избежать коллизий записи
export ALGO tmp_dir
xargs -0 -P "$JOBS" -I {} bash -c '
  set -euo pipefail
  f="$1"
  out="$tmp_dir/$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)-part.txt"
  "$ALGO" "$f" > "$out"
' _ {} < "$tmp_list" &
xargs_pid=$!

# Псевдо-прогресс: считаем количество готовых частей
while kill -0 "$xargs_pid" 2>/dev/null; do
  DONE=$(ls "$tmp_dir"/*-part.txt 2>/dev/null | wc -l | awk '{print $1}')
  printf "\r[%d/%d] обработано" "$DONE" "$TOTAL" >&2
  sleep 0.3
done
DONE=$(ls "$tmp_dir"/*-part.txt 2>/dev/null | wc -l | awk '{print $1}')
printf "\r[%d/%d] обработано\n" "$DONE" "$TOTAL" >&2
wait "$xargs_pid"

# Склейка результатов
cat "$tmp_dir"/*-part.txt | sort >> "$OUT"

popd >/dev/null
echo "Готово. Суммы сохранены в $OUT"