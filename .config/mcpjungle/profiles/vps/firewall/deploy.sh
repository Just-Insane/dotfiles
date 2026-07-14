#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${MATRIX_VPS_SSH_HOST:-root@78.47.193.205}
IDENTITY=${MATRIX_VPS_SSH_IDENTITY:-$HOME/.ssh/matrix_vps_mcp_ed25519}
SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$IDENTITY" "$HOST")
SCP=(scp -q -o BatchMode=yes -o IdentitiesOnly=yes -i "$IDENTITY")

for file in \
  "$ROOT/firewall/cf-web-lockdown.sh" \
  "$ROOT/firewall/matrix-platform-health.sh" \
  "$ROOT/systemd/cf-host-firewall.service" \
  "$ROOT/systemd/matrix-platform-health.service" \
  "$ROOT/systemd/matrix-platform-health.timer"; do
  [[ -f "$file" ]] || { echo "missing deployment file: $file" >&2; exit 1; }
done

tmp=$("${SSH[@]}" 'mktemp -d /root/matrix-platform-hardening.XXXXXX')
cleanup() { "${SSH[@]}" "rm -rf '$tmp'" >/dev/null 2>&1 || true; }
trap cleanup EXIT HUP INT TERM

"${SCP[@]}" \
  "$ROOT/firewall/cf-web-lockdown.sh" \
  "$ROOT/firewall/matrix-platform-health.sh" \
  "$ROOT/systemd/cf-host-firewall.service" \
  "$ROOT/systemd/matrix-platform-health.service" \
  "$ROOT/systemd/matrix-platform-health.timer" \
  "$HOST:$tmp/"

"${SSH[@]}" "set -euo pipefail
install -m 0755 '$tmp/cf-web-lockdown.sh' /usr/local/sbin/cf-web-lockdown.sh
install -m 0755 '$tmp/matrix-platform-health.sh' /usr/local/sbin/matrix-platform-health
install -m 0644 '$tmp/cf-host-firewall.service' /etc/systemd/system/cf-host-firewall.service
install -m 0644 '$tmp/matrix-platform-health.service' /etc/systemd/system/matrix-platform-health.service
install -m 0644 '$tmp/matrix-platform-health.timer' /etc/systemd/system/matrix-platform-health.timer
systemctl daemon-reload
systemctl enable --now cf-host-firewall.service matrix-platform-health.timer
systemctl restart cf-host-firewall.service
systemctl start matrix-platform-health.service
systemctl --no-pager --full status cf-host-firewall.service matrix-platform-health.service matrix-platform-health.timer"
