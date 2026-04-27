You are scaffolding an automated agentic roadmap workflow into the current repository. This is an interactive setup — ask the user each question conversationally, confirm choices, then generate all files.

## What you're setting up

A system where scheduled LLM agents autonomously implement work items from a YAML backlog against a staging environment. The user reviews and merges PRs to production. The full architecture is documented at `docs/ARCHITECTURE.md` in the roadmap-agent-toolkit repo.

## Setup flow

Work through these sections in order. For each, ask the user, confirm, then move to the next. Use sensible defaults — don't ask unnecessary questions.

### 1. Repository

Auto-detect from `git remote get-url origin`:
- GitHub owner and repo name
- Confirm production branch (default: `main`)
- Confirm staging branch (default: `staging`)

### 2. Backend platform

Ask which platform hosts the backend:
- **Heroku** — ask for staging + prod app names
- **Fly.io** — ask for staging + prod app names
- **AWS ECS/Fargate** — ask for region, ECR repo, cluster names
- **GCP Cloud Run** — ask for project ID, region, service names
- **Railway** — ask for project ID, service names
- **Render** — ask for service IDs
- **Custom** — ask for deploy commands + secrets
- **None** — skip backend deploy workflows

### 3. Frontend platform

Ask which platform hosts the frontend:
- **Cloudflare Pages** — ask for project names + account ID
- **Vercel** — ask for org/project IDs
- **Netlify** — ask for site IDs
- **AWS S3 + CloudFront** — ask for bucket names, distribution IDs
- **FTP/SFTP** — ask for hosts, paths, protocol
- **Custom** — ask for deploy commands
- **None** — skip frontend workflows

### 4. Test commands

Auto-detect by scanning the repo:
- `manage.py` → Django: `python manage.py test --noinput`
- `Gemfile` → Rails: `bundle exec rails test`
- `go.mod` → Go: `go test ./...`
- `Cargo.toml` → Rust: `cargo test`
- `package.json` in root → `npm test`

Ask user to confirm or override. Same for migration command (can be empty).

Frontend: default `npm test` / `npm run build`, ask for frontend directory.

### 5. CI settings

- Database for CI: sqlite (default), mysql, or postgres
- Python version (if applicable)
- Node version file path (if frontend exists)

### 6. Tracks

Ask how many roadmap tracks. For each:
- Name (e.g. `core`, `platform`, `ai`)
- ID prefix (single letter, e.g. `C`, `P`, `A`)
- Branch prefix (e.g. `roadmap`, `platform`)
- Issue label (default: `roadmap-<name>`)
- One-line north star goal

### 7. Ad-hoc agent

Ask: "Include an ad-hoc issue agent that picks up unlabeled GitHub issues?" (default: yes)

### 8. Agent runtime

Check if `claude` CLI is available (`claude --version`). If yes, default to Claude Code. Otherwise ask:
- **Claude Code** — built-in scheduling via routines (default model: claude-sonnet-4-6)
- **OpenAI Codex** — needs external scheduler (default model: codex-5.4)
- **Open Code** — needs external scheduler
- **Custom** — user provides invoke command

If non-Claude, ask about scheduler: launchd (macOS default), crontab (Linux default), GitHub Actions cron, or custom.

## File generation

Once all config is collected, generate these files by reading the templates from the toolkit repo and interpolating the user's values. Read each `.tmpl` file, replace `${__VARIABLE}` placeholders with the collected values, and write to the target location.

### Files to generate

Read templates from the roadmap-agent-toolkit directory (find it via `defaults.yml` or the toolkit's location). If running inside the toolkit repo itself, templates are at `templates/`. If running in a target repo, the user should have the toolkit cloned somewhere — ask for the path.

**Core docs:**
- `WORKFLOWS.md` ← copy verbatim from `templates/WORKFLOWS.md`
- `docs/INFRA.yml` ← from `templates/docs/INFRA.yml.tmpl`
- `docs/ROADMAPS.md` ← from `templates/docs/ROADMAPS.md.tmpl`
- `docs/roadmap/README.md` ← from `templates/docs/roadmap/README.md.tmpl`
- `docs/roadmap/AUTOMATION.md` ← from `templates/docs/roadmap/AUTOMATION.md.tmpl`
- `docs/roadmap/AGENT_PROMPT.md` ← from `templates/docs/roadmap/AGENT_PROMPT.md.tmpl`
- `docs/roadmap/BACKLOG.yml` ← from `templates/docs/roadmap/BACKLOG.yml.tmpl` (replace `# __TRACKS_PLACEHOLDER__` with generated track YAML)
- Create empty `docs/roadmap/epics/` and `docs/roadmap/items/` directories

**Ad-hoc agent (if enabled):**
- `docs/roadmap-adhoc/STATE.yml` ← from template
- `docs/roadmap-adhoc/AGENT_PROMPT.md` ← from template
- `docs/roadmap-adhoc/README.md` ← from template

**CI workflows:**
- `.github/workflows/tests.yml` ← from `templates/.github/workflows/tests.yml.tmpl`
- `.github/workflows/frontend-tests.yml` ← from template (skip if frontend is none)
- `.github/workflows/deploy-prod-backend.yml` ← select variant from `templates/.github/workflows/deploy-prod-backend/<platform>.yml.tmpl`
- `.github/workflows/deploy-prod-frontend.yml` ← select variant
- `.github/workflows/deploy-staging-frontend.yml` ← select variant
- `.github/workflows/staging-migrate.yml` ← select variant (skip if no migration command)

**Agent infrastructure (if non-Claude runtime):**
- `.roadmap/agents/tick-<track>.sh` for each track ← from runtime-specific tick template
- `.roadmap/setup-agents.sh` ← from template
- `.roadmap/.gitignore`
- `.roadmap/logs/` directory

**Saved config:**
- `.roadmap/config.yml` — write the resolved configuration

### BACKLOG.yml track generation

For each track, generate this YAML block and insert where `# __TRACKS_PLACEHOLDER__` appears:

```yaml
  <name>:
    meta:
      owner: <repo_owner>
      north_star: >
        <north_star>
      target_ship_date: null
      locked: false
      scheduled_agent_routine_id: null
      scheduled_agent_cron: "<cron>"
      branch_prefix: <branch_prefix>
      issue_label: <issue_label>
      commit_prefix: <commit_prefix>

    items:
      # Add your first item here
```

## Post-generation

After generating files:

1. If `gh` CLI is available, offer to:
   - Create GitHub issue labels for each track
   - Create ad-hoc labels (if enabled)
   - Create the staging branch
   - Enable auto-delete branches on PR merge

2. Print a summary:
   - All generated files
   - Required GitHub secrets per platform
   - Agent scheduling instructions (for Claude Code: `/schedule create` steps; for others: how to install the scheduler)
   - Cron expressions for each track
   - Next steps: add first backlog item, schedule agents, run one tick

## Important rules

- Ask before overwriting any existing file
- Never commit or push — just generate files
- If the user says "dry run" or "preview", describe what would be generated without writing
- Keep the conversation focused — don't over-explain; the generated docs handle that
- If something is ambiguous, pick the sensible default and confirm with the user
