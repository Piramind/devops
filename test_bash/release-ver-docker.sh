#!/bin/bash
set -euo pipefail

FILTER_REGEX="-"     # фильтр по имени образа
OUT_FILE="services.txt"

docker ps --format '{{.Image}}' \
  | grep -E "$FILTER_REGEX" \
  | awk -F'[/:]' '
      {
        service = $(NF-1)
        version = $NF
        if (service != "" && version != "") {
          print service ":" version
        }
      }
    ' \
  | sort -t: -k1,1 -k2,2V \
  | awk -F: '{ ver[$1] = $2 } END { for (s in ver) print s ":" ver[s] }' \
  | sort > "$OUT_FILE"

echo "Saved $(wc -l < "$OUT_FILE") unique services to $OUT_FILE"
