#!/usr/bin/env bash
set -euo pipefail

database_url="${DATABASE_URL:-}"
backup_path=""
confirmed=false

usage() {
  echo "Usage: $0 --backup FILE --database-url URL --confirm"
  echo "       DATABASE_URL=postgres://... $0 --backup FILE --confirm"
}

while (($#)); do
  case "$1" in
    --backup)
      backup_path="${2:?--backup requires a file}"
      shift 2
      ;;
    --database-url)
      database_url="${2:?--database-url requires a URL}"
      shift 2
      ;;
    --confirm)
      confirmed=true
      shift
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

if [[ -z "$backup_path" || -z "$database_url" ]]; then
  usage >&2
  exit 1
fi
if [[ "$confirmed" != true ]]; then
  echo "Restore replaces objects in the target database; pass --confirm to continue" >&2
  exit 1
fi
if [[ ! -f "$backup_path" ]]; then
  echo "Backup does not exist: $backup_path" >&2
  exit 1
fi

command -v pg_restore >/dev/null || { echo "pg_restore is required" >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "sha256sum is required" >&2; exit 1; }

if [[ -f "$backup_path.sha256" ]]; then
  (cd "$(dirname "$backup_path")" && sha256sum --check "$(basename "$backup_path").sha256")
fi
pg_restore --list "$backup_path" >/dev/null

pg_restore \
  --dbname="$database_url" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --exit-on-error \
  "$backup_path"

echo "Restore completed. Restart the gateway and verify /readyz before enabling traffic."
