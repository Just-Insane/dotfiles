#!/usr/bin/env python3
"""Generate the two comprehensive operational MCPJungle groups.

The rules intentionally fail closed for unknown servers. Tools that multiplex
read and write operations are routed to approved-actions unless their schema is
provably read-only. Bitwarden vault access is approval-gated even when the
individual operation is technically a read because it can disclose secrets.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


READ = "read"
ACTIONS = "actions"


def action_schema(tool: dict) -> set[str]:
    props = (tool.get("input_schema") or {}).get("properties") or {}
    return set((props.get("action") or {}).get("enum") or [])


def classify(tool: dict) -> str:
    server = tool["server"]
    name = tool["name"]
    annotations = tool.get("annotations") or {}
    read_hint = annotations.get("readOnlyHint") is True

    if server in {"catalog", "d2", "lastfm", "openfeature"}:
        return READ
    if server == "bitwarden":
        return READ if name == "status" else ACTIONS
    if server == "cloudflare":
        return READ if name in {"docs", "search"} else ACTIONS
    if server == "digitalocean":
        change_words = (
            "add", "assign", "change", "convert", "create", "delete", "disable",
            "edit", "enable", "flush", "power", "reboot", "rebuild", "release",
            "remove", "rename", "reserve", "reset", "resize", "restore", "shutdown",
            "snapshot", "transfer", "unassign", "update",
        )
        return ACTIONS if any(word in name for word in change_words) else READ
    if server == "fantastical":
        return READ if name.startswith("query") else ACTIONS
    if server == "github":
        return READ if read_hint else ACTIONS
    if server in {"hetzner", "hetzner-control-plane-ro"}:
        return READ if name.startswith(("get_", "list_")) else ACTIONS
    if server == "macos":
        return READ if action_schema(tool) == {"read"} else ACTIONS
    if server == "matrix-server":
        return READ if read_hint else ACTIONS
    if server == "matrix-notifier":
        return ACTIONS
    if server == "obsidian":
        return READ if name.startswith(("get_", "list_", "read_", "search_")) else ACTIONS
    if server == "omnifocus":
        return READ if name.startswith(("dump_", "filter_", "get_", "list_", "read_")) else ACTIONS
    if server == "plaud":
        return ACTIONS if name in {"login", "logout"} else READ
    if server == "playwright":
        safe = {
            "browser_close", "browser_console_messages", "browser_find", "browser_hover",
            "browser_navigate", "browser_navigate_back", "browser_network_request",
            "browser_network_requests", "browser_resize", "browser_snapshot", "browser_tabs",
            "browser_take_screenshot", "browser_wait_for",
        }
        return READ if name in safe else ACTIONS
    if server == "sentry":
        return ACTIONS if name in {"analyze_issue_with_seer", "execute_sentry_tool", "update_issue"} else READ
    if server == "ssh-matrix":
        return READ if name == "list-servers" else ACTIONS
    if server == "tmux":
        return READ if name.startswith(("capture-", "find-", "get-", "list-")) else ACTIONS
    raise ValueError(f"unclassified server/tool: {server}__{name}")


def load_tools(db_path: Path) -> list[dict]:
    with sqlite3.connect(db_path) as db:
        rows = db.execute(
            """
            SELECT s.name, t.name, t.input_schema, t.annotations
            FROM tools t JOIN mcp_servers s ON s.id = t.server_id
            WHERE t.enabled = 1 AND t.deleted_at IS NULL
              AND s.enabled = 1 AND s.deleted_at IS NULL
            ORDER BY s.name, t.name
            """
        )
    return [
        {
            "server": server,
            "name": name,
            "input_schema": json.loads(input_schema or "{}"),
            "annotations": json.loads(annotations or "{}"),
        }
        for server, name, input_schema, annotations in rows
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    tools = load_tools(args.db)
    buckets = {READ: [], ACTIONS: []}
    for tool in tools:
        buckets[classify(tool)].append(f'{tool["server"]}__{tool["name"]}')

    all_names = {f'{t["server"]}__{t["name"]}' for t in tools}
    read_names = set(buckets[READ])
    action_names = set(buckets[ACTIONS])
    if read_names & action_names:
        raise SystemExit(f"overlapping grants: {sorted(read_names & action_names)}")
    if read_names | action_names != all_names:
        raise SystemExit(f"unrouted grants: {sorted(all_names - read_names - action_names)}")

    profiles = {
        "read-mostly.json": {
            "name": "read-mostly",
            "description": "Automatic daily route for retrieval, research, diagnostics, and non-mutating local inspection.",
            "included_tools": buckets[READ],
            "included_servers": [],
            "excluded_tools": [],
        },
        "approved-actions.json": {
            "name": "approved-actions",
            "description": "Approval-gated route for writes, destructive actions, multiplexed read/write tools, credentials, and host execution.",
            "included_tools": buckets[ACTIONS],
            "included_servers": [],
            "excluded_tools": [],
        },
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for filename, profile in profiles.items():
        (args.output_dir / filename).write_text(json.dumps(profile, indent=2) + "\n")

    by_server: dict[str, dict[str, int]] = {}
    for tool in tools:
        bucket = classify(tool)
        by_server.setdefault(tool["server"], {READ: 0, ACTIONS: 0})[bucket] += 1
    print(json.dumps({"totals": {READ: len(read_names), ACTIONS: len(action_names)}, "servers": by_server}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
