#!/bin/sh
set -eu

docker exec -i mcp-platform-catalog python - <<'PY'
import json
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=10) as response:
    value = json.load(response)
if value.get("status") != "healthy":
    raise SystemExit(f"catalog unhealthy: {value}")
print(json.dumps(value, sort_keys=True))
PY
