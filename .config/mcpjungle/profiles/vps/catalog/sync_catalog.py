#!/usr/bin/env python3
"""Build a validated, provenance-aware FastMCP catalog snapshot."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import tomllib
from datetime import UTC, datetime
from pathlib import Path

import yaml


CATALOG_DIR = Path(__file__).resolve().parent
CONTENT_DIR = CATALOG_DIR / "content"
REPORT_PATH = CATALOG_DIR / "build-report.json"
HOME = Path.home()
VAULT = Path(os.environ.get("KNOWLEDGE_VAULT", HOME / "git/Knowledge-Platform"))
CHARM_REPO = Path(os.environ.get("CHARM_REPO", HOME / "git/Charm"))
CHARM_REF = os.environ.get("CHARM_REF", "origin/main")
MAX_FILE_BYTES = int(os.environ.get("CATALOG_MAX_FILE_BYTES", "1048576"))
ALLOW_REMOVALS = os.environ.get("CATALOG_ALLOW_REMOVALS") == "1"
TEXT_SUFFIXES = {
    ".css", ".html", ".js", ".json", ".jsx", ".md", ".mjs", ".py",
    ".sh", ".svg", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml",
}
SECRET_PATTERNS = {
    "private-key": re.compile(r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"),
    "github-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    "slack-token": re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    "aws-access-key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "jwt": re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b"),
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


def run(*args: str, cwd: Path | None = None) -> str:
    return subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def git_commit(repo: Path, ref: str = "HEAD") -> str | None:
    try:
        return run("git", "rev-parse", f"{ref}^{{commit}}", cwd=repo)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_allowed_file(path: Path) -> bool:
    return path.suffix.lower() in TEXT_SUFFIXES


def scan_text(data: bytes, source: str) -> str:
    if len(data) > MAX_FILE_BYTES:
        raise ValueError(f"File exceeds {MAX_FILE_BYTES} bytes: {source}")
    if b"\x00" in data:
        raise ValueError(f"Binary content rejected: {source}")
    text = data.decode("utf-8")
    for label, pattern in SECRET_PATTERNS.items():
        if pattern.search(text):
            raise ValueError(f"Possible {label} rejected: {source}")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def adapt_skill(text: str, source: str) -> str:
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
    name = re.sub(r"[^a-z0-9]+", "-", str(metadata.get("name") or Path(source).parent.name).lower()).strip("-")
    description = str(metadata.get("description") or f"Use the documented {name} workflow.").strip()
    if not name or len(name) > 64 or not re.fullmatch(r"[a-z0-9-]+", name):
        raise ValueError(f"Invalid normalized skill name {name!r} in {source}")
    if not description:
        raise ValueError(f"Missing skill description in {source}")
    frontmatter = f"---\nname: {name}\ndescription: {json.dumps(description)}\n---\n\n"
    marker = f"<!-- catalog-source: {source} -->\n\n"
    return frontmatter + marker + ROUTING_NOTE + body


class Builder:
    def __init__(self, root: Path):
        self.root = root
        self.sources: list[dict[str, object]] = []
        self.deduplicated_links: list[str] = []

    def write(self, relative: Path, data: bytes, source: str) -> None:
        text = scan_text(data, source)
        if relative.name == "SKILL.md":
            text = adapt_skill(text, source)
        destination = self.root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")

    def copy_tree(self, source: Path, destination: Path, label: str, allow_agent_links: bool = False) -> int:
        if not source.exists():
            return 0
        copied = 0
        source = source.resolve()
        for root, directories, files in os.walk(source, followlinks=False):
            root_path = Path(root)
            kept: list[str] = []
            for name in directories:
                candidate = root_path / name
                if name in {".git", ".system", "node_modules", "__pycache__"} or name.startswith("._"):
                    continue
                if candidate.is_symlink():
                    target = candidate.resolve()
                    agents_root = (HOME / ".agents/skills").resolve()
                    if allow_agent_links and (target == agents_root or agents_root in target.parents):
                        self.deduplicated_links.append(str(candidate.relative_to(source)))
                        continue
                    raise ValueError(f"Unexpected directory symlink: {candidate} -> {target}")
                kept.append(name)
            directories[:] = kept
            for name in files:
                file_path = root_path / name
                if name.startswith("._") or not is_allowed_file(file_path):
                    continue
                if file_path.is_symlink():
                    raise ValueError(f"Unexpected file symlink: {file_path} -> {file_path.resolve()}")
                relative = file_path.relative_to(source)
                self.write(destination / relative, file_path.read_bytes(), f"{label}:{relative.as_posix()}")
                copied += 1
        return copied

    def copy_charm(self) -> tuple[int, str | None]:
        commit = git_commit(CHARM_REPO, CHARM_REF)
        if not commit:
            return 0, None
        listing = subprocess.run(
            ["git", "ls-tree", "-r", "-z", "--name-only", commit, "--", ".agents/skills"],
            cwd=CHARM_REPO, check=True, capture_output=True,
        ).stdout
        copied = 0
        for raw_name in listing.split(b"\0"):
            if not raw_name:
                continue
            name = raw_name.decode()
            relative = Path(name.removeprefix(".agents/skills/"))
            if not is_allowed_file(relative) or any(part.startswith("._") for part in relative.parts):
                continue
            data = subprocess.run(["git", "show", f"{commit}:{name}"], cwd=CHARM_REPO, check=True, capture_output=True).stdout
            self.write(Path("skills/projects/charm") / relative, data, f"Charm {commit}:{name}")
            copied += 1
        return copied, commit

    def copy_claude_plugins(self) -> int:
        settings_path = HOME / ".claude/settings.json"
        installed_path = HOME / ".claude/plugins/installed_plugins.json"
        if not settings_path.is_file() or not installed_path.is_file():
            return 0
        settings = json.loads(settings_path.read_text())
        installed = json.loads(installed_path.read_text()).get("plugins", {})
        copied = 0
        for plugin_id, enabled in sorted(settings.get("enabledPlugins", {}).items()):
            if not enabled or not installed.get(plugin_id):
                continue
            record = max(installed[plugin_id], key=lambda item: item.get("lastUpdated", ""))
            plugin_name = plugin_id.split("@", 1)[0]
            copied += self.copy_tree(Path(record["installPath"]) / "skills", Path("skills/plugins/claude") / plugin_name, f"Claude plugin {plugin_id}")
            self.sources.append({"type": "claude-plugin", "id": plugin_id, "version": record.get("version"), "updated_at": record.get("lastUpdated")})
        return copied

    def copy_codex_plugins(self) -> int:
        config_path = HOME / ".codex/config.toml"
        if not config_path.is_file():
            return 0
        config = tomllib.loads(config_path.read_text())
        copied = 0
        for plugin_id, values in sorted(config.get("plugins", {}).items()):
            if not values.get("enabled", False):
                continue
            plugin_name, source = plugin_id.split("@", 1)
            plugin_root = HOME / ".codex/plugins/cache" / source / plugin_name
            versions = [item for item in plugin_root.iterdir() if item.is_dir()] if plugin_root.is_dir() else []
            if not versions:
                continue
            selected = max(versions, key=lambda item: item.stat().st_mtime)
            copied += self.copy_tree(selected / "skills", Path("skills/plugins/codex") / plugin_name, f"Codex plugin {plugin_id} {selected.name}")
            self.sources.append({"type": "codex-plugin", "id": plugin_id, "version": selected.name})
        return copied


def file_hashes(root: Path) -> dict[str, str]:
    return {
        path.relative_to(root).as_posix(): sha256(path.read_bytes())
        for path in sorted(root.rglob("*"))
        if path.is_file() and path.name != "provenance.json"
    }


def validate_packages(root: Path) -> int:
    skills = list(root.rglob("SKILL.md"))
    for skill in skills:
        text = skill.read_text()
        end = text.find("\n---\n", 4)
        metadata = yaml.safe_load(text[4:end]) if text.startswith("---\n") and end >= 0 else None
        if not isinstance(metadata, dict) or set(metadata) != {"name", "description"}:
            raise ValueError(f"Non-portable skill frontmatter: {skill}")
        if not re.fullmatch(r"[a-z0-9-]{1,64}", str(metadata["name"])) or not str(metadata["description"]).strip():
            raise ValueError(f"Invalid skill metadata: {skill}")
    return len(skills)


def main() -> None:
    generated_at = datetime.now(UTC).isoformat()
    old_hashes = file_hashes(CONTENT_DIR) if CONTENT_DIR.exists() else {}
    staging = Path(tempfile.mkdtemp(prefix="catalog-build-", dir=CATALOG_DIR))
    try:
        builder = Builder(staging)
        (staging / "prompts").mkdir(parents=True)
        charm_count, charm_commit = builder.copy_charm()
        counts = {
            "prompts": builder.copy_tree(VAULT / "_meta/prompts", Path("prompts"), "Knowledge Vault prompt"),
            "agents": builder.copy_tree(HOME / ".agents/skills", Path("skills/agents"), "user Agents skill"),
            "claude": builder.copy_tree(HOME / ".claude/skills", Path("skills/claude"), "user Claude skill", allow_agent_links=True),
            "codex": builder.copy_tree(HOME / ".codex/skills", Path("skills/codex"), "user Codex skill", allow_agent_links=True),
            "charm": charm_count,
            "claude_plugins": builder.copy_claude_plugins(),
            "codex_plugins": builder.copy_codex_plugins(),
        }
        skill_packages = validate_packages(staging / "skills")
        hashes = file_hashes(staging)
        added = sorted(hashes.keys() - old_hashes.keys())
        removed = sorted(old_hashes.keys() - hashes.keys())
        changed = sorted(path for path in hashes.keys() & old_hashes.keys() if hashes[path] != old_hashes[path])
        report = {
            "generated_at": generated_at,
            "approved": not removed or ALLOW_REMOVALS,
            "added": added, "changed": changed, "removed": removed,
            "unchanged": len(hashes) - len(added) - len(changed),
            "counts": counts, "skill_packages": skill_packages,
            "deduplicated_links": sorted(builder.deduplicated_links),
        }
        REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")
        if removed and not ALLOW_REMOVALS:
            raise RuntimeError(f"Refusing {len(removed)} removals without CATALOG_ALLOW_REMOVALS=1; review {REPORT_PATH}")
        sources = [
            {"type": "knowledge-vault", "commit": git_commit(VAULT)},
            {"type": "charm", "ref": CHARM_REF, "commit": charm_commit},
            {"type": "user-skills", "roots": ["~/.agents/skills", "~/.claude/skills", "~/.codex/skills"]},
            *builder.sources,
        ]
        content_digest = sha256("\n".join(f"{name}:{digest}" for name, digest in sorted(hashes.items())).encode())
        provenance = {
            "schema_version": 1, "generated_at": generated_at,
            "content_sha256": content_digest, "max_file_bytes": MAX_FILE_BYTES,
            "sources": sources,
            "entries": [{"path": path, "sha256": digest} for path, digest in sorted(hashes.items())],
        }
        (staging / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        backup = CATALOG_DIR / ".content.previous"
        shutil.rmtree(backup, ignore_errors=True)
        if CONTENT_DIR.exists():
            CONTENT_DIR.rename(backup)
        staging.rename(CONTENT_DIR)
        shutil.rmtree(backup, ignore_errors=True)
        staging = Path()
        print(json.dumps({**report, "content_sha256": content_digest, "files": len(hashes)}, indent=2))
    finally:
        if staging and staging.exists() and staging != Path():
            shutil.rmtree(staging, ignore_errors=True)


if __name__ == "__main__":
    main()
