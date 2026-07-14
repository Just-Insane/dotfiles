#!/bin/sh
set -eu

catalog_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python=${CATALOG_PYTHON:-$HOME/.pyenv/versions/3.13.9/bin/python3}
lock_dir="$HOME/Library/Caches/mcp-catalog-publish.lock"
state_dir="$HOME/Library/Application Support/mcp-catalog"
archive=$(mktemp -t mcp-catalog.XXXXXX.tgz)

finish() {
  status=$?
  rm -f "$archive"
  rmdir "$lock_dir" 2>/dev/null || true
  if [ "$status" -ne 0 ]; then
    /usr/bin/osascript -e 'display notification "Catalog refresh failed; check ~/Library/Logs/mcp-catalog-publish.err.log" with title "FastMCP catalog"' >/dev/null 2>&1 || true
  fi
  exit "$status"
}
trap finish EXIT HUP INT TERM

mkdir "$lock_dir" 2>/dev/null || {
  echo "A catalog publish is already running" >&2
  exit 75
}
mkdir -p "$state_dir"

"$python" "$catalog_dir/sync_catalog.py"
COPYFILE_DISABLE=1 /usr/bin/tar --no-xattrs \
  --exclude='catalog/content/._*' --exclude='catalog/__pycache__' \
  --exclude='catalog/build-report.json' \
  -C "$catalog_dir/.." -czf "$archive" compose.yaml catalog

/usr/bin/scp -q "$archive" matrix-vps-cf:/tmp/mcp-catalog-deploy.tgz
/usr/bin/ssh matrix-vps-cf sudo -n /usr/local/sbin/mcp-catalog-deploy

attempt=0
health=""
while [ "$attempt" -lt 12 ]; do
  if health=$(/usr/bin/curl --fail --silent --show-error https://mcp-catalog.gauthier.id/health 2>/dev/null); then
    break
  fi
  attempt=$((attempt + 1))
  sleep 5
done
[ -n "$health" ] || {
  echo "Catalog did not become healthy after deployment" >&2
  exit 1
}
printf '%s\n' "$health" >"$state_dir/last-success.json"
"$python" -c 'import json,sys; value=json.load(sys.stdin); assert value["status"] == "healthy"; print(json.dumps(value, indent=2))' <<EOF
$health
EOF
