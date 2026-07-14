#!/usr/bin/env python3
"""Build the allowlisted FastMCP prompt and skill snapshot."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

import yaml


CATALOG_DIR = Path(__file__).resolve().parent
CONTENT_DIR = CATALOG_DIR / "content"
HOME = Path.home()
VAULT = Path(os.environ.get("KNOWLEDGE_VAULT", HOME / "git/Knowledge-Platform"))
CHARM_REPO = Path(os.environ.get("CHARM_REPO", HOME / "git/Charm"))
CHARM_REF = os.environ.get("CHARM_REF", "origin/main")
TEXT_SUFFIXES = {
    ".css",
    ".html",
    ".js",
    ".json",
    ".jsx",
    ".md",
    ".mjs",
    ".py",
    ".sh",
    ".svg",
    ".toml",
    ".ts",
    ".tsx",
    ".txt",
    ".yaml",
    ".yml",
}
ROUTING_NOTE = """## Centralized tool routing

This is a generated catalog copy. Keep the source skill canonical and apply these
shared runtime conventions when following it:

- Discover GitHub, Sentry, infrastructure, productivity, macOS, Bitwarden,
  Matrix, SSH, tmux, and other MCP capabilities with
  `portal_codemode_search`, then invoke the selected nested tool with
  `portal_codemode_execute`.
- Do not use `portal_list_servers` to decide whether an MCPJungle service is
  available; that list intentionally shows only top-level upstreams.
- Use the read route for non-mutating calls. Use the approval-gated actions
  route for sensitive reads, writes, host control, and destructive operations.
- Treat client-specific tool names in the source as capability descriptions.
  Resolve them to the current Code Mode tool name before execution.

"""


def is_allowed_file(path: Path) -> bool:
    return path.name == "Dockerfile" or path.suffix.lower() in TEXT_SUFFIXES


def adapt_skill(text: str, source: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if "## Centralized tool routing" in text:
        return text
    body = text
    metadata: dict[str, object] = {}
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end < 0:
            raise ValueError(f"Unterminated skill frontmatter in {source}")
        loaded = yaml.safe_load(text[4:end]) or {}
        if not isinstance(loaded, dict):
            raise ValueError(f"Invalid skill frontmatter in {source}")
        metadata = loaded
        body = text[end + len("\n---\n") :].lstrip()
    name = str(metadata.get("name") or Path(source).parent.name)
    name = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    description = str(
        metadata.get("description")
        or f"Cataloged workflow for {name}. Use when the task matches this skill's documented workflow."
    ).strip()
    frontmatter = f"---\nname: {name}\ndescription: {json.dumps(description)}\n---\n\n"
    marker = f"<!-- catalog-source: {source} -->\n\n"
    return frontmatter + marker + ROUTING_NOTE + body


def write_file(destination: Path, data: bytes, source: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.name == "SKILL.md":
        text = data.decode("utf-8")
        destination.write_text(adapt_skill(text, source), encoding="utf-8")
    else:
        destination.write_bytes(data)


def copy_tree(source: Path, destination: Path, label: str) -> int:
    if not source.exists():
        return 0
    copied = 0
    source = source.resolve()
    for root, directories, files in os.walk(source, followlinks=True):
        directories[:] = [
            name
            for name in directories
            if name not in {".git", ".system", "node_modules", "__pycache__"}
            and not name.startswith("._")
        ]
        root_path = Path(root)
        for name in files:
            file_path = root_path / name
            if name.startswith("._") or not is_allowed_file(file_path):
                continue
            relative = file_path.relative_to(source)
            write_file(destination / relative, file_path.read_bytes(), label)
            copied += 1
    return copied


def copy_charm_skills() -> int:
    if not CHARM_REPO.is_dir():
        return 0
    listing = subprocess.run(
        ["git", "-C", str(CHARM_REPO), "ls-tree", "-r", "-z", "--name-only", CHARM_REF, "--", ".agents/skills"],
        check=True,
        capture_output=True,
    ).stdout
    copied = 0
    prefix = ".agents/skills/"
    for raw_name in listing.split(b"\0"):
        if not raw_name:
            continue
        name = raw_name.decode("utf-8")
        relative = name.removeprefix(prefix)
        candidate = Path(relative)
        if not is_allowed_file(candidate) or any(part.startswith("._") for part in candidate.parts):
            continue
        data = subprocess.run(
            ["git", "-C", str(CHARM_REPO), "show", f"{CHARM_REF}:{name}"],
            check=True,
            capture_output=True,
        ).stdout
        write_file(CONTENT_DIR / "skills/projects/charm" / candidate, data, f"Charm {CHARM_REF}:{name}")
        copied += 1
    return copied


def copy_claude_plugins() -> int:
    settings_path = HOME / ".claude/settings.json"
    installed_path = HOME / ".claude/plugins/installed_plugins.json"
    if not settings_path.is_file() or not installed_path.is_file():
        return 0
    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    installed = json.loads(installed_path.read_text(encoding="utf-8")).get("plugins", {})
    copied = 0
    for plugin_id, enabled in sorted(settings.get("enabledPlugins", {}).items()):
        if not enabled:
            continue
        records = installed.get(plugin_id, [])
        if not records:
            continue
        record = max(records, key=lambda item: item.get("lastUpdated", ""))
        install_path = Path(record["installPath"])
        plugin_name = plugin_id.split("@", 1)[0]
        copied += copy_tree(
            install_path / "skills",
            CONTENT_DIR / "skills/plugins/claude" / plugin_name,
            f"Claude plugin {plugin_id}",
        )
    return copied


def copy_codex_plugins() -> int:
    config_path = HOME / ".codex/config.toml"
    if not config_path.is_file():
        return 0
    config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    copied = 0
    cache_root = HOME / ".codex/plugins/cache"
    for plugin_id, values in sorted(config.get("plugins", {}).items()):
        if not values.get("enabled", False):
            continue
        plugin_name, source = plugin_id.split("@", 1)
        plugin_root = cache_root / source / plugin_name
        if not plugin_root.is_dir():
            continue
        versions = [item for item in plugin_root.iterdir() if item.is_dir()]
        if not versions:
            continue
        selected = max(versions, key=lambda item: item.stat().st_mtime)
        copied += copy_tree(
            selected / "skills",
            CONTENT_DIR / "skills/plugins/codex" / plugin_name,
            f"Codex plugin {plugin_id} ({selected.name})",
        )
    return copied


def main() -> None:
    shutil.rmtree(CONTENT_DIR, ignore_errors=True)
    (CONTENT_DIR / "prompts").mkdir(parents=True)
    counts = {
        "prompts": copy_tree(VAULT / "_meta/prompts", CONTENT_DIR / "prompts", "Knowledge Vault prompts"),
        "agents": copy_tree(HOME / ".agents/skills", CONTENT_DIR / "skills/agents", "user Agents skill"),
        "claude": copy_tree(HOME / ".claude/skills", CONTENT_DIR / "skills/claude", "user Claude skill"),
        "codex": copy_tree(HOME / ".codex/skills", CONTENT_DIR / "skills/codex", "user Codex skill"),
        "charm": copy_charm_skills(),
        "claude_plugins": copy_claude_plugins(),
        "codex_plugins": copy_codex_plugins(),
    }
    files = sorted(path for path in CONTENT_DIR.rglob("*") if path.is_file())
    packages = sum(1 for path in files if path.name == "SKILL.md")
    print(json.dumps({"files": len(files), "skill_packages": packages, "sources": counts}, indent=2))
    for path in files:
        print(path.relative_to(CONTENT_DIR))


if __name__ == "__main__":
    main()
