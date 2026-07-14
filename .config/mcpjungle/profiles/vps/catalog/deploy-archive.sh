#!/bin/sh
set -eu

archive=/tmp/mcp-catalog-deploy.tgz
platform=/srv/mcp-platform
current="$platform/catalog"
staging=$(mktemp -d "$platform/.catalog.next.XXXXXX")
previous="$platform/.catalog.previous"
previous_compose="$platform/.compose.previous.yaml"

cleanup() {
  rm -rf "$staging"
}
trap cleanup EXIT HUP INT TERM

[ "$(id -u)" -eq 0 ] || {
  echo "catalog deploy must run as root" >&2
  exit 1
}
[ -f "$archive" ] || {
  echo "missing $archive" >&2
  exit 1
}

python3 - "$archive" "$staging" <<'PY'
import json
import sys
import tarfile
from pathlib import Path, PurePosixPath

archive, destination = sys.argv[1:]
with tarfile.open(archive, "r:gz") as bundle:
    members = bundle.getmembers()
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or not path.parts or path.parts[0] not in {"catalog", "compose.yaml"} or ".." in path.parts:
            raise SystemExit(f"unsafe archive member: {member.name}")
        if path.parts[0] == "compose.yaml" and len(path.parts) != 1:
            raise SystemExit(f"unsafe archive member: {member.name}")
        if not (member.isfile() or member.isdir()):
            raise SystemExit(f"links and special files are forbidden: {member.name}")
    bundle.extractall(destination, filter="data")
root = Path(destination) / "catalog"
for required in ("Dockerfile", "server.py", "content/provenance.json"):
    if not (root / required).is_file():
        raise SystemExit(f"missing required archive member: {required}")
if not (Path(destination) / "compose.yaml").is_file():
    raise SystemExit("missing required archive member: compose.yaml")
provenance = json.loads((root / "content/provenance.json").read_text())
if not provenance.get("content_sha256") or not provenance.get("entries"):
    raise SystemExit("invalid provenance manifest")
PY

next="$staging/catalog"
next_compose="$staging/compose.yaml"
new_hash=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["content_sha256"])' "$next/content/provenance.json")
old_hash=""
if [ -f "$current/content/provenance.json" ]; then
  old_hash=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("content_sha256", ""))' "$current/content/provenance.json")
fi
new_runtime_hash=$(cat "$next/Dockerfile" "$next/server.py" "$next_compose" | sha256sum | cut -d' ' -f1)
old_runtime_hash=""
if [ -f "$current/Dockerfile" ] && [ -f "$current/server.py" ] && [ -f "$platform/compose.yaml" ]; then
  old_runtime_hash=$(cat "$current/Dockerfile" "$current/server.py" "$platform/compose.yaml" | sha256sum | cut -d' ' -f1)
fi

if [ "$new_hash" = "$old_hash" ] && [ "$new_runtime_hash" = "$old_runtime_hash" ]; then
  install -m 0644 "$next/content/provenance.json" "$current/content/provenance.json"
  rm -f "$archive"
  echo "Catalog content unchanged; refreshed provenance only ($new_hash)"
  exit 0
fi

rm -rf "$previous"
mv "$current" "$previous"
mv "$next" "$current"
chown -R evie:staff "$current"
cp "$platform/compose.yaml" "$previous_compose"
install -m 0644 "$next_compose" "$platform/compose.yaml"

if (cd "$platform" && docker compose up -d --build catalog-mcp); then
  rm -rf "$previous" "$previous_compose" "$archive"
  echo "Catalog deployed: content=$new_hash runtime=$new_runtime_hash"
else
  rm -rf "$current"
  mv "$previous" "$current"
  mv "$previous_compose" "$platform/compose.yaml"
  (cd "$platform" && docker compose up -d --build catalog-mcp)
  echo "Catalog deployment failed and was rolled back" >&2
  exit 1
fi
