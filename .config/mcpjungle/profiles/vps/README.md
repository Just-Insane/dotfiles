# VPS MCP platform

Secret-free deployment source for the isolated MCPJungle fallback on the Matrix
VPS. Runtime secrets live only in `/srv/mcp-platform/secrets`, the root-owned
`.env`, MCPJungle/PostgreSQL, or the macOS Keychain.

## Layout

- `compose.yaml`: PostgreSQL, MCPJungle Enterprise, the read-only FastMCP
  catalog, Prometheus, and cloudflared.
- `catalog/`: FastMCP 3 catalog server plus a local allowlist sync script. The
  generated `catalog/content/` snapshot is deployed but intentionally ignored;
  the Knowledge Vault and installed skill directories remain canonical.
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

Refresh and deploy the prompt/skill catalog from the desktop with:

```sh
~/.config/mcpjungle/profiles/vps/catalog/sync-content.sh
```

The catalog exposes native prompts, resources, and a resource template, plus
read-only `list_prompts`, `get_prompt`, `list_resources`, `read_resource`, and
`search_catalog` compatibility tools for Cloudflare Code Mode and tool-only
clients. `search_catalog` also supports the MCP background-task protocol. It
never mounts the whole vault or home directory.

The live endpoint is `https://mcp-catalog.gauthier.id/mcp`. It requires the
dedicated bearer token stored as `mcp-catalog-bearer-token` in macOS Keychain
and `CATALOG_BEARER_TOKEN` in the root-owned VPS `.env`; `/health` exposes only
counts and remains unauthenticated. Because Cloudflare's direct MCP server
synchronizer currently rejects otherwise-working VPS endpoints, the desktop
MCPJungle registers this remote server as `catalog` and publishes its five
compatibility tools in `read-mostly`. The Cloudflare read Portal therefore
reaches the catalog through Code Mode as `catalog__*`; native prompt and
resource discovery remains available to direct FastMCP clients.

The GitHub JSON is a template: substitute `GITHUB_TOKEN` only at registration
time. Never render a token into the tracked file.
