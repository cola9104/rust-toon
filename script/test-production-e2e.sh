#!/usr/bin/env bash
set -euo pipefail

container="rust-toon-production-e2e"
port="${TEST_PRODUCTION_POSTGRES_PORT:-55435}"
upload_dir="$(mktemp -d)"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  rm -rf -- "$upload_dir"
}
trap cleanup EXIT
cleanup_container() { docker rm -f "$container" >/dev/null 2>&1 || true; }
cleanup_container

command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg is required for the production export E2E test" >&2
  exit 1
}

docker run -d --name "$container" \
  -e POSTGRES_USER=rust_toon \
  -e POSTGRES_PASSWORD=rust_toon \
  -e POSTGRES_DB=rust_toon_test \
  -p "$port:5432" postgres:18 >/dev/null
for _ in $(seq 1 30); do
  docker exec "$container" pg_isready -h 127.0.0.1 -p 5432 -U rust_toon -d rust_toon_test >/dev/null 2>&1 && break
  sleep 1
done

export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:${port}/rust_toon_test"
export TEST_UPLOAD_DIR="$upload_dir"
cargo test -p rust-toon-toon-server production_e2e_tests -- --ignored --nocapture
