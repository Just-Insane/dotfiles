# Local Teams cache MCP

This Mac runs zaungast 0.5.0 as a stateful stdio server in MCPJungle. It reads
Teams' local IndexedDB/LevelDB cache through the JavaScript engine. It does not
use Microsoft Graph, tenant consent, Microsoft credentials, or a network sync
client. The Teams desktop app must perform its ordinary signed-in sync.

## Runtime

- Node: /Users/evie/.nvm/versions/node/v24.14.1/bin/node
- Installation: /Users/evie/.local/share/mcp-relay/zaungast-0.5.0
- Registration: ../mcpjungle-servers/zaungast.json
- Both zaungast and libzaungast are pinned to 0.5.0; the checked-in lockfile pins
  transitive dependencies. Installation lifecycle scripts are disabled.
- The registration selects one explicit Teams cache directory. After a Teams
  reinstall or profile change, confirm this is the active profile before changing it.
  A filesystem profile path is not a tenant allowlist.

To reproduce the package installation, copy package.json and package-lock.json
from this directory to the installation directory, then run the pinned Node with
its npm-cli.js and `ci --prefix <installation> --ignore-scripts --no-audit --no-fund`.
Use the existing enterprise CA configuration if npm needs it; retain TLS validation.
The registered runtime launches the installed dist/index.js directly and does not
invoke npx or contact npm on startup.

## Gateway contract

The separate pcp-satellite-teams-read group explicitly permits the ten reviewed
zaungast tools. The pcp-host-teams client permits only the zaungast server. The
host alias satt uses its own application-hop bearer through the existing Mac
satellite proxy, keeping satr/sata registrations and credentials intact.

The canonical satellite group, client contract and host registration belong to
Just-Insane/personal-infrastructure under platform/pcp-host/mac-satellite.
The host Read group grants only the ten exact satt__zaungast__* names. Unknown
future tool names are not automatically admitted. Keep all token values in
protected runtime secret storage, outside this source directory.

Do not run the legacy all-groups generator or full host bootstrap to activate
this integration. The current Mac uses satellite-specific groups, and full host
bootstrap force-registers existing providers. Apply only the new Teams objects
and preserve the complete live Read group when adding the exact tool names.

## Desktop operation and coverage

Keep current Microsoft Teams signed in, opening at login and running after its
window closes. Hide it rather than quit it. Disable Teams notifications in macOS
System Settings and review Teams' own call/meeting sound controls, since those
can operate independently of OS notifications.

These are desktop settings to verify after installation and sign-in; the MCP
configuration does not itself apply notification or login-item settings.

Teams caches only a locally synced slice. Keeping the app in the background does
not guarantee that every conversation or historical message is available. Open a
needed conversation in Teams once if its cache is stale. zaungast checks local
file changes when tools are called; it cannot download missing messages.

Verify startup, tools/list and one bounded list_conversations read through the
Mac group and final Read portal. Check cached coverage separately from connection
health. The initial October 23, 2026 test used an older cache; fresh Teams sign-in
is still needed before claiming current coverage.

## Rollback

Remove only the ten satt__zaungast__* grants from the host Read group, preserving
all other fields, and refresh that portal's schema. Then remove the dedicated
satt registration and the Teams-only Mac group/client/server if desired. Retain
Teams' own cache and the existing Mail/calendar satellite registrations. Do not
restore a whole registry database or reset other source changes.
