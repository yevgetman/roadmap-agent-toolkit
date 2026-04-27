#!/usr/bin/env bash
# roadmap-agent-toolkit installer
# Scaffolds multi-track backlogs, CI pipelines, and scheduled LLM
# agent infrastructure into any repo.
#
# Usage:
#   ./install.sh --target /path/to/your/repo
#   ./install.sh   (prompts for target directory)

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
TARGET_DIR=""

# Config variables (populated by prompts)
REPO_OWNER=""
REPO_NAME=""
PROD_BRANCH="main"
STAGING_BRANCH="staging"
BACKEND_TEST_CMD=""
FRONTEND_TEST_CMD=""
FRONTEND_DIR=""
FRONTEND_BUILD_CMD=""
MIGRATION_CMD=""
BACKEND_APP_STAGING=""
BACKEND_APP_PROD=""
FRONTEND_PROJECT_STAGING=""
FRONTEND_PROJECT_PROD=""
DB_SERVICE="none"
PYTHON_VERSION="3.12"
NODE_VERSION_FILE=""
BACKEND_PLATFORM=""
FRONTEND_PLATFORM=""

# Track config (arrays)
TRACK_NAMES=()
TRACK_ID_PREFIXES=()
TRACK_BRANCH_PREFIXES=()
TRACK_ISSUE_LABELS=()
TRACK_COMMIT_PREFIXES=()
TRACK_NORTH_STARS=()
TRACK_CRONS=()

ADHOC_AGENT="false"
ADHOC_CRON="0 2/6 * * *"

# ── Utilities ────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${BLUE}[info]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}[warn]${NC} %s\n" "$1"; }
error()   { printf "${RED}[error]${NC} %s\n" "$1" >&2; }

# Prompt with default value
ask() {
    local prompt="$1"
    local default="$2"
    local result
    if [ -n "$default" ]; then
        printf "${BOLD}%s${NC} [%s]: " "$prompt" "$default"
    else
        printf "${BOLD}%s${NC}: " "$prompt"
    fi
    read -r result
    echo "${result:-$default}"
}

# Numbered menu
ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    printf "\n${BOLD}%s${NC}\n" "$prompt"
    for i in "${!options[@]}"; do
        printf "  %d) %s\n" "$((i + 1))" "${options[$i]}"
    done
    local choice
    while true; do
        printf "${BOLD}Choice${NC} [1]: "
        read -r choice
        choice="${choice:-1}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "$((choice - 1))"
            return
        fi
        warn "Please enter a number between 1 and ${#options[@]}"
    done
}

# Y/n confirm
confirm() {
    local prompt="$1"
    local answer
    printf "${BOLD}%s${NC} [Y/n]: " "$prompt"
    read -r answer
    case "${answer,,}" in
        n|no) return 1 ;;
        *)    return 0 ;;
    esac
}

# sed replacement wrapper (macOS + Linux compatible)
generate_file() {
    local template="$1"
    local output="$2"

    if [ ! -f "$template" ]; then
        error "Template not found: $template"
        return 1
    fi

    local outdir
    outdir="$(dirname "$output")"
    mkdir -p "$outdir"

    # Check for existing file
    if [ -f "$output" ]; then
        if ! confirm "  File exists: $output — overwrite?"; then
            warn "  Skipped: $output"
            return 0
        fi
    fi

    # Build sed commands for all variables
    local sed_args=()
    sed_args+=(-e "s|\${__REPO_OWNER}|${REPO_OWNER}|g")
    sed_args+=(-e "s|\${__REPO_NAME}|${REPO_NAME}|g")
    sed_args+=(-e "s|\${__PROD_BRANCH}|${PROD_BRANCH}|g")
    sed_args+=(-e "s|\${__STAGING_BRANCH}|${STAGING_BRANCH}|g")
    sed_args+=(-e "s|\${__BACKEND_TEST_CMD}|${BACKEND_TEST_CMD}|g")
    sed_args+=(-e "s|\${__FRONTEND_TEST_CMD}|${FRONTEND_TEST_CMD}|g")
    sed_args+=(-e "s|\${__FRONTEND_DIR}|${FRONTEND_DIR}|g")
    sed_args+=(-e "s|\${__FRONTEND_BUILD_CMD}|${FRONTEND_BUILD_CMD}|g")
    sed_args+=(-e "s|\${__MIGRATION_CMD}|${MIGRATION_CMD}|g")
    sed_args+=(-e "s|\${__BACKEND_APP_STAGING}|${BACKEND_APP_STAGING}|g")
    sed_args+=(-e "s|\${__BACKEND_APP_PROD}|${BACKEND_APP_PROD}|g")
    sed_args+=(-e "s|\${__FRONTEND_PROJECT_STAGING}|${FRONTEND_PROJECT_STAGING}|g")
    sed_args+=(-e "s|\${__FRONTEND_PROJECT_PROD}|${FRONTEND_PROJECT_PROD}|g")
    sed_args+=(-e "s|\${__DB_SERVICE}|${DB_SERVICE}|g")
    sed_args+=(-e "s|\${__PYTHON_VERSION}|${PYTHON_VERSION}|g")
    sed_args+=(-e "s|\${__NODE_VERSION_FILE}|${NODE_VERSION_FILE}|g")

    sed "${sed_args[@]}" "$template" > "$output"
    success "  Created: $output"
}

# Generate BACKLOG.yml tracks section
generate_tracks() {
    local output="$1"
    local tracks_yaml=""

    for i in "${!TRACK_NAMES[@]}"; do
        local name="${TRACK_NAMES[$i]}"
        local id_prefix="${TRACK_ID_PREFIXES[$i]}"
        local branch_prefix="${TRACK_BRANCH_PREFIXES[$i]}"
        local issue_label="${TRACK_ISSUE_LABELS[$i]}"
        local commit_prefix="${TRACK_COMMIT_PREFIXES[$i]}"
        local north_star="${TRACK_NORTH_STARS[$i]}"
        local cron="${TRACK_CRONS[$i]}"

        tracks_yaml+="  ${name}:
    meta:
      owner: ${REPO_OWNER}
      north_star: >
        ${north_star}
      target_ship_date: null
      locked: false
      scheduled_agent_routine_id: null
      scheduled_agent_cron: \"${cron}\"
      branch_prefix: ${branch_prefix}
      issue_label: ${issue_label}
      commit_prefix: ${commit_prefix}

    items:

      # Add your first item here:
      # - id: ${id_prefix}01-01
      #   title: \"Your first item\"
      #   epic: ${id_prefix}E01
      #   status: ready
      #   deps: []
      #   spec: items/${id_prefix}01-01-your-first-item.md
      #   issue: null
      #   branch: null
      #   staging_merge_sha: null
      #   main_pr: null
      #   notes: null

"
    done

    # Replace the placeholder in the output file
    local tmpfile
    tmpfile="$(mktemp)"

    # Use awk to replace the placeholder line with the generated YAML
    awk -v tracks="$tracks_yaml" '{
        if ($0 ~ /^# __TRACKS_PLACEHOLDER__/) {
            printf "%s", tracks
        } else {
            print
        }
    }' "$output" > "$tmpfile"
    mv "$tmpfile" "$output"
}

# ── Ctrl+C handler ───────────────────────────────────────────────

cleanup() {
    echo ""
    warn "Installation cancelled."
    exit 130
}
trap cleanup INT

# ── Parse args ───────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--target <dir>]"
            echo ""
            echo "Scaffold agentic roadmap automation into a git repo."
            echo ""
            echo "Options:"
            echo "  --target <dir>  Target repository directory"
            echo "  --help, -h      Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Usage: $0 [--target <dir>]"
            exit 1
            ;;
    esac
done

# ── Banner ───────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}roadmap-agent-toolkit${NC} — scaffold agentic roadmap automation\n"
printf "────────────────────────────────────────────────────────────\n\n"

# ── Target directory ─────────────────────────────────────────────

if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$(ask "Target repository directory" ".")"
fi

TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    error "Directory does not exist: $TARGET_DIR"
    exit 1
}

# Validate git repo
if [ ! -d "$TARGET_DIR/.git" ]; then
    error "$TARGET_DIR is not a git repository"
    exit 1
fi

info "Target: $TARGET_DIR"

# ── Auto-detect repo info ───────────────────────────────────────

REMOTE_URL="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo "")"

if [ -n "$REMOTE_URL" ]; then
    # Extract owner/repo from SSH or HTTPS URL
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        info "Detected repo: $REPO_OWNER/$REPO_NAME"
    fi
fi

# ── Interactive prompts ──────────────────────────────────────────

printf "\n${BOLD}Repository${NC}\n"
REPO_OWNER="$(ask "GitHub owner (org or user)" "$REPO_OWNER")"
REPO_NAME="$(ask "Repository name" "$REPO_NAME")"
PROD_BRANCH="$(ask "Production branch" "$PROD_BRANCH")"
STAGING_BRANCH="$(ask "Staging branch" "$STAGING_BRANCH")"

printf "\n${BOLD}Backend${NC}\n"
BACKEND_TEST_CMD="$(ask "Backend test command" "python manage.py test --noinput")"
MIGRATION_CMD="$(ask "Migration command" "python manage.py migrate")"
PYTHON_VERSION="$(ask "Python version" "$PYTHON_VERSION")"

local_db_idx="$(ask_choice "Database service for CI" "postgres" "mysql" "none")"
case "$local_db_idx" in
    0) DB_SERVICE="postgres" ;;
    1) DB_SERVICE="mysql" ;;
    2) DB_SERVICE="none" ;;
esac

printf "\n${BOLD}Frontend${NC}\n"
FRONTEND_DIR="$(ask "Frontend directory" "frontend")"
FRONTEND_TEST_CMD="$(ask "Frontend test command" "npm test")"
FRONTEND_BUILD_CMD="$(ask "Frontend build command" "npm run build")"
NODE_VERSION_FILE="$(ask "Node version file" "${FRONTEND_DIR}/.nvmrc")"

printf "\n${BOLD}Hosting — Backend${NC}\n"
backend_idx="$(ask_choice "Backend hosting platform" "Heroku" "Fly.io" "Custom / other")"
case "$backend_idx" in
    0) BACKEND_PLATFORM="heroku" ;;
    1) BACKEND_PLATFORM="fly" ;;
    2) BACKEND_PLATFORM="custom" ;;
esac
BACKEND_APP_STAGING="$(ask "Staging backend app name" "${REPO_NAME}-staging")"
BACKEND_APP_PROD="$(ask "Production backend app name" "${REPO_NAME}-prod")"

printf "\n${BOLD}Hosting — Frontend${NC}\n"
frontend_idx="$(ask_choice "Frontend hosting platform" "Cloudflare Pages" "Vercel" "Custom / other")"
case "$frontend_idx" in
    0) FRONTEND_PLATFORM="cloudflare-pages" ;;
    1) FRONTEND_PLATFORM="vercel" ;;
    2) FRONTEND_PLATFORM="custom" ;;
esac
FRONTEND_PROJECT_STAGING="$(ask "Staging frontend project name" "${REPO_NAME}-staging")"
FRONTEND_PROJECT_PROD="$(ask "Production frontend project name" "${REPO_NAME}-prod")"

# ── Tracks ───────────────────────────────────────────────────────

printf "\n${BOLD}Roadmap tracks${NC}\n"
info "Each track is an independent work queue with its own agent."
info "You need at least one track. You can add more later."

track_count=0
add_another=true
cron_hour=0

while $add_another; do
    printf "\n${BOLD}Track #$((track_count + 1))${NC}\n"
    local_name="$(ask "Track name (e.g. core, platform, ai)" "")"
    if [ -z "$local_name" ]; then
        if [ "$track_count" -eq 0 ]; then
            warn "You need at least one track."
            continue
        else
            break
        fi
    fi

    local_id_prefix="$(ask "Item ID prefix (single letter, e.g. I, P, A)" "${local_name:0:1}" | tr '[:lower:]' '[:upper:]')"
    local_branch_prefix="$(ask "Branch prefix" "$local_name")"
    local_issue_label="$(ask "Issue label" "roadmap-${local_name}")"
    local_commit_prefix="$(ask "Commit prefix" "$local_name")"
    local_north_star="$(ask "One-line goal for this track" "")"
    local_cron="$(ask "Cron schedule (UTC)" "0 ${cron_hour}/6 * * *")"

    TRACK_NAMES+=("$local_name")
    TRACK_ID_PREFIXES+=("$local_id_prefix")
    TRACK_BRANCH_PREFIXES+=("$local_branch_prefix")
    TRACK_ISSUE_LABELS+=("$local_issue_label")
    TRACK_COMMIT_PREFIXES+=("$local_commit_prefix")
    TRACK_NORTH_STARS+=("$local_north_star")
    TRACK_CRONS+=("$local_cron")

    track_count=$((track_count + 1))
    cron_hour=$((cron_hour + 1))

    if ! confirm "Add another track?"; then
        add_another=false
    fi
done

# ── Ad-hoc agent ─────────────────────────────────────────────────

printf "\n${BOLD}Ad-hoc agent${NC}\n"
if confirm "Set up an ad-hoc issue agent? (picks up unlabeled GitHub issues)"; then
    ADHOC_AGENT="true"
    ADHOC_CRON="$(ask "Ad-hoc agent cron schedule (UTC)" "0 ${cron_hour}/6 * * *")"
fi

# ── Summary ──────────────────────────────────────────────────────

printf "\n${BOLD}Summary${NC}\n"
printf "────────────────────────────────────────────────────────────\n"
printf "  Repo:             %s/%s\n" "$REPO_OWNER" "$REPO_NAME"
printf "  Branches:         %s (prod) / %s (staging)\n" "$PROD_BRANCH" "$STAGING_BRANCH"
printf "  Backend:          %s (%s / %s)\n" "$BACKEND_PLATFORM" "$BACKEND_APP_STAGING" "$BACKEND_APP_PROD"
printf "  Frontend:         %s (%s / %s)\n" "$FRONTEND_PLATFORM" "$FRONTEND_PROJECT_STAGING" "$FRONTEND_PROJECT_PROD"
printf "  Tracks:           %s\n" "${TRACK_NAMES[*]}"
printf "  Ad-hoc agent:     %s\n" "$ADHOC_AGENT"
printf "────────────────────────────────────────────────────────────\n"

if ! confirm "Proceed with installation?"; then
    warn "Installation cancelled."
    exit 0
fi

# ── Generate files ───────────────────────────────────────────────

printf "\n${BOLD}Generating files...${NC}\n\n"

# WORKFLOWS.md (copied verbatim, not a template)
info "WORKFLOWS.md"
if [ -f "$TARGET_DIR/WORKFLOWS.md" ]; then
    if confirm "  File exists: WORKFLOWS.md — overwrite?"; then
        cp "$TEMPLATES_DIR/WORKFLOWS.md" "$TARGET_DIR/WORKFLOWS.md"
        success "  Created: WORKFLOWS.md"
    else
        warn "  Skipped: WORKFLOWS.md"
    fi
else
    cp "$TEMPLATES_DIR/WORKFLOWS.md" "$TARGET_DIR/WORKFLOWS.md"
    success "  Created: WORKFLOWS.md"
fi

# docs/ templates
info "docs/"
mkdir -p "$TARGET_DIR/docs/roadmap/epics" "$TARGET_DIR/docs/roadmap/items"
generate_file "$TEMPLATES_DIR/docs/INFRA.yml.tmpl" "$TARGET_DIR/docs/INFRA.yml"
generate_file "$TEMPLATES_DIR/docs/ROADMAPS.md.tmpl" "$TARGET_DIR/docs/ROADMAPS.md"
generate_file "$TEMPLATES_DIR/docs/roadmap/AGENT_PROMPT.md.tmpl" "$TARGET_DIR/docs/roadmap/AGENT_PROMPT.md"
generate_file "$TEMPLATES_DIR/docs/roadmap/AUTOMATION.md.tmpl" "$TARGET_DIR/docs/roadmap/AUTOMATION.md"
generate_file "$TEMPLATES_DIR/docs/roadmap/README.md.tmpl" "$TARGET_DIR/docs/roadmap/README.md"

# BACKLOG.yml — needs special track generation
info "BACKLOG.yml"
generate_file "$TEMPLATES_DIR/docs/roadmap/BACKLOG.yml.tmpl" "$TARGET_DIR/docs/roadmap/BACKLOG.yml"
generate_tracks "$TARGET_DIR/docs/roadmap/BACKLOG.yml"

# Ad-hoc agent files
if [ "$ADHOC_AGENT" = "true" ]; then
    info "docs/roadmap-adhoc/"
    mkdir -p "$TARGET_DIR/docs/roadmap-adhoc"
    generate_file "$TEMPLATES_DIR/docs/roadmap-adhoc/STATE.yml.tmpl" "$TARGET_DIR/docs/roadmap-adhoc/STATE.yml"
    generate_file "$TEMPLATES_DIR/docs/roadmap-adhoc/AGENT_PROMPT.md.tmpl" "$TARGET_DIR/docs/roadmap-adhoc/AGENT_PROMPT.md"
    generate_file "$TEMPLATES_DIR/docs/roadmap-adhoc/README.md.tmpl" "$TARGET_DIR/docs/roadmap-adhoc/README.md"
fi

# CI workflows
info ".github/workflows/"
mkdir -p "$TARGET_DIR/.github/workflows"

generate_file "$TEMPLATES_DIR/.github/workflows/tests.yml.tmpl" "$TARGET_DIR/.github/workflows/tests.yml"
generate_file "$TEMPLATES_DIR/.github/workflows/frontend-tests.yml.tmpl" "$TARGET_DIR/.github/workflows/frontend-tests.yml"

# Platform-specific workflows
info "  Selecting platform-specific workflow variants..."

# Staging migrate
case "$BACKEND_PLATFORM" in
    heroku) generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/heroku.yml.tmpl" "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
    *)      generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/custom.yml.tmpl" "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
esac

# Deploy prod backend
case "$BACKEND_PLATFORM" in
    heroku) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/heroku.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
    fly)    generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/fly.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
    *)      generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/custom.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
esac

# Deploy prod frontend
case "$FRONTEND_PLATFORM" in
    cloudflare-pages) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/cloudflare-pages.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
    vercel)           generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/vercel.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
    *)                generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/custom.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
esac

# Deploy staging frontend
case "$FRONTEND_PLATFORM" in
    cloudflare-pages) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/cloudflare-pages.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
    vercel)           generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/vercel.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
    *)                generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/custom.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
esac

# ── Optional: create GH labels + staging branch ─────────────────

printf "\n${BOLD}GitHub setup (optional)${NC}\n"

if command -v gh &>/dev/null; then
    if confirm "Create GitHub issue labels for each track?"; then
        COLORS=("FF6B35" "2EA043" "0969DA" "8957E5" "BF3989" "CF222E")
        for i in "${!TRACK_NAMES[@]}"; do
            local_label="${TRACK_ISSUE_LABELS[$i]}"
            local_color="${COLORS[$((i % ${#COLORS[@]}))]}"
            if gh label create "$local_label" --repo "$REPO_OWNER/$REPO_NAME" \
                --color "$local_color" --description "Roadmap: ${TRACK_NAMES[$i]}" 2>/dev/null; then
                success "  Label: $local_label"
            else
                warn "  Label already exists or failed: $local_label"
            fi
        done

        if [ "$ADHOC_AGENT" = "true" ]; then
            for lbl in "adhoc:in-progress" "adhoc:staged" "adhoc:blocked" "adhoc:needs-clarification" "adhoc:not-actionable"; do
                if gh label create "$lbl" --repo "$REPO_OWNER/$REPO_NAME" \
                    --color "FBCA04" --description "Ad-hoc agent state" 2>/dev/null; then
                    success "  Label: $lbl"
                else
                    warn "  Label already exists or failed: $lbl"
                fi
            done
        fi
    fi

    if confirm "Create the '$STAGING_BRANCH' branch from '$PROD_BRANCH'?"; then
        if git -C "$TARGET_DIR" show-ref --verify --quiet "refs/heads/$STAGING_BRANCH" 2>/dev/null; then
            warn "  Branch '$STAGING_BRANCH' already exists locally"
        else
            git -C "$TARGET_DIR" branch "$STAGING_BRANCH" "$PROD_BRANCH" 2>/dev/null && \
                success "  Branch: $STAGING_BRANCH (from $PROD_BRANCH)" || \
                warn "  Could not create branch"
        fi

        if confirm "Push '$STAGING_BRANCH' to origin?"; then
            git -C "$TARGET_DIR" push -u origin "$STAGING_BRANCH" 2>/dev/null && \
                success "  Pushed: $STAGING_BRANCH" || \
                warn "  Could not push (may already exist on remote)"
        fi
    fi
else
    warn "gh CLI not found — skipping label + branch creation."
    info "Install: https://cli.github.com"
fi

# ── Summary ──────────────────────────────────────────────────────

printf "\n"
printf "${GREEN}${BOLD}Installation complete!${NC}\n"
printf "────────────────────────────────────────────────────────────\n"
printf "\n"
printf "${BOLD}Generated files:${NC}\n"
printf "  WORKFLOWS.md\n"
printf "  docs/INFRA.yml\n"
printf "  docs/ROADMAPS.md\n"
printf "  docs/roadmap/README.md\n"
printf "  docs/roadmap/AUTOMATION.md\n"
printf "  docs/roadmap/AGENT_PROMPT.md\n"
printf "  docs/roadmap/BACKLOG.yml\n"
if [ "$ADHOC_AGENT" = "true" ]; then
    printf "  docs/roadmap-adhoc/STATE.yml\n"
    printf "  docs/roadmap-adhoc/AGENT_PROMPT.md\n"
    printf "  docs/roadmap-adhoc/README.md\n"
fi
printf "  .github/workflows/tests.yml\n"
printf "  .github/workflows/frontend-tests.yml\n"
printf "  .github/workflows/staging-migrate.yml\n"
printf "  .github/workflows/deploy-prod-backend.yml\n"
printf "  .github/workflows/deploy-prod-frontend.yml\n"
printf "  .github/workflows/deploy-staging-frontend.yml\n"
printf "\n"
printf "${BOLD}Next steps:${NC}\n"
printf "  1. Review the generated files, especially:\n"
printf "     - docs/roadmap/BACKLOG.yml — add your first items\n"
printf "     - docs/roadmap/AGENT_PROMPT.md — customize env details\n"
printf "     - .github/workflows/tests.yml — add your CI setup steps\n"
printf "  2. Create item spec files under docs/roadmap/items/\n"
printf "  3. Set up required GitHub repo secrets for your platform\n"
printf "  4. Schedule agents (one per track) via your preferred scheduler\n"
printf "  5. Run one tick manually to verify end-to-end\n"
printf "\n"
printf "  Full documentation: https://github.com/yevgetman/roadmap-agent-toolkit\n"
printf "\n"
