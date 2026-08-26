#!/usr/bin/env bash
set -euo pipefail
umask 077

minio_endpoint="${MINIO_ENDPOINT:-http://127.0.0.1:9000}"
minio_access_key="${MINIO_ACCESS_KEY:-}"
minio_secret_key="${MINIO_SECRET_KEY:-}"
minio_bucket="${MINIO_BUCKET:-rust-toon}"
backup_dir="${MINIO_BACKUP_DIR:-/var/backups/rust-toon/minio}"
retention_days="${BACKUP_RETENTION_DAYS:-14}"

usage() {
  echo "Usage: MINIO_ACCESS_KEY=... MINIO_SECRET_KEY=... $0 [--output-dir DIR] [--retention-days DAYS] [--bucket NAME]"
}

while (($#)); do
  case "$1" in
    --output-dir)
      backup_dir="${2:?--output-dir requires a directory}"
      shift 2
      ;;
    --retention-days)
      retention_days="${2:?--retention-days requires a number}"
      shift 2
      ;;
    --bucket)
      minio_bucket="${2:?--bucket requires a name}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$minio_access_key" || -z "$minio_secret_key" ]]; then
  echo "MINIO_ACCESS_KEY and MINIO_SECRET_KEY are required" >&2
  exit 1
fi
if [[ ! "$retention_days" =~ ^[0-9]+$ ]] || ((retention_days < 1)); then
  echo "BACKUP_RETENTION_DAYS must be a positive integer" >&2
  exit 1
fi
case "$backup_dir" in
  ""|/|/var|/var/backups)
    echo "Refusing unsafe backup directory: $backup_dir" >&2
    exit 1
    ;;
esac

backup_dir="$(realpath -m -- "$backup_dir")"
case "$backup_dir" in
  /|/var|/var/backups)
    echo "Refusing unsafe backup directory: $backup_dir" >&2
    exit 1
    ;;
esac

command -v mc >/dev/null || { echo "MinIO Client (mc) is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "sha256sum is required" >&2; exit 1; }

mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
final_path="$backup_dir/rust-toon-minio-$timestamp"
publish_lock="$backup_dir/.rust-toon-minio-$timestamp.lock"
temporary_path=""
mc_config_dir=""

cleanup() {
  if [[ -n "$temporary_path" ]]; then
    rm -rf -- "$temporary_path"
  fi
  if [[ -n "$mc_config_dir" ]]; then
    rm -rf -- "$mc_config_dir"
  fi
  rmdir -- "$publish_lock" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! mkdir -- "$publish_lock" 2>/dev/null; then
  echo "A MinIO backup is already being published for timestamp $timestamp" >&2
  exit 1
fi
if [[ -e "$final_path" || -L "$final_path" ]]; then
  echo "Refusing to overwrite existing MinIO backup: $final_path" >&2
  exit 1
fi

temporary_path="$(mktemp -d "$backup_dir/.rust-toon-minio-$timestamp.XXXXXX")"
mc_config_dir="$(mktemp -d)"

MC_CONFIG_DIR="$mc_config_dir" mc alias set rust-toon-source \
  "$minio_endpoint" "$minio_access_key" "$minio_secret_key" >/dev/null
MC_CONFIG_DIR="$mc_config_dir" mc stat "rust-toon-source/$minio_bucket" >/dev/null
mkdir -p "$temporary_path/objects"
MC_CONFIG_DIR="$mc_config_dir" mc mirror --quiet --preserve \
  "rust-toon-source/$minio_bucket" "$temporary_path/objects" >/dev/null

jq -cn --arg bucket "$minio_bucket" --arg created_at "$timestamp" \
  '{formatVersion: 1, bucket: $bucket, createdAt: $created_at}' \
  > "$temporary_path/manifest.json"
(
  cd "$temporary_path"
  find objects manifest.json -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum -- > SHA256SUMS
)

if ! mv -T -- "$temporary_path" "$final_path"; then
  echo "Failed to publish MinIO backup without replacing an existing destination: $final_path" >&2
  exit 1
fi
temporary_path=""
chmod -R go-rwx "$final_path"

find "$backup_dir" -mindepth 1 -maxdepth 1 -type d \
  -name 'rust-toon-minio-*' -mtime "+$retention_days" -exec rm -rf -- {} +

echo "$final_path"
