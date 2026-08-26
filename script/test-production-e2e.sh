#!/usr/bin/env bash
set -euo pipefail

postgres_container="rust-toon-production-e2e-postgres"
minio_container="rust-toon-production-e2e-minio"
postgres_port="${TEST_PRODUCTION_POSTGRES_PORT:-55435}"
minio_port="${TEST_PRODUCTION_MINIO_PORT:-59002}"
minio_image="${MINIO_IMAGE:-minio/minio:RELEASE.2025-04-22T22-12-26Z}"
upload_dir="$(mktemp -d)"
cleanup() {
  docker rm -f "$postgres_container" "$minio_container" >/dev/null 2>&1 || true
  rm -rf -- "$upload_dir"
}
trap cleanup EXIT
docker rm -f "$postgres_container" "$minio_container" >/dev/null 2>&1 || true

for command_name in cargo curl docker ffmpeg; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required for the production export E2E test" >&2
    exit 1
  }
done

docker run -d --name "$postgres_container" \
  -e POSTGRES_USER=rust_toon \
  -e POSTGRES_PASSWORD=rust_toon \
  -e POSTGRES_DB=rust_toon_test \
  -p "$postgres_port:5432" postgres:18 >/dev/null
docker run -d --name "$minio_container" \
  -e MINIO_ROOT_USER=rust_toon \
  -e MINIO_ROOT_PASSWORD=rust_toon_password \
  -p "$minio_port:9000" "$minio_image" \
  server /data >/dev/null

for _ in $(seq 1 30); do
  docker exec "$postgres_container" pg_isready -h 127.0.0.1 -p 5432 -U rust_toon -d rust_toon_test >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$postgres_container" pg_isready -h 127.0.0.1 -p 5432 -U rust_toon -d rust_toon_test >/dev/null

for _ in $(seq 1 45); do
  curl -fsS "http://127.0.0.1:${minio_port}/minio/health/ready" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://127.0.0.1:${minio_port}/minio/health/ready" >/dev/null

export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:${postgres_port}/rust_toon_test"
export TEST_UPLOAD_DIR="$upload_dir"
export MINIO_ENDPOINT="http://127.0.0.1:${minio_port}"
export MINIO_ACCESS_KEY="rust_toon"
export MINIO_SECRET_KEY="rust_toon_password"
export MINIO_BUCKET="rust-toon"
cargo test -p rust-toon-toon-server production_e2e_tests -- --ignored --nocapture
