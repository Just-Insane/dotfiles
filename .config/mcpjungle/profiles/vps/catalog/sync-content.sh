#!/bin/sh
set -eu

catalog_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
content_dir="$catalog_dir/content"
vault=${KNOWLEDGE_VAULT:-$HOME/git/Knowledge-Platform}

rm -rf "$content_dir"
mkdir -p "$content_dir/prompts" "$content_dir/skills/agents" \
  "$content_dir/skills/claude" "$content_dir/skills/codex"

rsync -a --delete "$vault/_meta/prompts/" "$content_dir/prompts/"

copy_skill_docs() {
  source_dir=$1
  destination=$2
  [ -d "$source_dir" ] || return 0
  rsync -a --prune-empty-dirs \
    --include '*/' --include '*.md' --include '*.yaml' --include '*.yml' \
    --exclude '.git/' --exclude '.system/' --exclude '*' \
    "$source_dir/" "$destination/"
}

copy_skill_docs "$HOME/.agents/skills" "$content_dir/skills/agents"
copy_skill_docs "$HOME/.claude/skills" "$content_dir/skills/claude"
copy_skill_docs "$HOME/.codex/skills" "$content_dir/skills/codex"

find "$content_dir" -name '._*' -delete

find "$content_dir" -type f -print | LC_ALL=C sort
