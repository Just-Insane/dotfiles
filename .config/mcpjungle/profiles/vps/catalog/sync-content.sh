#!/bin/sh
set -eu

catalog_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$catalog_dir/sync_catalog.py"
