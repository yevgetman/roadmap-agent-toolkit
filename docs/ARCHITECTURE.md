# Architecture

The complete workflow pattern that this toolkit scaffolds.

## Core concepts

**Tracks.** A backlog contains one or more independent tracks
(e.g. `core`, `platform`, `ai`). Each track has its own item
queue, branch prefix, issue label, and scheduled agent. Tracks
share the staging environment and CI but have no cross-track
dependencies.

**One item at a time.** Each agent picks exactly one item per
tick, implements it, merges it to staging, waits for CI, and
reconciles. No parallelism within a track.

**Staging is the agent's world.** Agents implement, merge, test,
and fix everything against the staging branch and staging
environment. Production is exclusively human-controlled. If an
agent ever concludes "this needs a production merge," it is
almost certainly wrong — the fix is always on staging.

**Human merge gate.** After an item passes CI on staging, the
agent opens a PR against the production branch. A human reviews
and merges. The auto-deploy pipeline handles the rest. The agent
detects the merge on a subsequent tick, verifies the deploy
succeeded, and marks the item done.

**Feature branches are ephemeral.** Each item gets a short-lived
branch off the production branch, merged into staging via
`--no-ff`, then proposed to production via PR. Automatically
deleted when the PR merges.

## Branch model

Two long-lived branches:

| Branch | Role |
|---|---|
| `main` (or `trunk`) | Production source of truth. Human-controlled. |
| `staging` | Integration environment. Agent-controlled. |

Feature branches:
- Named `<branch_prefix>/<item_id>` (e.g. `roadmap/I01-02`)
- Always branched off the production branch
- Merged into `staging` by the agent (direct merge, no PR)
- Proposed to production via PR (human merges)

Rules:
- Never branch off `staging`
- Never force-push to shared branches
- To undo a bad staging merge: `git revert -m 1` (new commit)
- Enable "Automatically delete head branches" in repo settings

## CI / deploy pipeline

Two independent lanes — backend and frontend — each path-filtered
so changes to one don't trigger the other.

```
Push to staging (by agent)
    ├── backend files changed?
    │   └── Backend tests run
    │       ├── green → staging backend auto-deploys
    │       │           + staging migrations auto-run
    │       └── red → agent reverts the staging merge
    └── frontend files changed?
        └── Frontend tests run
            └── green → staging frontend auto-deploys

Push to main (by human — PR merge)
    ├── backend files changed?
    │   └── Backend tests run
    │       └── green → prod backend auto-deploys
    │                   + prod migrations auto-run
    └── frontend files changed?
        └── Frontend tests run
            └── green → prod frontend auto-deploys

Docs-only push → neither CI runs → no deploy fires
```

### Key principles

1. **Path-filtered CI.** Backend tests ignore frontend paths and
   vice versa. Docs-only changes trigger nothing.
2. **CI gates deploys.** Deploy workflows use `workflow_run`
   triggers that fire only after tests succeed.
3. **Deploys include migrations.** Idempotent — safely no-ops
   when none exist.
4. **Production deploys are human-triggered.** The auto-deploy
   pipeline fires on pushes to production, but those pushes are
   exclusively human actions (PR merges). Agents never push code
   to the production branch.
5. **Staging deploys are agent-triggered.** Agents merge feature
   branches into staging and push. CI + auto-deploy follow.

### Concurrency

- Test workflows: `cancel-in-progress: true` (new push supersedes)
- Deploy workflows: `cancel-in-progress: false` (never interrupt)
- Migration workflows: `cancel-in-progress: false` (queue, don't stomp)

### Full clone for deploys

If your hosting platform deploys via `git push`, use
`fetch-depth: 0` in `actions/checkout`. Many platforms reject
shallow-clone pushes.

## Backlog schema (version 2)

```yaml
version: 2

tracks:
  <track_name>:
    meta:
      owner: <username>
      north_star: >
        One-paragraph goal for this track.
      locked: false              # kill switch
      branch_prefix: <prefix>    # e.g. "roadmap"
      issue_label: <label>       # e.g. "roadmap-core"
      commit_prefix: <prefix>    # e.g. "roadmap"
      scheduled_agent_cron: "0 */6 * * *"

    items:
      - id: <PREFIX>01-01
        title: "Short title"
        epic: <EPIC_ID>
        status: ready
        deps: []
        spec: items/<PREFIX>01-01-slug.md
        issue: null              # GH issue number (agent fills)
        branch: null             # branch name (agent fills)
        staging_merge_sha: null  # merge commit on staging (agent fills)
        main_pr: null            # PR number against production (agent fills)
        notes: null
```

### Adding a track

1. Add a key under `tracks:` with `meta:` and `items:`
2. Pick a unique ID prefix, branch prefix, and issue label
3. Create the issue label in GitHub (with a distinct color)
4. Schedule an agent with `TRACK` set to the new key

### Kill switch

Set `tracks.<name>.meta.locked: true`, commit, push to production
branch. Agent exits immediately on next tick.

### Labeling

Every issue and PR must carry the track's label. The `--label`
flag on `gh pr create` and `gh issue create` is mandatory.

## Status lifecycle

```
                                                human merges PR
                                                + auto-deploy succeeds
ready ──agent picks──▶ in-progress ──CI green──▶ staged ──────────────▶ done
  │                        │                        │                    │
  │ deps unmet             │ CI red                  │ PR closed          │ issue
  ▼                        ▼                        ▼                    │ auto-closed
blocked                 blocked                  blocked                 ▼
                                                                      complete
```

| Status | What happened | Who acts next |
|---|---|---|
| `ready` | In the backlog, deps satisfied | Agent (next tick) |
| `in-progress` | Implemented + merged to staging, CI running | Agent (waits for CI) |
| `staged` | CI green, PR opened against production | Human (review + merge) |
| `done` | PR merged, deploy verified, issue closed | Nobody — complete |
| `blocked` | CI failed, spec unclear, or deploy failed | Human or agent |
| `deferred` | Explicitly shelved | Human |

## Agent contract

The agent prompt (`AGENT_PROMPT.md`) defines all behavior. It is
parameterized by `TRACK` — one prompt works for all tracks.

### Hard rules

0. **Staging is your world.** Never gate on production.
1. Never push code to production branch (only BACKLOG.yml updates)
2. Production environment is off-limits
3. Staging is unlocked — deploy, migrate, set env vars freely
4. Never force-push to shared branches
5. Never commit secrets
6. One in-progress item per track
7. Never skip git hooks
8. Only touch files the item spec authorizes
9. Respect the kill switch
10. Mark items requiring manual/external work as blocked
11. Only operate on your own track

### Procedure per tick

1. Orient — fetch, read BACKLOG, identify track
2. Kill switch — exit if locked
3. Promote staged → done — verify deploy before marking done
4. Reconcile in-progress — check CI, diagnose failures on staging
5. Pick next ready item
6. Ensure GH issue exists
7. Implement — branch, code, test, commit
8. Merge to staging — direct merge, push
9. Wait for CI inline — green: PR + staged; red: fix or revert

### CI failure handling

**Diagnose within staging, never gate on production.** Before
blocking, check if the fix is doable on the feature branch
(renumber a migration, fix a test, fix an import). If fixable,
fix and re-merge in the same tick. Only revert + block as a last
resort. Notes must describe a staging-side fix path, never a
production-merge dependency.

### Deploy verification (Step 3)

Before marking `done`, the agent verifies the deploy workflow
succeeded on the merge commit:
- Success → done
- Failure → blocked (not done)
- Still running → skip, check next tick
- No run triggered (docs-only) → proceed

## Scheduling

Each track gets its own agent on a cron. Recommended: every 6
hours, offset 1 hour per track so no two fire simultaneously.

| Agent | Cron (UTC) | Fires at |
|---|---|---|
| core-agent | `0 */6 * * *` | 00, 06, 12, 18 |
| platform-agent | `0 1/6 * * *` | 01, 07, 13, 19 |
| ai-agent | `0 2/6 * * *` | 02, 08, 14, 20 |
| adhoc-agent | `0 3/6 * * *` | 03, 09, 15, 21 |

Runtime options (provider-agnostic):
- Claude Code routines
- GitHub Actions cron
- Custom cron + CLI
- Any task scheduler with repo access + LLM API

Empty backlog: agent exits cleanly. Cron keeps firing — picks up
new items when added. Only cancel manually when a track is retired.

## Ad-hoc issue handling

An optional agent picks up GitHub issues that aren't part of any
roadmap track:

1. Queries for oldest open issue without roadmap/adhoc labels
2. Analyzes coherence, solvability, sufficient detail
3. Not actionable → label + comment + exit
4. Needs clarification → questions + label + exit
5. Actionable → implement on `adhoc/<N>` branch
6. Same staging → CI → PR flow as roadmap items
7. State tracked in `STATE.yml` (in-flight only; removed on done)

Label state machine:
```
(no label) → analyzes → adhoc:in-progress → adhoc:staged → (issue closed)
                    ├→ adhoc:not-actionable
                    └→ adhoc:needs-clarification
```

## Design principles

1. **Staging is the agent's world.** Never wait on production.
2. **One item, one tick.** Simple to reason about, simple to recover.
3. **Human merge gate.** Agent proposes; human disposes. Production
   deploys are triggered by human actions only.
4. **Provider-agnostic.** LLM, CI, hosting are all swappable.
5. **Kill switches everywhere.** Per-track `locked` flag.
6. **Audit trail in git.** `git log -- BACKLOG.yml` is the history.
7. **Fail safe.** Diagnose before blocking. Revert with commits,
   not force-pushes.
