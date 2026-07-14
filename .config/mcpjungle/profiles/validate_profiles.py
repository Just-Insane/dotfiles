#!/usr/bin/env python3
"""Validate MCPJungle tool-group profiles without contacting services."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path

from generate_operational_groups import ACTIONS, READ, classify, load_tools

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
            WHERE t.enabled = 1 AND t.deleted_at IS NULL
              AND s.enabled = 1 AND s.deleted_at IS NULL
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
    profiles_by_name: dict[str, dict] = {}
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
            profiles_by_name[name] = profile

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

    if args.db:
        live_tools = load_tools(args.db)
        expected = {READ: set(), ACTIONS: set()}
        for tool in live_tools:
            expected[classify(tool)].add(f'{tool["server"]}__{tool["name"]}')

        for profile_name, bucket in (("read-mostly", READ), ("approved-actions", ACTIONS)):
            profile = profiles_by_name.get(profile_name)
            if profile is None:
                errors.append(f"missing required operational profile {profile_name}")
                continue
            actual = set(profile.get("included_tools", []))
            missing = sorted(expected[bucket] - actual)
            excess = sorted(actual - expected[bucket])
            if missing:
                errors.append(f"{profile_name}: missing classified tools: {missing}")
            if excess:
                errors.append(f"{profile_name}: tools in the wrong operational route: {excess}")

        with sqlite3.connect(args.db) as db:
            rows = db.execute(
                """
                SELECT name, transport, session_mode, config
                FROM mcp_servers
                WHERE enabled = 1 AND deleted_at IS NULL
                """
            )
            servers = {
                name: {
                    "transport": transport,
                    "session_mode": session_mode,
                    "config": json.loads(config or "{}"),
                }
                for name, transport, session_mode, config in rows
            }

        for name, server in servers.items():
            config = server["config"]
            command = config.get("command")
            if server["transport"] == "stdio" and (
                not isinstance(command, str)
                or not command.startswith("/")
                or not Path(command).exists()
            ):
                errors.append(f"{name}: stdio command must be an existing absolute path")

        server_source_dir = args.profile_dir.parent / "mcpjungle-servers"
        for name, server in servers.items():
            if name == "catalog":
                # The catalog registration contains an authentication header and
                # is intentionally reconstructed from Keychain instead of tracked.
                continue
            source_path = server_source_dir / f"{name}.json"
            if not source_path.exists():
                errors.append(f"{name}: missing secret-free tracked server definition")
                continue
            try:
                source = json.loads(source_path.read_text())
            except (OSError, json.JSONDecodeError) as exc:
                errors.append(f"{name}: invalid tracked server definition: {exc}")
                continue
            expected_runtime = {
                "transport": source.get("transport"),
                "session_mode": source.get("session_mode", "stateless"),
                "command": source.get("command"),
                "args": source.get("args", []),
            }
            actual_runtime = {
                "transport": server["transport"],
                "session_mode": server["session_mode"],
                "command": server["config"].get("command"),
                "args": server["config"].get("args", []),
            }
            if expected_runtime != actual_runtime:
                errors.append(f"{name}: live registration differs from tracked runtime definition")

        d2_args = (servers.get("d2") or {}).get("config", {}).get("args", [])
        if "-write-files" in d2_args or "--write-files" in d2_args:
            errors.append("d2: read-route renderer must not enable server-side file writes")

        for name, kind in (("cloudflare", "cloudflare"), ("plaud", "node-ca")):
            config = (servers.get(name) or {}).get("config", {})
            server_args = config.get("args", [])
            if config.get("command") != "/Users/evie/.local/share/mcp-relay/run-with-credential":
                errors.append(f"{name}: must use the secret-safe runtime wrapper")
            elif not server_args or server_args[0] != kind:
                errors.append(f"{name}: runtime wrapper must select {kind}")

        playwright = (servers.get("playwright") or {}).get("config", {})
        playwright_args = playwright.get("args", [])
        required_flags = {"--headless", "--isolated", "--output-dir", "--output-max-size"}
        missing_flags = sorted(required_flags - set(playwright_args))
        if missing_flags:
            errors.append(f"playwright: missing confinement flags: {missing_flags}")
        if "--allow-unrestricted-file-access" in playwright_args:
            errors.append("playwright: unrestricted filesystem access must remain disabled")
        if "--output-dir" in playwright_args:
            output_dir = playwright_args[playwright_args.index("--output-dir") + 1]
            if playwright.get("command") != "/usr/bin/env" or playwright_args[:2] != ["-C", output_dir]:
                errors.append("playwright: process cwd must match its configured output directory")

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
