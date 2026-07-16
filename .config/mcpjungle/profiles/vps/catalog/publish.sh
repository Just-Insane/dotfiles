#!/bin/sh
set -eu

catalog_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python=${CATALOG_PYTHON:-$HOME/.pyenv/versions/3.13.9/bin/python3}
lock_dir="$HOME/Library/Caches/mcp-catalog-publish.lock"
state_dir="$HOME/Library/Application Support/mcp-catalog"
archive=$(mktemp -t mcp-catalog.XXXXXX.tgz)
work_dir=$(mktemp -d -t mcp-catalog-publish.XXXXXX)
pcp_tunnel_pid=""

finish() {
  status=$?
  if [ -n "$pcp_tunnel_pid" ]; then
    kill "$pcp_tunnel_pid" 2>/dev/null || true
    wait "$pcp_tunnel_pid" 2>/dev/null || true
  fi
  rm -f "$archive"
  rm -rf "$work_dir"
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

TUNNEL_SERVICE_TOKEN_ID=$(
  "$HOME/.local/bin/vault-runtime-secret" pcp-ssh PCP_SSH_CLOUDFLARE_ACCESS_CLIENT_ID
)
TUNNEL_SERVICE_TOKEN_SECRET=$(
  "$HOME/.local/bin/vault-runtime-secret" pcp-ssh PCP_SSH_CLOUDFLARE_ACCESS_CLIENT_SECRET
)
export TUNNEL_SERVICE_TOKEN_ID TUNNEL_SERVICE_TOKEN_SECRET
/opt/homebrew/bin/cloudflared access tcp \
  --hostname ssh-agent-pcp1.gauthier.id --url 127.0.0.1:22522 \
  >"$work_dir/pcp-tunnel.log" 2>&1 &
pcp_tunnel_pid=$!
attempt=0
while ! /usr/bin/nc -z 127.0.0.1 22522 >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 40 ] || {
    echo "PCP SSH route did not become ready" >&2
    exit 1
  }
  sleep 1
done
unset TUNNEL_SERVICE_TOKEN_ID TUNNEL_SERVICE_TOKEN_SECRET

/usr/bin/scp -q -P 22522 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  "$archive" root@127.0.0.1:/tmp/mcp-catalog-deploy.tgz
/usr/bin/ssh -p 22522 -o BatchMode=yes root@127.0.0.1 \
  /usr/local/sbin/mcp-catalog-deploy

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
