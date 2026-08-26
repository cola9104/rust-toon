#!/usr/bin/env bash
set -euo pipefail

gateway_ready_url="${GATEWAY_READY_URL:-http://127.0.0.1:8080/readyz}"
worker_ready_url="${WORKER_READY_URL:-http://127.0.0.1:8081/readyz}"
nats_monitor_url="${NATS_MONITOR_URL:-http://127.0.0.1:8222}"

command -v curl >/dev/null 2>&1 || {
  echo "curl is required" >&2
  exit 1
}

check() {
  local label="$1"
  local url="$2"
  if ! curl --connect-timeout 3 --max-time 10 -fsS "$url" >/dev/null; then
    echo "$label is not ready: $url" >&2
    return 1
  fi
  echo "$label ready"
}

check "gateway" "$gateway_ready_url"
check "toon-worker" "$worker_ready_url"
check "NATS JetStream" "${nats_monitor_url%/}/healthz?js-enabled-only=true"
