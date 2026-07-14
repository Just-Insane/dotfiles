# MCPJungle least-privilege profiles

This directory is tracked by the bare dotfiles repository at `~/.cfg`.
It contains only secret-free MCPJungle group definitions and local validation
helpers. Do not add client tokens, Cloudflare Access credentials, tunnel
credentials, registry databases, logs, or AI-client configs containing secrets.

## Profiles

| Profile | Intended use | Deliberately absent |
|---|---|---|
| `read-mostly` | Always-on daily route: non-sensitive reads, research, and isolated browser inspection | Secrets, host commands, external writes and destructive actions |
| `approved-actions` | Sensitive reads, routine writes, host control, and destructive actions; clients must prompt for every call | Nothing intentionally excluded; upstream credentials still define scope |
| `charm-dev` | GitHub intelligence and isolated browser testing | Personal data, infrastructure, GitHub writes |
| `charm-maintenance` | Issue, PR, Actions, release, and advisory triage | Comments, edits, merge, admin, workflow dispatch |
| `charm-maintenance-change` | Short-lived approved collaboration actions | Merge, delete, admin, workflow dispatch |
| `security-research` | Disposable web research | Credentials, host execution, personal data |
| `personal-admin` | Task and calendar overview | Mail, messages, contacts, writes, vault |
| `cloud-infrastructure-read` | Infrastructure inventory | Mutations, SSH, unscoped Cloudflare access |

`read-mostly` and `approved-actions` are the operational pair. The narrower
profiles remain available as optional building blocks; they are not required
for ordinary solo use.

MCPJungle groups authorize tool names, not arguments or resource identities.
Repository, room, calendar, and vault-path boundaries require separate upstream
credentials or independently registered servers with server-side enforcement.

The operational pair is generated from the live MCPJungle registry by
`generate_operational_groups.py`. It classifies every enabled tool, rejects
unknown servers, and verifies that the groups have no overlap and no gaps. The
current inventory covers Bitwarden, Cloudflare, D2, DigitalOcean, Fantastical,
GitHub, Hetzner, Last.fm, macOS services, Matrix, Obsidian, OmniFocus,
OpenFeature, Plaud, Playwright, Sentry, SSH, and tmux.

Sensitive reads are deliberately routed through `approved-actions`. This
includes Bitwarden vault contents, SSH file transfer and execution, tmux
session mutation, Matrix actions, and any multiplexed tool that can write based
on its arguments. Bitwarden exposes its complete surface, including destructive
operations, but only its status check is available automatically.

## Validate

```sh
python3 ~/.config/mcpjungle/profiles/validate_profiles.py \
  ~/.config/mcpjungle/profiles/mcpjungle-groups \
  --db ~/.local/share/mcpjungle/mcpjungle.db
```

## Apply after approval

Back up the registry database and review every JSON file first. The script
refuses to run without an explicit environment flag and skips change profiles
unless separately enabled.

```sh
MCPJUNGLE_DB="$HOME/.local/share/mcpjungle/mcpjungle.db" \
APPLY_MCPJUNGLE_GROUPS=1 \
  ~/.config/mcpjungle/profiles/apply_groups.sh
```

After creation, keep `read-mostly` available automatically and configure
`approved-actions` with per-call prompting. Negative-test both endpoints before
retiring `/mcp`. Separate client/profile credentials remain a future hardening
option rather than a prerequisite for the two-route cutover.

## Live two-route wiring

The Cloudflare MCP Portal endpoints are:

- `https://mcp-read.gauthier.id/mcp?codemode=search_and_execute`
- `https://mcp-actions.gauthier.id/mcp?codemode=search_and_execute`

Both portals use Code Mode and the `mcp-relay-service-token-only` Access
policy. The read portal contains the `read-mostly` MCPJungle group plus three
Home Assistant reads. The actions portal contains the `approved-actions` group
plus 21 Home Assistant controls, including destructive tools. The current split
is 194 automatic tools and 268 approval-gated tools. Clients must treat every
call to the actions portal as approval-gated.

`~/.local/bin/mcp-portal-relay read|actions` is the secret-safe stdio adapter
for local clients. It retrieves the Cloudflare Access service-token values from
the macOS Keychain at runtime; credentials must not be copied into tracked
configuration.

Codex uses `default_tools_approval_mode = "auto"` for the read adapter and
`default_tools_approval_mode = "prompt"` for the actions adapter. Claude Code,
Claude Desktop/Cowork, and VS Code use the same two adapters; their global or
session permission mode must remain approval-oriented rather than bypass or
auto-accept mode.

Service MCPs must not also be registered directly in clients. Sentry,
Cloudflare, GitHub, and the other remote services enter through MCPJungle and
Cloudflare so calls share one policy and audit path. Local product runtime
plumbing remains local by design: Codex's Node/browser/computer-use bridges and
Claude's built-in Design MCP do not provide a parallel route to these services.
The legacy broad `mcp-portal.gauthier.id` Portal has been retired.

## VPS fallback and Cloudflare SSH

The secret-free VPS deployment source is in `vps/`. The live isolated stack on
the Matrix VPS uses PostgreSQL, MCPJungle Enterprise, Prometheus, and a
Cloudflare Tunnel, with no MCP, database, or metrics ports published on the
host. A validated root-only database backup runs daily.

Cloudflare SSH uses separate human and machine applications:

- `ssh-vps.gauthier.id` and `ssh-desktop.gauthier.id` render browser terminals
  after human Access login.
- `ssh-agent-vps.gauthier.id` and `ssh-agent-desktop.gauthier.id` accept only
  the dedicated agent service token. `~/.local/bin/cloudflare-ssh-proxy` reads
  that credential from Keychain at runtime.
- `matrix-vps-cf` and `desktop-cf` are the corresponding OpenSSH aliases.

The existing SSH MCP reaches the VPS through the local
`cloudflare-ssh-listener` on `127.0.0.1:2222`; it no longer connects to the
public VPS SSH address directly. Public port 22 remains a break-glass path until
the Hetzner firewall inventory and an interactive browser login are verified.

The browser applications each have a Cloudflare short-lived SSH certificate
CA. The VPS trusts its CA for the `evie` Unix account; the existing root key is
retained only as break glass. The desktop CA and sshd drop-in are tracked under
`profiles/ssh/`; run `install-cloudflare-desktop-ssh-ca` interactively to install
them because macOS requires an administrator password. Cloudflare derives the
browser certificate principal from the Access identity, so use `evie`, not
`root`, in both browser terminals.

Both MCP portals have Secure Web Gateway routing enabled. Tool calls have been
verified through each portal and the corresponding upstream requests appear in
Gateway HTTP logs. Cloudflare's native MCP Portal Logs view still returns no
rows; treat that as an unresolved structured-telemetry issue rather than as an
absence of Gateway audit data.

The local GitHub MCP runs through `mcp-github-relay`, which reads its credential
from Keychain. Because Cloudflare Gateway inspects local HTTPS traffic, the
GitHub container mounts the WARP-managed CA copy at
`~/.local/share/cloudflare/installed_cert.pem`; that generated certificate is
not tracked.
