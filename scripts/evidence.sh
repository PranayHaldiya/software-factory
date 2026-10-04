#!/usr/bin/env bash
# Screenshot the routes in .github/factory.json "evidence" on the base branch (before) and
# on the pull request (after), and record a short video of the after state.
# The config is read from the base branch. Without an "evidence" block this does nothing.
# Usage: evidence.sh <base-branch> <output-dir>
set -euo pipefail

base="$1"
out="$2"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"

config=$(git show "origin/$base:.github/factory.json" 2>/dev/null || echo '{}')
start=$(jq -r '.evidence.start // empty' <<<"$config")
if [ -z "$start" ]; then
  echo "evidence: no \"evidence\" block in .github/factory.json, skipping screenshots"
  exit 0
fi
routes=$(jq -r '(.evidence.routes // ["/"]) | join(",")' <<<"$config")
ready=$(jq -r '.evidence.ready_path // "/"' <<<"$config")

pw="${RUNNER_TEMP:-/tmp}/factory-playwright"
mkdir -p "$pw"
cp "$here/evidence.mjs" "$pw/"
(
  cd "$pw"
  [ -f package.json ] || npm init -y >/dev/null
  npm install --no-audit --no-fund --silent playwright@1 >/dev/null
  npx playwright install --with-deps chromium >/dev/null
)

pids=()
serve() { # <dir> <port>
  # Redirect the whole subshell so no server holds this script's stdout open.
  (cd "$1" && PORT="$2" exec bash -c "$start") > "$pw/server-$2.log" 2>&1 < /dev/null &
  pids+=("$!")
}
stop_servers() {
  for pid in "${pids[@]}"; do
    pkill -P "$pid" 2> /dev/null || true
    kill "$pid" 2> /dev/null || true
  done
}
trap stop_servers EXIT
wait_up() { # <port>
  for _ in $(seq 1 90); do
    curl -fsS "http://localhost:$1$ready" > /dev/null 2>&1 && return 0
    sleep 2
  done
  echo "evidence: server on port $1 did not start" >&2
  tail -n 20 "$pw/server-$1.log" >&2 || true
  return 1
}

basedir="$pw/base"
rm -rf "$basedir"
git worktree add --quiet --detach "$basedir" "origin/$base"

serve "$basedir" 4101
serve "$PWD" 4102

if wait_up 4101; then
  node "$pw/evidence.mjs" "http://localhost:4101" "$routes" before "$out"
else
  echo "evidence: skipping before screenshots"
fi
wait_up 4102
node "$pw/evidence.mjs" "http://localhost:4102" "$routes" after "$out" --video

git worktree remove --force "$basedir" || true
ls -1 "$out"
