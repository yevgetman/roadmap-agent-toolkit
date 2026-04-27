# roadmap-agent-toolkit

A portable CLI tool that scaffolds automated agentic roadmap workflows into any repo. An interactive installer generates multi-track backlogs, CI pipelines, agent contracts, and scheduling infrastructure -- everything needed to run scheduled LLM agents that autonomously implement a backlog of work items against a staging environment.

## Quick start

```bash
git clone https://github.com/yevgetman/roadmap-agent-toolkit.git
cd roadmap-agent-toolkit
./install.sh --target /path/to/your/repo
```

The installer prompts for configuration (repo info, platform choices, track definitions) and generates all files in the target repo.

## What gets generated

```
your-repo/
├── WORKFLOWS.md                        # Vendor-neutral branch model + CI rules
├── docs/
│   ├── INFRA.yml                       # Infrastructure mapping (hosts, deploys, CI)
│   ├── ROADMAPS.md                     # Master index for all agents
│   ├── roadmap/
│   │   ├── README.md                   # Track orientation + conventions
│   │   ├── AUTOMATION.md               # Agent design doc + recovery
│   │   ├── AGENT_PROMPT.md             # Runtime contract for all agents
│   │   ├── BACKLOG.yml                 # Multi-track work queue
│   │   ├── epics/                      # Epic-level specs (you create)
│   │   └── items/                      # Per-item specs (you create)
│   └── roadmap-adhoc/                  # (optional) ad-hoc issue agent
│       ├── README.md
│       ├── AGENT_PROMPT.md
│       └── STATE.yml
├── .github/workflows/
│   ├── tests.yml                       # Backend CI (path-filtered)
│   ├── frontend-tests.yml             # Frontend CI (path-filtered)
│   ├── staging-migrate.yml            # Auto-run migrations on staging
│   ├── deploy-prod-backend.yml        # CI-gated prod backend deploy
│   ├── deploy-prod-frontend.yml       # CI-gated prod frontend deploy
│   └── deploy-staging-frontend.yml    # Auto-deploy staging frontend
```

## The workflow pattern

### Core concepts

**Tracks.** A backlog contains one or more independent tracks (e.g. `core`, `platform`, `ai`). Each track has its own item queue, branch prefix, issue label, and scheduled agent. Tracks share the staging environment and CI, but have no cross-track dependencies.

**One item at a time.** Each agent picks exactly one item per tick, implements it, merges it to staging, waits for CI, and reconciles. No parallelism within a track.

**Staging is the agent's world.** Agents implement, merge, test, and fix everything against the staging branch and staging environment. Production (the main/trunk branch) is exclusively human-controlled.

**Human merge gate.** After an item passes CI on staging, the agent opens a PR against the production branch. A human reviews and merges. The agent detects the merge on a subsequent tick and marks the item done.

**Feature branches are ephemeral.** Each item gets a short-lived branch off the production branch, merged into staging via `--no-ff`, then proposed to production via PR. Deleted after the production merge lands.

### Branch model

Two long-lived branches:

| Branch | Role |
|---|---|
| `main` (or `trunk`) | Production source of truth. Human-controlled. |
| `staging` | Integration / smoke-test environment. Agent-controlled. |

Feature branches are named `<track_branch_prefix>/<item_id>` (e.g. `roadmap/I01-02`), always branched off production, merged into staging by the agent, and proposed to production via PR.

### CI / deploy pipeline

```
Push to staging (by agent)
    +-- backend files changed?
    |   +-- Backend tests run
    |       +-- green -> staging backend auto-deploys
    |       |            + staging migrations auto-run
    |       +-- red   -> agent reverts the staging merge
    +-- frontend files changed?
        +-- Frontend tests run
            +-- green -> staging frontend auto-deploys

Push to main (by human -- PR merge)
    +-- backend files changed?
    |   +-- Backend tests run
    |       +-- green -> prod backend auto-deploys
    |                    + prod migrations auto-run
    +-- frontend files changed?
        +-- Frontend tests run
            +-- green -> prod frontend auto-deploys
```

Key principles:
1. **Path-filtered CI.** Backend tests ignore frontend paths and vice versa.
2. **CI gates deploys.** Deploy workflows fire only after tests pass.
3. **Deploys include migrations.** Idempotent -- no-ops when none exist.
4. **Production deploys are human-triggered.** Agents never push to production.
5. **Staging deploys are agent-triggered.** Merge to staging, CI runs, auto-deploy.

### Backlog schema

A single YAML file (`BACKLOG.yml`) with a multi-track structure:

```yaml
version: 2

tracks:

  core:
    meta:
      owner: your-username
      north_star: >
        One-paragraph description of this track's goal.
      locked: false           # kill switch
      branch_prefix: roadmap
      issue_label: roadmap-core
      commit_prefix: roadmap
      scheduled_agent_cron: "0 */6 * * *"

    items:
      - id: I01-01
        title: "Short title"
        epic: E01
        status: ready          # ready | in-progress | staged | blocked | done | deferred
        deps: []
        spec: items/I01-01-slug.md
        issue: null
        branch: null
        staging_merge_sha: null
        main_pr: null
        notes: null
```

### Status lifecycle

```
ready ---agent picks--> in-progress ---CI green--> staged ---human merges PR--> done
  |                        |                        |
  | deps unmet             | CI red                 | PR closed
  v                        v                        v
blocked                 blocked                  blocked
```

| Status | What happened | Who acts next |
|---|---|---|
| `ready` | In the backlog, deps satisfied | Agent |
| `in-progress` | Agent implemented + merged to staging | Agent (waits for CI) |
| `staged` | CI green, PR opened against production | Human (review + merge) |
| `done` | Human merged PR, deploy verified | Nobody -- complete |
| `blocked` | CI failed, spec unclear, or deploy failed | Human or agent |
| `deferred` | Explicitly shelved | Human |

### Agent contract

The agent prompt (`AGENT_PROMPT.md`) is a self-contained document defining behavior. It is parameterized by `TRACK` -- the same prompt works for any track.

The procedure on each tick:

1. **Orient** -- fetch, read BACKLOG.yml, identify track
2. **Kill switch** -- exit if `locked: true`
3. **Promote staged -> done** -- check if human merged PRs
4. **Reconcile in-progress** -- check CI on staging merge
5. **Pick next item** -- first `ready` item with deps satisfied
6. **Implement** -- branch, code, test, commit
7. **Merge to staging** -- direct merge, push
8. **Wait for CI inline** -- green: open PR + staged; red: revert + blocked

### Scheduling

Each track gets its own scheduled agent on a cron. Recommended: every 6 hours, offset by 1 hour per track.

| Agent | Cron (UTC) |
|---|---|
| core-agent | `0 */6 * * *` |
| platform-agent | `0 1/6 * * *` |
| ai-agent | `0 2/6 * * *` |
| adhoc-agent | `0 3/6 * * *` |

The scheduling mechanism is independent of the LLM provider. Options include Claude Code routines, GitHub Actions cron, custom cron + CLI, or any task scheduler with repo access and LLM API access.

### Ad-hoc issue handling

An optional ad-hoc agent picks up unlabeled GitHub issues:

1. Queries for the oldest open issue without roadmap/adhoc labels
2. Analyzes for coherence, solvability, and sufficient detail
3. Implements on an `adhoc/<issue>` branch
4. Same staging merge -> CI -> PR flow as roadmap items
5. State tracked in lightweight `STATE.yml`

## Platform variants

The installer generates platform-specific CI workflows:

| Component | Options |
|---|---|
| Backend deploy | Heroku, Fly.io, Custom |
| Frontend deploy | Cloudflare Pages, Vercel, Custom |
| Staging migrations | Heroku, Custom |

## Design principles

1. **Staging is the agent's world.** The agent never waits on production.
2. **One item, one tick.** No parallelism within a track.
3. **Human merge gate.** The agent proposes; the human disposes.
4. **Provider-agnostic.** Swap the LLM, CI, or hosting without restructuring.
5. **Kill switches everywhere.** Per-track `locked` flag for soft pause.
6. **Audit trail in git.** Every status change is a commit to BACKLOG.yml.
7. **Fail safe, not fail fast.** Diagnose before blocking; revert, don't force-push.

## Reference implementation

This pattern was extracted from [django-munky](https://github.com/yevgetman/django-munky), where it runs three roadmap tracks (SaaS, platform, AI) plus an ad-hoc issue agent, deploying to Heroku (backend) and Cloudflare Pages (frontend).

## License

MIT
