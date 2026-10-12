#!/usr/bin/env bash
# PostToolUse hook: runs after Claude uses Write, Edit or MultiEdit.
#
# Claude Code sends the event as JSON on stdin; the edited file is at
# .tool_input.file_path. Exit 0 means "all good". Exit 2 sends whatever we
# print to stderr back to Claude, so it can fix the problem.

input=$(cat)

# Pull out the file path with jq, or python3 if jq is not installed.
if command -v jq >/dev/null 2>&1; then
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
elif command -v python3 >/dev/null 2>&1; then
  file=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))')
else
  exit 0
fi

# Only check HTML files that exist.
case "$file" in
  *.html|*.htm) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

problems=()

if ! grep -qi '<title>[^<]' "$file"; then
  problems+=("missing or empty <title>")
fi

# Count <img> tags with no alt attribute.
missing_alt=$(grep -oi '<img[^>]*>' "$file" | grep -vic 'alt=')
if [ "$missing_alt" -gt 0 ]; then
  problems+=("$missing_alt <img> tag(s) without alt text")
fi

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "starter-kit HTML check for $file:"
    printf ' - %s\n' "${problems[@]}"
  } >&2
  exit 2
fi

exit 0
