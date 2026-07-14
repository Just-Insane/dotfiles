# MCPJungle least-privilege profiles

This directory is tracked by the bare dotfiles repository at `~/.cfg`.
It contains only secret-free MCPJungle group definitions and local validation
helpers. Do not add client tokens, Cloudflare Access credentials, tunnel
credentials, registry databases, logs, or AI-client configs containing secrets.

## Profiles

| Profile | Intended use | Deliberately absent |
|---|---|---|
| `charm-dev` | GitHub intelligence and isolated browser testing | Personal data, infrastructure, GitHub writes |
| `charm-maintenance` | Issue, PR, Actions, release, and advisory triage | Comments, edits, merge, admin, workflow dispatch |
| `charm-maintenance-change` | Short-lived approved collaboration actions | Merge, delete, admin, workflow dispatch |
| `security-research` | Disposable web research | Credentials, host execution, personal data |
| `personal-admin` | Task and calendar overview | Mail, messages, contacts, writes, vault |
| `cloud-infrastructure-read` | Infrastructure inventory | Mutations, SSH, unscoped Cloudflare access |

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

After creation, route clients through `/v0/groups/<profile>/mcp`, issue a
distinct MCPJungle token and Cloudflare Access service token for each
client/profile pair, and negative-test forbidden tools before retiring `/mcp`.
