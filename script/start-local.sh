#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-backend}"

case "$mode" in
  infra|backend|all) ;;
  *)
    echo "Usage: $0 [infra|backend|all]" >&2
    exit 2
    ;;
esac

docker compose -f "$repository_root/script/docker/docker-compose.yml" up -d
if [[ "$mode" == infra ]]; then
  docker compose -f "$repository_root/script/docker/docker-compose.yml" ps
  exit 0
fi

export DATABASE_URL="${DATABASE_URL:-postgres://rust_toon:rust_toon@127.0.0.1:5432/rust_toon}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
export JWT_SECRET="${JWT_SECRET:-local-development-jwt-secret-change-me-32bytes}"
export BOOTSTRAP_ADMIN_USERNAME="${BOOTSTRAP_ADMIN_USERNAME:-admin}"
export BOOTSTRAP_ADMIN_PASSWORD="${BOOTSTRAP_ADMIN_PASSWORD:-Admin#123456}"
export RUST_LOG="${RUST_LOG:-info}"

cd "$repository_root"
if [[ "$mode" == backend ]]; then
  exec cargo run -p rust-toon-gateway
fi

gateway_pid=""
frontend_pid=""
cleanup() {
  [[ -n "$gateway_pid" ]] && kill "$gateway_pid" 2>/dev/null || true
  [[ -n "$frontend_pid" ]] && kill "$frontend_pid" 2>/dev/null || true
  wait "$gateway_pid" "$frontend_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

cargo run -p rust-toon-gateway &
gateway_pid=$!
pnpm --dir apps/web --filter @vben/web-antd run dev &
frontend_pid=$!
wait -n "$gateway_pid" "$frontend_pid"
