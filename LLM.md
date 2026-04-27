# LLM.md — codebase summary for context scanning

This file gives an LLM enough context to work on this repo
without reading every file. Scan this first; read specific files
only when needed.

## What this repo is

An interactive CLI installer (`install.sh`) that scaffolds
automated agentic roadmap workflows into any git repo. It
generates backlogs, agent contracts, CI pipelines, deploy
workflows, tick scripts, and scheduling infrastructure from
templates and deploy profiles — everything needed to run scheduled
LLM agents that autonomously implement work items against a
staging environment.

## Key abstractions

**Template** (`.tmpl` file) — a file with `${__VARIABLE}`
placeholders that `sed` replaces during installation. Lives under
`templates/`. The installer copies the interpolated result into
the target repo without the `.tmpl` extension.

**Profile** (YAML in `profiles/`) — a declarative description of
a deploy platform, agent runtime, or scheduler. Each profile
defines prompts to ask the user, deploy commands, required
secrets, health checks, and agent fallbacks. The installer loads
the selected profile and uses its values during template
interpolation. Four categories: `backend/`, `frontend/`,
`agents/`, `schedulers/`.

**Platform variant** — a set of alternative `.tmpl` files for the
same workflow, one per hosting platform (e.g.
`deploy-prod-backend/heroku.yml.tmpl` vs `aws-ecs.yml.tmpl`). The
installer picks the right one based on the user's choice.

**Track** — an independent lane in the backlog (e.g. `core`,
`platform`, `ai`). Each track has its own items, branch prefix,
issue label, and scheduled agent. Tracks share staging + CI but
have no cross-dependencies.

**Agent contract** (`AGENT_PROMPT.md.tmpl`) — the prompt that
defines all agent behavior. Parameterized by `TRACK`. Contains
hard rules, the full procedure (Steps 0-7), CI failure handling,
deploy verification, conflict resolution, and the "staging is
your world" principle.

**Tick script** (`.roadmap/agents/tick*.sh.tmpl`) — a shell script
that invokes the agent CLI for one tick. Generated per-track for
non-Claude-Code runtimes (Codex, Open Code, custom). Claude Code
uses built-in routines and does not need a tick script.

**Scheduler** — the mechanism that fires agent ticks on a cron.
Options: Claude Code routines (built-in), launchd (macOS),
crontab (Linux), GitHub Actions cron, or custom. Scheduler
templates live in `profiles/schedulers/` and
`templates/.roadmap/schedulers/`.

## File map

```
.
├── install.sh                  # ~1700-line bash installer (the only executable)
├── defaults.yml                # Config schema: every option with type, default, prompt
├── README.md                   # User-facing: quick start, what gets generated
├── LLM.md                     # THIS FILE
├── CLAUDE.md                  # Rules of engagement for Claude Code sessions
├── AGENTS.md                  # Same rules, cross-tool format
├── LICENSE                    # MIT
│
├── profiles/                  # Declarative platform/runtime profiles
│   ├── backend/               # 7 backend deploy profiles
│   │   ├── heroku.yml
│   │   ├── fly.yml
│   │   ├── aws-ecs.yml
│   │   ├── gcp-cloud-run.yml
│   │   ├── railway.yml
│   │   ├── render.yml
│   │   └── custom.yml
│   ├── frontend/              # 6 frontend deploy profiles
│   │   ├── cloudflare-pages.yml
│   │   ├── vercel.yml
│   │   ├── netlify.yml
│   │   ├── aws-s3-cloudfront.yml
│   │   ├── ftp.yml
│   │   └── custom.yml
│   ├── agents/                # 4 agent runtime profiles
│   │   ├── claude-code.yml
│   │   ├── codex.yml
│   │   ├── open-code.yml
│   │   └── custom.yml
│   └── schedulers/            # 4 scheduler profiles
│       ├── github-actions.yml
│       ├── launchd.yml
│       ├── crontab.yml
│       └── custom.yml
│
├── .claude/commands/          # Claude Code slash commands
│   ├── init-roadmap.md        # /init-roadmap — conversational setup
│   ├── roadmap-status.md      # /roadmap-status — backlog summary
│   ├── add-track.md           # /add-track — add a track to BACKLOG.yml
│   └── add-item.md            # /add-item — create spec + backlog entry
│
├── docs/
│   ├── USAGE.md               # Installation walkthrough + post-install
│   ├── ARCHITECTURE.md        # Full workflow pattern reference
│   ├── DEVELOPER.md           # File map, template vars, adding variants
│   └── BUILD.md               # Build plan tracker (all 11 items complete)
│
├── templates/                 # Everything below here → target repo
│   ├── WORKFLOWS.md                              # Verbatim (no placeholders)
│   ├── docs/
│   │   ├── INFRA.yml.tmpl                        # Infra mapping
│   │   ├── ROADMAPS.md.tmpl                      # Master index
│   │   ├── roadmap/
│   │   │   ├── BACKLOG.yml.tmpl                  # Backlog (has __TRACKS_PLACEHOLDER__)
│   │   │   ├── AGENT_PROMPT.md.tmpl              # Agent contract (most complex template)
│   │   │   ├── AUTOMATION.md.tmpl                # Design doc
│   │   │   └── README.md.tmpl                    # Track orientation
│   │   └── roadmap-adhoc/
│   │       ├── STATE.yml.tmpl
│   │       ├── AGENT_PROMPT.md.tmpl
│   │       └── README.md.tmpl
│   ├── .github/workflows/
│   │   ├── tests.yml.tmpl                        # Backend CI
│   │   ├── frontend-tests.yml.tmpl               # Frontend CI
│   │   ├── agent-tick.yml.tmpl                   # GH Actions agent scheduler
│   │   ├── deploy-prod-backend/                  # 7 variants
│   │   │   └── {heroku,fly,aws-ecs,gcp-cloud-run,railway,render,custom}.yml.tmpl
│   │   ├── deploy-prod-frontend/                 # 6 variants
│   │   │   └── {cloudflare-pages,vercel,netlify,aws-s3-cloudfront,ftp,custom}.yml.tmpl
│   │   ├── deploy-staging-frontend/              # 6 variants (same platforms)
│   │   │   └── {cloudflare-pages,vercel,netlify,aws-s3-cloudfront,ftp,custom}.yml.tmpl
│   │   └── staging-migrate/                      # 7 variants
│   │       └── {heroku,fly,aws-ecs,gcp-cloud-run,railway,render,custom}.yml.tmpl
│   └── .roadmap/
│       ├── .gitignore                            # Excludes logs + generated plists
│       ├── setup-agents.sh.tmpl                  # Unified install/uninstall/status
│       ├── agents/
│       │   ├── tick.sh.tmpl                      # Claude Code tick (reference)
│       │   ├── tick-codex.sh.tmpl                # Codex tick
│       │   ├── tick-open-code.sh.tmpl            # Open Code tick
│       │   └── tick-custom.sh.tmpl               # Custom runtime tick
│       └── schedulers/
│           └── launchd.plist.tmpl                # macOS LaunchAgent template
│
├── tests/
│   ├── run.sh                              # Test runner
│   ├── test_syntax.sh                      # install.sh bash syntax check
│   ├── test_help_flag.sh                   # --help output validation
│   ├── test_bad_target.sh                  # Graceful failure on bad path
│   ├── test_no_leftover_vars.sh            # No malformed placeholders
│   ├── test_templates_valid_yaml.sh        # Workflow structural checks
│   └── test_all_profiles_have_workflows.sh # Profile/template alignment
│
└── examples/                              # Reference configs
    ├── django-heroku-cloudflare/config.yml # 3 tracks, Django+Heroku+CF Pages
    ├── rails-fly-vercel/config.yml         # 1 track, Rails+Fly+Vercel
    ├── nextjs-vercel/config.yml            # 1 track, Next.js fullstack, Codex
    └── go-aws/config.yml                   # 2 tracks, Go+AWS ECS+S3/CF
```

## How install.sh works

1. **Parse flags** — `--target`, `--config`, `--force`, `--help`
2. **Load config or prompt interactively** — if `--config` is
   given, parse the YAML config file and skip prompts; otherwise
   run the interactive flow
3. **Auto-detect** — scan target repo for `manage.py`, `Gemfile`,
   `go.mod`, `Cargo.toml` to pre-fill test/migration commands;
   check for `claude`/`codex` CLI to pre-select agent runtime
4. **Collect config** — repository info, backend platform, frontend
   platform, test commands, CI settings, tracks, ad-hoc agent,
   agent runtime, scheduler
5. **Load profiles** — read the selected backend, frontend, agent,
   and scheduler profiles from `profiles/`
6. **Generate files** — for each template, `sed`-replace
   `${__VARIABLE}` placeholders and write to target repo
7. **Handle existing files** — if a target file exists, show
   skip/overwrite/all menu (unless `--force` is set)
8. **Save config** — write resolved config to
   `<target>/.roadmap/config.yml` for re-runs
9. **Optional GH setup** — create labels, staging branch,
   auto-delete setting (if `gh` CLI available)
10. **Print summary** — generated files, required secrets,
    scheduling instructions

### Flags

| Flag | Purpose |
|---|---|
| `--target <path>` | Target repo path (prompted if omitted) |
| `--config <file>` | Non-interactive mode: read config from YAML |
| `--force` | Overwrite existing files without prompting |
| `--help` | Show usage and exit |

## How template interpolation works

1. User answers interactive prompts (or values come from `--config`)
   → values stored in bash vars
2. For each `.tmpl` file: `sed` replaces `${__VAR}` → write to
   target repo without `.tmpl` extension
3. BACKLOG.yml is special: the `# __TRACKS_PLACEHOLDER__` marker
   is replaced by YAML generated in a loop (one block per track)
4. Platform-specific workflows: installer picks the correct
   variant file from the subdirectory

47 interpolation variables — see `docs/DEVELOPER.md` for the
complete table.

## What the installer does NOT do

- Run any code in the target repo (no builds, no tests)
- Install dependencies
- Create git commits (files are generated but not committed)
- Schedule agents (generates scripts; user runs setup)
- Manage secrets (user sets them in GitHub)

## Slash commands (Claude Code)

Alternative to `install.sh` — run inside a Claude Code session:

| Command | Purpose |
|---|---|
| `/init-roadmap` | Conversational setup — reads templates and generates files |
| `/roadmap-status` | Reads BACKLOG.yml and summarizes state per track |
| `/add-track` | Adds a new track to an existing BACKLOG.yml |
| `/add-item` | Creates a spec file and adds a backlog entry |

## Conventions

- Pure bash, no external dependencies beyond git + sed
- All templates are complete, working files (not skeletons)
- `WORKFLOWS.md` is the only non-templated file (copied verbatim)
- Generated files have zero dependency on this toolkit repo
- django-munky is the reference implementation and proving ground
- Config schema lives in `defaults.yml`; profiles provide
  platform-specific values
