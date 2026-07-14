#!/bin/sh
set -eu

source_dir=${1:-.}
d2_bin=${D2_BIN:-d2}
layout=${D2_LAYOUT:-elk}
theme=${D2_THEME:-200}
dark_theme=${D2_DARK_THEME:-200}
pad=${D2_PAD:-32}

if ! command -v "$d2_bin" >/dev/null 2>&1; then
  echo "D2 is required. On macOS, install it with: brew install d2" >&2
  exit 1
fi

if ! test -d "$source_dir"; then
  echo "D2 source directory does not exist: $source_dir" >&2
  exit 1
fi

found=false
count=0
for source in "$source_dir"/*.d2; do
  if ! test -f "$source"; then
    continue
  fi
  found=true
  output=${source%.d2}.svg
  "$d2_bin" validate "$source"
  "$d2_bin" --layout "$layout" --theme "$theme" --dark-theme "$dark_theme" \
    --pad "$pad" --omit-version "$source" "$output"
  count=$((count + 1))
done

if test "$found" = false; then
  echo "No .d2 sources found in: $source_dir" >&2
  exit 1
fi

echo "Rendered $count D2 diagram(s)."
