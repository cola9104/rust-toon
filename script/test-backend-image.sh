#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image_tag="${BACKEND_IMAGE_TAG:-rust-toon/backend:ci-validation}"

docker version >/dev/null
DOCKER_BUILDKIT=1 docker build \
  --file "$repo_root/deploy/docker/Dockerfile.backend" \
  --tag "$image_tag" \
  "$repo_root"

docker run --rm --entrypoint /bin/sh "$image_tag" -eu -c '
  test "$(id -u)" = "10001"
  test -x /usr/local/bin/rust-toon-gateway
  test -x /usr/local/bin/rust-toon-worker
  command -v curl >/dev/null
  command -v ffmpeg >/dev/null
  command -v ffprobe >/dev/null
  curl --version >/dev/null
  ffmpeg -version >/dev/null
  ffprobe -version >/dev/null
'

echo "Backend image build and runtime smoke checks passed ($image_tag)"
