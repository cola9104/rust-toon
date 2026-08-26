#!/usr/bin/env bash
set -euo pipefail

database_url="${DATABASE_URL:-}"
backup_dir="${BACKUP_DIR:-/var/backups/rust-toon/postgresql}"
retention_days="${BACKUP_RETENTION_DAYS:-14}"
backup_set_id="${BACKUP_SET_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"

usage() {
  echo "Usage: DATABASE_URL=postgres://... $0 [--output-dir DIR] [--retention-days DAYS]"
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

if [[ -z "$database_url" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi
if [[ ! "$retention_days" =~ ^[0-9]+$ ]] || ((retention_days < 1)); then
  echo "BACKUP_RETENTION_DAYS must be a positive integer" >&2
  exit 1
fi
if [[ ! "$backup_set_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "BACKUP_SET_ID contains unsupported characters" >&2
  exit 1
fi
case "$backup_dir" in
  ""|/|/var|/var/backups)
    echo "Refusing unsafe backup directory: $backup_dir" >&2
    exit 1
    ;;
esac

command -v pg_dump >/dev/null || { echo "pg_dump is required" >&2; exit 1; }
command -v pg_restore >/dev/null || { echo "pg_restore is required" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "sha256sum is required" >&2; exit 1; }

mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

final_path="$backup_dir/rust-toon-$backup_set_id.dump"
temporary_path="$final_path.partial"

cleanup() {
  rm -f -- "$temporary_path"
}
trap cleanup EXIT

pg_dump \
  --dbname="$database_url" \
  --format=custom \
  --compress=9 \
  --no-owner \
  --no-privileges \
  --file="$temporary_path"

pg_restore --list "$temporary_path" >/dev/null
mv -- "$temporary_path" "$final_path"
sha256sum "$final_path" > "$final_path.sha256"
chmod 600 "$final_path" "$final_path.sha256"

find "$backup_dir" -maxdepth 1 -type f \
  \( -name 'rust-toon-*.dump' -o -name 'rust-toon-*.dump.sha256' \) \
  -mtime "+$retention_days" -delete

echo "$final_path"
