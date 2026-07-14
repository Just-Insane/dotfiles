#!/bin/sh
set -eu

if [ "${APPLY_MCPJUNGLE_GROUPS:-}" != "1" ]; then
  echo "Refusing to change MCPJungle. Re-run with APPLY_MCPJUNGLE_GROUPS=1 after review." >&2
  exit 2
fi

registry="${MCPJUNGLE_REGISTRY:-http://127.0.0.1:8950}"
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "${MCPJUNGLE_DB:-}" ]; then
  python3 "$base/validate_profiles.py" "$base/mcpjungle-groups" --db "$MCPJUNGLE_DB"
else
  python3 "$base/validate_profiles.py" "$base/mcpjungle-groups"
fi

for profile in "$base"/mcpjungle-groups/*.json; do
  case "$(basename "$profile")" in
    *-change.json)
      if [ "${INCLUDE_CHANGE_PROFILES:-}" != "1" ]; then
        echo "Skipping approval-gated change profile $(basename "$profile")"
        continue
      fi
      ;;
  esac
  mcpjungle create group --registry "$registry" --conf "$profile"
done
