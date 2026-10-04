#!/usr/bin/env bash
# Write what the reviewer checks against: the triage acceptance criteria and the owner's issue.
# The criteria come from the triage comment the factory posts on the issue (marker
# `<!-- factory:criteria -->`, written by github-actions). Without one, the reviewer judges
# against the issue alone.
# Usage: write-criteria.sh <issue-number> <output-file>
set -euo pipefail

issue="$1"
out="$2"
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp)"

"$here/write-issue.sh" "$issue" "$tmp"

triage=$(gh issue view "$issue" --repo "$GITHUB_REPOSITORY" --json comments --jq '
  [.comments[]
   | select(.author.login | test("^(app/)?github-actions"))
   | select(.body | startswith("<!-- factory:criteria -->"))]
  | last | .body // ""' |
  awk '/^```json$/ {on=1; next} /^```$/ {on=0} on')

{
  echo "# Acceptance criteria"
  echo
  if [ -n "$triage" ] && jq -e . >/dev/null 2>&1 <<<"$triage"; then
    jq -r '"Summary: \(.summary)\n", (.acceptance_criteria[] | "- \(.)")' <<<"$triage"
  else
    echo "No triage criteria were found. Judge the change against the issue below."
  fi
  echo
  cat "$tmp"
} > "$out"
rm -f "$tmp"
