# CLAUDE.md — Rules of engagement

## What this repo is

An interactive CLI installer that scaffolds automated agentic
roadmap workflows into any git repo. Templates + deploy profiles +
installer script. No application code, no runtime dependencies.

## Read order

1. **This file** — rules and context
2. **[`LLM.md`](./LLM.md)** — codebase summary, file map, key
   abstractions. Read this before scanning files directly.
3. **[`docs/DEVELOPER.md`](./docs/DEVELOPER.md)** — template
   variables, install.sh structure, adding platform variants

## Source of truth

[`django-munky`](https://github.com/yevgetman/django-munky) is
the **proving ground** where the workflow is battle-tested. This
repo follows django-munky — not the other way around.

When django-munky's workflow changes, those changes are cascaded
here. If this repo disagrees with django-munky on any workflow
detail (agent contract, status lifecycle, CI pipeline, hard rules),
django-munky wins — update this repo to match.

## Key files

| File | What it is | When to read |
|---|---|---|
| `install.sh` | The installer (~1700 lines, pure bash) | When changing the CLI flow |
| `defaults.yml` | Config schema + rational defaults | When changing prompts, adding options |
| `profiles/backend/*.yml` | Backend deploy profiles (7 platforms) | When changing deploy behavior |
| `profiles/frontend/*.yml` | Frontend deploy profiles (6 platforms) | When changing deploy behavior |
| `profiles/agents/*.yml` | Agent runtime profiles (4 runtimes) | When changing agent wiring |
| `profiles/schedulers/*.yml` | Scheduler profiles (4 types) | When changing scheduling |
| `templates/docs/roadmap/AGENT_PROMPT.md.tmpl` | Agent contract | When changing agent behavior |
| `templates/docs/roadmap/BACKLOG.yml.tmpl` | Backlog schema | When changing the data model |
| `templates/WORKFLOWS.md` | Branch model | When changing branch/merge rules |
| `templates/.github/workflows/` | CI/deploy templates | When changing pipeline behavior |
| `templates/.roadmap/` | Tick scripts + scheduler templates | When changing agent infrastructure |
| `.claude/commands/` | Claude Code slash commands | When changing the conversational UX |
| `tests/` | Test suite (bash) | When verifying changes |
| `examples/` | Example configs (4 stacks) | When testing interpolation |

## Slash commands

These are available when working inside this repo with Claude Code:

| Command | Purpose |
|---|---|
| `/init-roadmap` | Scaffold the roadmap workflow conversationally (alternative to `install.sh`) |
| `/roadmap-status` | Summarize current backlog state across all tracks |
| `/add-track` | Add a new track to an existing BACKLOG.yml |
| `/add-item` | Create a spec file and add a backlog entry |

## Rules

1. **Never change the workflow pattern without validating in
   django-munky first.** This repo is downstream.
2. **Templates must produce working files.** Every `.tmpl` file,
   when interpolated, should be a complete, functional file — not
   a skeleton that needs manual editing beyond the installer's
   config.
3. **Keep install.sh dependency-free.** Pure bash, no npm/pip/brew
   dependencies. `git`, `gh` (optional), `sed`, and standard
   POSIX tools only.
4. **Platform variants are separate files.** Don't use
   conditionals inside templates. Each platform (Heroku, Fly,
   AWS ECS, etc.) gets its own complete workflow file.
5. **Don't hardcode repo-specific values.** Everything concrete
   (app names, repo URLs, branch names, commands) must be a
   `${__VARIABLE}` placeholder.
6. **Test against examples.** The `examples/` configs should
   always reflect what the installer would produce for their
   respective stacks.

## Testing changes

Run the test suite:

```bash
./tests/run.sh
```

The suite includes 6 tests:

| Test | What it checks |
|---|---|
| `test_syntax` | `install.sh` has valid bash syntax |
| `test_help_flag` | `--help` exits 0, mentions `--target`, `--config`, `--force` |
| `test_bad_target` | Graceful failure on non-existent target |
| `test_no_leftover_vars` | No malformed `${__` placeholders in templates |
| `test_templates_valid_yaml` | All workflow templates have `name:`, `on:`, `jobs:` |
| `test_all_profiles_have_workflows` | Every profile has a matching workflow template |

For manual verification:

1. Run `./install.sh --config examples/django-heroku-cloudflare/config.yml --target /tmp/test-repo --force` against a fresh git repo
2. Review the generated files for correctness
3. Compare against the django-munky reference implementation
