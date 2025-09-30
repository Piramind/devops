#!/usr/bin/env bash
set -euo pipefail

# === Настройки по умолчанию ===
ROOT="${1:-.}"                 # Что хешировать (по умолчанию текущая папка)
OUT="${2:-checksums.txt}"      # Куда писать суммы
ALGO="${ALGO:-sha256sum}"      # Алгоритм: sha256sum/md5sum/sha1sum и т.д.

# Определяем количество потоков
if command -v nproc >/dev/null 2>&1; then
  JOBS="${JOBS:-$(nproc)}"
elif command -v sysctl >/dev/null 2>&1; then
  JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
else
  JOBS="${JOBS:-4}"
fi

echo "# algorithm: $ALGO" > "$OUT"
echo "# root: $(realpath "$ROOT")" >> "$OUT"
echo "# generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUT"

# Считаем список файлов один раз
tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list" "$prog_fifo"; [ -n "${pv_pid:-}" ] && kill "$pv_pid" 2>/dev/null || true' EXIT

# -print0 для безопасности имён с пробелами/юникодом
find "$ROOT" -type f -print0 > "$tmp_list"
TOTAL=$(tr -cd '\0' < "$tmp_list" | wc -c | awk '{print $1}')

if [ "$TOTAL" -eq 0 ]; then
  echo "Нет файлов для обработки."
  exit 0
fi

echo "# files: $TOTAL" >> "$OUT"
echo "Файлов: $TOTAL, потоки: $JOBS, алгоритм: $ALGO"
echo "Выход: $OUT"
echo

# === Вариант 1: GNU parallel с прогресс-баром ===
if command -v parallel >/dev/null 2>&1; then
  # --will-cite чтобы не было интерактивного запроса
  # -0     читать NUL-разделённый список
  # -j N   число джоб
  # --bar  прогресс с ETA
  # -k     (keep order) — по желанию; без -k скорость выше, но строки будут в произвольном порядке
  parallel -0 --will-cite -j "$JOBS" --bar "$ALGO" {} ::"$tmp_list" >> "$OUT"
  echo -e "\nГотово. Суммы сохранены в $OUT"
  exit 0
fi

# === Вариант 2: Фолбэк на xargs + pv (прогресс по завершённым задачам) ===
# Делаем именованный канал, где будем считать завершения задач
prog_fifo="$(mktemp -u)"
mkfifo "$prog_fifo"

# pv считает строки (-l) и знает общее кол-во (-s)
pv -l -s "$TOTAL" < "$prog_fifo" > /dev/stderr &
pv_pid=$!

# Параллельно считаем суммы:
# -0     читать NUL-разделённый список
# -P N   параллелизм
# -I {}  шаблон подстановки
# Внутренняя bash-джоба: посчитать хеш, добавить в файл, записать маркер завершения в FIFO
export ALGO OUT prog_fifo
xargs -0 -P "$JOBS" -I {} bash -c '
  set -euo pipefail
  "$ALGO" "$1" >> "$OUT"
  printf "1\n" > "$prog_fifo"
' _ {} < "$tmp_list"

# Дожидаемся pv и очищаемся (trap сделает остальное)
wait "$pv_pid" 2>/dev/null || true
echo -e "\nГотово. Суммы сохранены в $OUT"