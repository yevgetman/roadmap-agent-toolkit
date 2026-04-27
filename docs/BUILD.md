# BUILD.md — Integration plan

This document tracks the work needed to wire together all the
surfaces of the toolkit — config schema, deploy profiles, agent
profiles, templates, and the installer. Each section describes
what exists, what's missing, and how to connect them.

Use this as the reference when working on any piece. Check off
items as they're completed.

---

## 1. Installer reads `defaults.yml` for config schema

**Status:** not started

**What exists:**
- `defaults.yml` defines every configurable option with type,
  default, prompt text, template variable mapping, and conditions
- `install.sh` has its own hardcoded prompts and variable names

**What to build:**
- [ ] Parse `defaults.yml` at installer startup (bash YAML parsing
      — extract keys, defaults, types, prompts)
- [ ] Replace hardcoded prompts in `install.sh` with schema-driven
      prompts from `defaults.yml`
- [ ] Validate input against type constraints (choice options,
      integer min/max, required fields)
- [ ] Apply conditional logic (skip frontend prompts if
      `frontend.platform == none`, etc.)
- [ ] Apply auto-detect rules (scan target repo for `manage.py`,
      `Gemfile`, `go.mod` to pre-fill test/migration commands)

**Design notes:**
Bash YAML parsing is limited. Two approaches:
- a) Simple line-by-line grep/awk parser for the flat structure
- b) Require `yq` as an optional dependency (fall back to grep)
- c) Pre-process `defaults.yml` into a flat key=value file at
     build time that the installer sources

Recommend (a) for MVP — the schema is regular enough that
positional parsing works.

---

## 2. Installer loads deploy profiles

**Status:** not started

**What exists:**
- `profiles/backend/*.yml` — 7 backend deploy profiles
- `profiles/frontend/*.yml` — 6 frontend deploy profiles
- Each profile defines: prompts, deploy commands, secrets,
  health checks, agent fallbacks

**What to build:**
- [ ] When user selects a backend platform, load the corresponding
      profile from `profiles/backend/<slug>.yml`
- [ ] Present the profile's prompts (app names, regions, etc.)
      with pre-filled defaults
- [ ] Store the resolved profile values for template interpolation
- [ ] Same for frontend platform → `profiles/frontend/<slug>.yml`
- [ ] For "custom" profiles, collect the user-provided commands
      and secrets list
- [ ] Aggregate all required secrets across backend + frontend
      profiles for the post-install summary

**Design notes:**
The profile YAML files have a regular structure. The installer
needs to extract `prompts[].key`, `prompts[].prompt`,
`prompts[].default`, and `secrets[].name`. This is a second
YAML-parsing problem — same approach as §1.

---

## 3. Workflow templates for all platform variants

**Status:** COMPLETE

**What exists:**
- `templates/.github/workflows/deploy-prod-backend/` has:
  heroku, fly, aws-ecs, gcp-cloud-run, railway, render, custom
- `templates/.github/workflows/deploy-prod-frontend/` has:
  cloudflare-pages, vercel, netlify, aws-s3-cloudfront, ftp, custom
- `templates/.github/workflows/deploy-staging-frontend/` has:
  cloudflare-pages, vercel, netlify, aws-s3-cloudfront, ftp, custom
- `templates/.github/workflows/staging-migrate/` has:
  heroku, fly, aws-ecs, gcp-cloud-run, railway, render, custom

**Completed:**
- [x] `deploy-prod-backend/aws-ecs.yml.tmpl`
- [x] `deploy-prod-backend/gcp-cloud-run.yml.tmpl`
- [x] `deploy-prod-backend/railway.yml.tmpl`
- [x] `deploy-prod-backend/render.yml.tmpl`
- [x] `deploy-prod-frontend/netlify.yml.tmpl`
- [x] `deploy-prod-frontend/aws-s3-cloudfront.yml.tmpl`
- [x] `deploy-prod-frontend/ftp.yml.tmpl`
- [x] `deploy-staging-frontend/netlify.yml.tmpl`
- [x] `deploy-staging-frontend/aws-s3-cloudfront.yml.tmpl`
- [x] `deploy-staging-frontend/ftp.yml.tmpl`
- [x] `staging-migrate/fly.yml.tmpl`
- [x] `staging-migrate/aws-ecs.yml.tmpl`
- [x] `staging-migrate/gcp-cloud-run.yml.tmpl`
- [x] `staging-migrate/railway.yml.tmpl`
- [x] `staging-migrate/render.yml.tmpl`

---

## 4. Agent runtime + scheduler wiring

**Status:** profiles defined, not wired into installer

**What exists:**
- `profiles/agents/*.yml` — 4 runtime profiles (claude-code,
  codex, open-code, custom)
- `profiles/schedulers/*.yml` — 4+1 scheduler profiles (launchd,
  crontab, github-actions, custom, claude-code-routines)
- `templates/.roadmap/agents/tick.sh.tmpl` — tick script template
- `defaults.yml` has `agents.runtime` and `agents.scheduler`
  with auto-select logic

**What to build:**
- [ ] Installer detects available agent CLIs (`claude --version`,
      `codex --version`) and pre-selects runtime
- [ ] If runtime is `claude-code`, skip scheduler selection and
      print setup instructions for `/schedule create`
- [ ] If runtime is non-Claude, auto-select scheduler based on
      platform (darwin → launchd, linux → crontab) with option
      to override
- [ ] Generate `tick-<track>.sh` for each track using the tick
      script template + the runtime's invoke command
- [ ] Make tick scripts executable (`chmod +x`)
- [ ] Create `.roadmap/logs/` directory
- [ ] For launchd: generate plist files, offer to `launchctl load`
- [ ] For crontab: generate entries, offer to install via
      `crontab -l | ... | crontab -`
- [ ] For GH Actions: generate `agent-<track>.yml` workflow files
- [ ] For custom: print the tick script paths and let the user
      schedule them
- [ ] Print the cron expression for each track in the summary
      (with UTC times)

**Design notes:**
The tick script needs `${__AGENT_INVOKE_COMMAND}` interpolated
from the runtime profile's `invoke_command` field. For Claude
Code, no tick script is generated — only the setup instructions
are printed.

---

## 5. Non-interactive mode (`--config` flag)

**Status:** not started

**What to build:**
- [ ] Accept `--config <file.yml>` flag
- [ ] Parse the config file (same format as `defaults.yml` but
      with concrete values instead of schema metadata)
- [ ] Skip all interactive prompts — use config values directly
- [ ] Validate that all required fields are present
- [ ] Error with clear message if a required field is missing
- [ ] Still run post-generation steps (GH labels, branch setup)
      unless `--no-setup` is also passed

**Config file format:**
```yaml
repository:
  owner: yevgetman
  name: django-munky
  production_branch: main
  staging_branch: staging

backend:
  platform: heroku
  app_name_staging: django-munky-staging
  app_name_prod: django-munky-v2
  test_command: "python manage.py test api.tests --noinput"
  migration_command: "python manage.py migrate --noinput"

frontend:
  platform: cloudflare-pages
  directory: frontend-legacy
  project_name_staging: django-munky-staging
  project_name_prod: django-munky-prod
  test_command: "npm test"
  build_command: "npm run build"

ci:
  database_service: mysql
  python_version: "3.12"

tracks:
  - name: saas
    id_prefix: I
    branch_prefix: roadmap
    issue_label: roadmap-saas
    north_star: "Self-serve SaaS product"
  - name: platform
    id_prefix: P
    branch_prefix: platform
    issue_label: roadmap-platform
    north_star: "Platform improvements"

agents:
  runtime: claude-code
  cadence_hours: 6
  offset_hours: 1

adhoc:
  enabled: true
```

---

## 6. Save config on completion

**Status:** not started

**What to build:**
- [ ] After generating files, write the user's resolved config
      to `<target-repo>/.roadmap/config.yml`
- [ ] Format matches the `--config` input format (§5)
- [ ] Enables re-running the installer with `--config .roadmap/config.yml`
      to regenerate files after a toolkit update
- [ ] Add `.roadmap/` to the file list in the summary
- [ ] Include a comment header noting when it was generated

---

## 7. Idempotent re-runs

**Status:** partially done (installer warns on existing files)

**What to build:**
- [ ] When a target file already exists, show a diff preview
      (or at minimum the first few lines of the existing file)
- [ ] Offer: [S]kip / [O]verwrite / [A]ll / [Q]uit
- [ ] Track which files were skipped vs written in the summary
- [ ] If `--force` flag is passed, overwrite without prompting
- [ ] Don't touch files that haven't changed (compare before
      writing)

---

## 8. Test suite

**Status:** not started

**What to build:**
- [ ] `tests/` directory with bash test scripts
- [ ] Test: `install.sh --config` with the django-munky example
      config produces expected files
- [ ] Test: generated workflow files are valid YAML
- [ ] Test: template interpolation replaces all `${__VAR}`
      placeholders (no leftover `${__` in output)
- [ ] Test: each platform variant produces a syntactically
      valid workflow
- [ ] Test: installer exits cleanly on Ctrl+C
- [ ] Test: installer handles missing target directory
- [ ] Test: installer handles non-git target directory

**Design notes:**
Bash tests can use `diff` against expected output snapshots.
The django-munky example config serves as the golden test case.
Run in CI via a simple GH Actions workflow.

---

## 9. Update examples

**Status:** partially done (one example exists)

**What to build:**
- [ ] Update `examples/django-heroku-cloudflare/config.json` →
      rename to `config.yml` to match the new config format
- [ ] Add `examples/rails-fly-vercel/config.yml`
- [ ] Add `examples/nextjs-vercel-vercel/config.yml` (monorepo,
      same platform for both)
- [ ] Add `examples/go-aws-s3/config.yml`
- [ ] Each example should include a `README.md` with what the
      example demonstrates

---

## 10. Update documentation

**Status:** docs exist but reference the old installer flow

**What to build:**
- [ ] Update `docs/USAGE.md` to reflect schema-driven prompts,
      auto-detection, `--config` flag, saved config
- [ ] Update `docs/DEVELOPER.md` with the new file map (profiles,
      defaults.yml, .roadmap/)
- [ ] Update `LLM.md` with the new abstractions (profiles,
      config schema, auto-detect)
- [ ] Update `README.md` platform table with all supported
      platforms

---

## Build order

Recommended sequence (each step is independently useful):

1. **§3 — Workflow templates** — fill the gaps so every profile
   has a matching workflow template. Pure file creation, no
   installer changes.

2. **§4 — Agent wiring** — generate tick scripts and scheduler
   files. The most user-visible missing piece.

3. **§1 + §2 — Schema-driven installer** — the big refactor.
   Replace hardcoded prompts with defaults.yml-driven flow.
   Load deploy profiles. This touches most of install.sh.

4. **§6 — Save config** — small addition after §1+§2.

5. **§5 — Non-interactive mode** — reads the saved config.
   Depends on §6's format.

6. **§7 — Idempotent re-runs** — polish for re-running after
   toolkit updates.

7. **§8 — Test suite** — validates everything above.

8. **§9 + §10 — Examples + docs** — update to match the new
   reality.
