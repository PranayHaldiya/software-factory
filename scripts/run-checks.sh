#!/usr/bin/env bash
# Run the commands listed under "checks" in .github/factory.json and write a Markdown report.
# The config is read from the base branch, so a pull request can't change its own checks.
# Usage: run-checks.sh <base-branch> <report-file>
# Exit code: 0 when every check passes or none are configured, 1 otherwise.
set -uo pipefail

base="$1"
report="$2"

config=$(git show "origin/$base:.github/factory.json" 2>/dev/null || echo '{}')
checks=()
while IFS= read -r line; do checks+=("$line"); done < <(jq -r '.checks[]? // empty' <<<"$config")

if [ "${#checks[@]}" -eq 0 ]; then
  echo "No checks are configured in \`.github/factory.json\`." > "$report"
  exit 0
fi

: > "$report"
status=0
for cmd in "${checks[@]}"; do
  output=$(bash -c "$cmd" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    result="passed"
  else
    result="**failed** (exit $code)"
    status=1
  fi
  {
    echo "- \`$cmd\`: $result"
    if [ -n "$output" ]; then
      echo
      echo '  ```'
      tail -n 30 <<<"$output" | sed 's/^/  /'
      echo '  ```'
    fi
  } >> "$report"
done
exit "$status"
