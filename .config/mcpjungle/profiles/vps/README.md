# VPS MCP platform

Secret-free deployment source for the isolated MCPJungle fallback on the Matrix
VPS. Runtime secrets live only in `/srv/mcp-platform/secrets`, the root-owned
`.env`, MCPJungle/PostgreSQL, or the macOS Keychain.

## Layout

- `compose.yaml`: PostgreSQL, MCPJungle Enterprise, Prometheus, and cloudflared.
- `prometheus.yml`: private MCPJungle metrics scrape.
- `servers/github.json`: provider-hosted GitHub remote MCP template.
- `worker/mcp-vps-bridge.mjs`: authenticated Cloudflare Worker bridge used for
  origin troubleshooting; its secrets are Worker bindings.
- `backup.sh` and `systemd/*`: root-only daily PostgreSQL backup and validation.

The VPS has no published MCPJungle, PostgreSQL, or Prometheus ports. Cloudflare
Tunnel is the only HTTP ingress. Browser SSH and headless agent SSH use distinct
Access applications so human identity policies and service-token policies do
not overlap.

## Deploy

Copy this directory to `/srv/mcp-platform`, create a mode-600 `.env` containing
`POSTGRES_PASSWORD`, install the tunnel token at
`secrets/cloudflared-token`, then run:

```sh
docker compose -f /srv/mcp-platform/compose.yaml up -d
install -m 0755 /srv/mcp-platform/backup.sh /usr/local/sbin/mcp-platform-backup
install -m 0644 /srv/mcp-platform/systemd/mcp-platform-backup.service /etc/systemd/system/
install -m 0644 /srv/mcp-platform/systemd/mcp-platform-backup.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mcp-platform-backup.timer
```

The GitHub JSON is a template: substitute `GITHUB_TOKEN` only at registration
time. Never render a token into the tracked file.
