#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rnacos_image="${RNACOS_IMAGE:-qingpan/rnacos:v0.8.6}"
container_name="rust-toon-rnacos-e2e-$$"
cache_dir="$(mktemp -d)"

cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  rm -rf -- "$cache_dir"
}
trap cleanup EXIT

docker run --rm -d \
  --name "$container_name" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --tmpfs /io/nacos_db:rw,noexec,nosuid,size=64m \
  -p 127.0.0.1:18848:8848 \
  -p 127.0.0.1:19848:9848 \
  -e RNACOS_DATA_DIR=/io/nacos_db \
  -e RNACOS_SDK_HOST=0.0.0.0 \
  -e RNACOS_CONSOLE_HOST=0.0.0.0 \
  -e RNACOS_HTTP_CONSOLE_PORT=0 \
  -e RNACOS_ENABLE_OPEN_API_AUTH=true \
  -e RNACOS_INIT_ADMIN_USERNAME=rust_toon \
  -e RNACOS_INIT_ADMIN_PASSWORD=rust_toon_nacos_password \
  -e RUST_LOG=warn \
  "$rnacos_image" >/dev/null

ready=false
for _ in $(seq 1 30); do
  if docker exec "$container_name" \
    /usr/bin/bash -ec 'exec 3<>/dev/tcp/127.0.0.1/9848' 2>/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  docker logs "$container_name" >&2
  echo "r-nacos did not become ready" >&2
  exit 1
fi

cd "$repo_root"
TEST_NACOS_SERVER_ADDR=127.0.0.1:18848 \
TEST_NACOS_USERNAME=rust_toon \
TEST_NACOS_PASSWORD=rust_toon_nacos_password \
TEST_NACOS_CACHE_DIR="$cache_dir" \
cargo test -p rust-toon-framework-dynamic-config \
  live_rnacos_push_updates_the_receiver -- --ignored

echo "r-nacos authenticated push and hot-update checks passed"
