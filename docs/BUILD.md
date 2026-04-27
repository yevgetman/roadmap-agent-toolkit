# BUILD.md — Integration plan

This document tracks the work needed to wire together all the
surfaces of the toolkit — config schema, deploy profiles, agent
profiles, templates, and the installer. Each section describes
what was built.

**All 11 build items are complete.**

---

## 1. Installer reads `defaults.yml` for config schema

**Status:** COMPLETE

- [x] Parse `defaults.yml` at installer startup (bash YAML parsing)
- [x] Replace hardcoded prompts with schema-driven prompts
- [x] Validate input against type constraints
- [x] Apply conditional logic (skip frontend prompts if none, etc.)
- [x] Apply auto-detect rules (scan for `manage.py`, `Gemfile`,
      `go.mod` to pre-fill test/migration commands)

---

## 2. Installer loads deploy profiles

**Status:** COMPLETE

- [x] Load backend profile from `profiles/backend/<slug>.yml`
- [x] Present profile's prompts with pre-filled defaults
- [x] Store resolved profile values for template interpolation
- [x] Same for frontend platform profiles
- [x] For "custom" profiles, collect user-provided commands/secrets
- [x] Aggregate all required secrets for post-install summary

---

## 3. Workflow templates for all platform variants

**Status:** COMPLETE

- [x] `deploy-prod-backend/` — heroku, fly, aws-ecs, gcp-cloud-run,
      railway, render, custom (7 variants)
- [x] `deploy-prod-frontend/` — cloudflare-pages, vercel, netlify,
      aws-s3-cloudfront, ftp, custom (6 variants)
- [x] `deploy-staging-frontend/` — same 6 variants
- [x] `staging-migrate/` — heroku, fly, aws-ecs, gcp-cloud-run,
      railway, render, custom (7 variants)

---

## 4. Agent runtime + scheduler wiring

**Status:** COMPLETE

- [x] Per-runtime tick scripts: tick-codex.sh, tick-open-code.sh,
      tick-custom.sh (Claude Code uses built-in routines)
- [x] Scheduler templates: launchd.plist, agent-tick.yml (GH Actions),
      crontab entries generated inline by setup-agents.sh
- [x] `setup-agents.sh` — unified install/uninstall/status for all
      scheduler types
- [x] `.roadmap/.gitignore` — excludes logs and generated plists
- [x] Installer detects available agent CLIs and pre-selects runtime
- [x] Installer generates tick scripts per track with interpolated
      invoke commands
- [x] Installer prints cron expressions for each track in summary

---

## 5. Non-interactive mode (`--config` flag)

**Status:** COMPLETE

- [x] Accept `--config <file.yml>` flag
- [x] Parse YAML config file
- [x] Skip all interactive prompts — use config values directly
- [x] Validate required fields are present
- [x] Error with clear message if required field missing
- [x] Still run post-generation steps unless `--no-setup` passed

---

## 6. Save config on completion

**Status:** COMPLETE

- [x] Write resolved config to `<target>/.roadmap/config.yml`
- [x] Format matches `--config` input format
- [x] Enables re-running installer with saved config
- [x] Added to file list in summary
- [x] Includes comment header with generation timestamp

---

## 7. Idempotent re-runs

**Status:** COMPLETE

- [x] Detect existing target files
- [x] Offer: Skip / Overwrite / All / Quit
- [x] Track skipped vs written files in summary
- [x] `--force` flag overwrites without prompting
- [x] Don't touch files that haven't changed

---

## 8. Test suite

**Status:** COMPLETE

- [x] `tests/` directory with bash test scripts
- [x] `test_syntax.sh` — install.sh bash syntax validation
- [x] `test_help_flag.sh` — `--help` output validation
- [x] `test_bad_target.sh` — graceful failure on bad path
- [x] `test_no_leftover_vars.sh` — no malformed placeholders
- [x] `test_templates_valid_yaml.sh` — workflow structural checks
- [x] `test_all_profiles_have_workflows.sh` — profile/template alignment
- [x] `run.sh` runner that iterates all tests

---

## 9. Update examples

**Status:** COMPLETE

- [x] `examples/django-heroku-cloudflare/config.yml` — 3 tracks
- [x] `examples/rails-fly-vercel/config.yml` — 1 track
- [x] `examples/nextjs-vercel/config.yml` — Codex runtime
- [x] `examples/go-aws/config.yml` — AWS ECS + S3/CloudFront

---

## 10. Update documentation

**Status:** COMPLETE

- [x] `docs/USAGE.md` — reflects all phases, auto-detection,
      `--config`/`--force` flags, saved config, slash commands
- [x] `docs/DEVELOPER.md` — complete file map, all 47 template
      variables, profile structure, tick scripts, testing
- [x] `LLM.md` — updated file map, new abstractions (profile,
      scheduler, tick script), flags, slash commands
- [x] `README.md` — platform table, examples, `.roadmap/` in tree,
      `/init-roadmap` in quick start

---

## 11. Claude Code slash commands

**Status:** COMPLETE

- [x] `.claude/commands/init-roadmap.md` — full conversational setup
- [x] `.claude/commands/roadmap-status.md` — backlog summary
- [x] `.claude/commands/add-track.md` — add track to BACKLOG.yml
- [x] `.claude/commands/add-item.md` — create spec + backlog entry

---

## Build order (completed)

1. Workflow templates
2. Agent wiring
3. Schema-driven installer
4. Non-interactive mode
5. Save config
6. Idempotent re-runs
7. Test suite
8. Examples + docs
9. Slash commands
