#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUN_PAID_AI_E2E:-}" != "1" ]]; then
  echo "Refusing to call paid providers. Set RUN_PAID_AI_E2E=1 explicitly." >&2
  exit 2
fi

required=(DATABASE_URL REAL_IMAGE_MODEL_ID REAL_VIDEO_MODEL_ID REAL_VIDEO_PAYLOAD_JSON)
for variable in "${required[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "$variable is required" >&2
    exit 2
  fi
done

echo "Running paid provider smoke test with AI_REQUEST_TIMEOUT_SECONDS=${AI_REQUEST_TIMEOUT_SECONDS:-120} and AI_REQUEST_RETRIES=${AI_REQUEST_RETRIES:-2}" >&2

cargo test -p rust-toon-toon-server \
  provider_e2e_tests::configured_image_and_video_providers_return_media_urls \
  -- --ignored --nocapture --exact
