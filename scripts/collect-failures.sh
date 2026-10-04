#!/usr/bin/env bash
# Collect what failed on a commit for the CI-fix station: failing checks, the failed
# steps' logs from GitHub Actions runs, and the factory's own check report.
# Usage: collect-failures.sh <sha> <base-branch> <output-file>
set -uo pipefail

sha="$1"
base="$2"
out="$3"
here="$(cd "$(dirname "$0")" && pwd)"

{
  echo "# What failed on ${sha:0:7}"
  echo
  echo "## Failing checks"
  echo
  # shellcheck disable=SC2016 # $c is a jq variable
  gh api --paginate "repos/$GITHUB_REPOSITORY/commits/$sha/check-runs?per_page=100" --jq '
    .check_runs[]
    | select(.status == "completed")
    | select(.conclusion as $c | ["success", "neutral", "skipped"] | index($c) | not)
    | select(.name | test("factory|^claude$"; "i") | not)
    | "- \(.name): \(.conclusion) (\(.details_url))"'
  gh api "repos/$GITHUB_REPOSITORY/commits/$sha/status" --jq '
    .statuses[] | select(.state == "failure" or .state == "error") | "- \(.context): \(.state) (\(.target_url))"'
  echo

  for id in $(gh run list --repo "$GITHUB_REPOSITORY" --commit "$sha" --json databaseId,conclusion,workflowName \
      --jq '.[] | select(.conclusion == "failure") | select(.workflowName | test("^Factory") | not) | .databaseId'); do
    echo "## Failed steps in run $id"
    echo
    echo '```'
    gh run view "$id" --repo "$GITHUB_REPOSITORY" --log-failed 2>&1 | tail -n 150
    echo '```'
    echo
  done

  echo "## Configured checks (.github/factory.json)"
  echo
  report="$(mktemp)"
  "$here/run-checks.sh" "$base" "$report"
  cat "$report"
  rm -f "$report"
} > "$out"
