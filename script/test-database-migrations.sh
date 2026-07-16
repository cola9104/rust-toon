#!/usr/bin/env bash
set -euo pipefail

container="rust-toon-migration-test"
port="${TEST_POSTGRES_PORT:-55432}"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "$container" \
  -e POSTGRES_USER=rust_toon \
  -e POSTGRES_PASSWORD=rust_toon \
  -e POSTGRES_DB=rust_toon_test \
  -p "$port:5432" postgres:18 >/dev/null
for _ in $(seq 1 30); do
  docker exec "$container" pg_isready -U rust_toon -d rust_toon_test >/dev/null 2>&1 && break
  sleep 1
done
export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:${port}/rust_toon_test"
cargo test -p rust-toon-framework-database --test migrations -- --ignored --nocapture
