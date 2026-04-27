# WORKFLOWS.md — Code Development & CI Workflow

> This file describes the **preferred development workflow and CI gating pattern**.
> It is intentionally **portable** — no references to specific cloud vendors,
> platform names, host URLs, or app names. Drop this file into another repo
> and it should still make sense.
>
> For the concrete infrastructure mapping (which host runs what, which branch
> deploys where, which CI workflow gates which environment, etc.) see the
> companion **`INFRA.yml`** file alongside this one.

## Branch model

Two long-lived branches:

| Branch | Role |
|---|---|
| `main` | Production source of truth. Every commit here is eligible to ship to production. |
| `staging` | Integration / smoke-test environment source. Disposable. |

All other branches are **short-lived** and always branched off `main`:

| Prefix | Use |
|---|---|
| `feature/<slug>` | New functionality |
| `fix/<slug>` | Bug fixes |
| `chore/<slug>` | Housekeeping (docs, deps, tooling) |

### Branching rules

1. **Always branch off an up-to-date `main`.** Never branch off `staging` —
   `staging` is disposable integration state, not a source of truth.
   ```bash
   git checkout main && git pull
   git checkout -b feature/<slug>
   ```
2. **Never commit directly to `main` or `staging`.** They only receive
   merge commits produced by merging a feature/fix/chore branch.
3. **Never `git push --force` to `main`** (or any branch that production
   deploys from). It rewrites history and can strand downstream consumers.
4. **`staging` may be force-reset from `main`** — and ONLY from `main` —
   when every commit currently on `staging` is already represented in an
   open feature/fix branch (i.e. no work will be lost):
   ```bash
   git checkout staging && git reset --hard main
   git push --force-with-lease origin staging
   ```
5. **Never bypass git hooks** (`--no-verify`, `--no-gpg-sign`, etc.)
   without an explicit ask. If a hook fails, diagnose and fix the
   underlying issue.

## Lifecycle of a feature / fix branch

```
  main -branch-> feature/<slug> -merge-> staging   (-> deploy to staging)
    ^                                        |
    +-------------- merge (after approval) --+
                  |
                  deploy to production per deploy rules
                  |
                  confirm deploy success
                  |
                  delete branch (local + remote)
```

1. **Start from `main`.** Up-to-date, clean working tree.
2. **Develop on the branch.** Small, reviewable commits. Push the branch
   early if you want CI to build it against a PR.
3. **Open a PR against `main`.** PRs always target `main` — never
   `staging`. Merges into `staging` are administrative smoke-test
   pushes, not reviewed merges.
4. **Optional staging smoke test.** Merge the branch into `staging`
   (`git checkout staging && git merge --no-ff <branch>`) and push.
   Verify the resulting staging deploy is healthy.
5. **Merge the same branch into `main`.** Via the PR (when CI is green
   and a reviewer approves), or `git merge --no-ff <branch>` locally
   when appropriate.
6. **Ship to production** per the repo's deployment rules (see
   "Deployment" below and `INFRA.yml`).
7. **Confirm deploy success.** Wait for the platform's "green deploy"
   signal before declaring the work done.
8. **Delete the branch — locally AND on the remote.** Any open PR
   auto-closes when its head ref is deleted from the remote.
   ```bash
   git branch -d <branch>
   git push origin --delete <branch>
   ```

## Issue tracking

Most non-trivial changes should be tied to a GitHub issue for a
searchable history — "what was reported, how we verified, what the
fix was, when it shipped."

1. **User reports a bug or asks for a feature** in conversation
   (not as a GH issue).
2. **Verify first.** Reproduce the bug or locate the offending code;
   for a feature, confirm scope. If the claim turns out to be wrong
   or already fixed, say so instead of filing — don't create noise
   issues.
3. **Open a GH issue** (`gh issue create`) with a concrete summary,
   reproduction steps, expected vs. actual, and a suspected root
   cause / file pointer when you have one.
4. **Branch + fix + PR.** Commit messages reference the issue
   (`Fix #N: ...`). The PR description uses `Closes #N` so the issue
   auto-closes when the PR merges.
5. **Exception — trivial changes.** One-line typos, comment tweaks,
   low-risk copy edits, etc. can go straight to a branch + PR
   without an issue. The test is not "did it take me five minutes"
   but **"would a reader a year from now want a trail?"**
6. An issue with an open PR = on staging waiting for approval. A
   closed issue = shipped to prod. This mapping makes the state of
   in-flight work legible at a glance.

## Pull requests

- PRs target `main` only.
- Title is short and action-oriented (under 70 characters). Details
  go in the body, not the title.
- Body includes a brief summary and a test plan — especially for
  UI changes that CI can't fully verify.
- **No forced merges to main without approval.** Even when CI is
  green, the human reviewer is the merge gate.

## CI

Test suites are **path-gated**: a backend-only commit runs only the
backend suite, a frontend-only commit runs only the frontend suite,
a commit touching both runs both. The concrete workflow files and
their path filters are documented in `INFRA.yml`.

CI workflows should trigger on:

| Event | Branches |
|---|---|
| `push` | `main` **and** `staging` |
| `pull_request` | `main` only |

Why `staging` on push: any platform auto-deploy gate attached to
pushes to `staging` needs CI to actually run, so the gate has checks
to wait on.

### CI gate behavior — the absent-check gotcha

A CI workflow that is **skipped** (because `paths-ignore` excluded
all changed files, e.g. a docs-only commit) produces an **absent**
check on that commit. An absent check is not the same as a red
check: many hosting platforms' "wait for checks to pass" deploy
gates hang **indefinitely** waiting for a check that will never
arrive.

Know for each of your environments:
- Which CI workflow is required for the deploy gate
- Whether a docs-only / frontend-only / backend-only commit would
  skip it
- The manual-deploy bypass (dashboard button, direct platform push,
  etc.) — `INFRA.yml` documents each.

### Rules for contributors

1. **Run the relevant suite locally before declaring work
   complete.** Don't "push and hope CI is green" — in this repo
   some deploy paths bypass the CI gate (see `INFRA.yml`), so a
   red CI on a deployed change is a real failure mode.
2. **If local runs aren't practical** (missing env, slow DB start,
   host mismatch), you may rely on CI — but then you MUST verify
   the CI run on your commit is green before the task is
   considered done. Never declare work complete while CI is red,
   pending, or absent-when-expected.
3. **When adding a new feature** with non-trivial logic, add a
   corresponding test in the same PR. Follow established patterns
   in each suite.
4. **If CI is red, diagnose and fix** — don't push over it, don't
   `--no-verify` around it, don't retry hoping for flake.

## Deployment

The **concrete deployment model** (which platforms, which branches
auto-deploy, which require manual triggers, which gates apply) lives
in `INFRA.yml`. The generic principles:

1. **Deploys to production require explicit user approval for the
   specific deploy.** "User asked me to commit" is NOT approval to
   deploy. Phrases like "deploy this", "ship it", "deploy and
   monitor" are.
2. **Automatic deploys are OK for production frontends** (static
   assets, no data risk) as long as the CI gate can catch
   regressions before they ship. They are **not** OK for production
   backends without an explicit approval gate.
3. **Staging auto-deploy is encouraged** — the point of staging is
   to exercise the deploy path often and catch environment-specific
   issues before prod.
4. **Any deploy path that bypasses CI** (e.g. a direct platform-
   remote push that skips the GitHub-integration gate) must be
   treated as a build trigger — verify CI yourself before using it.

## Sensitive operations — always confirm

Generic categories:

- Direct production-data writes (SQL, admin shell modifications,
  API endpoints that bypass app guardrails)
- Full reindexes / re-syncs that are memory- or time-heavy
- Smoke tests or replay tools targeting production (they touch
  real rows)
- Force-pushes, history rewrites, tag/branch deletions on shared
  refs
- Third-party-visible actions (sending emails, posting to external
  APIs, publishing packages)

The repo-specific list of sensitive ops is in `CLAUDE.md` /
`AGENTS.md` under "Sensitive Operations".
