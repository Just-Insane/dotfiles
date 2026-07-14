# MCPJungle least-privilege profiles

This directory is tracked by the bare dotfiles repository at `~/.cfg`.
It contains only secret-free MCPJungle group definitions and local validation
helpers. Do not add client tokens, Cloudflare Access credentials, tunnel
credentials, registry databases, logs, or AI-client configs containing secrets.

## Profiles

| Profile | Intended use | Deliberately absent |
|---|---|---|
| `read-mostly` | Always-on daily route: reads, research, and isolated browser work | Credentials, host commands, external writes and destructive actions |
| `approved-actions` | Routine writes and destructive actions; clients must prompt for every call | Bitwarden retrieval, SSH commands, tmux commands |
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
policy. The read portal contains only the `read-mostly` MCPJungle group. The
actions portal contains only the `approved-actions` group, including destructive
tools. Clients must treat every call to the actions portal as approval-gated.

`~/.local/bin/mcp-portal-relay read|actions` is the secret-safe stdio adapter
for local clients. It retrieves the Cloudflare Access service-token values from
the macOS Keychain at runtime; credentials must not be copied into tracked
configuration.

Codex uses `default_tools_approval_mode = "auto"` for the read adapter and
`default_tools_approval_mode = "prompt"` for the actions adapter. Claude Code,
Claude Desktop/Cowork, and VS Code use the same two adapters; their global or
session permission mode must remain approval-oriented rather than bypass or
auto-accept mode.
