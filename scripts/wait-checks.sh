#!/usr/bin/env bash
# Wait for every check on a commit to finish, except the factory's own jobs and @claude.
# Counts check runs from any app plus commit statuses (Vercel and similar).
# Usage: wait-checks.sh <sha> [timeout-seconds]
# Writes state=success|failure|timeout and failed=<names> to $GITHUB_OUTPUT when set.
set -euo pipefail

sha="$1"
timeout="${2:-1800}"
skip='factory|^claude$'
start=$(date +%s)
out="${GITHUB_OUTPUT:-/dev/stdout}"

while :; do
  runs=$(gh api --paginate "repos/$GITHUB_REPOSITORY/commits/$sha/check-runs?per_page=100" \
    --jq '.check_runs[] | {name, status, conclusion}' | jq -s .)
  statuses=$(gh api "repos/$GITHUB_REPOSITORY/commits/$sha/status" \
    --jq '[.statuses[] | {name: .context, status: (if .state == "pending" then "in_progress" else "completed" end), conclusion: .state}]')
  all=$(jq -s --arg skip "$skip" 'add | [.[] | select(.name | test($skip; "i") | not)]' <<<"$runs"$'\n'"$statuses")

  total=$(jq length <<<"$all")
  pending=$(jq '[.[] | select(.status != "completed")] | length' <<<"$all")
  elapsed=$(( $(date +%s) - start ))

  # Checks can take a few seconds to register after a push; don't call "no checks" too early.
  if [ "$pending" -eq 0 ] && { [ "$total" -gt 0 ] || [ "$elapsed" -ge 90 ]; }; then
    failed=$(jq -r '[.[] | select(.conclusion as $c | ["success", "neutral", "skipped"] | index($c) | not) | .name] | unique | join(", ")' <<<"$all")
    jq -r '.[] | "\(.name): \(.conclusion)"' <<<"$all" >&2
    if [ -z "$failed" ]; then
      echo "state=success" >> "$out"
    else
      echo "state=failure" >> "$out"
    fi
    echo "failed=$failed" >> "$out"
    exit 0
  fi

  if [ "$elapsed" -ge "$timeout" ]; then
    echo "state=timeout" >> "$out"
    echo "failed=$(jq -r '[.[] | select(.status != "completed") | .name] | join(", ")' <<<"$all")" >> "$out"
    exit 0
  fi
  sleep 20
done
