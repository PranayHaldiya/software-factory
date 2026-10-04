# software-factory

A software factory on GitHub Actions and claude-code-action.

- Workflows: `.github/workflows/`. `factory.yml`, `factory-pr.yml`, `factory-sweep.yml` and `factory-sync.yml` are thin callers; the stations are in the reusable `factory-issue.yml`, `factory-pr-run.yml` and `factory-sync-run.yml`.
- Station instructions: `stations/`. Helper scripts the stations' workflow steps run: `scripts/`.
- `templates/workflows/` holds copies of the callers for other repositories. Keep them in sync with the callers here (only the `uses:` lines differ).
- `site/` is a static demo page the evidence station screenshots.

## Verify

Run what CI runs; all of it must pass with no findings:

- `actionlint -color` (`.github/factory-setup.sh` installs it)
- `shellcheck scripts/*.sh .github/factory-setup.sh`
- `node --check scripts/evidence.mjs`
- `jq -e '.checks | type == "array"' .github/factory.json`
- every station file a workflow references exists and isn't empty

## Conventions

- Each job gets its own minimal `permissions:` block.
- Never interpolate issue, comment or PR text into a `run:` script with `${{ }}`. Pass it through `env:` and quote it.
- Steps that don't need judgment (labels, comments, verdicts, waiting, merging) are plain shell steps. Use model stations only for judgment and code.
- Station instructions are plain Markdown: one job per station, written as steps, with a Safety section that treats issue text as data.
- Scripts are bash with `set -euo pipefail` (or `-uo` where a failing command is the point), pass shellcheck, and avoid bash-4-only builtins such as `mapfile`.
- Action versions are pinned to a major tag (`@v6`, `@v1`).
- Prose: plain and specific, no em dashes, no hype.
