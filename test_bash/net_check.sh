#!/usr/bin/env bash
# net_check.sh — проверка сетевого взаимодействия до удалённого сервера
# Usage:
#   ./net_check.sh <host> [port1,port2,...]
# Examples:
#   ./net_check.sh 10.0.0.12
#   ./net_check.sh server-b.example.com 22,80,443,9100

set -euo pipefail

HOST="${1:-}"
PORTS_CSV="${2:-22,80,443}"
TIMEOUT_SEC="${TIMEOUT_SEC:-3}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <host> [port1,port2,...]"
  exit 1
fi

IFS=',' read -r -a PORTS <<< "$PORTS_CSV"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "✅ %s\n" "$*"; }
bad()  { printf "❌ %s\n" "$*"; }
info() { printf "ℹ️  %s\n" "$*"; }

bold "Network check to: $HOST"
echo "Timeout: ${TIMEOUT_SEC}s"
echo

# 1) DNS / resolve
bold "1) DNS resolve"
if getent ahosts "$HOST" >/dev/null 2>&1; then
  ok "Resolved: $(getent ahosts "$HOST" | awk '{print $1}' | head -n 3 | tr '\n' ' ')"
else
  bad "Cannot resolve host via getent"
fi
echo

# 2) Ping (может быть запрещён ICMP)
bold "2) ICMP ping"
if command -v ping >/dev/null 2>&1; then
  if ping -c 2 -W "$TIMEOUT_SEC" "$HOST" >/dev/null 2>&1; then
    ok "Ping OK"
  else
    bad "Ping failed (ICMP may be blocked — this is common)"
  fi
else
  info "ping not installed"
fi
echo

# 3) TCP ports check via nc
bold "3) TCP ports"
if command -v nc >/dev/null 2>&1; then
  for p in "${PORTS[@]}"; do
    if nc -z -w "$TIMEOUT_SEC" "$HOST" "$p" >/dev/null 2>&1; then
      ok "TCP $HOST:$p is reachable"
    else
      bad "TCP $HOST:$p is NOT reachable"
    fi
  done
else
  bad "nc (netcat) not installed. Install it or ask me for /dev/tcp version."
fi
echo

# 4) Optional: traceroute
bold "4) Route (optional)"
if command -v traceroute >/dev/null 2>&1; then
  info "Traceroute (first ~15 hops):"
  traceroute -n -m 15 "$HOST" 2>/dev/null | sed 's/^/   /' || true
else
  info "traceroute not installed (skip)"
fi

echo
bold "Done."
