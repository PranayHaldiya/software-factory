# software-factory

A software factory that runs on GitHub Actions and Claude Code. Label an issue `factory` and AI stations take it from triage to a reviewed, tested pull request, and merge it when every check is green. It costs nothing beyond a Claude subscription: Actions minutes are free on public repositories, and Claude Code runs on the subscription's OAuth token instead of per-token API billing.

## How it works

```
issue labeled "factory"            (or "factory:queued", picked up by the nightly sweep)
        │
        ▼
  ┌───────────┐  not ready   asks questions on the issue
  │  triage   │ ───────────▶
  │ (Sonnet)  │
  └─────┬─────┘ ready: posts acceptance criteria on the issue
        ▼
  ┌───────────┐
  │ implement │ ──▶ draft pull request on factory/issue-<n>
  │  (Opus)   │
  └───────────┘
        │  every push to the pull request runs:
        ▼
  ┌───────────┐  changes requested   ┌──────────┐
  │  review   │ ───────────────────▶ │  revise  │ ──▶ push (next round; three reviews at most)
  │  (Fable)  │                      │  (Opus)  │
  └─────┬─────┘                      └──────────┘
        │ approved
        ▼
  ┌───────────┐     ┌───────────┐  red   ┌──────────┐
  │ evidence  │ ──▶ │   gate    │ ─────▶ │  ci-fix  │ ──▶ push (two attempts at most)
  │           │     │ waits for │        │  (Opus)  │
  └───────────┘     │ every     │        └──────────┘
                    │ check     │  green
                    └─────┬─────┘ ─────▶ merge (FACTORY_AUTOMERGE=1) or label factory:ready
                          │
                  out of rounds ──▶ label factory:needs-human
```

- **Triage** reads the issue and the relevant code and returns a structured verdict: actionable or not, kind, size, a summary, acceptance criteria, and questions. It only gets read tools. If the item isn't ready, or is too large for one pull request, it asks on the issue instead of building the wrong thing. When it is ready, the criteria are posted on the issue so later stations judge against them.
- **Implement** branches to `factory/issue-<n>`, makes the smallest change that meets the criteria, runs the repository's checks, and opens a draft pull request that lists what it verified.
- **Review** runs on a different model (Fable) from the implementer (Opus). It sees the diff and the triage criteria, not the implementer's notes or pull request description. It marks each criterion met or not, lists findings by severity, and the workflow, not the model, decides the verdict: any unmet criterion or blocker or major finding means changes are requested.
- **Revise** fixes what the review found and pushes, which starts the next round. After three reviews the pull request goes to a person.
- **Evidence** runs the checks from `.github/factory.json` and, when the repository has a UI, takes before and after screenshots of the configured pages and records a short video of the change. They're attached to the pull request with `gh pr comment --attach`.
- **Gate** waits for every other check on the commit: CI, deploy previews, anything. If one fails, **ci-fix** reads the failed logs, fixes the cause and pushes (two attempts). When everything is green the gate merges, if the repository allows it, or labels the pull request `factory:ready` for a person.
- **Each station is a separate Claude Code run** with its own instructions (`stations/*.md`), tool allowlist, model, and turn limit. Stations pass work through files and comments, not a shared conversation.

## Trust model

- Only the repository owner can start the factory: they must have written the issue and applied the label (`factory`, or `factory:queued` for the sweep). Comments from anyone else are filtered out before a station sees the issue.
- The pull request stations only act on `factory/*` branches in the same repository, opened by the factory or the owner. Add `factory:hold` to stop them on a pull request.
- Side effects that don't need judgment (labels, comments, the verdict, waiting for checks, merging) are plain workflow steps, not model actions.
- Each job gets the narrowest `permissions:` block it needs. Untrusted text never goes into a `run:` script through `${{ }}`; it passes through environment variables.
- Checks and evidence settings are read from `.github/factory.json` on the base branch, so a pull request can't change its own checks. The stations are told not to edit the factory's workflows or that file.
- No station can push to the default branch. A branch ruleset blocks it, and the instructions forbid it.
- Merging is opt-in per repository with the variable `FACTORY_AUTOMERGE=1`, and only happens when the review approved the exact head commit, the evidence is posted, and every check passed.

## Setup

1. Install the [Claude GitHub App](https://github.com/apps/claude) on the repository.
2. Create a subscription token with `claude setup-token` (Claude Pro or Max). Save it as the repository secret `CLAUDE_CODE_OAUTH_TOKEN`: `gh secret set CLAUDE_CODE_OAUTH_TOKEN`.
3. Create the `factory` label (`gh label create factory`). The workflows create the other labels they use.
4. Optional: add `.github/factory.json` (below) and an executable `.github/factory-setup.sh` that installs what your checks need. The setup script runs before the implement, revise, evidence, and CI-fix stations.
5. Optional: `gh variable set FACTORY_AUTOMERGE --body 1` to let the factory merge green pull requests.

Running `/install-github-app` inside Claude Code does steps 1 and 2 for you.

To hand work to the factory, open an issue with the "Factory task" form (`.github/ISSUE_TEMPLATE/factory-task.yml`). It asks what should change, why, and how we'll know it's done, and applies the `factory` label. To queue work for the nightly sweep instead, label the issue `factory:queued`. That works from the GitHub app on a phone. Run the "Factory sweep" workflow by hand to start the oldest queued issue, or a given issue number, right away.

If a station fails without a clear reason, set the repository variable `FACTORY_DEBUG` to `1` to print Claude's full output in the run log. Turn it off afterwards: the log then includes tool output.

Mention `@claude` in any issue or pull request comment for one-off questions and changes (`.github/workflows/claude.yml`).

### `.github/factory.json`

```json
{
  "checks": ["npm test", "npm run lint"],
  "evidence": {
    "start": "npm run dev -- --port $PORT",
    "routes": ["/", "/pricing"],
    "ready_path": "/"
  }
}
```

- `checks`: shell commands the evidence station runs and reports. A failure sends the pull request to the CI-fix station.
- `evidence.start`: a command that serves the app on `$PORT`. It runs once on the base branch (before) and once on the pull request (after).
- `evidence.routes`: pages to screenshot. `ready_path` is polled until the server answers.
- Leave `evidence` out for repositories without a UI. This repository's config serves the demo page in `site/`.

### Use it in another repository

The stations are reusable workflows. Copy the three files in [`templates/workflows/`](templates/workflows) into the other repository's `.github/workflows/`, then do the setup steps above there. They call this repository's `factory-issue.yml` and `factory-pr-run.yml` at `main` and read the station instructions from here, so improvements land everywhere at once. Pin `@main` to a commit SHA if you'd rather upgrade by hand.

Inputs you can override in the caller: `reviewer_model`, `implementer_model`, `triage_model`, `max_reviews`, `max_ci_fixes`, `factory_ref`.

## Roadmap

- [x] Station 1: triage, implement, draft pull request
- [x] Station 2: an independent reviewer on a different model that sees only the diff and the criteria, with up to two revision rounds
- [x] Station 3: evidence. Configured checks, before and after screenshots, and a recorded video attached to the pull request
- [x] Station 4: fix red CI on factory branches, and merge on green for repositories that opt in
- [x] Reusable workflows any repository can call, a `factory:queued` label for phone intake, and a nightly sweep
- [ ] Intake from chat (Slack or Telegram) and a weekly report of what the factory shipped

## Credits

The station design (classifier, analyst, implementer, independent reviewer, owner-gated intake) follows Vercel's [eve Software Factory template](https://github.com/vercel-labs/eve-software-factory-template) ("Foreman", MIT). This repository is a separate implementation on GitHub Actions and [claude-code-action](https://github.com/anthropics/claude-code-action); no code is copied from it.

## License

MIT
