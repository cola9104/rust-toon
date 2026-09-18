#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_id=""
cleanup() {
  if [[ -n "$container_id" ]]; then
    docker rm -f "$container_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
# Docker selects a free loopback port. Only this disposable container is removed.
container_id="$(docker run -d --name "rust-toon-alignment-test-$$" \
  -e POSTGRES_USER=rust_toon -e POSTGRES_PASSWORD=rust_toon \
  -e POSTGRES_DB=rust_toon_alignment_test \
  -p 127.0.0.1::5432 postgres:18)"
port="$(docker port "$container_id" 5432/tcp | head -n 1 | cut -d: -f2)"
for _ in $(seq 1 30); do
  if docker exec "$container_id" pg_isready -U rust_toon -d rust_toon_alignment_test >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
export TEST_DATABASE_URL="postgres://rust_toon:rust_toon@127.0.0.1:$port/rust_toon_alignment_test"
cd "$repo_root"
cargo test -p rust-toon-toon-server --lib alignment_stage_skills_and_image_prompt_reach_model_boundary -- --ignored --nocapture
