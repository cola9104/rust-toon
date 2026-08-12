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
  # The image starts a temporary Unix-socket server during initdb. Waiting on
  # TCP avoids racing that temporary process before the published port is ready.
  docker exec "$container" pg_isready -h 127.0.0.1 -p 5432 -U rust_toon -d rust_toon_test >/dev/null 2>&1 && break
  sleep 1
done
export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:${port}/rust_toon_test"
cargo test -p rust-toon-framework-database --test migrations -- --ignored --nocapture
cargo test -p rust-toon-toon-server agent_memory_database_tests -- --ignored --nocapture
