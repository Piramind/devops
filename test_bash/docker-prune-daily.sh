#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/docker-prune.log"
exec 9>/var/lock/docker-prune.lock
flock -n 9 || exit 0

{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  command -v docker >/dev/null 2>&1 || { echo "docker not found"; exit 1; }

  echo "[Before] docker system df:"
  docker system df || true

  echo "[Prune] docker system prune -a --volumes -f"
  docker system prune -a --volumes -f

  echo "[After] docker system df:"
  docker system df || true
  echo
} >> "$LOG" 2>&1
