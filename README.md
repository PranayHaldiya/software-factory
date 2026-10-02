# software-factory

A software factory that runs on GitHub Actions and Claude Code. Label an issue `factory` and AI stations take it from triage to a draft pull request. It costs nothing beyond a Claude subscription: Actions minutes are free on public repositories, and Claude Code runs on the subscription's OAuth token instead of per-token API billing.

> Status: station 1 (triage and implement). The roadmap below lists what comes next. The factory builds its own later stations from issues in this repository.

## How it works

```
issue labeled "factory"
        │
        ▼
  ┌───────────┐  not ready   ┌──────────────────────────────┐
  │  triage   │ ───────────▶ │ asks questions on the issue  │
  │ (Sonnet)  │              └──────────────────────────────┘
  └─────┬─────┘
        │ ready
        ▼
  ┌───────────┐              ┌──────────────────────────────┐
  │ implement │ ───────────▶ │ draft PR: summary, criteria, │
  │  (Opus)   │              │ verification, Closes #N      │
  └───────────┘              └──────────────────────────────┘
```

- **Triage** reads the issue and the relevant code, then returns a structured verdict: actionable or not, kind, size, a summary, acceptance criteria, and questions. It only gets read tools. If the item isn't ready, or is too large for one pull request, the workflow asks on the issue instead of building the wrong thing.
- **Implement** branches to `factory/issue-<n>`, makes the smallest change that meets the criteria, runs the repository's own checks, and opens a draft pull request that lists what it verified.
- **Each station is a separate Claude Code run** with its own instructions (`stations/*.md`), tool allowlist, model, and turn limit. Stations pass work through files, not shared conversation.

## Trust model

- Only the repository owner can start the factory: the owner must have written the issue and applied the label. Comments from anyone else are filtered out before a station sees the issue.
- Side effects that don't need judgment (labels, comments, failure reports) are plain workflow steps, not model actions.
- Each job gets the narrowest `permissions:` block it needs. Untrusted text never goes into a `run:` script through `${{ }}`; it passes through environment variables.
- The implementer can't push to the default branch. A branch ruleset blocks it, and the station instructions forbid it.
- Merging stays with a person until the reviewer and evidence stations exist.

## Setup

1. Install the [Claude GitHub App](https://github.com/apps/claude) on the repository.
2. Create a subscription token with `claude setup-token` (Claude Pro or Max). Save it as the repository secret `CLAUDE_CODE_OAUTH_TOKEN`: `gh secret set CLAUDE_CODE_OAUTH_TOKEN`.
3. Create the labels: `factory`, `factory:needs-info`, `factory:pr-open`, `factory:failed`.
4. Optional: add an executable `.github/factory-setup.sh` that installs what your checks need. It runs before the implementer.

Running `/install-github-app` inside Claude Code does steps 1 and 2 for you.

To hand work to the factory, open an issue with the "Factory task" form (`.github/ISSUE_TEMPLATE/factory-task.yml`). It asks what should change, why, and how we'll know it's done, and applies the `factory` label for you. Blank issues are still allowed.

If a station fails without a clear reason, set the repository variable `FACTORY_DEBUG` to `1` (`gh variable set FACTORY_DEBUG --body 1`) to print Claude's full output in the run log. Turn it off afterwards: the log then includes tool output.

Mention `@claude` in any issue or pull request comment for one-off questions and changes (`.github/workflows/claude.yml`).

## Roadmap

- [x] Station 1: triage, implement, draft pull request
- [ ] Station 2: an independent reviewer on a different model that sees only the diff and the criteria, with up to two revision rounds
- [ ] Station 3: evidence. Playwright before/after screenshots and a recorded video attached to the pull request
- [ ] Station 4: fix red CI on factory branches, and merge on green with evidence, for allowlisted repositories
- [ ] Reusable workflow so any repository can call the factory, plus intake from a phone and a nightly sweep of the backlog

## Credits

The station design (classifier, analyst, implementer, independent reviewer, owner-gated intake) follows Vercel's [eve Software Factory template](https://github.com/vercel-labs/eve-software-factory-template) ("Foreman", MIT). This repository is a separate implementation on GitHub Actions and [claude-code-action](https://github.com/anthropics/claude-code-action); no code is copied from it.

## License

MIT
