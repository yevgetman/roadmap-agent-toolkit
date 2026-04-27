#!/usr/bin/env bash
# Test: all workflow templates are structurally sound GH Actions files.
# Full YAML validation is impractical because GH Actions ${{ }}
# expressions confuse parsers after sed substitution. Instead we
# check structural requirements: name, on, jobs sections present.
TOOLKIT_DIR="${1:-.}"

ERRORS=0

for tmpl in $(find "$TOOLKIT_DIR/templates/.github/workflows" -name "*.yml.tmpl" -type f); do
    name="$(basename "$tmpl")"

    # Check: file has 'name:' line
    if ! grep -q '^name:' "$tmpl"; then
        echo "Missing 'name:' in: $name"
        ERRORS=$((ERRORS + 1))
    fi

    # Check: file has 'on:' trigger
    if ! grep -q '^on:' "$tmpl"; then
        echo "Missing 'on:' in: $name"
        ERRORS=$((ERRORS + 1))
    fi

    # Check: file has 'jobs:' section
    if ! grep -q '^jobs:' "$tmpl"; then
        echo "Missing 'jobs:' in: $name"
        ERRORS=$((ERRORS + 1))
    fi
done

[ "$ERRORS" -eq 0 ]
