# Usage guide

## Prerequisites

- A git repo with a GitHub remote
- `git` CLI
- `gh` CLI (optional — for label creation and branch auto-delete setup)

No Node, Python, or other runtime is required for the installer
itself. Your project's runtimes are configured during setup.

## Installation

### Option 1: CLI installer

```bash
git clone https://github.com/yevgetman/roadmap-agent-toolkit.git
cd roadmap-agent-toolkit
./install.sh --target /path/to/your-repo
```

If `--target` is omitted, the installer prompts for the path.

### Option 2: Non-interactive mode

Pass a config file to skip all prompts:

```bash
./install.sh --config config.yml --target /path/to/your-repo
```

See `examples/` for reference configs. The format matches what
the installer saves to `.roadmap/config.yml` after a run, so you
can re-run with the saved config to regenerate files after a
toolkit update.

Use `--force` to overwrite existing files without prompting:

```bash
./install.sh --config config.yml --target /path/to/your-repo --force
```

### Option 3: Claude Code slash command

If you use Claude Code, run `/init-roadmap` inside any session.
Claude reads the templates and walks you through setup
conversationally. No bash needed. Additional slash commands:

| Command | Purpose |
|---|---|
| `/init-roadmap` | Full setup (alternative to `install.sh`) |
| `/roadmap-status` | Summarize backlog state across all tracks |
| `/add-track` | Add a new track to an existing BACKLOG.yml |
| `/add-item` | Create a spec file and add a backlog entry |

### Flags

| Flag | Purpose |
|---|---|
| `--target <path>` | Target repo path (prompted if omitted) |
| `--config <file>` | Non-interactive: read config from YAML file |
| `--force` | Overwrite existing files without prompting |
| `--help` | Show usage and exit |

## Installer walkthrough

The installer runs interactively in 12 phases:

### Phase 1: Target repo

```
Where should the roadmap system be scaffolded?
Path [./]: /path/to/my-project
```

Validates the path is a git repo with a remote.

### Phase 2: Repository info

Auto-detects from `git remote get-url origin`:

```
Detected: github.com/myorg/myrepo
GitHub owner [myorg]:
Repo name [myrepo]:
```

### Phase 3: Branch config

```
Production branch [main]:
Staging branch [staging]:
```

### Phase 4: Backend platform

```
Backend platform:
  1) Heroku
  2) Fly.io
  3) AWS ECS/Fargate
  4) GCP Cloud Run
  5) Railway
  6) Render
  7) Custom
  8) None (no auto-deploy)
Choose [1-8]:
```

Platform-specific follow-ups depend on the choice:
- **Heroku** — staging + prod app names
- **Fly.io** — staging + prod app names
- **AWS ECS** — region, ECR repo, cluster names, subnet, security group
- **GCP Cloud Run** — project ID, region, artifact registry repo
- **Railway** — project ID, service names
- **Render** — service IDs
- **Custom** — deploy commands, secrets list

### Phase 5: Frontend platform

```
Frontend platform:
  1) Cloudflare Pages
  2) Vercel
  3) Netlify
  4) AWS S3 + CloudFront
  5) FTP/SFTP
  6) Custom
  7) None
Choose [1-7]:
```

Follow-ups: frontend directory, project names, test/build commands.
Platform-specific prompts for bucket names, distribution IDs,
site IDs, hosts, etc.

### Phase 6: Test commands

Auto-detected from project files when possible:

| File found | Backend test default |
|---|---|
| `manage.py` | `python manage.py test --noinput` |
| `Gemfile` | `bundle exec rails test` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |

```
Backend test command [python manage.py test --noinput]:
Frontend test command [npm test]:
```

### Phase 7: Database for CI

```
Database for CI tests:
  1) MySQL 8.0
  2) PostgreSQL 15
  3) SQLite (no service)
Choose [1-3]:
```

### Phase 8: Migration command

Auto-detected similarly to test commands:

```
Migration command [python manage.py migrate --noinput]:
```

Leave empty if no migrations are needed.

### Phase 9: Track setup

```
How many roadmap tracks? [1]: 2

Track 1:
  Name [core]:
  ID prefix [C]:
  Branch prefix [core]:
  Issue label [roadmap-core]:
  North star: One sentence describing the goal.

Track 2:
  Name [platform]:
  ...
```

### Phase 10: Ad-hoc agent

```
Include ad-hoc issue handling agent? [Y/n]:
```

### Phase 11: Agent runtime

Auto-detects available CLIs (`claude --version`, `codex --version`):

```
Agent runtime:
  1) Claude Code (built-in scheduling)
  2) OpenAI Codex (needs external scheduler)
  3) Open Code (needs external scheduler)
  4) Custom (provide invoke command)
Choose [1-4]:
```

### Phase 12: Scheduler

Only asked if the runtime is not Claude Code (which has built-in
scheduling). Auto-selects based on OS:

```
Scheduler:
  1) launchd (macOS)
  2) crontab
  3) GitHub Actions cron
  4) Custom
Choose [1-4]:
```

## Generated output

The installer creates files in the target repo and saves the
resolved config for re-runs:

### Generated files

- `WORKFLOWS.md` — branch model (copied verbatim)
- `docs/INFRA.yml` — infrastructure mapping
- `docs/ROADMAPS.md` — master index
- `docs/roadmap/` — backlog, agent prompt, design doc
- `docs/roadmap-adhoc/` — ad-hoc agent (if enabled)
- `.github/workflows/` — CI, deploy, and migration workflows
- `.roadmap/config.yml` — saved config
- `.roadmap/setup-agents.sh` — agent install/uninstall/status
- `.roadmap/agents/` — tick scripts (for non-Claude runtimes)
- `.roadmap/.gitignore` — excludes logs and generated plists

### Handling existing files

When a target file already exists:
- In interactive mode: prompted to skip, overwrite, overwrite all,
  or quit
- With `--force`: always overwrites without prompting
- Files that haven't changed are not rewritten

## Post-install setup

After the installer runs:

### 1. Review generated files

Scan `INFRA.yml`, the workflow files, and `AGENT_PROMPT.md` for
accuracy. The installer fills in what it can from your answers;
platform-specific details (URLs, database tiers, etc.) may need
manual adjustment.

### 2. Set GitHub repo secrets

Required secrets depend on your platform choices:

| Platform | Secrets |
|---|---|
| Heroku | `HEROKU_API_KEY` |
| Cloudflare Pages | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |
| Vercel | `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` |
| Fly.io | `FLY_API_TOKEN` |
| AWS ECS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| GCP Cloud Run | `GCP_SA_KEY` |
| Netlify | `NETLIFY_AUTH_TOKEN` |
| Railway | `RAILWAY_TOKEN` |
| Render | `RENDER_API_KEY` |
| FTP/SFTP | `FTP_USERNAME`, `FTP_PASSWORD` |

Add via: Settings > Secrets and variables > Actions.

### 3. Create the staging branch

If the installer didn't create it (no `gh` CLI), create it
manually:

```bash
git checkout main
git checkout -b staging
git push -u origin staging
```

### 4. Enable branch auto-delete

If the installer didn't set it, enable manually:
Settings > General > "Automatically delete head branches"

### 5. Add your first backlog item

1. Write a spec in `docs/roadmap/items/<ID>-slug.md`
2. Add an entry to the appropriate track in
   `docs/roadmap/BACKLOG.yml` with `status: ready`
3. Commit and push

Or use `/add-item` in Claude Code.

### 6. Schedule your agents

The installer prints scheduling instructions per track. Options:

- **Claude Code**: run `/schedule create` with the AGENT_PROMPT
  content and `TRACK` set to the track name
- **launchd/crontab**: run `.roadmap/setup-agents.sh install`
- **GitHub Actions cron**: the workflow file is already generated
- **Custom**: follow the instructions in the summary

Recommended cadence: every 6 hours, offset 1 hour per track.

### 7. Verify end-to-end

Run one agent tick manually. Confirm it:
- Picks up the `ready` item
- Implements on a feature branch
- Merges to staging
- CI runs and passes
- Opens a PR against production

Then merge the PR and confirm:
- Auto-deploy fires
- Agent detects the merge on next tick
- Item marked `done`, branch deleted, issue closed

## Updating

When the toolkit is updated (new template content, new platform
variants), re-run the installer with the saved config:

```bash
./install.sh --config /path/to/your-repo/.roadmap/config.yml --target /path/to/your-repo
```

The installer warns before overwriting existing files unless
`--force` is passed.

## Uninstalling

The toolkit generates standard files — delete them manually.
There is no uninstall command. The generated files have no
dependency on the toolkit repo after generation.
