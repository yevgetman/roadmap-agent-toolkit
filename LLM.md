# LLM.md — codebase summary for context scanning

This file gives an LLM enough context to work on this repo
without reading every file. Scan this first; read specific files
only when needed.

## What this repo is

An interactive CLI installer (`install.sh`) that scaffolds
automated agentic roadmap workflows into any git repo. It
generates backlogs, agent contracts, CI pipelines, and deploy
workflows from templates — everything needed to run scheduled LLM
agents that autonomously implement work items against a staging
environment.

## Key abstractions

**Template** (`.tmpl` file) — a file with `${__VARIABLE}`
placeholders that `sed` replaces during installation. Lives under
`templates/`. The installer copies the interpolated result into
the target repo without the `.tmpl` extension.

**Platform variant** — a set of alternative `.tmpl` files for the
same workflow, one per hosting platform (e.g.
`deploy-prod-backend/heroku.yml.tmpl` vs `fly.yml.tmpl`). The
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

## File map

```
.
├── install.sh              # 580-line bash installer (the only executable)
├── README.md               # User-facing: quick start, what gets generated
├── LLM.md                  # THIS FILE
├── CLAUDE.md               # Rules of engagement for Claude Code sessions
├── AGENTS.md               # Same rules, cross-tool format
├── LICENSE                  # MIT
│
├── docs/
│   ├── USAGE.md            # Installation walkthrough + post-install
│   ├── ARCHITECTURE.md     # Full workflow pattern reference
│   └── DEVELOPER.md        # File map, template vars, adding variants
│
├── templates/              # Everything below here → target repo
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
│   └── .github/workflows/
│       ├── tests.yml.tmpl                        # Backend CI
│       ├── frontend-tests.yml.tmpl               # Frontend CI
│       ├── deploy-prod-backend/{heroku,fly,custom}.yml.tmpl
│       ├── deploy-prod-frontend/{cloudflare-pages,vercel,custom}.yml.tmpl
│       ├── deploy-staging-frontend/{cloudflare-pages,vercel,custom}.yml.tmpl
│       └── staging-migrate/{heroku,custom}.yml.tmpl
│
└── examples/
    └── django-heroku-cloudflare/config.json      # Reference config
```

## How template interpolation works

1. User answers interactive prompts → values stored in bash vars
2. For each `.tmpl` file: `sed` replaces `${__VAR}` → write to
   target repo without `.tmpl` extension
3. BACKLOG.yml is special: the `# __TRACKS_PLACEHOLDER__` marker
   is replaced by YAML generated in a loop (one block per track)
4. Platform-specific workflows: installer picks the correct
   variant file from the subdirectory

16 interpolation variables — see `docs/DEVELOPER.md` for the
complete table.

## What the installer does NOT do

- Run any code in the target repo (no builds, no tests)
- Install dependencies
- Create commits (files are generated but not committed)
- Schedule agents (post-install step the user does)
- Manage secrets (user sets them in GitHub)

## Conventions

- Pure bash, no external dependencies beyond git + sed
- All templates are complete, working files (not skeletons)
- `WORKFLOWS.md` is the only non-templated file (copied verbatim)
- Generated files have zero dependency on this toolkit repo
- django-munky is the reference implementation and proving ground
