#!/usr/bin/env bash
# roadmap-agent-toolkit installer
# Scaffolds multi-track backlogs, CI pipelines, scheduled LLM agent
# infrastructure, and deploy workflows into any repo.
#
# Usage:
#   ./install.sh --target /path/to/your/repo
#   ./install.sh --config config.yml --target /path/to/your/repo
#   ./install.sh   (prompts for everything interactively)

set -euo pipefail

# ── Globals ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
PROFILES_DIR="$SCRIPT_DIR/profiles"
TARGET_DIR=""
CONFIG_FILE=""

# Repository
REPO_OWNER=""
REPO_NAME=""
PROD_BRANCH="main"
STAGING_BRANCH="staging"

# Backend
BACKEND_PLATFORM=""
BACKEND_TEST_CMD=""
MIGRATION_CMD=""
BACKEND_APP_STAGING=""
BACKEND_APP_PROD=""
PYTHON_VERSION="3.12"
DB_SERVICE="sqlite"

# Backend — platform-specific (AWS ECS)
AWS_REGION=""
ECR_REPO=""
ECS_CLUSTER_PROD=""
ECS_CLUSTER_STAGING=""
ECS_SUBNET=""
ECS_SG=""

# Backend — platform-specific (GCP Cloud Run)
GCP_PROJECT_ID=""
GCP_REGION=""
ARTIFACT_REGISTRY_REPO=""

# Backend — platform-specific (Render)
RENDER_SERVICE_ID_PROD=""
RENDER_SERVICE_ID_STAGING=""

# Frontend
FRONTEND_PLATFORM=""
FRONTEND_DIR="frontend"
FRONTEND_TEST_CMD="npm test"
FRONTEND_BUILD_CMD="npm run build"
FRONTEND_PROJECT_STAGING=""
FRONTEND_PROJECT_PROD=""
NODE_VERSION_FILE=""

# Frontend — platform-specific (Netlify)
NETLIFY_SITE_ID_PROD=""
NETLIFY_SITE_ID_STAGING=""

# Frontend — platform-specific (S3+CloudFront)
S3_BUCKET_PROD=""
S3_BUCKET_STAGING=""
CLOUDFRONT_DIST_PROD=""
CLOUDFRONT_DIST_STAGING=""

# Frontend — platform-specific (FTP)
FTP_PROTOCOL="sftp"
FTP_HOST_PROD=""
FTP_HOST_STAGING=""
FTP_REMOTE_PATH_PROD="/var/www/html/"
FTP_REMOTE_PATH_STAGING="/var/www/staging/"

# Agents
AGENT_RUNTIME=""
AGENT_MODEL=""
AGENT_INVOKE_COMMAND=""
AGENT_INSTALL_COMMAND=""
AGENT_GHA_INVOKE_COMMAND=""
SCHEDULER=""

# Agent cadence
CADENCE_HOURS=6
CADENCE_SECONDS=21600
OFFSET_HOURS=1

# Track config (arrays)
TRACK_NAMES=()
TRACK_ID_PREFIXES=()
TRACK_BRANCH_PREFIXES=()
TRACK_ISSUE_LABELS=()
TRACK_COMMIT_PREFIXES=()
TRACK_NORTH_STARS=()
TRACK_CRONS=()

# Ad-hoc agent
ADHOC_AGENT="false"
ADHOC_CRON="0 2/6 * * *"

# Files generated (for summary)
GENERATED_FILES=()
SKIPPED_FILES=()
FORCE_OVERWRITE=false
OVERWRITE_ALL=false

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
    if [ -f "$output" ] && [ "$FORCE_OVERWRITE" != "true" ] && [ "$OVERWRITE_ALL" != "true" ]; then
        local rel_path="${output#$TARGET_DIR/}"
        printf "  ${YELLOW}exists:${NC} %s\n" "$rel_path"

        local action
        while true; do
            printf "  ${BOLD}[S]kip / [O]verwrite / [A]ll / [Q]uit${NC}: "
            read -r action
            case "${action,,}" in
                s|skip|"")
                    warn "  Skipped: $rel_path"
                    SKIPPED_FILES+=("$rel_path")
                    return 0
                    ;;
                o|overwrite) break ;;
                a|all) OVERWRITE_ALL=true; break ;;
                q|quit) warn "Installation stopped by user."; exit 0 ;;
                *) warn "  Enter S, O, A, or Q" ;;
            esac
        done
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

    # Platform-specific: AWS ECS
    sed_args+=(-e "s|\${__AWS_REGION}|${AWS_REGION}|g")
    sed_args+=(-e "s|\${__ECR_REPO}|${ECR_REPO}|g")
    sed_args+=(-e "s|\${__ECS_CLUSTER_PROD}|${ECS_CLUSTER_PROD}|g")
    sed_args+=(-e "s|\${__ECS_CLUSTER_STAGING}|${ECS_CLUSTER_STAGING}|g")
    sed_args+=(-e "s|\${__ECS_SUBNET}|${ECS_SUBNET}|g")
    sed_args+=(-e "s|\${__ECS_SG}|${ECS_SG}|g")

    # Platform-specific: GCP Cloud Run
    sed_args+=(-e "s|\${__GCP_PROJECT_ID}|${GCP_PROJECT_ID}|g")
    sed_args+=(-e "s|\${__GCP_REGION}|${GCP_REGION}|g")
    sed_args+=(-e "s|\${__ARTIFACT_REGISTRY_REPO}|${ARTIFACT_REGISTRY_REPO}|g")

    # Platform-specific: Render
    sed_args+=(-e "s|\${__RENDER_SERVICE_ID_PROD}|${RENDER_SERVICE_ID_PROD}|g")
    sed_args+=(-e "s|\${__RENDER_SERVICE_ID_STAGING}|${RENDER_SERVICE_ID_STAGING}|g")

    # Platform-specific: Netlify
    sed_args+=(-e "s|\${__NETLIFY_SITE_ID_PROD}|${NETLIFY_SITE_ID_PROD}|g")
    sed_args+=(-e "s|\${__NETLIFY_SITE_ID_STAGING}|${NETLIFY_SITE_ID_STAGING}|g")

    # Platform-specific: S3+CloudFront
    sed_args+=(-e "s|\${__S3_BUCKET_PROD}|${S3_BUCKET_PROD}|g")
    sed_args+=(-e "s|\${__S3_BUCKET_STAGING}|${S3_BUCKET_STAGING}|g")
    sed_args+=(-e "s|\${__CLOUDFRONT_DIST_PROD}|${CLOUDFRONT_DIST_PROD}|g")
    sed_args+=(-e "s|\${__CLOUDFRONT_DIST_STAGING}|${CLOUDFRONT_DIST_STAGING}|g")

    # Platform-specific: FTP
    sed_args+=(-e "s|\${__FTP_PROTOCOL}|${FTP_PROTOCOL}|g")
    sed_args+=(-e "s|\${__FTP_HOST_PROD}|${FTP_HOST_PROD}|g")
    sed_args+=(-e "s|\${__FTP_HOST_STAGING}|${FTP_HOST_STAGING}|g")
    sed_args+=(-e "s|\${__FTP_REMOTE_PATH_PROD}|${FTP_REMOTE_PATH_PROD}|g")
    sed_args+=(-e "s|\${__FTP_REMOTE_PATH_STAGING}|${FTP_REMOTE_PATH_STAGING}|g")

    # Agent / scheduler
    sed_args+=(-e "s|\${__AGENT_MODEL}|${AGENT_MODEL}|g")
    sed_args+=(-e "s|\${__AGENT_RUNTIME}|${AGENT_RUNTIME}|g")
    sed_args+=(-e "s|\${__SCHEDULER}|${SCHEDULER}|g")
    sed_args+=(-e "s|\${__AGENT_INVOKE_COMMAND}|${AGENT_INVOKE_COMMAND}|g")
    sed_args+=(-e "s|\${__AGENT_INSTALL_COMMAND}|${AGENT_INSTALL_COMMAND}|g")
    sed_args+=(-e "s|\${__AGENT_GHA_INVOKE_COMMAND}|${AGENT_GHA_INVOKE_COMMAND}|g")
    sed_args+=(-e "s|\${__REPO_ROOT}|${TARGET_DIR}|g")
    sed_args+=(-e "s|\${__HOME}|${HOME}|g")
    sed_args+=(-e "s|\${__CADENCE_HOURS}|${CADENCE_HOURS}|g")
    sed_args+=(-e "s|\${__CADENCE_SECONDS}|${CADENCE_SECONDS}|g")

    sed "${sed_args[@]}" "$template" > "$output"
    success "  Created: $output"
    GENERATED_FILES+=("$output")
}

# Generate a file with per-track sed replacements (track name, cron)
generate_file_for_track() {
    local template="$1"
    local output="$2"
    local track_name="$3"
    local cron_expression="$4"

    # Temporarily set track-level vars, generate, then restore
    local saved_track_name="${TRACK_NAME_CURRENT:-}"
    local saved_cron="${CRON_EXPRESSION_CURRENT:-}"
    TRACK_NAME_CURRENT="$track_name"
    CRON_EXPRESSION_CURRENT="$cron_expression"

    if [ ! -f "$template" ]; then
        error "Template not found: $template"
        return 1
    fi

    local outdir
    outdir="$(dirname "$output")"
    mkdir -p "$outdir"

    if [ -f "$output" ] && [ "$FORCE_OVERWRITE" != "true" ] && [ "$OVERWRITE_ALL" != "true" ]; then
        # Generate to a temp file first to check for changes
        local tmpgen
        tmpgen="$(mktemp)"
        # (we'll fill tmpgen after sed runs — for now just prompt)

        local rel_path="${output#$TARGET_DIR/}"
        printf "  ${YELLOW}exists:${NC} %s\n" "$rel_path"

        # Show brief diff preview
        if command -v diff &>/dev/null; then
            local preview
            preview="$(diff --brief "$output" "$template" 2>/dev/null)" || true
        fi

        local action
        while true; do
            printf "  ${BOLD}[S]kip / [O]verwrite / [A]ll / [Q]uit${NC}: "
            read -r action
            case "${action,,}" in
                s|skip|"")
                    warn "  Skipped: $rel_path"
                    SKIPPED_FILES+=("$rel_path")
                    rm -f "$tmpgen"
                    return 0
                    ;;
                o|overwrite)
                    break
                    ;;
                a|all)
                    OVERWRITE_ALL=true
                    break
                    ;;
                q|quit)
                    warn "Installation stopped by user."
                    rm -f "$tmpgen"
                    exit 0
                    ;;
                *)
                    warn "  Enter S, O, A, or Q"
                    ;;
            esac
        done
        rm -f "$tmpgen"
    fi

    # Start with the base generate_file sed_args, then add track-specific ones
    local sed_args=()
    sed_args+=(-e "s|\${__REPO_OWNER}|${REPO_OWNER}|g")
    sed_args+=(-e "s|\${__REPO_NAME}|${REPO_NAME}|g")
    sed_args+=(-e "s|\${__PROD_BRANCH}|${PROD_BRANCH}|g")
    sed_args+=(-e "s|\${__STAGING_BRANCH}|${STAGING_BRANCH}|g")
    sed_args+=(-e "s|\${__TRACK_NAME}|${track_name}|g")
    sed_args+=(-e "s|\${__CRON_EXPRESSION}|${cron_expression}|g")
    sed_args+=(-e "s|\${__CADENCE_SECONDS}|${CADENCE_SECONDS}|g")
    sed_args+=(-e "s|\${__CADENCE_HOURS}|${CADENCE_HOURS}|g")
    sed_args+=(-e "s|\${__AGENT_MODEL}|${AGENT_MODEL}|g")
    sed_args+=(-e "s|\${__AGENT_RUNTIME}|${AGENT_RUNTIME}|g")
    sed_args+=(-e "s|\${__AGENT_INVOKE_COMMAND}|${AGENT_INVOKE_COMMAND}|g")
    sed_args+=(-e "s|\${__AGENT_INSTALL_COMMAND}|${AGENT_INSTALL_COMMAND}|g")
    sed_args+=(-e "s|\${__AGENT_GHA_INVOKE_COMMAND}|${AGENT_GHA_INVOKE_COMMAND}|g")
    sed_args+=(-e "s|\${__SCHEDULER}|${SCHEDULER}|g")
    sed_args+=(-e "s|\${__REPO_ROOT}|${TARGET_DIR}|g")
    sed_args+=(-e "s|\${__HOME}|${HOME}|g")

    sed "${sed_args[@]}" "$template" > "$output"
    success "  Created: $output"
    GENERATED_FILES+=("$output")

    TRACK_NAME_CURRENT="$saved_track_name"
    CRON_EXPRESSION_CURRENT="$saved_cron"
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

# ── Config file parser ──────────────────────────────────────────
# Simple YAML reader: flattens nested keys to dot notation,
# strips comments, handles basic key: value pairs.
# No dependency on yq — uses grep/awk/sed.

parse_config() {
    local file="$1"

    if [ ! -f "$file" ]; then
        error "Config file not found: $file"
        exit 1
    fi

    info "Reading config from: $file"

    # Read key-value pairs, flattening nested indentation to dot notation
    local prefix=""
    local prev_indent=0

    # Stack of prefixes for nested levels
    local prefix_stack=("")

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Count leading spaces
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local indent=$(( ${#line} - ${#stripped} ))

        # Extract key and value
        if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*):(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            val="$(echo "$val" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')"

            # Determine nesting level (2 spaces per level)
            local level=$((indent / 2))

            # Adjust prefix stack
            while [ ${#prefix_stack[@]} -gt $((level + 1)) ]; do
                unset 'prefix_stack[${#prefix_stack[@]}-1]'
            done

            if [ -n "$val" ]; then
                # Leaf key: value
                local full_key=""
                for p in "${prefix_stack[@]}"; do
                    if [ -n "$p" ]; then
                        full_key="${full_key}${p}."
                    fi
                done
                full_key="${full_key}${key}"
                config_set "$full_key" "$val"
            else
                # Section key (no value) — push onto prefix stack
                prefix_stack+=("$key")
            fi
        fi
    done < "$file"
}

# Map a config key (dot notation) to the corresponding global variable
config_set() {
    local key="$1"
    local val="$2"

    case "$key" in
        repository.owner)                  REPO_OWNER="$val" ;;
        repository.name)                   REPO_NAME="$val" ;;
        repository.production_branch)      PROD_BRANCH="$val" ;;
        repository.staging_branch)         STAGING_BRANCH="$val" ;;
        backend.platform)                  BACKEND_PLATFORM="$val" ;;
        backend.test_command)              BACKEND_TEST_CMD="$val" ;;
        backend.migration_command)         MIGRATION_CMD="$val" ;;
        backend.app_name_staging)          BACKEND_APP_STAGING="$val" ;;
        backend.app_name_prod)             BACKEND_APP_PROD="$val" ;;
        backend.aws_region)                AWS_REGION="$val" ;;
        backend.ecr_repo)                  ECR_REPO="$val" ;;
        backend.ecs_cluster_prod)          ECS_CLUSTER_PROD="$val" ;;
        backend.ecs_cluster_staging)       ECS_CLUSTER_STAGING="$val" ;;
        backend.ecs_subnet)                ECS_SUBNET="$val" ;;
        backend.ecs_sg)                    ECS_SG="$val" ;;
        backend.gcp_project_id)            GCP_PROJECT_ID="$val" ;;
        backend.gcp_region)                GCP_REGION="$val" ;;
        backend.artifact_registry_repo)    ARTIFACT_REGISTRY_REPO="$val" ;;
        backend.render_service_id_prod)    RENDER_SERVICE_ID_PROD="$val" ;;
        backend.render_service_id_staging) RENDER_SERVICE_ID_STAGING="$val" ;;
        frontend.platform)                 FRONTEND_PLATFORM="$val" ;;
        frontend.directory)                FRONTEND_DIR="$val" ;;
        frontend.test_command)             FRONTEND_TEST_CMD="$val" ;;
        frontend.build_command)            FRONTEND_BUILD_CMD="$val" ;;
        frontend.project_name_staging)     FRONTEND_PROJECT_STAGING="$val" ;;
        frontend.project_name_prod)        FRONTEND_PROJECT_PROD="$val" ;;
        frontend.node_version_file)        NODE_VERSION_FILE="$val" ;;
        frontend.netlify_site_id_prod)     NETLIFY_SITE_ID_PROD="$val" ;;
        frontend.netlify_site_id_staging)  NETLIFY_SITE_ID_STAGING="$val" ;;
        frontend.s3_bucket_prod)           S3_BUCKET_PROD="$val" ;;
        frontend.s3_bucket_staging)        S3_BUCKET_STAGING="$val" ;;
        frontend.cloudfront_dist_prod)     CLOUDFRONT_DIST_PROD="$val" ;;
        frontend.cloudfront_dist_staging)  CLOUDFRONT_DIST_STAGING="$val" ;;
        frontend.ftp_protocol)             FTP_PROTOCOL="$val" ;;
        frontend.ftp_host_prod)            FTP_HOST_PROD="$val" ;;
        frontend.ftp_host_staging)         FTP_HOST_STAGING="$val" ;;
        frontend.ftp_remote_path_prod)     FTP_REMOTE_PATH_PROD="$val" ;;
        frontend.ftp_remote_path_staging)  FTP_REMOTE_PATH_STAGING="$val" ;;
        ci.database_service)               DB_SERVICE="$val" ;;
        ci.python_version)                 PYTHON_VERSION="$val" ;;
        agents.runtime)                    AGENT_RUNTIME="$val" ;;
        agents.scheduler)                  SCHEDULER="$val" ;;
        agents.cadence_hours)              CADENCE_HOURS="$val"; CADENCE_SECONDS=$((val * 3600)) ;;
        agents.offset_hours)               OFFSET_HOURS="$val" ;;
        agents.model)                      AGENT_MODEL="$val" ;;
        agents.invoke_command)             AGENT_INVOKE_COMMAND="$val" ;;
        adhoc.enabled)
            case "$val" in
                true|yes|1) ADHOC_AGENT="true" ;;
                *)          ADHOC_AGENT="false" ;;
            esac
            ;;
        adhoc.cron)                        ADHOC_CRON="$val" ;;
        *)
            # Handle track entries: tracks.0.name, tracks.1.name, etc.
            if [[ "$key" =~ ^tracks\.([0-9]+)\.(.+)$ ]]; then
                local idx="${BASH_REMATCH[1]}"
                local field="${BASH_REMATCH[2]}"
                case "$field" in
                    name)           TRACK_NAMES[$idx]="$val" ;;
                    id_prefix)      TRACK_ID_PREFIXES[$idx]="$val" ;;
                    branch_prefix)  TRACK_BRANCH_PREFIXES[$idx]="$val" ;;
                    issue_label)    TRACK_ISSUE_LABELS[$idx]="$val" ;;
                    commit_prefix)  TRACK_COMMIT_PREFIXES[$idx]="$val" ;;
                    north_star)     TRACK_NORTH_STARS[$idx]="$val" ;;
                    cron)           TRACK_CRONS[$idx]="$val" ;;
                esac
            fi
            ;;
    esac
}

# Validate required config fields
validate_config() {
    local errors=0

    if [ -z "$REPO_OWNER" ]; then
        error "Missing required config: repository.owner"
        errors=$((errors + 1))
    fi
    if [ -z "$REPO_NAME" ]; then
        error "Missing required config: repository.name"
        errors=$((errors + 1))
    fi
    if [ -z "$BACKEND_PLATFORM" ]; then
        error "Missing required config: backend.platform"
        errors=$((errors + 1))
    fi
    if [ -z "$FRONTEND_PLATFORM" ]; then
        error "Missing required config: frontend.platform"
        errors=$((errors + 1))
    fi
    if [ ${#TRACK_NAMES[@]} -eq 0 ]; then
        error "Missing required config: at least one track must be defined"
        errors=$((errors + 1))
    fi

    if [ "$errors" -gt 0 ]; then
        error "Config validation failed with $errors error(s)."
        exit 1
    fi
}

# ── Helper: auto-detect test commands ────────────────────────────

auto_detect_test_commands() {
    if [ -n "$BACKEND_TEST_CMD" ]; then
        return
    fi

    if [ -f "$TARGET_DIR/manage.py" ]; then
        BACKEND_TEST_CMD="python manage.py test --noinput"
        info "Auto-detected: Django project (manage.py)"
    elif [ -f "$TARGET_DIR/Gemfile" ]; then
        BACKEND_TEST_CMD="bundle exec rails test"
        info "Auto-detected: Rails project (Gemfile)"
    elif [ -f "$TARGET_DIR/go.mod" ]; then
        BACKEND_TEST_CMD="go test ./..."
        info "Auto-detected: Go project (go.mod)"
    elif [ -f "$TARGET_DIR/Cargo.toml" ]; then
        BACKEND_TEST_CMD="cargo test"
        info "Auto-detected: Rust project (Cargo.toml)"
    fi
}

auto_detect_migration_command() {
    if [ -n "$MIGRATION_CMD" ]; then
        return
    fi

    if [ -f "$TARGET_DIR/manage.py" ]; then
        MIGRATION_CMD="python manage.py migrate --noinput"
    elif [ -f "$TARGET_DIR/Gemfile" ]; then
        MIGRATION_CMD="bundle exec rails db:migrate"
    fi
}

# ── Helper: resolve agent invoke/install commands ────────────────

resolve_agent_commands() {
    case "$AGENT_RUNTIME" in
        claude-code)
            AGENT_INVOKE_COMMAND="claude -p \"\$FULL_PROMPT\" --model ${AGENT_MODEL} --max-turns 100"
            AGENT_INSTALL_COMMAND="npm install -g @anthropic-ai/claude-code"
            AGENT_GHA_INVOKE_COMMAND="claude -p \"Run with TRACK: \${TRACK}  \$PROMPT\" --model ${AGENT_MODEL} --max-turns 100"
            ;;
        codex)
            AGENT_INVOKE_COMMAND="codex -q --model ${AGENT_MODEL} --full-auto \"\$FULL_PROMPT\""
            AGENT_INSTALL_COMMAND="npm install -g @openai/codex"
            AGENT_GHA_INVOKE_COMMAND="codex -q --model ${AGENT_MODEL} --full-auto \"Run with TRACK: \${TRACK}  \$PROMPT\""
            ;;
        open-code)
            AGENT_INVOKE_COMMAND="open-code --non-interactive --prompt \"\$FULL_PROMPT\""
            AGENT_INSTALL_COMMAND="npm install -g @nicepkg/open-code"
            AGENT_GHA_INVOKE_COMMAND="open-code --non-interactive --prompt \"Run with TRACK: \${TRACK}  \$PROMPT\""
            ;;
        custom)
            # AGENT_INVOKE_COMMAND already set by user prompt or config
            if [ -z "$AGENT_INSTALL_COMMAND" ]; then
                AGENT_INSTALL_COMMAND="echo 'Install your agent CLI here'"
            fi
            if [ -z "$AGENT_GHA_INVOKE_COMMAND" ]; then
                AGENT_GHA_INVOKE_COMMAND="$AGENT_INVOKE_COMMAND"
            fi
            ;;
    esac
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
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --force|-f)
            FORCE_OVERWRITE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--target <dir>] [--config <file>] [--force]"
            echo ""
            echo "Scaffold agentic roadmap automation into a git repo."
            echo ""
            echo "Options:"
            echo "  --target <dir>   Target repository directory"
            echo "  --config <file>  YAML config for non-interactive mode"
            echo "  --force, -f      Overwrite existing files without prompting"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Usage: $0 [--target <dir>] [--config <file>] [--force]"
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

# ── Non-interactive mode: parse config and skip prompts ─────────

if [ -n "$CONFIG_FILE" ]; then
    parse_config "$CONFIG_FILE"
    validate_config

    # Apply defaults for optional fields not in config
    if [ -z "$BACKEND_APP_STAGING" ] && [ "$BACKEND_PLATFORM" != "none" ]; then
        BACKEND_APP_STAGING="${REPO_NAME}-staging"
    fi
    if [ -z "$BACKEND_APP_PROD" ] && [ "$BACKEND_PLATFORM" != "none" ]; then
        BACKEND_APP_PROD="${REPO_NAME}-prod"
    fi
    if [ -z "$FRONTEND_PROJECT_STAGING" ] && [ "$FRONTEND_PLATFORM" != "none" ]; then
        FRONTEND_PROJECT_STAGING="${REPO_NAME}-staging"
    fi
    if [ -z "$FRONTEND_PROJECT_PROD" ] && [ "$FRONTEND_PLATFORM" != "none" ]; then
        FRONTEND_PROJECT_PROD="${REPO_NAME}-prod"
    fi
    if [ -z "$NODE_VERSION_FILE" ] && [ "$FRONTEND_PLATFORM" != "none" ]; then
        NODE_VERSION_FILE="${FRONTEND_DIR}/.nvmrc"
    fi
    if [ -z "$AGENT_RUNTIME" ]; then
        AGENT_RUNTIME="claude-code"
    fi

    # Resolve agent model if not set
    if [ -z "$AGENT_MODEL" ]; then
        case "$AGENT_RUNTIME" in
            claude-code) AGENT_MODEL="claude-sonnet-4-6" ;;
            codex)       AGENT_MODEL="codex-5.4" ;;
            *)           AGENT_MODEL="" ;;
        esac
    fi

    # Resolve scheduler if not set
    if [ -z "$SCHEDULER" ]; then
        if [ "$AGENT_RUNTIME" = "claude-code" ]; then
            SCHEDULER="claude-code-routines"
        elif [ "$(uname -s)" = "Darwin" ]; then
            SCHEDULER="launchd"
        else
            SCHEDULER="crontab"
        fi
    fi

    # Resolve agent commands
    resolve_agent_commands

    # Auto-detect test/migration if not in config
    if [ -z "$BACKEND_TEST_CMD" ]; then
        auto_detect_test_commands
    fi
    if [ -z "$MIGRATION_CMD" ]; then
        auto_detect_migration_command
    fi

    # Generate crons if not specified per-track
    for i in "${!TRACK_NAMES[@]}"; do
        if [ -z "${TRACK_CRONS[$i]:-}" ]; then
            local_offset=$((i * OFFSET_HOURS))
            TRACK_CRONS[$i]="0 ${local_offset}/${CADENCE_HOURS} * * *"
        fi
        # Fill in other defaults
        if [ -z "${TRACK_ID_PREFIXES[$i]:-}" ]; then
            TRACK_ID_PREFIXES[$i]="$(echo "${TRACK_NAMES[$i]:0:1}" | tr '[:lower:]' '[:upper:]')"
        fi
        if [ -z "${TRACK_BRANCH_PREFIXES[$i]:-}" ]; then
            TRACK_BRANCH_PREFIXES[$i]="${TRACK_NAMES[$i]}"
        fi
        if [ -z "${TRACK_ISSUE_LABELS[$i]:-}" ]; then
            TRACK_ISSUE_LABELS[$i]="roadmap-${TRACK_NAMES[$i]}"
        fi
        if [ -z "${TRACK_COMMIT_PREFIXES[$i]:-}" ]; then
            TRACK_COMMIT_PREFIXES[$i]="${TRACK_NAMES[$i]}"
        fi
        if [ -z "${TRACK_NORTH_STARS[$i]:-}" ]; then
            TRACK_NORTH_STARS[$i]=""
        fi
    done

    info "Config loaded. Skipping interactive prompts."

    # Jump straight to generation (skip the interactive prompts section)
    # We still show the summary
    printf "\n${BOLD}Summary (from config)${NC}\n"
    printf "────────────────────────────────────────────────────────────\n"
    printf "  Repo:             %s/%s\n" "$REPO_OWNER" "$REPO_NAME"
    printf "  Branches:         %s (prod) / %s (staging)\n" "$PROD_BRANCH" "$STAGING_BRANCH"
    printf "  Backend:          %s" "$BACKEND_PLATFORM"
    [ "$BACKEND_PLATFORM" != "none" ] && printf " (%s / %s)" "$BACKEND_APP_STAGING" "$BACKEND_APP_PROD"
    printf "\n"
    printf "  Frontend:         %s" "$FRONTEND_PLATFORM"
    [ "$FRONTEND_PLATFORM" != "none" ] && printf " (%s / %s)" "$FRONTEND_PROJECT_STAGING" "$FRONTEND_PROJECT_PROD"
    printf "\n"
    printf "  Agent runtime:    %s\n" "$AGENT_RUNTIME"
    printf "  Scheduler:        %s\n" "$SCHEDULER"
    printf "  Tracks:           %s\n" "${TRACK_NAMES[*]}"
    printf "  Ad-hoc agent:     %s\n" "$ADHOC_AGENT"
    printf "────────────────────────────────────────────────────────────\n"

else
    # ── Interactive prompts ──────────────────────────────────────

    # ── Repository ───────────────────────────────────────────────
    printf "\n${BOLD}Repository${NC}\n"
    REPO_OWNER="$(ask "GitHub owner (org or user)" "$REPO_OWNER")"
    REPO_NAME="$(ask "Repository name" "$REPO_NAME")"
    PROD_BRANCH="$(ask "Production branch" "$PROD_BRANCH")"
    STAGING_BRANCH="$(ask "Staging branch" "$STAGING_BRANCH")"

    # ── Auto-detect test/migration commands ──────────────────────
    auto_detect_test_commands
    auto_detect_migration_command

    # ── Backend ──────────────────────────────────────────────────
    printf "\n${BOLD}Backend${NC}\n"
    BACKEND_TEST_CMD="$(ask "Backend test command" "$BACKEND_TEST_CMD")"
    MIGRATION_CMD="$(ask "Migration command (leave empty if none)" "$MIGRATION_CMD")"

    # Python version (only ask if detected as Python project)
    if [ -f "$TARGET_DIR/manage.py" ] || [ -f "$TARGET_DIR/requirements.txt" ] || [ -f "$TARGET_DIR/pyproject.toml" ]; then
        PYTHON_VERSION="$(ask "Python version" "$PYTHON_VERSION")"
    fi

    local_db_idx="$(ask_choice "Database service for CI" "postgres" "mysql" "sqlite (default)")"
    case "$local_db_idx" in
        0) DB_SERVICE="postgres" ;;
        1) DB_SERVICE="mysql" ;;
        2) DB_SERVICE="sqlite" ;;
    esac

    # ── Backend platform ─────────────────────────────────────────
    printf "\n${BOLD}Hosting — Backend${NC}\n"
    backend_idx="$(ask_choice "Backend hosting platform" \
        "Heroku" "Fly.io" "AWS ECS / Fargate" "GCP Cloud Run" \
        "Railway" "Render" "Custom / other" "None (no backend deploy)")"
    case "$backend_idx" in
        0) BACKEND_PLATFORM="heroku" ;;
        1) BACKEND_PLATFORM="fly" ;;
        2) BACKEND_PLATFORM="aws-ecs" ;;
        3) BACKEND_PLATFORM="gcp-cloud-run" ;;
        4) BACKEND_PLATFORM="railway" ;;
        5) BACKEND_PLATFORM="render" ;;
        6) BACKEND_PLATFORM="custom" ;;
        7) BACKEND_PLATFORM="none" ;;
    esac

    # Platform-specific backend prompts
    if [ "$BACKEND_PLATFORM" != "none" ]; then
        BACKEND_APP_STAGING="$(ask "Staging backend app name" "${REPO_NAME}-staging")"
        BACKEND_APP_PROD="$(ask "Production backend app name" "${REPO_NAME}-prod")"

        case "$BACKEND_PLATFORM" in
            aws-ecs)
                AWS_REGION="$(ask "AWS region" "us-east-1")"
                ECR_REPO="$(ask "ECR repository URI" "")"
                ECS_CLUSTER_STAGING="$(ask "ECS cluster name (staging)" "${REPO_NAME}-staging")"
                ECS_CLUSTER_PROD="$(ask "ECS cluster name (production)" "${REPO_NAME}-prod")"
                ECS_SUBNET="$(ask "ECS subnet ID (optional)" "")"
                ECS_SG="$(ask "ECS security group ID (optional)" "")"
                ;;
            gcp-cloud-run)
                GCP_PROJECT_ID="$(ask "GCP project ID" "")"
                GCP_REGION="$(ask "GCP region" "us-central1")"
                ARTIFACT_REGISTRY_REPO="$(ask "Artifact Registry repository" "${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${REPO_NAME}")"
                ;;
            render)
                RENDER_SERVICE_ID_STAGING="$(ask "Staging service ID" "")"
                RENDER_SERVICE_ID_PROD="$(ask "Production service ID" "")"
                ;;
        esac
    fi

    # ── Frontend ─────────────────────────────────────────────────
    printf "\n${BOLD}Hosting — Frontend${NC}\n"
    frontend_idx="$(ask_choice "Frontend hosting platform" \
        "Cloudflare Pages" "Vercel" "Netlify" "AWS S3 + CloudFront" \
        "FTP / SFTP" "Custom / other" "None (no frontend deploy)")"
    case "$frontend_idx" in
        0) FRONTEND_PLATFORM="cloudflare-pages" ;;
        1) FRONTEND_PLATFORM="vercel" ;;
        2) FRONTEND_PLATFORM="netlify" ;;
        3) FRONTEND_PLATFORM="aws-s3-cloudfront" ;;
        4) FRONTEND_PLATFORM="ftp" ;;
        5) FRONTEND_PLATFORM="custom" ;;
        6) FRONTEND_PLATFORM="none" ;;
    esac

    # Frontend common prompts
    if [ "$FRONTEND_PLATFORM" != "none" ]; then
        FRONTEND_DIR="$(ask "Frontend directory" "$FRONTEND_DIR")"
        FRONTEND_TEST_CMD="$(ask "Frontend test command" "$FRONTEND_TEST_CMD")"
        FRONTEND_BUILD_CMD="$(ask "Frontend build command" "$FRONTEND_BUILD_CMD")"
        NODE_VERSION_FILE="$(ask "Node version file" "${FRONTEND_DIR}/.nvmrc")"
        FRONTEND_PROJECT_STAGING="$(ask "Staging frontend project name" "${REPO_NAME}-staging")"
        FRONTEND_PROJECT_PROD="$(ask "Production frontend project name" "${REPO_NAME}-prod")"

        # Platform-specific frontend prompts
        case "$FRONTEND_PLATFORM" in
            netlify)
                NETLIFY_SITE_ID_STAGING="$(ask "Staging Netlify site ID" "")"
                NETLIFY_SITE_ID_PROD="$(ask "Production Netlify site ID" "")"
                ;;
            aws-s3-cloudfront)
                S3_BUCKET_STAGING="$(ask "Staging S3 bucket name" "${REPO_NAME}-staging")"
                S3_BUCKET_PROD="$(ask "Production S3 bucket name" "${REPO_NAME}-prod")"
                CLOUDFRONT_DIST_STAGING="$(ask "Staging CloudFront distribution ID" "")"
                CLOUDFRONT_DIST_PROD="$(ask "Production CloudFront distribution ID" "")"
                if [ -z "$AWS_REGION" ]; then
                    AWS_REGION="$(ask "AWS region" "us-east-1")"
                fi
                ;;
            ftp)
                local_ftp_idx="$(ask_choice "Protocol" "SFTP" "FTP" "FTPS")"
                case "$local_ftp_idx" in
                    0) FTP_PROTOCOL="sftp" ;;
                    1) FTP_PROTOCOL="ftp" ;;
                    2) FTP_PROTOCOL="ftps" ;;
                esac
                FTP_HOST_STAGING="$(ask "Staging server hostname" "")"
                FTP_HOST_PROD="$(ask "Production server hostname" "")"
                FTP_REMOTE_PATH_STAGING="$(ask "Staging remote path" "/var/www/staging/")"
                FTP_REMOTE_PATH_PROD="$(ask "Production remote path" "/var/www/html/")"
                ;;
        esac
    fi

    # ── Tracks ───────────────────────────────────────────────────
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
        local_cron="$(ask "Cron schedule (UTC)" "0 ${cron_hour}/${CADENCE_HOURS} * * *")"

        TRACK_NAMES+=("$local_name")
        TRACK_ID_PREFIXES+=("$local_id_prefix")
        TRACK_BRANCH_PREFIXES+=("$local_branch_prefix")
        TRACK_ISSUE_LABELS+=("$local_issue_label")
        TRACK_COMMIT_PREFIXES+=("$local_commit_prefix")
        TRACK_NORTH_STARS+=("$local_north_star")
        TRACK_CRONS+=("$local_cron")

        track_count=$((track_count + 1))
        cron_hour=$((cron_hour + OFFSET_HOURS))

        if ! confirm "Add another track?"; then
            add_another=false
        fi
    done

    # ── Ad-hoc agent ─────────────────────────────────────────────
    printf "\n${BOLD}Ad-hoc agent${NC}\n"
    if confirm "Set up an ad-hoc issue agent? (picks up unlabeled GitHub issues)"; then
        ADHOC_AGENT="true"
        ADHOC_CRON="$(ask "Ad-hoc agent cron schedule (UTC)" "0 ${cron_hour}/${CADENCE_HOURS} * * *")"
    fi

    # ── Agent runtime ────────────────────────────────────────────
    printf "\n${BOLD}Agent runtime${NC}\n"

    # Auto-detect available runtimes
    DETECTED_RUNTIME=""
    if command -v claude &>/dev/null; then
        DETECTED_RUNTIME="claude-code"
        info "Detected: claude CLI (Claude Code)"
    elif command -v codex &>/dev/null; then
        DETECTED_RUNTIME="codex"
        info "Detected: codex CLI (OpenAI Codex)"
    fi

    agent_idx="$(ask_choice "Agent runtime" \
        "Claude Code${DETECTED_RUNTIME:+ (detected)}" \
        "OpenAI Codex" \
        "Open Code" \
        "Custom")"
    case "$agent_idx" in
        0) AGENT_RUNTIME="claude-code" ;;
        1) AGENT_RUNTIME="codex" ;;
        2) AGENT_RUNTIME="open-code" ;;
        3) AGENT_RUNTIME="custom" ;;
    esac

    # Set default model based on runtime
    case "$AGENT_RUNTIME" in
        claude-code) AGENT_MODEL="claude-sonnet-4-6" ;;
        codex)       AGENT_MODEL="codex-5.4" ;;
        *)           AGENT_MODEL="" ;;
    esac
    AGENT_MODEL="$(ask "Model" "$AGENT_MODEL")"

    # Custom runtime: ask for invoke command
    if [ "$AGENT_RUNTIME" = "custom" ]; then
        AGENT_INVOKE_COMMAND="$(ask "Command to invoke one agent tick" "")"
    fi

    # ── Scheduler ────────────────────────────────────────────────
    if [ "$AGENT_RUNTIME" = "claude-code" ]; then
        SCHEDULER="claude-code-routines"
        info "Claude Code has built-in scheduling via /schedule create."
        info "No external scheduler needed."
    else
        printf "\n${BOLD}Scheduler${NC}\n"

        # Auto-detect platform
        DETECTED_SCHEDULER=""
        if [ "$(uname -s)" = "Darwin" ]; then
            DETECTED_SCHEDULER="launchd"
            info "Detected: macOS — recommending launchd"
        else
            DETECTED_SCHEDULER="crontab"
            info "Detected: Linux — recommending crontab"
        fi

        sched_idx="$(ask_choice "Scheduler" \
            "launchd (macOS)${DETECTED_SCHEDULER:+}" \
            "crontab" \
            "GitHub Actions cron" \
            "Custom")"
        case "$sched_idx" in
            0) SCHEDULER="launchd" ;;
            1) SCHEDULER="crontab" ;;
            2) SCHEDULER="github-actions" ;;
            3) SCHEDULER="custom" ;;
        esac
    fi

    # Cadence
    CADENCE_HOURS="$(ask "Agent tick cadence (hours)" "$CADENCE_HOURS")"
    CADENCE_SECONDS=$((CADENCE_HOURS * 3600))

    # Resolve agent commands
    resolve_agent_commands

    # ── Summary ──────────────────────────────────────────────────
    printf "\n${BOLD}Summary${NC}\n"
    printf "────────────────────────────────────────────────────────────\n"
    printf "  Repo:             %s/%s\n" "$REPO_OWNER" "$REPO_NAME"
    printf "  Branches:         %s (prod) / %s (staging)\n" "$PROD_BRANCH" "$STAGING_BRANCH"
    printf "  Backend:          %s" "$BACKEND_PLATFORM"
    [ "$BACKEND_PLATFORM" != "none" ] && printf " (%s / %s)" "$BACKEND_APP_STAGING" "$BACKEND_APP_PROD"
    printf "\n"
    printf "  Frontend:         %s" "$FRONTEND_PLATFORM"
    [ "$FRONTEND_PLATFORM" != "none" ] && printf " (%s / %s)" "$FRONTEND_PROJECT_STAGING" "$FRONTEND_PROJECT_PROD"
    printf "\n"
    printf "  Agent runtime:    %s\n" "$AGENT_RUNTIME"
    printf "  Scheduler:        %s\n" "$SCHEDULER"
    printf "  Tracks:           %s\n" "${TRACK_NAMES[*]}"
    printf "  Ad-hoc agent:     %s\n" "$ADHOC_AGENT"
    printf "────────────────────────────────────────────────────────────\n"

    if ! confirm "Proceed with installation?"; then
        warn "Installation cancelled."
        exit 0
    fi
fi

# ── Generate files ───────────────────────────────────────────────

printf "\n${BOLD}Generating files...${NC}\n\n"

# WORKFLOWS.md (copied verbatim, not a template)
info "WORKFLOWS.md"
if [ -f "$TARGET_DIR/WORKFLOWS.md" ]; then
    if confirm "  File exists: WORKFLOWS.md — overwrite?"; then
        cp "$TEMPLATES_DIR/WORKFLOWS.md" "$TARGET_DIR/WORKFLOWS.md"
        success "  Created: WORKFLOWS.md"
        GENERATED_FILES+=("$TARGET_DIR/WORKFLOWS.md")
    else
        warn "  Skipped: WORKFLOWS.md"
    fi
else
    cp "$TEMPLATES_DIR/WORKFLOWS.md" "$TARGET_DIR/WORKFLOWS.md"
    success "  Created: WORKFLOWS.md"
    GENERATED_FILES+=("$TARGET_DIR/WORKFLOWS.md")
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

# ── CI workflows ─────────────────────────────────────────────────

info ".github/workflows/"
mkdir -p "$TARGET_DIR/.github/workflows"

generate_file "$TEMPLATES_DIR/.github/workflows/tests.yml.tmpl" "$TARGET_DIR/.github/workflows/tests.yml"

# Only generate frontend tests workflow if frontend is not "none"
if [ "$FRONTEND_PLATFORM" != "none" ]; then
    generate_file "$TEMPLATES_DIR/.github/workflows/frontend-tests.yml.tmpl" "$TARGET_DIR/.github/workflows/frontend-tests.yml"
fi

# ── Platform-specific backend workflows ──────────────────────────

if [ "$BACKEND_PLATFORM" != "none" ]; then
    info "  Selecting backend workflow variants ($BACKEND_PLATFORM)..."

    # Staging migrate
    case "$BACKEND_PLATFORM" in
        heroku)        generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/heroku.yml.tmpl"        "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        fly)           generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/fly.yml.tmpl"           "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        aws-ecs)       generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/aws-ecs.yml.tmpl"       "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        gcp-cloud-run) generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/gcp-cloud-run.yml.tmpl" "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        railway)       generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/railway.yml.tmpl"       "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        render)        generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/render.yml.tmpl"        "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
        *)             generate_file "$TEMPLATES_DIR/.github/workflows/staging-migrate/custom.yml.tmpl"        "$TARGET_DIR/.github/workflows/staging-migrate.yml" ;;
    esac

    # Deploy prod backend
    case "$BACKEND_PLATFORM" in
        heroku)        generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/heroku.yml.tmpl"        "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        fly)           generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/fly.yml.tmpl"           "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        aws-ecs)       generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/aws-ecs.yml.tmpl"       "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        gcp-cloud-run) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/gcp-cloud-run.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        railway)       generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/railway.yml.tmpl"       "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        render)        generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/render.yml.tmpl"        "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
        *)             generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-backend/custom.yml.tmpl"        "$TARGET_DIR/.github/workflows/deploy-prod-backend.yml" ;;
    esac
fi

# ── Platform-specific frontend workflows ─────────────────────────

if [ "$FRONTEND_PLATFORM" != "none" ]; then
    info "  Selecting frontend workflow variants ($FRONTEND_PLATFORM)..."

    # Deploy prod frontend
    case "$FRONTEND_PLATFORM" in
        cloudflare-pages)  generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/cloudflare-pages.yml.tmpl"  "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
        vercel)            generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/vercel.yml.tmpl"            "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
        netlify)           generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/netlify.yml.tmpl"           "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
        aws-s3-cloudfront) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/aws-s3-cloudfront.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
        ftp)               generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/ftp.yml.tmpl"               "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
        *)                 generate_file "$TEMPLATES_DIR/.github/workflows/deploy-prod-frontend/custom.yml.tmpl"            "$TARGET_DIR/.github/workflows/deploy-prod-frontend.yml" ;;
    esac

    # Deploy staging frontend
    case "$FRONTEND_PLATFORM" in
        cloudflare-pages)  generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/cloudflare-pages.yml.tmpl"  "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
        vercel)            generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/vercel.yml.tmpl"            "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
        netlify)           generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/netlify.yml.tmpl"           "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
        aws-s3-cloudfront) generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/aws-s3-cloudfront.yml.tmpl" "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
        ftp)               generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/ftp.yml.tmpl"               "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
        *)                 generate_file "$TEMPLATES_DIR/.github/workflows/deploy-staging-frontend/custom.yml.tmpl"            "$TARGET_DIR/.github/workflows/deploy-staging-frontend.yml" ;;
    esac
fi

# ── Agent files ──────────────────────────────────────────────────

info ".roadmap/"
mkdir -p "$TARGET_DIR/.roadmap/agents"
mkdir -p "$TARGET_DIR/.roadmap/schedulers"
mkdir -p "$TARGET_DIR/.roadmap/logs"

# .gitignore for .roadmap/
if [ -f "$TEMPLATES_DIR/.roadmap/.gitignore" ]; then
    if [ -f "$TARGET_DIR/.roadmap/.gitignore" ]; then
        if confirm "  File exists: .roadmap/.gitignore — overwrite?"; then
            cp "$TEMPLATES_DIR/.roadmap/.gitignore" "$TARGET_DIR/.roadmap/.gitignore"
            success "  Created: .roadmap/.gitignore"
            GENERATED_FILES+=("$TARGET_DIR/.roadmap/.gitignore")
        else
            warn "  Skipped: .roadmap/.gitignore"
        fi
    else
        cp "$TEMPLATES_DIR/.roadmap/.gitignore" "$TARGET_DIR/.roadmap/.gitignore"
        success "  Created: .roadmap/.gitignore"
        GENERATED_FILES+=("$TARGET_DIR/.roadmap/.gitignore")
    fi
fi

# Tick scripts — one per track, using runtime-specific template
if [ "$AGENT_RUNTIME" != "claude-code" ]; then
    info "  Generating tick scripts for ${#TRACK_NAMES[@]} track(s)..."

    # Select the right template for the runtime
    local_tick_template=""
    case "$AGENT_RUNTIME" in
        codex)     local_tick_template="$TEMPLATES_DIR/.roadmap/agents/tick-codex.sh.tmpl" ;;
        open-code) local_tick_template="$TEMPLATES_DIR/.roadmap/agents/tick-open-code.sh.tmpl" ;;
        custom)    local_tick_template="$TEMPLATES_DIR/.roadmap/agents/tick-custom.sh.tmpl" ;;
        *)         local_tick_template="$TEMPLATES_DIR/.roadmap/agents/tick.sh.tmpl" ;;
    esac

    for i in "${!TRACK_NAMES[@]}"; do
        local_track="${TRACK_NAMES[$i]}"
        local_cron="${TRACK_CRONS[$i]}"
        generate_file_for_track \
            "$local_tick_template" \
            "$TARGET_DIR/.roadmap/agents/tick-${local_track}.sh" \
            "$local_track" \
            "$local_cron"
        chmod +x "$TARGET_DIR/.roadmap/agents/tick-${local_track}.sh"
    done
fi

# setup-agents.sh
info "  Generating setup-agents.sh..."

# Build the TRACKS_ARRAY definition for setup-agents.sh
TRACKS_ARRAY_DEF="TRACK_NAMES=("
for t in "${TRACK_NAMES[@]}"; do
    TRACKS_ARRAY_DEF+="\"$t\" "
done
TRACKS_ARRAY_DEF+=")"
TRACKS_ARRAY_DEF+=$'\n'"TRACK_CRONS=("
for c in "${TRACK_CRONS[@]}"; do
    TRACKS_ARRAY_DEF+="\"$c\" "
done
TRACKS_ARRAY_DEF+=")"

# Temporarily set __TRACKS_ARRAY for sed
SAVED_TRACKS_ARRAY="${TRACKS_ARRAY_DEF}"

if [ -f "$TEMPLATES_DIR/.roadmap/setup-agents.sh.tmpl" ]; then
    # We need a custom generate for this file because of __TRACKS_ARRAY
    outfile="$TARGET_DIR/.roadmap/setup-agents.sh"
    outdir="$(dirname "$outfile")"
    mkdir -p "$outdir"

    if [ -f "$outfile" ]; then
        if ! confirm "  File exists: $outfile — overwrite?"; then
            warn "  Skipped: $outfile"
        else
            sed \
                -e "s|\${__SCHEDULER}|${SCHEDULER}|g" \
                -e "s|\${__AGENT_RUNTIME}|${AGENT_RUNTIME}|g" \
                -e "s|\${__REPO_NAME}|${REPO_NAME}|g" \
                -e "s|\${__CADENCE_SECONDS}|${CADENCE_SECONDS}|g" \
                -e "s|\${__CADENCE_HOURS}|${CADENCE_HOURS}|g" \
                -e "s|\${__AGENT_MODEL}|${AGENT_MODEL}|g" \
                "$TEMPLATES_DIR/.roadmap/setup-agents.sh.tmpl" | \
            awk -v tracks="$SAVED_TRACKS_ARRAY" '{
                if ($0 ~ /\$\{__TRACKS_ARRAY\}/) {
                    print tracks
                } else {
                    print
                }
            }' > "$outfile"
            chmod +x "$outfile"
            success "  Created: $outfile"
            GENERATED_FILES+=("$outfile")
        fi
    else
        sed \
            -e "s|\${__SCHEDULER}|${SCHEDULER}|g" \
            -e "s|\${__AGENT_RUNTIME}|${AGENT_RUNTIME}|g" \
            -e "s|\${__REPO_NAME}|${REPO_NAME}|g" \
            -e "s|\${__CADENCE_SECONDS}|${CADENCE_SECONDS}|g" \
            -e "s|\${__CADENCE_HOURS}|${CADENCE_HOURS}|g" \
            -e "s|\${__AGENT_MODEL}|${AGENT_MODEL}|g" \
            "$TEMPLATES_DIR/.roadmap/setup-agents.sh.tmpl" | \
        awk -v tracks="$SAVED_TRACKS_ARRAY" '{
            if ($0 ~ /\$\{__TRACKS_ARRAY\}/) {
                print tracks
            } else {
                print
            }
        }' > "$outfile"
        chmod +x "$outfile"
        success "  Created: $outfile"
        GENERATED_FILES+=("$outfile")
    fi
fi

# ── Scheduler files ──────────────────────────────────────────────

case "$SCHEDULER" in
    launchd)
        info "  Generating launchd plist template..."
        # Copy the plist template so setup-agents.sh can use it at install time
        if [ -f "$TEMPLATES_DIR/.roadmap/schedulers/launchd.plist.tmpl" ]; then
            mkdir -p "$TARGET_DIR/.roadmap/schedulers"
            if [ -f "$TARGET_DIR/.roadmap/schedulers/launchd.plist.tmpl" ]; then
                if confirm "  File exists: .roadmap/schedulers/launchd.plist.tmpl — overwrite?"; then
                    cp "$TEMPLATES_DIR/.roadmap/schedulers/launchd.plist.tmpl" "$TARGET_DIR/.roadmap/schedulers/launchd.plist.tmpl"
                    success "  Created: .roadmap/schedulers/launchd.plist.tmpl"
                    GENERATED_FILES+=("$TARGET_DIR/.roadmap/schedulers/launchd.plist.tmpl")
                else
                    warn "  Skipped: .roadmap/schedulers/launchd.plist.tmpl"
                fi
            else
                cp "$TEMPLATES_DIR/.roadmap/schedulers/launchd.plist.tmpl" "$TARGET_DIR/.roadmap/schedulers/launchd.plist.tmpl"
                success "  Created: .roadmap/schedulers/launchd.plist.tmpl"
                GENERATED_FILES+=("$TARGET_DIR/.roadmap/schedulers/launchd.plist.tmpl")
            fi
        fi
        ;;
    github-actions)
        info "  Generating GitHub Actions agent workflows..."
        for i in "${!TRACK_NAMES[@]}"; do
            local_track="${TRACK_NAMES[$i]}"
            local_cron="${TRACK_CRONS[$i]}"
            generate_file_for_track \
                "$TEMPLATES_DIR/.github/workflows/agent-tick.yml.tmpl" \
                "$TARGET_DIR/.github/workflows/agent-${local_track}.yml" \
                "$local_track" \
                "$local_cron"
        done
        ;;
    crontab)
        info "  Crontab entries will be installed by .roadmap/setup-agents.sh install"
        ;;
    claude-code-routines)
        info "  Claude Code routines: use /schedule create in a Claude Code session"
        ;;
    custom)
        info "  Custom scheduler: run tick scripts manually or with your own mechanism"
        ;;
esac

# ── Save resolved config ────────────────────────────────────────

info "Saving resolved config..."
CONFIG_OUT="$TARGET_DIR/.roadmap/config.yml"
mkdir -p "$(dirname "$CONFIG_OUT")"

{
    echo "# roadmap-agent-toolkit resolved config"
    echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "repository:"
    echo "  owner: \"$REPO_OWNER\""
    echo "  name: \"$REPO_NAME\""
    echo "  production_branch: \"$PROD_BRANCH\""
    echo "  staging_branch: \"$STAGING_BRANCH\""
    echo ""
    echo "backend:"
    echo "  platform: \"$BACKEND_PLATFORM\""
    [ "$BACKEND_PLATFORM" != "none" ] && echo "  app_name_staging: \"$BACKEND_APP_STAGING\""
    [ "$BACKEND_PLATFORM" != "none" ] && echo "  app_name_prod: \"$BACKEND_APP_PROD\""
    echo "  test_command: \"$BACKEND_TEST_CMD\""
    echo "  migration_command: \"$MIGRATION_CMD\""
    # Platform-specific backend values
    case "$BACKEND_PLATFORM" in
        aws-ecs)
            echo "  aws_region: \"$AWS_REGION\""
            echo "  ecr_repo: \"$ECR_REPO\""
            echo "  ecs_cluster_staging: \"$ECS_CLUSTER_STAGING\""
            echo "  ecs_cluster_prod: \"$ECS_CLUSTER_PROD\""
            [ -n "$ECS_SUBNET" ] && echo "  ecs_subnet: \"$ECS_SUBNET\""
            [ -n "$ECS_SG" ] && echo "  ecs_sg: \"$ECS_SG\""
            ;;
        gcp-cloud-run)
            echo "  gcp_project_id: \"$GCP_PROJECT_ID\""
            echo "  gcp_region: \"$GCP_REGION\""
            echo "  artifact_registry_repo: \"$ARTIFACT_REGISTRY_REPO\""
            ;;
        render)
            echo "  render_service_id_staging: \"$RENDER_SERVICE_ID_STAGING\""
            echo "  render_service_id_prod: \"$RENDER_SERVICE_ID_PROD\""
            ;;
    esac
    echo ""
    echo "frontend:"
    echo "  platform: \"$FRONTEND_PLATFORM\""
    if [ "$FRONTEND_PLATFORM" != "none" ]; then
        echo "  directory: \"$FRONTEND_DIR\""
        echo "  project_name_staging: \"$FRONTEND_PROJECT_STAGING\""
        echo "  project_name_prod: \"$FRONTEND_PROJECT_PROD\""
        echo "  test_command: \"$FRONTEND_TEST_CMD\""
        echo "  build_command: \"$FRONTEND_BUILD_CMD\""
        echo "  node_version_file: \"$NODE_VERSION_FILE\""
        # Platform-specific frontend values
        case "$FRONTEND_PLATFORM" in
            netlify)
                echo "  netlify_site_id_staging: \"$NETLIFY_SITE_ID_STAGING\""
                echo "  netlify_site_id_prod: \"$NETLIFY_SITE_ID_PROD\""
                ;;
            aws-s3-cloudfront)
                echo "  s3_bucket_staging: \"$S3_BUCKET_STAGING\""
                echo "  s3_bucket_prod: \"$S3_BUCKET_PROD\""
                echo "  cloudfront_dist_staging: \"$CLOUDFRONT_DIST_STAGING\""
                echo "  cloudfront_dist_prod: \"$CLOUDFRONT_DIST_PROD\""
                ;;
            ftp)
                echo "  ftp_protocol: \"$FTP_PROTOCOL\""
                echo "  ftp_host_staging: \"$FTP_HOST_STAGING\""
                echo "  ftp_host_prod: \"$FTP_HOST_PROD\""
                echo "  ftp_remote_path_staging: \"$FTP_REMOTE_PATH_STAGING\""
                echo "  ftp_remote_path_prod: \"$FTP_REMOTE_PATH_PROD\""
                ;;
        esac
    fi
    echo ""
    echo "ci:"
    echo "  database_service: \"$DB_SERVICE\""
    echo "  python_version: \"$PYTHON_VERSION\""
    echo ""
    echo "agents:"
    echo "  runtime: \"$AGENT_RUNTIME\""
    echo "  scheduler: \"$SCHEDULER\""
    echo "  model: \"$AGENT_MODEL\""
    echo "  cadence_hours: $CADENCE_HOURS"
    echo ""
    echo "adhoc:"
    echo "  enabled: $ADHOC_AGENT"
    [ "$ADHOC_AGENT" = "true" ] && echo "  cron: \"$ADHOC_CRON\""
    echo ""
    echo "tracks:"
    for i in "${!TRACK_NAMES[@]}"; do
        echo "  $i:"
        echo "    name: \"${TRACK_NAMES[$i]}\""
        echo "    id_prefix: \"${TRACK_ID_PREFIXES[$i]}\""
        echo "    branch_prefix: \"${TRACK_BRANCH_PREFIXES[$i]}\""
        echo "    issue_label: \"${TRACK_ISSUE_LABELS[$i]}\""
        echo "    commit_prefix: \"${TRACK_COMMIT_PREFIXES[$i]}\""
        echo "    north_star: \"${TRACK_NORTH_STARS[$i]}\""
        echo "    cron: \"${TRACK_CRONS[$i]}\""
    done
} > "$CONFIG_OUT"
success "  Created: $CONFIG_OUT"
GENERATED_FILES+=("$CONFIG_OUT")

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

    if confirm "Enable auto-delete branches on PR merge?"; then
        if gh api "repos/$REPO_OWNER/$REPO_NAME" --method PATCH \
            -f delete_branch_on_merge=true --silent 2>/dev/null; then
            success "  Auto-delete head branches: enabled"
        else
            warn "  Could not update repo setting (may need admin access)"
        fi
    fi
else
    warn "gh CLI not found — skipping label + branch creation."
    info "Install: https://cli.github.com"
fi

# ── Final summary ───────────────────────────────────────────────

printf "\n"
printf "${GREEN}${BOLD}Installation complete!${NC}\n"
printf "────────────────────────────────────────────────────────────\n"
printf "\n"

# Generated files list
printf "${BOLD}Generated files:${NC}\n"
for f in "${GENERATED_FILES[@]}"; do
    local_rel="${f#$TARGET_DIR/}"
    printf "  ${GREEN}%s${NC}\n" "$local_rel"
done
if [ "${#SKIPPED_FILES[@]}" -gt 0 ]; then
    printf "\n${BOLD}Skipped (existing, unchanged):${NC}\n"
    for f in "${SKIPPED_FILES[@]}"; do
        printf "  ${YELLOW}%s${NC}\n" "$f"
    done
fi
printf "\n"

# Required secrets per platform
printf "${BOLD}Required GitHub repo secrets:${NC}\n"
case "$BACKEND_PLATFORM" in
    heroku)        printf "  HEROKU_API_KEY           — Heroku account API key\n" ;;
    fly)           printf "  FLY_API_TOKEN            — Fly.io API token\n" ;;
    aws-ecs)
        printf "  AWS_ACCESS_KEY_ID        — IAM key (ECR push + ECS deploy)\n"
        printf "  AWS_SECRET_ACCESS_KEY    — IAM secret key\n"
        ;;
    gcp-cloud-run) printf "  GCP_SA_KEY               — Service account key JSON\n" ;;
    railway)       printf "  RAILWAY_TOKEN            — Railway project token\n" ;;
    render)        printf "  RENDER_API_KEY           — Render API key\n" ;;
esac
case "$FRONTEND_PLATFORM" in
    cloudflare-pages)
        printf "  CLOUDFLARE_API_TOKEN     — Pages Edit permission\n"
        printf "  CLOUDFLARE_ACCOUNT_ID    — Cloudflare account ID\n"
        ;;
    vercel)
        printf "  VERCEL_TOKEN             — Vercel access token\n"
        printf "  VERCEL_ORG_ID            — Vercel org/team ID\n"
        printf "  VERCEL_PROJECT_ID        — Vercel project ID\n"
        ;;
    netlify)       printf "  NETLIFY_AUTH_TOKEN       — Netlify access token\n" ;;
    aws-s3-cloudfront)
        printf "  AWS_ACCESS_KEY_ID        — IAM key (S3 write + CloudFront)\n"
        printf "  AWS_SECRET_ACCESS_KEY    — IAM secret key\n"
        ;;
    ftp)
        printf "  FTP_USERNAME             — FTP/SFTP username\n"
        printf "  FTP_PASSWORD             — FTP/SFTP password\n"
        ;;
esac
if [ "$SCHEDULER" = "github-actions" ]; then
    printf "  AGENT_PAT                — GitHub PAT (repo write access)\n"
fi
if [ "$BACKEND_PLATFORM" = "none" ] && [ "$FRONTEND_PLATFORM" = "none" ] && [ "$SCHEDULER" != "github-actions" ]; then
    printf "  (none)\n"
fi
printf "\n"

# Agent scheduling instructions
printf "${BOLD}Agent scheduling:${NC}\n"
case "$SCHEDULER" in
    claude-code-routines)
        printf "  Runtime: Claude Code (built-in scheduler)\n"
        printf "  For each track, run in a Claude Code session:\n"
        printf "    /schedule create\n"
        printf "  Set the cron, model (%s), and prompt from\n" "$AGENT_MODEL"
        printf "  docs/roadmap/AGENT_PROMPT.md (BEGIN PROMPT to END PROMPT).\n"
        printf "  Record the routine ID in BACKLOG.yml.\n"
        printf "  Manage at: https://claude.ai/code/routines\n"
        ;;
    launchd)
        printf "  Runtime: %s | Scheduler: launchd (macOS)\n" "$AGENT_RUNTIME"
        printf "  Install:    .roadmap/setup-agents.sh install\n"
        printf "  Uninstall:  .roadmap/setup-agents.sh uninstall\n"
        printf "  Status:     .roadmap/setup-agents.sh status\n"
        ;;
    crontab)
        printf "  Runtime: %s | Scheduler: crontab\n" "$AGENT_RUNTIME"
        printf "  Install:    .roadmap/setup-agents.sh install\n"
        printf "  Uninstall:  .roadmap/setup-agents.sh uninstall\n"
        printf "  Status:     crontab -l | grep roadmap-agent\n"
        ;;
    github-actions)
        printf "  Runtime: %s | Scheduler: GitHub Actions cron\n" "$AGENT_RUNTIME"
        printf "  Agent workflows generated as .github/workflows/agent-<track>.yml\n"
        printf "  Push to enable. Set AGENT_PAT secret for repo write access.\n"
        ;;
    custom)
        printf "  Runtime: %s | Scheduler: custom\n" "$AGENT_RUNTIME"
        printf "  Tick scripts at .roadmap/agents/tick-<track>.sh\n"
        printf "  Schedule them with your preferred mechanism.\n"
        ;;
esac
printf "\n"

# Cron expressions for each track
printf "${BOLD}Track schedules:${NC}\n"
for i in "${!TRACK_NAMES[@]}"; do
    printf "  %-20s %s\n" "${TRACK_NAMES[$i]}" "${TRACK_CRONS[$i]}"
done
if [ "$ADHOC_AGENT" = "true" ]; then
    printf "  %-20s %s\n" "adhoc" "$ADHOC_CRON"
fi
printf "\n"

printf "${BOLD}Next steps:${NC}\n"
printf "  1. Review the generated files, especially:\n"
printf "     - docs/roadmap/BACKLOG.yml — add your first items\n"
printf "     - docs/roadmap/AGENT_PROMPT.md — customize env details\n"
if [ "$BACKEND_PLATFORM" != "none" ] || [ "$FRONTEND_PLATFORM" != "none" ]; then
    printf "     - .github/workflows/*.yml — verify CI + deploy config\n"
fi
printf "  2. Create item spec files under docs/roadmap/items/\n"
printf "  3. Set up required GitHub repo secrets (listed above)\n"
printf "  4. Schedule agents using the instructions above\n"
printf "  5. Run one tick manually to verify end-to-end\n"
printf "\n"
printf "  Saved config: .roadmap/config.yml (use with --config for re-runs)\n"
printf "  Full documentation: https://github.com/yevgetman/roadmap-agent-toolkit\n"
printf "\n"
