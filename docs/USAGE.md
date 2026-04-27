# Usage guide

## Prerequisites

- A git repo with a GitHub remote
- `git` CLI
- `gh` CLI (optional — for label creation and branch auto-delete setup)

No Node, Python, or other runtime is required for the installer
itself. Your project's runtimes are configured during setup.

## Installation

### Option 1: Clone and run

```bash
git clone https://github.com/yevgetman/roadmap-agent-toolkit.git
cd roadmap-agent-toolkit
./install.sh --target /path/to/your-repo
```

### Option 2: Run directly

```bash
git clone https://github.com/yevgetman/roadmap-agent-toolkit.git
roadmap-agent-toolkit/install.sh --target /path/to/your-repo
```

If `--target` is omitted, the installer prompts for the path.

## Installer walkthrough

The installer runs interactively in 10 phases:

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
  3) Custom
  4) None (no auto-deploy)
Choose [1-4]:
```

Platform-specific follow-ups (app names for staging + prod).

### Phase 5: Frontend platform

```
Frontend platform:
  1) Cloudflare Pages
  2) Vercel
  3) Custom
  4) None
Choose [1-4]:
```

Follow-ups: frontend directory, project names, test/build commands.

### Phase 6: Test commands

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

```
Migration command [python manage.py migrate --noinput]:
```

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

Add via: Settings → Secrets and variables → Actions.

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
Settings → General → "Automatically delete head branches" ✓

### 5. Add your first backlog item

1. Write a spec in `docs/roadmap/items/<ID>-slug.md`
2. Add an entry to the appropriate track in
   `docs/roadmap/BACKLOG.yml` with `status: ready`
3. Commit and push

### 6. Schedule your agents

Options:

- **Claude Code routines**: `/schedule create` with the
  AGENT_PROMPT content and `TRACK` set
- **GitHub Actions cron**: a workflow that invokes your LLM CLI
- **Custom cron**: any scheduler with repo + LLM access

Recommended: every 6 hours, offset 1 hour per track.

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
variants), re-run the installer. It warns before overwriting
existing files and lets you skip or replace each one.

## Uninstalling

The toolkit generates standard files — delete them manually.
There is no uninstall command. The generated files have no
dependency on the toolkit repo after generation.
