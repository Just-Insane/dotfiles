#!/bin/sh
set -eu

base=/srv/mcp-platform
backup_dir="$base/backups"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
umask 077
mkdir -p "$backup_dir"

docker compose -f "$base/compose.yaml" exec -T db \
  pg_dump -U mcpjungle -d mcpjungle -Fc > "$backup_dir/mcpjungle-$stamp.dump"
docker compose -f "$base/compose.yaml" exec -T db \
  pg_restore --list < "$backup_dir/mcpjungle-$stamp.dump" >/dev/null

tar -C "$base" -czf "$backup_dir/config-$stamp.tar.gz" \
  compose.yaml prometheus.yml config

find "$backup_dir" -type f -mtime +14 -delete
