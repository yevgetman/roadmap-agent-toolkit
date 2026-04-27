# roadmap-agent-toolkit

Scaffold automated agentic roadmap workflows into any repo.

An interactive CLI installer generates multi-track backlogs, CI
pipelines, agent contracts, and scheduling infrastructure —
everything needed to run scheduled LLM agents that autonomously
implement a backlog of work items against a staging environment.

## Quick start

### Option A: CLI installer

```bash
git clone https://github.com/yevgetman/roadmap-agent-toolkit.git
cd roadmap-agent-toolkit
./install.sh --target /path/to/your-repo
```

The installer prompts for your stack, how many roadmap tracks you
want, which agent runtime to use, and generates all files in the
target repo. No dependencies beyond `git` and standard POSIX tools.

For non-interactive use, pass a config file:

```bash
./install.sh --config examples/django-heroku-cloudflare/config.yml --target /path/to/your-repo
```

### Option B: Claude Code slash command

If you have Claude Code, run `/init-roadmap` inside any session.
Claude reads the templates and walks you through setup
conversationally — no bash needed.

## What it does

1. You define work items in a YAML backlog with specs
2. Scheduled LLM agents pick up items, implement them, merge to
   staging, wait for CI, and open PRs against production
3. You review and merge the PRs — auto-deploy handles the rest
4. The agent detects the merge, verifies the deploy, and marks
   the item done

The agents' entire world is staging. Production is exclusively
human-controlled.

## What gets generated

```
your-repo/
├── WORKFLOWS.md                        # Branch model + CI rules
├── docs/
│   ├── INFRA.yml                       # Infrastructure mapping
│   ├── ROADMAPS.md                     # Master index
│   ├── roadmap/
│   │   ├── BACKLOG.yml                 # Multi-track work queue
│   │   ├── AGENT_PROMPT.md             # Agent runtime contract
│   │   ├── AUTOMATION.md               # Agent design doc
│   │   ├── README.md                   # Track orientation
│   │   ├── epics/                      # Epic specs (you create)
│   │   └── items/                      # Item specs (you create)
│   └── roadmap-adhoc/                  # Ad-hoc issue agent
│       ├── STATE.yml
│       ├── AGENT_PROMPT.md
│       └── README.md
├── .github/workflows/
│   ├── tests.yml                       # Backend CI
│   ├── frontend-tests.yml              # Frontend CI
│   ├── deploy-prod-backend.yml         # CI-gated prod deploy
│   ├── deploy-prod-frontend.yml        # CI-gated prod deploy
│   ├── deploy-staging-frontend.yml     # Staging frontend deploy
│   └── staging-migrate.yml             # Auto-run migrations
└── .roadmap/                           # Agent infrastructure
    ├── config.yml                      # Saved config (for re-runs)
    ├── setup-agents.sh                 # Install/uninstall/status
    ├── agents/                         # Tick scripts (per runtime)
    │   └── tick-<track>.sh
    └── logs/                           # Agent tick logs
```

## Documentation

- **[Usage guide](docs/USAGE.md)** — installation walkthrough,
  `--config`/`--force` flags, post-install setup
- **[Architecture](docs/ARCHITECTURE.md)** — the workflow pattern,
  status lifecycle, CI pipeline, agent contract, scheduling
- **[Developer reference](docs/DEVELOPER.md)** — file map,
  template variables, profiles, adding platform variants
- **[LLM.md](LLM.md)** — codebase summary for LLM context
  scanning (file map, key abstractions, conventions)

## Platform support

| Component | Options |
|---|---|
| Backend deploy | Heroku, Fly.io, AWS ECS/Fargate, GCP Cloud Run, Railway, Render, Custom |
| Frontend deploy | Cloudflare Pages, Vercel, Netlify, AWS S3+CloudFront, FTP/SFTP, Custom |
| Agent runtime | Claude Code, OpenAI Codex, Open Code, Custom |
| Scheduler | Claude Code routines, launchd (macOS), crontab, GH Actions cron, Custom |
| CI platform | GitHub Actions |
| Issue tracker | GitHub Issues |

## Examples

- [`django-heroku-cloudflare`](examples/django-heroku-cloudflare/) — Django + Heroku + CF Pages (3 tracks)
- [`rails-fly-vercel`](examples/rails-fly-vercel/) — Rails + Fly.io + Vercel (1 track)
- [`nextjs-vercel`](examples/nextjs-vercel/) — Next.js fullstack on Vercel (Codex runtime)
- [`go-aws`](examples/go-aws/) — Go + AWS ECS + S3/CloudFront (2 tracks)

## Design principles

1. **Staging is the agent's world.** Never wait on production.
2. **One item, one tick.** No parallelism within a track.
3. **Human merge gate.** Agent proposes; human disposes.
4. **Provider-agnostic.** Swap LLM, CI, or hosting freely.
5. **Kill switches everywhere.** Per-track `locked` flag.
6. **Audit trail in git.** Status changes are commits.
7. **Fail safe.** Diagnose before blocking; revert, don't force-push.

## Reference implementation

Extracted from [django-munky](https://github.com/yevgetman/django-munky),
where it runs 3 roadmap tracks + an ad-hoc agent, deploying to
Heroku and Cloudflare Pages.

## License

MIT
