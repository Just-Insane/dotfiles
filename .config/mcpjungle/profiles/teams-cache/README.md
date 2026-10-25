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

## Structured capture preparation (not activated)

`server-0.5.0.patch` adds `structuredContent` only to `get_message` from the
same pinned `live.current()` view used by the existing text renderer. The helper
`capture-envelope.mjs` exposes native IDs and exact source timestamps, bounds
one message to 128 KB, and reports reader-text completeness, unknown provider
revision/deletion and partial cache coverage. All ten existing names, arguments,
text responses and read-only classifications remain. The public facade does not
expose its internal provider version; no version or tombstone is invented.
`account_id` is the reader's `meta.selfMri` attribution, not an independently
verified tenant/account claim. Missing identity or ambiguous selection fails closed.

Run `node --test capture-envelope.test.mjs` offline. Apply only after coordinated
provider rollout approval: verify installed zaungast/libzaungast versions 0.5.0
and the unmodified `zaungast/dist/server.js` SHA-256
`46369fbdb0720f7a4d264759c040706ab2ab2f24dfed67e874162e4ffdab732a`,
copy the helper to `zaungast/dist/capture-envelope.mjs`, then apply the checked-in
patch from the zaungast package directory. Prepare a separate staged package
first; do not patch a running instance. Preserve the original package for rollback.
Coordinate the existing Teams-only process/session restart through the parent;
never run broad bootstrap or reset satr/sata. Requalify exact ten-tool inventory,
existing text responses and one bounded structured read before PCP admission.
No installed file, running process, registry or group was changed by this preparation.

## Resumable cache enumeration

`enumeration-0.5.0.patch` applies **after** the original structured-message patch.
It extends the existing `list_conversations` and `read_conversation` tools with an
opt-in `capture:true` mode. Their ordinary text responses and original arguments
remain unchanged, as do all ten tool names and registrations. It adds no server,
Graph client, permission, credential, sign-in or cache location.

Both requests require `expected_account_id` matching the pinned view's `selfMri`.
List requests accept `n` (1–30); `include_empty` is ignored in capture mode because
all accessible conversation rows are enumerated, including empty roots. Read
requests require `expected_conversation_id`; native identity is authoritative over
short display handles, which may change after a cache refresh. `conversation`
remains required by the legacy schema. Read `limit` is 1–200 (default 50).
`capture_cursor` is separate from legacy `cursor`. Date, person, kind and human
cursor filters fail closed in capture mode.

Structured responses use `teams-cache-conversations/v1` or
`teams-cache-messages/v1`, `status:observed`, exact `account_id`, `observed_at`,
`cache_as_of`, `may_be_stale`, `lossy`, `gaps:[{code,detail}]`, `next_cursor`,
`cache_complete` and `provider_complete:false`. Conversation entries are
`{conversation_id,conversation,kind}`. Read responses also have `conversation_id`
and `messages` containing unchanged `teams-cache-message/v1` observations.
Unavailable reads return `{schema,status:"unavailable",reason}` with a static
reason, never private content.

The library patch adds opt-in SQL keysets: conversations by binary native ID,
messages by `(timestamp, native ID)` descending. Message capture includes channel
replies and system rows. Each SQL request is bounded to one page plus a lookahead;
no full-cache materialization or offset scan is used. Cursors bind account and
conversation and reject malformed or cross-scope values. The continuation tuple
survives disappearance of the previous message. New items behind an already passed
keyset are found on the next complete sweep; a sweep is not an atomic snapshot of
a changing cache and is never proof of full provider history.

A page is below 1 MB. Messages retain the prior 128000-byte JSON bound. Oversized
messages advance the cursor with `MESSAGE_TOO_LARGE`, never silently disappearing
from coverage. A discovered conversation later absent from cache returns an empty
exhausted page and `CONVERSATION_NOT_CACHED`; deletion remains unknown. Consumers
must accumulate gaps across pages/sweeps and distinguish cache enumeration
exhaustion from completeness of captured bodies or provider history.

### Qualification and guarded rollout

Prepare a separate copy of **both** installed 0.5.0 packages; the library query is
part of this reviewed reader change. Before applying the patch, verify these
installed prerequisite SHA-256 values:

- `zaungast/dist/server.js`: `1e520bff3b8617d06419e265bb10e63c76cb6f5bcb3946e1712e5d08ec71ddb6`
- `zaungast/dist/schemas.js`: `c13581d9de7049e44504bae5af36588c7a3d25a23f6ed335a6a56872df3603e0`
- `libzaungast/dist/query.js`: `53082765d2a8378816888577b254f40f34347bc8dc8adb3bf49e0397037b0cd9`

Apply `patch -p1 < enumeration-0.5.0.patch` from staged `node_modules`, then copy
`enumeration-envelope.mjs` into staged `zaungast/dist/`. The prior capture helper
must remain identical. Run `node --test *test.mjs` here and
`node qualify-enumeration.mjs /absolute/staged/node_modules`. Qualification uses
synthetic in-memory fixtures and SQLite, never Teams files or network. It verifies
65 conversations, 205 tied-timestamp messages including system rows, SQL keysets,
SDK schema/transport, all ten names and unchanged legacy text.

After protected review/merge, coordinate a Teams-only reader restart and guarded
swap of both packages, preserving both originals. Do not change group grants,
registrations or other satellite sessions. Verify the additive schemas and bounded
structured reads through the existing route before deploying the PCP consumer.
If any operation is uncertain, reconcile package hashes and exact process state
before retrying. Restore both originals together for rollback; retain canonical
PCP evidence and checkpoints. This source change itself performs no rollout.
