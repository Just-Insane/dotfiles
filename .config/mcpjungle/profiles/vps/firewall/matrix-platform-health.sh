#!/usr/bin/env bash
set -euo pipefail

MAX_SECONDS=${MAX_SECONDS:-2.0}
failures=()

check_http() {
  local label=$1 url=$2 result code seconds
  if ! result=$(curl -fsS --max-time 5 -o /dev/null -w '%{http_code} %{time_total}' "$url"); then
    failures+=("$label request failed")
    return
  fi
  read -r code seconds <<<"$result"
  if [[ "$code" != 200 ]]; then
    failures+=("$label returned HTTP $code")
  elif ! awk -v value="$seconds" -v maximum="$MAX_SECONDS" 'BEGIN { exit !(value <= maximum) }'; then
    failures+=("$label took ${seconds}s (limit ${MAX_SECONDS}s)")
  fi
}

check_http 'Matrix client versions' 'https://matrix.cloudhub.social/_matrix/client/versions'
check_http 'Matrix federation version' 'https://matrix.cloudhub.social/_matrix/federation/v1/version'
check_http 'Matrix client well-known' 'https://cloudhub.social/.well-known/matrix/client'
check_http 'Matrix server well-known' 'https://cloudhub.social/.well-known/matrix/server'

if ! docker exec matrix-traefik sh -c \
  'wget -q -O /dev/null -T 3 http://host.docker.internal:8080/health'; then
  failures+=("Traefik cannot reach CrowdSec LAPI")
fi

appsec_probe=$(docker exec matrix-traefik sh -c \
  'wget -S -O /dev/null -T 3 http://host.docker.internal:7422/' 2>&1 || true)
if [[ "$appsec_probe" != *'401 Unauthorized'* ]]; then
  failures+=("Traefik cannot reach CrowdSec AppSec")
fi

if journalctl -u matrix-traefik.service --since '10 minutes ago' --no-pager \
  | grep -q 'appsecQuery:unreachable'; then
  failures+=("Traefik logged appsecQuery:unreachable in the last 10 minutes")
fi

for unit in cf-host-firewall crowdsec crowdsec-firewall-bouncer matrix-traefik matrix-synapse; do
  if ! systemctl is-active --quiet "$unit"; then
    failures+=("$unit is not active")
  fi
done

if ((${#failures[@]})); then
  printf 'matrix-platform-health: %s\n' "${failures[@]}" >&2
  exit 1
fi

printf 'matrix-platform-health: healthy (public endpoints <= %ss; CrowdSec reachable)\n' "$MAX_SECONDS"
