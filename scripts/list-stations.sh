#!/usr/bin/env bash
# Print each station file and its first "# " heading.
# Usage: scripts/list-stations.sh (from the repository root)
set -euo pipefail

for f in stations/*.md; do
  heading=$(grep -m 1 '^# ' "$f" | sed 's/^# //' || true)
  [ -n "$heading" ] && printf '%s\t%s\n' "$(basename "$f")" "$heading" || printf '%s\t%s\n' "$(basename "$f")" "(no heading)"
done
