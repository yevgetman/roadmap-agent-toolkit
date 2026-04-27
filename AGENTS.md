# AGENTS.md — Rules of engagement

Cross-tool agent entry point (Claude Code, Cursor, Aider, etc.).
Mirrors `CLAUDE.md` — same rules, vendor-neutral framing.

## What this repo is

An interactive CLI installer that scaffolds automated agentic
roadmap workflows into any git repo. Templates + installer script.
No application code, no runtime dependencies.

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
| `install.sh` | The installer | When changing the CLI flow |
| `templates/docs/roadmap/AGENT_PROMPT.md.tmpl` | Agent contract | When changing agent behavior |
| `templates/docs/roadmap/BACKLOG.yml.tmpl` | Backlog schema | When changing the data model |
| `templates/WORKFLOWS.md` | Branch model | When changing branch/merge rules |
| `templates/.github/workflows/` | CI/deploy templates | When changing pipeline behavior |

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
   conditionals inside templates. Each platform gets its own
   complete workflow file.
5. **Don't hardcode repo-specific values.** Everything concrete
   must be a `${__VARIABLE}` placeholder.
6. **Test against the django-munky example.** The example config
   should always reflect what the installer produces for
   django-munky's setup.

## Testing changes

No automated test suite yet. To verify:

1. Run `./install.sh --target /tmp/test-repo` against a fresh
   git repo
2. Review generated files for correctness
3. Compare against django-munky reference implementation
4. Verify edge cases (existing files, missing `gh`, Ctrl+C)
