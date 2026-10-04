#!/usr/bin/env bash
# Write an issue and the owner's comments on it as Markdown.
# Comments from anyone else never reach a station.
# Usage: write-issue.sh <issue-number> <output-file>
set -euo pipefail

issue="$1"
out="$2"
owner="${GITHUB_REPOSITORY_OWNER:?}"

gh issue view "$issue" --repo "$GITHUB_REPOSITORY" --json number,title,body,comments |
  jq -r --arg owner "$owner" '
    "# Issue #\(.number): \(.title)\n\n\(.body // "")\n\n## Comments from the owner\n\n"
    + ([.comments[] | select(.author.login == $owner) | "- \(.body)"] | join("\n"))
  ' > "$out"
