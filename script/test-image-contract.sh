#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container="rust-toon-image-contract-test-$$"
port="${TEST_IMAGE_CONTRACT_POSTGRES_PORT:-55439}"
container_id=""
cleanup() {
  if [[ -n "$container_id" ]]; then
    docker rm -f "$container_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
container_id="$(docker run -d --name "$container" \
  -e POSTGRES_USER=rust_toon -e POSTGRES_PASSWORD=rust_toon \
  -e POSTGRES_DB=rust_toon_image_contract_test \
  -p "127.0.0.1:$port:5432" postgres:18)"
for _ in $(seq 1 30); do
  if docker exec "$container_id" pg_isready -h 127.0.0.1 -U rust_toon -d rust_toon_image_contract_test >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:$port/rust_toon_image_contract_test"
cd "$repo_root"
cargo test -p rust-toon-toon-server --lib \
  image_contract_rejects_bad_results_without_replacing_assets -- --ignored --nocapture
