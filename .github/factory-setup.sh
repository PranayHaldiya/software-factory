#!/usr/bin/env bash
# Runs before the implementer station (and in CI) so the repository's checks can run.
# This repository's only check is actionlint.
set -euo pipefail

ACTIONLINT_VERSION=1.7.12
BIN="$HOME/.local/bin"

mkdir -p "$BIN"
bash <(curl -fsSL "https://raw.githubusercontent.com/rhysd/actionlint/v${ACTIONLINT_VERSION}/scripts/download-actionlint.bash") "$ACTIONLINT_VERSION" "$BIN"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$BIN" >> "$GITHUB_PATH"
fi
