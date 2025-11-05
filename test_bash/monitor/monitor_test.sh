#!/usr/bin/env bash
# monitor_test.sh
set -euo pipefail

LOGFILE="/var/log/monitoring.log"
STATE_DIR="/var/lib/monitor_test"
STATE_FILE="$STATE_DIR/prev_pid"
URL="https://test.com/monitoring/test/api" #поставить свое
PGREP_NAME="test"
CURL_TIMEOUT=10

mkdir -p -- "$STATE_DIR"
touch "$LOGFILE"

timestamp() {
  date --iso-8601=seconds
}

# Find current pid of exact process name.
current_pid=""
if pids=$(pgrep -x "$PGREP_NAME" || true); then
  if [[ -n "$pids" ]]; then
    current_pid=$(echo "$pids" | head -n1)
  fi
fi

if [[ -z "$current_pid" ]]; then
  exit 0
fi

if [[ -f "$STATE_FILE" ]]; then
  prev_pid=$(<"$STATE_FILE")
else
  prev_pid=""
fi

if [[ -n "$prev_pid" && "$prev_pid" != "$current_pid" ]]; then
  echo "$(timestamp) INFO: process '$PGREP_NAME' restarted: $prev_pid -> $current_pid" >> "$LOGFILE"
fi

printf "%s\n" "$current_pid" > "$STATE_FILE"

http_code=""
curl_err=""
if http_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "$URL" 2> /tmp/monitor_test_curl_err.$$); then
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    :
  else
    echo "$(timestamp) ERROR: monitoring server returned HTTP $http_code for $URL" >> "$LOGFILE"
  fi
else
  curl_err=$(< /tmp/monitor_test_curl_err.$$ || true)
  echo "$(timestamp) ERROR: cannot reach monitoring server $URL — curl failed: ${curl_err}" >> "$LOGFILE"
fi

rm -f /tmp/monitor_test_curl_err.$$ || true

exit 0
