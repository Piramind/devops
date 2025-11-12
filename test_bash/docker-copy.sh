#!/usr/bin/env bash
set -euo pipefail

# docker-pack.sh — архивирует Docker образы или контейнеры.
# Требования: docker, (опц.) pigz или gzip, sha256sum.

usage() {
  cat <<EOF
Usage:
  $0 --mode images|containers --out DIR [--names "pat1 pat2 ..."] [--force]

Опции:
  --mode        images       Архивировать образы docker (docker save)
               containers    Архивировать контейнеры (docker export)
  --out DIR                  Папка для сохранения архива(ов)
  --names "..."              Список шаблонов (grep -E), чтобы сузить набор
  --force                    Перезаписывать, даже если файл уже есть

Примеры:
  $0 --mode images --out /backup/docker
  $0 --mode images --out /backup/docker --names "myapp:|nginx:1.25"
  $0 --mode containers --out /backup/ctr --names "prod-|db$" --force
EOF
  exit 1
}

MODE=""
OUT=""
NAMES=""
FORCE="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2;;
    --out) OUT="${2:-}"; shift 2;;
    --names) NAMES="${2:-}"; shift 2;;
    --force) FORCE="yes"; shift;;
    -h|--help) usage;;
    *) echo "Неизвестный аргумент: $1"; usage;;
  esac
done

[[ -z "$MODE" || -z "$OUT" ]] && usage
[[ "$MODE" != "images" && "$MODE" != "containers" ]] && usage
mkdir -p "$OUT"

# Выбор компрессора
COMPRESS=""
EXT="tar.gz"
if command -v pigz >/dev/null 2>&1; then
  COMPRESS="pigz -9"
elif command -v gzip >/dev/null 2>&1; then
  COMPRESS="gzip -9"
else
  echo "WARN: pigz/gzip не найден — архивы будут без сжатия."
  EXT="tar"
fi

timestamp() { date +"%Y%m%d-%H%M%S"; }

sanitize() {
  # заменяем недопустимые для имени файла символы
  sed -E 's/[^A-Za-z0-9._-]+/_/g'
}

manifest="${OUT}/manifest.csv"
if [[ ! -f "$manifest" ]]; then
  echo "type,name,id,archive,size_bytes,sha256,created_at" > "$manifest"
fi

log() { echo "[$(date +%F\ %T)] $*"; }

match_names() {
  # Фильтрация по шаблонам из --names через grep -E
  if [[ -n "$NAMES" ]]; then
    grep -E "$NAMES" || true
  else
    cat
  fi
}

# Получаем список целей
if [[ "$MODE" == "images" ]]; then
  # Формат: <repo:tag>;<id>
  # Исключаем <none> теги по умолчанию, их можно включить шаблоном.
  mapfile -t items < <(
    docker images --format '{{.Repository}}:{{.Tag}};{{.ID}}' \
    | grep -v '^<none>:' \
    | match_names
  )
else
  # Контейнеры (включая остановленные): <name>;<id>
  mapfile -t items < <(
    docker ps -a --format '{{.Names}};{{.ID}}' \
    | match_names
  )
fi

if [[ ${#items[@]} -eq 0 ]]; then
  log "Ничего не найдено по заданным критериям."
  exit 0
fi

for line in "${items[@]}"; do
  name="${line%%;*}"
  id="${line##*;}"
  safe_name="$(echo -n "$name" | sanitize)"
  ts="$(timestamp)"

  if [[ "$MODE" == "images" ]]; then
    base="${safe_name}__${id:0:12}__${ts}"
    out_tar="${OUT}/${base}.tar"
    out_arc="${OUT}/${base}.${EXT}"
    exists_glob="${OUT}/${safe_name}__${id:0:12}__*.${EXT}"
  else
    base="ctr_${safe_name}__${id:0:12}__${ts}"
    out_tar="${OUT}/${base}.tar"
    out_arc="${OUT}/${base}.${EXT}"
    exists_glob="${OUT}/ctr_${safe_name}__${id:0:12}__*.${EXT}"
  fi

  if [[ "$FORCE" != "yes" ]] && ls $exists_glob >/dev/null 2>&1; then
    log "Пропуск: архив для ${name} (${id:0:12}) уже существует."
    continue
  fi

  log "→ Сохранение ${MODE%?}: ${name} (${id})"

  # Временный тар
  tmp_tar="${out_tar}.tmp"
  tmp_arc="${out_arc}.tmp"

  rm -f "$tmp_tar" "$tmp_arc"

  if [[ "$MODE" == "images" ]]; then
    docker save -o "$tmp_tar" "$name"
  else
    docker export -o "$tmp_tar" "$id"
  fi

  if [[ -n "$COMPRESS" ]]; then
    $COMPRESS "$tmp_tar"
    mv "${tmp_tar}.gz" "$tmp_arc"
  else
    mv "$tmp_tar" "$tmp_arc"
  fi

  mv "$tmp_arc" "$out_arc"

  # Контрольная сумма
  sum_file="${out_arc}.sha256"
  sha256sum "$(basename "$out_arc")" > "$sum_file".tmp --tag --binary 2>/dev/null || sha256sum "$out_arc" > "$sum_file".tmp
  mv "$sum_file".tmp "$sum_file"

  size=$(stat -c%s "$out_arc" 2>/dev/null || wc -c < "$out_arc")
  sha=$(cut -d' ' -f1 "$sum_file")
  created="$(date -Iseconds)"

  if [[ "$MODE" == "images" ]]; then
    echo "image,${name},${id},$(basename "$out_arc"),${size},${sha},${created}" >> "$manifest"
  else
    echo "container,${name},${id},$(basename "$out_arc"),${size},${sha},${created}" >> "$manifest"
  fi

  log "✓ Готово: $(basename "$out_arc") (${size} байт)"
done

log "Манифест: $manifest"
