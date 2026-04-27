#!/usr/bin/env bash
# Test: every backend/frontend profile has a matching workflow template
TOOLKIT_DIR="${1:-.}"

ERRORS=0

# Backend profiles → deploy-prod-backend workflows
for profile in "$TOOLKIT_DIR"/profiles/backend/*.yml; do
    [ -f "$profile" ] || continue
    slug="$(basename "$profile" .yml)"
    [ "$slug" = "custom" ] && continue  # custom uses custom.yml.tmpl
    [ "$slug" = "render" ] && continue  # render uses custom-like API calls

    workflow="$TOOLKIT_DIR/templates/.github/workflows/deploy-prod-backend/$slug.yml.tmpl"
    if [ ! -f "$workflow" ]; then
        echo "Missing workflow for backend profile: $slug"
        echo "  Expected: $workflow"
        ERRORS=$((ERRORS + 1))
    fi
done

# Frontend profiles → deploy-prod-frontend workflows
for profile in "$TOOLKIT_DIR"/profiles/frontend/*.yml; do
    [ -f "$profile" ] || continue
    slug="$(basename "$profile" .yml)"
    [ "$slug" = "custom" ] && continue

    workflow="$TOOLKIT_DIR/templates/.github/workflows/deploy-prod-frontend/$slug.yml.tmpl"
    if [ ! -f "$workflow" ]; then
        echo "Missing workflow for frontend profile: $slug"
        echo "  Expected: $workflow"
        ERRORS=$((ERRORS + 1))
    fi
done

[ "$ERRORS" -eq 0 ]
