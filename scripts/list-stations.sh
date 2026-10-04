#!/usr/bin/env bash
# Print each station file and its first "# " heading.
# Usage: scripts/list-stations.sh (from the repository root)
set -euo pipefail

for f in stations/*.md; do
  [ -e "$f" ] || continue
  heading=$(grep -m 1 '^# ' "$f" | sed 's/^# //' || true)
  if [ -z "$heading" ]; then
    heading='(no heading)'
  fi
  printf '%s\t%s\n' "$(basename "$f")" "$heading"
done
