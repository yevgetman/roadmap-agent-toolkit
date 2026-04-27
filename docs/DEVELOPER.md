# Developer reference

Technical details for contributors and LLMs scanning the codebase.

## File map

```
roadmap-agent-toolkit/
│
├── README.md                 # User-facing: what this is, quick start, links to docs
├── LICENSE                   # MIT
├── install.sh                # Interactive CLI installer (~1700 lines, pure bash)
├── defaults.yml              # Config schema: every option with type, default, prompt
│
├── profiles/                 # Declarative platform/runtime profiles
│   ├── backend/
│   │   ├── heroku.yml             # Heroku: git-push deploy, full clone
│   │   ├── fly.yml                # Fly.io: flyctl deploy
│   │   ├── aws-ecs.yml            # AWS ECS/Fargate: Docker + ECR
│   │   ├── gcp-cloud-run.yml      # GCP Cloud Run: Docker + Artifact Registry
│   │   ├── railway.yml            # Railway: railwayapp deploy
│   │   ├── render.yml             # Render: API-triggered deploy
│   │   └── custom.yml             # User-provided deploy commands
│   ├── frontend/
│   │   ├── cloudflare-pages.yml   # Cloudflare Pages: wrangler
│   │   ├── vercel.yml             # Vercel: vercel CLI
│   │   ├── netlify.yml            # Netlify: netlify-cli
│   │   ├── aws-s3-cloudfront.yml  # AWS S3 + CloudFront invalidation
│   │   ├── ftp.yml                # FTP/SFTP: lftp
│   │   └── custom.yml             # User-provided deploy commands
│   ├── agents/
│   │   ├── claude-code.yml        # Claude Code: built-in routines
│   │   ├── codex.yml              # OpenAI Codex CLI
│   │   ├── open-code.yml          # Open Code CLI
│   │   └── custom.yml             # User-provided agent CLI
│   └── schedulers/
│       ├── github-actions.yml     # GH Actions cron workflow
│       ├── launchd.yml            # macOS LaunchAgent
│       ├── crontab.yml            # Linux/macOS crontab
│       └── custom.yml             # User-provided scheduler
│
├── .claude/commands/         # Claude Code slash commands
│   ├── init-roadmap.md            # /init-roadmap — conversational setup
│   ├── roadmap-status.md          # /roadmap-status — backlog summary
│   ├── add-track.md               # /add-track — new track to BACKLOG
│   └── add-item.md                # /add-item — spec file + entry
│
├── docs/
│   ├── USAGE.md              # Installation walkthrough + post-install setup
│   ├── ARCHITECTURE.md       # The workflow pattern in full detail
│   ├── DEVELOPER.md          # This file — codebase internals
│   └── BUILD.md              # Build plan tracker (all 11 items complete)
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
│   ├── .github/workflows/
│   │   ├── tests.yml.tmpl                        # Backend CI
│   │   ├── frontend-tests.yml.tmpl               # Frontend CI
│   │   ├── agent-tick.yml.tmpl                   # GH Actions agent scheduler
│   │   ├── deploy-prod-backend/
│   │   │   ├── heroku.yml.tmpl
│   │   │   ├── fly.yml.tmpl
│   │   │   ├── aws-ecs.yml.tmpl
│   │   │   ├── gcp-cloud-run.yml.tmpl
│   │   │   ├── railway.yml.tmpl
│   │   │   ├── render.yml.tmpl
│   │   │   └── custom.yml.tmpl
│   │   ├── deploy-prod-frontend/
│   │   │   ├── cloudflare-pages.yml.tmpl
│   │   │   ├── vercel.yml.tmpl
│   │   │   ├── netlify.yml.tmpl
│   │   │   ├── aws-s3-cloudfront.yml.tmpl
│   │   │   ├── ftp.yml.tmpl
│   │   │   └── custom.yml.tmpl
│   │   ├── deploy-staging-frontend/
│   │   │   ├── cloudflare-pages.yml.tmpl
│   │   │   ├── vercel.yml.tmpl
│   │   │   ├── netlify.yml.tmpl
│   │   │   ├── aws-s3-cloudfront.yml.tmpl
│   │   │   ├── ftp.yml.tmpl
│   │   │   └── custom.yml.tmpl
│   │   └── staging-migrate/
│   │       ├── heroku.yml.tmpl
│   │       ├── fly.yml.tmpl
│   │       ├── aws-ecs.yml.tmpl
│   │       ├── gcp-cloud-run.yml.tmpl
│   │       ├── railway.yml.tmpl
│   │       ├── render.yml.tmpl
│   │       └── custom.yml.tmpl
│   └── .roadmap/
│       ├── .gitignore                            # Excludes logs + generated plists
│       ├── setup-agents.sh.tmpl                  # Unified scheduler management
│       ├── agents/
│       │   ├── tick.sh.tmpl                      # Claude Code tick (reference)
│       │   ├── tick-codex.sh.tmpl                # Codex tick
│       │   ├── tick-open-code.sh.tmpl            # Open Code tick
│       │   └── tick-custom.sh.tmpl               # Custom runtime tick
│       └── schedulers/
│           └── launchd.plist.tmpl                # macOS LaunchAgent
│
├── tests/                    # Bash test suite
│   ├── run.sh                     # Test runner (runs all test_*.sh)
│   ├── test_syntax.sh             # install.sh bash syntax check
│   ├── test_help_flag.sh          # --help exits 0, mentions flags
│   ├── test_bad_target.sh         # Graceful failure on bad path
│   ├── test_no_leftover_vars.sh   # No malformed ${__ placeholders
│   ├── test_templates_valid_yaml.sh  # Workflow structural checks
│   └── test_all_profiles_have_workflows.sh  # Profile-template alignment
│
└── examples/                 # Reference configs
    ├── django-heroku-cloudflare/config.yml   # 3 tracks
    ├── rails-fly-vercel/config.yml           # 1 track
    ├── nextjs-vercel/config.yml              # 1 track, Codex runtime
    └── go-aws/config.yml                     # 2 tracks, AWS stack
```

## Template interpolation

### Variables

Templates use `${__VARIABLE}` placeholders. The installer replaces
them with `sed` (macOS-compatible, no `envsubst` dependency).

#### Core variables

| Variable | Example | Used in |
|---|---|---|
| `${__REPO_OWNER}` | `yevgetman` | AGENT_PROMPT, workflows, INFRA |
| `${__REPO_NAME}` | `django-munky` | AGENT_PROMPT, workflows, INFRA |
| `${__PROD_BRANCH}` | `main` | AGENT_PROMPT, workflows |
| `${__STAGING_BRANCH}` | `staging` | AGENT_PROMPT, workflows |
| `${__BACKEND_TEST_CMD}` | `python manage.py test --noinput` | AGENT_PROMPT, tests.yml |
| `${__FRONTEND_TEST_CMD}` | `npm test` | AGENT_PROMPT, frontend-tests.yml |
| `${__FRONTEND_DIR}` | `frontend-legacy` | AGENT_PROMPT, workflows |
| `${__FRONTEND_BUILD_CMD}` | `npm run build` | Frontend workflows |
| `${__MIGRATION_CMD}` | `python manage.py migrate --noinput` | staging-migrate, deploy |
| `${__BACKEND_APP_STAGING}` | `myapp-staging` | staging-migrate |
| `${__BACKEND_APP_PROD}` | `myapp-prod` | deploy-prod-backend |
| `${__FRONTEND_PROJECT_STAGING}` | `myapp-staging` | deploy-staging-frontend |
| `${__FRONTEND_PROJECT_PROD}` | `myapp-prod` | deploy-prod-frontend |
| `${__NODE_VERSION_FILE}` | `frontend/.nvmrc` | Frontend workflows |

#### CI variables

| Variable | Example | Used in |
|---|---|---|
| `${__DB_SERVICE}` | `mysql` | tests.yml |
| `${__PYTHON_VERSION}` | `3.12` | tests.yml |

#### AWS ECS variables

| Variable | Example | Used in |
|---|---|---|
| `${__AWS_REGION}` | `us-east-1` | ECS + S3/CF workflows |
| `${__ECR_REPO}` | `123456789.dkr.ecr...` | ECS deploy |
| `${__ECS_CLUSTER_PROD}` | `my-cluster-prod` | deploy-prod-backend |
| `${__ECS_CLUSTER_STAGING}` | `my-cluster-staging` | staging-migrate |
| `${__ECS_SUBNET}` | `subnet-abc123` | ECS deploy |
| `${__ECS_SG}` | `sg-def456` | ECS deploy |

#### GCP Cloud Run variables

| Variable | Example | Used in |
|---|---|---|
| `${__GCP_PROJECT_ID}` | `my-project` | Cloud Run workflows |
| `${__GCP_REGION}` | `us-central1` | Cloud Run workflows |
| `${__ARTIFACT_REGISTRY_REPO}` | `us-central1-docker.pkg.dev/...` | Cloud Run deploy |

#### AWS S3 + CloudFront variables

| Variable | Example | Used in |
|---|---|---|
| `${__CLOUDFRONT_DIST_PROD}` | `E1234567890` | deploy-prod-frontend |
| `${__CLOUDFRONT_DIST_STAGING}` | `E0987654321` | deploy-staging-frontend |

#### FTP/SFTP variables

| Variable | Example | Used in |
|---|---|---|
| `${__FTP_PROTOCOL}` | `sftp` | FTP workflows |
| `${__FTP_HOST_PROD}` | `ftp.example.com` | deploy-prod-frontend |
| `${__FTP_HOST_STAGING}` | `staging.ftp.example.com` | deploy-staging-frontend |
| `${__FTP_REMOTE_PATH_PROD}` | `/var/www/html` | deploy-prod-frontend |
| `${__FTP_REMOTE_PATH_STAGING}` | `/var/www/staging` | deploy-staging-frontend |

#### Render variables

| Variable | Example | Used in |
|---|---|---|
| `${__RENDER_SERVICE_ID_PROD}` | `srv-abc123` | deploy-prod-backend |
| `${__RENDER_SERVICE_ID_STAGING}` | `srv-def456` | staging-migrate |

#### Netlify variables

| Variable | Example | Used in |
|---|---|---|
| `${__NETLIFY_SITE_ID_PROD}` | `abc-123-def` | deploy-prod-frontend |
| `${__NETLIFY_SITE_ID_STAGING}` | `def-456-ghi` | deploy-staging-frontend |

#### Agent + scheduler variables

| Variable | Example | Used in |
|---|---|---|
| `${__AGENT_RUNTIME}` | `claude-code` | setup-agents.sh, INFRA |
| `${__AGENT_MODEL}` | `claude-sonnet-4-6` | setup-agents.sh |
| `${__AGENT_INVOKE_COMMAND}` | `claude --model ...` | tick scripts |
| `${__AGENT_INSTALL_COMMAND}` | `npm install -g @anthropic/...` | agent-tick GHA |
| `${__AGENT_GHA_INVOKE_COMMAND}` | `claude ...` | agent-tick GHA |
| `${__SCHEDULER}` | `launchd` | setup-agents.sh |
| `${__CRON_EXPRESSION}` | `0 */6 * * *` | scheduler templates |
| `${__CADENCE_HOURS}` | `6` | setup-agents.sh |
| `${__CADENCE_SECONDS}` | `21600` | launchd plist |
| `${__TRACK_NAME}` | `core` | tick scripts, agent-tick GHA |
| `${__TRACKS_ARRAY}` | `core platform ai` | setup-agents.sh |

#### Path/environment variables

| Variable | Example | Used in |
|---|---|---|
| `${__REPO_ROOT}` | `/Users/me/code/myrepo` | tick scripts |
| `${__HOME}` | `/Users/me` | launchd plist |

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

## Profile structure

Profiles are YAML files in `profiles/` that describe a platform,
runtime, or scheduler. The installer loads the selected profile
to determine what prompts to show and what values to interpolate.

### Deploy profile (backend/frontend)

```yaml
name: "Human-readable name"
slug: "file-system-slug"

prompts:                        # Questions asked during install
  - key: app_name_staging       # Internal key
    prompt: "Staging app name"  # Display text
    default: "${repo_name}-staging"  # Default (supports refs)

deploy:
  staging:
    command: "..."              # Deploy command template
  production:
    command: "..."
    full_clone: true            # Needs fetch-depth: 0?

migration:
  staging:
    command: "..."              # Migration command
  production:
    command: "..."

health_check:                   # Optional health check commands
  staging:
    command: "..."
  production:
    command: "..."

secrets:                        # Required GH Actions secrets
  - name: HEROKU_API_KEY
    description: "..."
    how_to_get: "..."
    used_in: [deploy-prod-backend, staging-migrate]

staging_agent_fallbacks:        # Commands the agent can use
  deploy: "..."
  migrate: "..."
  env_var: "..."
```

### Agent runtime profile

```yaml
name: "Claude Code"
slug: claude-code
scheduler: built-in             # or "external"
requires_cli: claude            # CLI binary name
auth_check: "claude --version"  # Auth verification command
default_model: claude-sonnet-4-6

setup_method: manual            # or "script"
setup_instructions: |
  ...                           # User-facing setup steps

schedule_file: null             # Path to generated schedule file
prompt_template: |
  ...                           # Agent tick prompt template
```

### Scheduler profile

```yaml
name: "GitHub Actions Cron"
slug: github-actions
platform: any                   # or "darwin", "linux"

workflow_template: |            # Schedule config template
  ...
workflow_file: ".github/workflows/agent-${track_name}.yml"

secrets:                        # Additional secrets needed
  - name: AGENT_PAT
    description: "..."
status_command: "..."           # How to check scheduler status
```

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
| `parse_config()` | Read YAML config for `--config` mode |
| `load_profile()` | Parse a profile YAML from `profiles/` |
| `detect_test_command()` | Auto-detect from project files |
| `detect_agent_cli()` | Check for available agent CLIs |
| `save_config()` | Write `.roadmap/config.yml` |

Flow: parse flags -> validate target -> detect repo info ->
collect config (or load from `--config`) -> load profiles ->
generate files (with overwrite handling) -> save config ->
optional GH setup -> summary.

## Adding a new platform variant

End-to-end steps to add a new backend or frontend platform:

### 1. Create the profile

Add a YAML file in `profiles/backend/<slug>.yml` or
`profiles/frontend/<slug>.yml`. Follow the structure of an
existing profile (e.g. `heroku.yml`). Define:
- `prompts` — what to ask the user
- `deploy.staging.command` / `deploy.production.command`
- `migration` (backend only)
- `secrets` — required GitHub Actions secrets
- `staging_agent_fallbacks` — commands for the agent

### 2. Create workflow templates

Add `.yml.tmpl` files in the appropriate variant directories:
- `templates/.github/workflows/deploy-prod-backend/<slug>.yml.tmpl`
- `templates/.github/workflows/staging-migrate/<slug>.yml.tmpl` (backend)
- `templates/.github/workflows/deploy-prod-frontend/<slug>.yml.tmpl` (frontend)
- `templates/.github/workflows/deploy-staging-frontend/<slug>.yml.tmpl` (frontend)

Use `${__VARIABLE}` placeholders for all configurable values.
Every workflow must be a complete, working GitHub Actions file
with `name:`, `on:`, and `jobs:` sections.

### 3. Update the installer

In `install.sh`:
- Add the platform to the selection menu
- Add any new variables to the global declarations
- Add the platform's prompts to the collection phase
- Add any new variables to the `sed` interpolation step

### 4. Add new template variables (if any)

If the platform needs variables not already in the table above:
- Add them to `defaults.yml` with type, default, prompt, and
  `template_var`
- Add corresponding entries to the profile's `prompts` list

### 5. Test

- Run `./tests/run.sh` — `test_all_profiles_have_workflows`
  verifies that every profile has matching workflow templates
- Run the installer with `--config` using an example config that
  exercises the new platform
- Review the generated workflow for correctness

### 6. Add an example (optional)

Create `examples/<stack>/config.yml` that uses the new platform
so future tests can exercise it.

## Tick scripts + scheduler templates

For agent runtimes other than Claude Code (which has built-in
scheduling), the installer generates:

- **Tick scripts** (`.roadmap/agents/tick-<track>.sh`) — one per
  track, invokes the agent CLI with the correct prompt. Template
  source depends on runtime: `tick-codex.sh.tmpl`,
  `tick-open-code.sh.tmpl`, or `tick-custom.sh.tmpl`.

- **setup-agents.sh** (`.roadmap/setup-agents.sh`) — a unified
  script that handles install, uninstall, and status for the
  selected scheduler. Supports launchd, crontab, GitHub Actions,
  and custom schedulers.

- **Scheduler config** — platform-specific: `launchd.plist.tmpl`
  for macOS, crontab entries generated inline by setup-agents.sh,
  `agent-tick.yml.tmpl` for GitHub Actions.

## Testing

Run the full test suite:

```bash
./tests/run.sh
```

### Test inventory

| Test file | What it checks |
|---|---|
| `test_syntax.sh` | `install.sh` parses without bash syntax errors |
| `test_help_flag.sh` | `--help` exits 0, output mentions `--target`, `--config`, `--force` |
| `test_bad_target.sh` | Non-existent target directory produces error + non-zero exit |
| `test_no_leftover_vars.sh` | No malformed `${__` patterns in any template file |
| `test_templates_valid_yaml.sh` | All `.yml.tmpl` workflow files have `name:`, `on:`, `jobs:` |
| `test_all_profiles_have_workflows.sh` | Every backend/frontend profile has matching workflow templates |

Each test script accepts the toolkit directory as `$1` (defaults
to `.`). The runner (`run.sh`) iterates all `test_*.sh` files,
reports pass/fail, and shows output for failures.

## Conventions

- Template files end in `.tmpl`; the installer strips the extension
- `WORKFLOWS.md` is the only template copied verbatim (no `.tmpl`)
- All workflow templates are complete, working GH Actions files —
  not skeletons
- The installer warns before overwriting existing files
- Generated files have no runtime dependency on the toolkit repo
- Config schema lives in `defaults.yml`; profiles provide
  platform-specific values
- Profiles use `${repo_name}` style refs in defaults (resolved
  at install time, distinct from template `${__VAR}` placeholders)

## Reference implementation

[django-munky](https://github.com/yevgetman/django-munky) is the
proving ground. Workflow changes are battle-tested there first,
then cascaded here. The cascade rule is documented in django-munky's
CLAUDE.md and AGENTS.md.
