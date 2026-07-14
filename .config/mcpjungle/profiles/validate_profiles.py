#!/usr/bin/env python3
"""Validate MCPJungle tool-group profiles without contacting services."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path

ALLOWED_KEYS = {"name", "description", "included_tools", "included_servers", "excluded_tools"}
CHANGE_ACTION = re.compile(
    r"(?:^|[_-])(add|assign|attach|create|delete|detach|edit|execute|fork|invite|join|leave|merge|modify|power|push|reboot|redact|remove|replay|restart|set|unsafe|update|upload|write)(?:$|[_-])"
)
READ_NAME_EXCEPTIONS = {"matrix-server__replay-queue"}


def available_tools(db_path: Path) -> set[str]:
    with sqlite3.connect(db_path) as db:
        rows = db.execute(
            """
            SELECT s.name || '__' || t.name
            FROM tools t JOIN mcp_servers s ON s.id = t.server_id
            WHERE t.enabled = 1 AND t.deleted_at IS NULL AND s.deleted_at IS NULL
            """
        )
        return {row[0] for row in rows}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile_dir", type=Path)
    parser.add_argument("--db", type=Path, help="Optional live MCPJungle SQLite database")
    args = parser.parse_args()

    errors: list[str] = []
    seen_names: set[str] = set()
    live = available_tools(args.db) if args.db else None
    files = sorted(args.profile_dir.glob("*.json"))
    if not files:
        errors.append(f"no JSON profiles found in {args.profile_dir}")

    for path in files:
        try:
            profile = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{path.name}: {exc}")
            continue

        unknown_keys = set(profile) - ALLOWED_KEYS
        if unknown_keys:
            errors.append(f"{path.name}: unknown keys {sorted(unknown_keys)}")
        name = profile.get("name")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9-]+", name):
            errors.append(f"{path.name}: invalid group name")
        elif name in seen_names:
            errors.append(f"{path.name}: duplicate group name {name}")
        else:
            seen_names.add(name)

        tools = profile.get("included_tools", [])
        if not isinstance(tools, list) or not all(isinstance(tool, str) for tool in tools):
            errors.append(f"{path.name}: included_tools must be a string array")
            continue
        if len(tools) != len(set(tools)):
            errors.append(f"{path.name}: duplicate included_tools entries")
        if not (path.stem.endswith("-change") or path.stem == "approved-actions"):
            if profile.get("included_servers"):
                errors.append(f"{path.name}: read profiles must cherry-pick tools, not whole servers")
            risky = [
                tool
                for tool in tools
                if tool not in READ_NAME_EXCEPTIONS
                and CHANGE_ACTION.search(tool.split("__", 1)[-1])
            ]
            if risky:
                errors.append(f"{path.name}: change-capable names in read profile: {risky}")
        malformed = [tool for tool in tools if not re.fullmatch(r"[^_]+(?:[-\w]*)?__[-\w]+", tool)]
        if malformed:
            errors.append(f"{path.name}: malformed tool names: {malformed}")
        if live is not None:
            missing = sorted(set(tools) - live)
            if missing:
                errors.append(f"{path.name}: tools absent from live registry: {missing}")

    if errors:
        print("Profile validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    grant_count = sum(len(json.loads(p.read_text()).get("included_tools", [])) for p in files)
    print(f"Validated {len(files)} profiles with {grant_count} tool grants.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
