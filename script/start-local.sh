#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-backend}"

case "$mode" in
  infra|gateway|worker|backend|all) ;;
  *)
    echo "Usage: $0 [infra|gateway|worker|backend|all]" >&2
    exit 2
    ;;
esac

docker compose -f "$repository_root/script/docker/docker-compose.yml" \
  up -d --wait --wait-timeout 90
if [[ "$mode" == infra ]]; then
  docker compose -f "$repository_root/script/docker/docker-compose.yml" ps
  exit 0
fi

export DATABASE_URL="${DATABASE_URL:-postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
export NATS_URL="${NATS_URL:-nats://127.0.0.1:4222}"
export JWT_SECRET="${JWT_SECRET:-local-development-jwt-secret-change-me-32bytes}"
export BOOTSTRAP_ADMIN_USERNAME="${BOOTSTRAP_ADMIN_USERNAME:-admin}"
export BOOTSTRAP_ADMIN_PASSWORD="${BOOTSTRAP_ADMIN_PASSWORD:-Admin#123456}"
export RUST_LOG="${RUST_LOG:-info}"

cd "$repository_root"
if [[ "$mode" == gateway ]]; then
  exec cargo run -p rust-toon-gateway
fi
if [[ "$mode" == worker ]]; then
  exec cargo run -p rust-toon-worker
fi

gateway_pid=""
worker_pid=""
frontend_pid=""
cleanup() {
  [[ -n "$gateway_pid" ]] && kill "$gateway_pid" 2>/dev/null || true
  [[ -n "$worker_pid" ]] && kill "$worker_pid" 2>/dev/null || true
  [[ -n "$frontend_pid" ]] && kill "$frontend_pid" 2>/dev/null || true
  [[ -n "$gateway_pid" ]] && wait "$gateway_pid" 2>/dev/null || true
  [[ -n "$worker_pid" ]] && wait "$worker_pid" 2>/dev/null || true
  [[ -n "$frontend_pid" ]] && wait "$frontend_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

cargo run -p rust-toon-gateway &
gateway_pid=$!

# The gateway owns migrations. On a clean database the worker must not start
# until /readyz confirms that the full migration chain has committed.
gateway_ready_url="${LOCAL_GATEWAY_READY_URL:-http://127.0.0.1:${GATEWAY_PORT:-8080}/readyz}"
for _ in $(seq 1 180); do
  if curl -fsS "$gateway_ready_url" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$gateway_pid" >/dev/null 2>&1; then
    echo "Gateway exited before completing database migrations" >&2
    exit 1
  fi
  sleep 1
done
if ! curl -fsS "$gateway_ready_url" >/dev/null 2>&1; then
  echo "Gateway did not become ready: $gateway_ready_url" >&2
  exit 1
fi

cargo run -p rust-toon-worker &
worker_pid=$!
if [[ "$mode" == backend ]]; then
  wait -n "$gateway_pid" "$worker_pid"
  exit $?
fi
pnpm --dir apps/web --filter @vben/web-antd run dev &
frontend_pid=$!
wait -n "$gateway_pid" "$worker_pid" "$frontend_pid"
