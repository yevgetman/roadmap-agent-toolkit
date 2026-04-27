# Developer reference

Technical details for contributors and LLMs scanning the codebase.

## File map

```
roadmap-agent-toolkit/
│
├── README.md                 # User-facing: what this is, quick start, links to docs
├── LICENSE                   # MIT
├── install.sh                # Interactive CLI installer (580 lines, pure bash)
│
├── docs/
│   ├── USAGE.md              # Installation walkthrough + post-install setup
│   ├── ARCHITECTURE.md       # The workflow pattern in full detail
│   └── DEVELOPER.md          # This file — codebase internals
│
├── LLM.md                    # Compact codebase summary for LLM context scanning
├── CLAUDE.md                 # Claude Code rules of engagement
├── AGENTS.md                 # Cross-tool agent rules (mirrors CLAUDE.md)
│
├── templates/                # Files that get copied into the target repo
│   ├── WORKFLOWS.md          # Verbatim copy (vendor-neutral branch model)
│   ├── docs/
│   │   ├── INFRA.yml.tmpl                        # Infrastructure mapping
│   │   ├── ROADMAPS.md.tmpl                      # Master agent index
│   │   ├── roadmap/
│   │   │   ├── BACKLOG.yml.tmpl                  # Multi-track backlog schema
│   │   │   ├── AGENT_PROMPT.md.tmpl              # Agent runtime contract
│   │   │   ├── AUTOMATION.md.tmpl                # Agent design doc
│   │   │   └── README.md.tmpl                    # Track orientation
│   │   └── roadmap-adhoc/
│   │       ├── STATE.yml.tmpl                    # Ad-hoc agent state
│   │       ├── AGENT_PROMPT.md.tmpl              # Ad-hoc agent contract
│   │       └── README.md.tmpl                    # Ad-hoc orientation
│   └── .github/workflows/
│       ├── tests.yml.tmpl                        # Backend CI
│       ├── frontend-tests.yml.tmpl               # Frontend CI
│       ├── deploy-prod-backend/
│       │   ├── heroku.yml.tmpl                   # Heroku backend deploy
│       │   ├── fly.yml.tmpl                      # Fly.io backend deploy
│       │   └── custom.yml.tmpl                   # User-provided command
│       ├── deploy-prod-frontend/
│       │   ├── cloudflare-pages.yml.tmpl         # CF Pages frontend deploy
│       │   ├── vercel.yml.tmpl                   # Vercel frontend deploy
│       │   └── custom.yml.tmpl                   # User-provided command
│       ├── deploy-staging-frontend/
│       │   ├── cloudflare-pages.yml.tmpl         # CF Pages staging deploy
│       │   ├── vercel.yml.tmpl                   # Vercel staging deploy
│       │   └── custom.yml.tmpl                   # User-provided command
│       └── staging-migrate/
│           ├── heroku.yml.tmpl                   # Heroku staging migrations
│           └── custom.yml.tmpl                   # User-provided command
│
└── examples/
    └── django-heroku-cloudflare/
        └── config.json           # What the installer produces for django-munky
```

## Template interpolation

### Variables

Templates use `${__VARIABLE}` placeholders. The installer replaces
them with `sed` (macOS-compatible, no `envsubst` dependency).

| Variable | Example | Used in |
|---|---|---|
| `${__REPO_OWNER}` | `yevgetman` | AGENT_PROMPT, workflows, INFRA |
| `${__REPO_NAME}` | `django-munky` | AGENT_PROMPT, workflows, INFRA |
| `${__PROD_BRANCH}` | `main` | AGENT_PROMPT, workflows |
| `${__STAGING_BRANCH}` | `staging` | AGENT_PROMPT, workflows |
| `${__BACKEND_TEST_CMD}` | `python manage.py test --noinput` | AGENT_PROMPT, tests.yml |
| `${__FRONTEND_TEST_CMD}` | `npm test` | AGENT_PROMPT, frontend-tests.yml |
| `${__FRONTEND_DIR}` | `frontend-legacy` | AGENT_PROMPT, workflows |
| `${__FRONTEND_BUILD_CMD}` | `npm run build` | frontend workflows |
| `${__MIGRATION_CMD}` | `python manage.py migrate --noinput` | staging-migrate, deploy |
| `${__BACKEND_APP_STAGING}` | `myapp-staging` | staging-migrate |
| `${__BACKEND_APP_PROD}` | `myapp-prod` | deploy-prod-backend |
| `${__FRONTEND_PROJECT_STAGING}` | `myapp-staging` | deploy-staging-frontend |
| `${__FRONTEND_PROJECT_PROD}` | `myapp-prod` | deploy-prod-frontend |
| `${__DB_SERVICE}` | `mysql` | tests.yml |
| `${__PYTHON_VERSION}` | `3.12` | tests.yml |
| `${__NODE_VERSION_FILE}` | `frontend/.nvmrc` | frontend workflows |

### Track generation

BACKLOG.yml tracks are variable in count and can't use simple
`sed` replacement. The template has a `# __TRACKS_PLACEHOLDER__`
marker that the installer replaces with YAML generated in a loop.
See the `generate_tracks_yaml()` function in `install.sh`.

### Platform variant selection

The installer picks the correct workflow variant file based on
the user's platform choice. For example, if they choose Heroku:
`templates/.github/workflows/deploy-prod-backend/heroku.yml.tmpl`
is copied and interpolated as
`target-repo/.github/workflows/deploy-prod-backend.yml`.

## install.sh structure

The installer is a single bash script with no external
dependencies. Key functions:

| Function | Purpose |
|---|---|
| `ask()` | Prompt with default value |
| `ask_choice()` | Numbered menu selection |
| `confirm()` | Y/n prompt |
| `generate_file()` | sed-based template interpolation |
| `generate_tracks_yaml()` | Loop to build BACKLOG.yml tracks |
| `select_variant()` | Pick platform-specific workflow |

Flow: validate target → detect repo info → collect config →
generate files → optional GH setup → summary.

## Adding a new platform variant

1. Create a new `.yml.tmpl` file in the appropriate variant
   directory (e.g. `templates/.github/workflows/deploy-prod-backend/railway.yml.tmpl`)
2. Use `${__VARIABLE}` placeholders for app names, commands, etc.
3. Add the option to `install.sh`'s platform selection menu
4. Add any new variables to the interpolation step
5. Update the example config if needed

## Conventions

- Template files end in `.tmpl`; the installer strips the extension
- `WORKFLOWS.md` is the only template copied verbatim (no `.tmpl`)
- All workflow templates are complete, working GH Actions files —
  not skeletons
- The installer warns before overwriting existing files
- Generated files have no runtime dependency on the toolkit repo

## Reference implementation

[django-munky](https://github.com/yevgetman/django-munky) is the
proving ground. Workflow changes are battle-tested there first,
then cascaded here. The cascade rule is documented in django-munky's
CLAUDE.md and AGENTS.md.
