#!/usr/bin/env bash
# Test: no template files have broken/partial ${__ patterns
# (all placeholders should be well-formed ${__VARIABLE_NAME})
TOOLKIT_DIR="${1:-.}"

ERRORS=0

for tmpl in $(find "$TOOLKIT_DIR/templates" -name "*.tmpl" -type f); do
    # Check for malformed patterns: ${ without __ or unclosed
    if grep -Pn '\$\{(?!__[A-Z_]+\}|\{ )' "$tmpl" 2>/dev/null | grep -v '\${{' | grep -q .; then
        echo "Possible malformed template var in: $tmpl"
        grep -Pn '\$\{(?!__[A-Z_]+\}|\{ )' "$tmpl" | grep -v '\${{' | head -3
        ERRORS=$((ERRORS + 1))
    fi
done

[ "$ERRORS" -eq 0 ]
