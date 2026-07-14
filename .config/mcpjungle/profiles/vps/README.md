# VPS MCP platform

Secret-free deployment source for the isolated MCPJungle fallback on the Matrix
VPS. Runtime secrets live only in `/srv/mcp-platform/secrets`, the root-owned
`.env`, MCPJungle/PostgreSQL, or the macOS Keychain.

## Layout

- `compose.yaml`: PostgreSQL, MCPJungle Enterprise, the read-only FastMCP
  catalog, Prometheus, and cloudflared.
- `catalog/`: FastMCP 3 catalog server plus a configuration-aware allowlist
  sync. The generated `catalog/content/` snapshot is deployed but intentionally
  ignored; the Knowledge Vault, project repositories, user skill directories,
  and client plugin caches remain canonical.
- `prometheus.yml`: private MCPJungle metrics scrape.
- `servers/github.json`: provider-hosted GitHub remote MCP template.
- `worker/mcp-vps-bridge.mjs`: authenticated Cloudflare Worker bridge used for
  origin troubleshooting; its secrets are Worker bindings.
- `backup.sh` and `systemd/*`: root-only daily PostgreSQL backup and validation.
- `firewall/`: tracked host ingress policy, deployment helper, and Matrix/
  CrowdSec regression checks. Public SSH remains available for Ansible and
  break-glass recovery and is monitored by CrowdSec.

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

Deploy or refresh the tracked firewall and five-minute health timer with:

```sh
~/.config/mcpjungle/profiles/vps/firewall/deploy.sh
```

The health check covers the public Matrix client, federation, and well-known
endpoints with a two-second latency ceiling; Traefik-to-CrowdSec LAPI and AppSec
connectivity; recent `appsecQuery:unreachable` errors; and the critical
firewall, CrowdSec, Traefik, and Synapse units. The Hetzner firewall retains
TCP/22 for Ansible and break glass. CrowdSec's `linux` and `sshd` collections
and host firewall bouncer protect that path. CrowdSec ports 7422 and 8080 are
reachable only from local Docker bridges at the host firewall.

Matrix deployment secrets are stored in the separate Bitwarden Secrets Manager
project `MDAD`, not in `MCP Relay`. Existing machine accounts are reused across
projects with project-specific grants: the Mac Studio account reads both
projects, while the VPS account needs `MDAD` only if Ansible execution moves to
the VPS. The editable, secret-free source is
`~/.config/mdad/matrix.cloudhub.social/vars.yml`; the ignored playbook inventory
path is a symlink to it. Run the playbook through
`~/.local/bin/matrix-ansible-bsm`, which obtains its machine-account token from
macOS Keychain, reads only the 17 keys in the tracked allowlist, and injects
their values into the Ansible process environment. It never materializes a
secret or private-key file:

```sh
matrix-ansible-bsm -- just install-all
matrix-ansible-bsm -- ansible-playbook -i inventory/hosts setup.yml --syntax-check
```

Each password, token, credential document, or private key is a separate
`MDAD_*` BSM object. `vars.yml` references them with fail-closed Ansible
environment lookups. Missing or duplicate objects stop the wrapper before
Ansible starts. Machine accounts need read access only during normal operation;
secret creation and rotation use a short, deliberate write window.

Refresh and deploy the prompt/skill catalog from the desktop with:

```sh
~/.config/mcpjungle/profiles/vps/catalog/publish.sh
```

`com.gauthier.mcp-catalog-publish` runs the same operation daily at 04:15.
It builds a staged snapshot, transfers it through the restricted
`matrix-vps-cf` SSH identity, and invokes only the root-owned
`mcp-catalog-deploy` helper. Deployments validate archive paths and provenance,
replace the catalog atomically, rebuild only when content or runtime files
change, roll back on failure, and retry the public health check for one minute.
The VPS also runs `mcp-catalog-health.timer` hourly. Desktop success state is
written under `~/Library/Application Support/mcp-catalog/`; failures are logged
under `~/Library/Logs/` and produce a macOS notification.

The sync requires Python 3 with PyYAML. It includes Knowledge Vault prompts,
user-level Agents/Claude/Codex skills, the skills currently present on Charm's
`origin/main`, and skills from plugins currently enabled in Claude and Codex.
System skills, disabled plugins, binary assets, credentials, worktrees, and
whole-home or whole-vault mounts are excluded. Text references, scripts,
templates, and client metadata are included so skill instructions do not lose
their supporting material.

The builder rejects unexpected symlinks, binary files, files larger than 1 MiB,
high-confidence credential patterns, invalid skill frontmatter, and unapproved
removals. It pins repository and plugin provenance, hashes every deployed file,
and emits a content digest in `catalog://provenance`. Generated `SKILL.md` copies
are normalized to portable `name` and `description`
frontmatter and receive a shared routing note. That note maps client-specific
MCP names onto Cloudflare Portal Code Mode discovery/execution, preserves the
read versus approval-gated action boundary, and prevents top-level Portal server
listing from being mistaken for the MCPJungle service inventory. Originals are
never rewritten. Override `CHARM_REPO`, `CHARM_REF`, or `KNOWLEDGE_VAULT` when
building from a different checkout or ref.

The catalog exposes native prompts, text resources, and a resource template, plus
read-only `list_prompts`, `get_prompt`, `list_resources`, `read_resource`, and
`search_catalog` compatibility tools for Cloudflare Code Mode and tool-only
clients. `search_catalog` also supports the MCP background-task protocol. It
never mounts the whole vault or home directory.

The live endpoint is `https://mcp-catalog.gauthier.id/mcp`. It accepts separate
bearer tokens for the desktop MCPJungle client and Cloudflare Portal, stored as
`mcp-catalog-bearer-token` and `mcp-catalog-cloudflare-bearer-token` in macOS
Keychain and as `CATALOG_BEARER_TOKEN` and
`CATALOG_CLOUDFLARE_BEARER_TOKEN` in the root-owned VPS `.env`. `/health`
exposes only counts and freshness and remains unauthenticated. Catalog reads are
logged as structured JSON with the authenticated client ID, event, target,
result count or byte count, and timestamp; token values and resource contents
are never logged.

Cloudflare directly registers this endpoint as `fastmcp-catalog` and currently
reports it Ready with five tools and seven prompts. All capabilities are
authorized in the `Evie MCP Read` portal. The desktop MCPJungle `catalog`
registration remains in `read-mostly` as a fallback, so existing sessions keep
working while new portal sessions pick up the direct VPS route. The shared
`catalog-resolver` skill in Agents, Claude, and Codex searches the catalog,
reads the most relevant candidate instructions, checks provenance, and then
uses the selected workflow without treating catalog content as executable
authority.

The GitHub JSON is a template: substitute `GITHUB_TOKEN` only at registration
time. Never render a token into the tracked file.
