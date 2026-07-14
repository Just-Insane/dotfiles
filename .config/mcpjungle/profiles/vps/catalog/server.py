from __future__ import annotations

import json
import logging
import mimetypes
import os
import re
from datetime import UTC, datetime
from pathlib import Path

from fastmcp import FastMCP
from fastmcp.server.auth.providers.jwt import StaticTokenVerifier
from fastmcp.server.dependencies import get_access_token
from fastmcp.server.transforms import PromptsAsTools, ResourcesAsTools
from starlette.responses import JSONResponse


CONTENT_ROOT = Path(os.environ.get("CATALOG_CONTENT_ROOT", "/catalog/content")).resolve()
VALID_KINDS = {"prompts", "skills"}
MAX_AGE_HOURS = int(os.environ.get("CATALOG_MAX_AGE_HOURS", "48"))
logging.basicConfig(level=logging.INFO, format="%(message)s")
LOGGER = logging.getLogger("catalog.audit")


def _tokens() -> dict[str, dict[str, object]]:
    configured = {
        "desktop-mcpjungle": os.environ.get("CATALOG_BEARER_TOKEN"),
        "cloudflare-portal": os.environ.get("CATALOG_CLOUDFLARE_BEARER_TOKEN"),
    }
    tokens = {
        token: {"client_id": client_id, "scopes": ["catalog:read"]}
        for client_id, token in configured.items()
        if token
    }
    if not tokens:
        raise RuntimeError("At least one catalog bearer token is required")
    return tokens


def _audit(event: str, **fields: object) -> None:
    token = get_access_token()
    LOGGER.info(
        json.dumps(
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "event": event,
                "client_id": token.client_id if token else "unauthenticated",
                **fields,
            },
            sort_keys=True,
        )
    )

auth = StaticTokenVerifier(
    tokens=_tokens(),
    required_scopes=["catalog:read"],
)

mcp = FastMCP(
    "Evie Knowledge Catalog",
    auth=auth,
    instructions=(
        "Read-only catalog of curated prompts and skill documentation. "
        "Use native prompts/resources when supported or the compatibility tools otherwise."
    ),
)


def _safe_path(kind: str, relative_path: str) -> Path:
    if kind not in VALID_KINDS:
        raise ValueError(f"Unsupported catalog kind: {kind}")
    candidate = (CONTENT_ROOT / kind / relative_path).resolve()
    expected_root = (CONTENT_ROOT / kind).resolve()
    if candidate != expected_root and expected_root not in candidate.parents:
        raise ValueError("Path escapes the catalog allowlist")
    if not candidate.is_file():
        raise FileNotFoundError(relative_path)
    return candidate


def _entries() -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for kind in sorted(VALID_KINDS):
        root = CONTENT_ROOT / kind
        if not root.exists():
            continue
        for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
            if any(part.startswith("._") for part in path.parts):
                continue
            relative = path.relative_to(root).as_posix()
            entries.append(
                {
                    "kind": kind,
                    "path": relative,
                    "uri": f"catalog://content/{kind}/{relative}",
                    "mime_type": mimetypes.guess_type(path.name)[0] or "text/plain",
                }
            )
    return entries


def _provenance() -> dict[str, object]:
    path = CONTENT_ROOT / "provenance.json"
    if not path.is_file():
        return {}
    loaded = json.loads(path.read_text(encoding="utf-8"))
    return loaded if isinstance(loaded, dict) else {}


@mcp.resource("catalog://manifest", mime_type="application/json")
def manifest() -> str:
    """List all allowlisted catalog entries."""
    entries = _entries()
    provenance = _provenance()
    _audit("manifest.read", entries=len(entries))
    return json.dumps({"count": len(entries), "entries": entries, "provenance": provenance}, indent=2)


@mcp.resource("catalog://provenance", mime_type="application/json")
def provenance() -> str:
    """Read the catalog build provenance, hashes, and pinned source revisions."""
    value = _provenance()
    _audit("provenance.read", entries=len(value.get("entries", [])))
    return json.dumps(value, indent=2)


@mcp.resource("catalog://content/{kind}/{relative_path*}", mime_type="text/plain")
def catalog_content(kind: str, relative_path: str) -> str:
    """Read one allowlisted prompt or skill document."""
    path = _safe_path(kind, relative_path)
    _audit("resource.read", kind=kind, path=relative_path, bytes=path.stat().st_size)
    return path.read_text(encoding="utf-8")


@mcp.tool(task=True, annotations={"readOnlyHint": True, "idempotentHint": True})
async def search_catalog(query: str, kind: str = "all", limit: int = 20) -> list[dict[str, str | int]]:
    """Search the curated prompt and skill catalog by filename and text."""
    if kind != "all" and kind not in VALID_KINDS:
        raise ValueError("kind must be all, prompts, or skills")
    if not query.strip():
        raise ValueError("query must not be empty")
    limit = max(1, min(limit, 50))
    terms = [term.lower() for term in re.findall(r"[A-Za-z0-9_-]+", query)]
    results: list[dict[str, str | int]] = []
    for entry in _entries():
        if kind != "all" and entry["kind"] != kind:
            continue
        text = _safe_path(entry["kind"], entry["path"]).read_text(encoding="utf-8", errors="replace")
        haystack = f"{entry['path']}\n{text}".lower()
        score = sum(haystack.count(term) for term in terms)
        if score:
            results.append({**entry, "score": score})
    selected = sorted(results, key=lambda item: (-int(item["score"]), str(item["path"])))[:limit]
    _audit("catalog.search", query=query, kind=kind, limit=limit, results=len(selected))
    return selected


def _register_prompts() -> None:
    prompt_root = CONTENT_ROOT / "prompts"
    if not prompt_root.exists():
        return
    for path in sorted(prompt_root.rglob("*.md")):
        if any(part.startswith("._") for part in path.parts):
            continue
        relative = path.relative_to(prompt_root).as_posix()
        name = re.sub(r"[^a-z0-9_]+", "_", path.stem.lower()).strip("_")
        content = path.read_text(encoding="utf-8")

        def make_prompt(prompt_content: str, prompt_path: str):
            def render_prompt() -> str:
                _audit("prompt.read", path=prompt_path)
                return prompt_content

            return render_prompt

        render_prompt = make_prompt(content, relative)
        render_prompt.__name__ = f"prompt_{name}"
        render_prompt.__doc__ = f"Curated prompt from {relative}."
        mcp.prompt(name=name)(render_prompt)


_register_prompts()
mcp.add_transform(PromptsAsTools(mcp))
mcp.add_transform(ResourcesAsTools(mcp))


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    entries = _entries()
    provenance = _provenance()
    generated_at = provenance.get("generated_at")
    age_hours = None
    stale = True
    if isinstance(generated_at, str):
        try:
            age_hours = (datetime.now(UTC) - datetime.fromisoformat(generated_at)).total_seconds() / 3600
            stale = age_hours > MAX_AGE_HOURS
        except ValueError:
            pass
    return JSONResponse(
        {
            "status": "stale" if stale else "healthy",
            "entries": len(entries),
            "prompts": sum(1 for entry in entries if entry["kind"] == "prompts"),
            "skills": sum(1 for entry in entries if entry["kind"] == "skills"),
            "skill_packages": sum(
                1 for entry in entries if entry["kind"] == "skills" and entry["path"].endswith("/SKILL.md")
            ),
            "generated_at": generated_at,
            "age_hours": round(age_hours, 2) if age_hours is not None else None,
            "max_age_hours": MAX_AGE_HOURS,
            "content_sha256": provenance.get("content_sha256"),
        },
        status_code=503 if stale else 200,
    )


if __name__ == "__main__":
    mcp.run(
        transport="http",
        host="0.0.0.0",
        port=8000,
        path="/mcp",
        allowed_hosts=[
            "mcp-catalog.gauthier.id",
            "catalog-mcp",
            "catalog-mcp:8000",
            "localhost",
            "127.0.0.1",
        ],
    )
