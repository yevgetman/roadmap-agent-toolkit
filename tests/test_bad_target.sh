#!/usr/bin/env bash
# Test: install.sh fails gracefully on non-existent target
TOOLKIT_DIR="${1:-.}"

OUTPUT=$("$TOOLKIT_DIR/install.sh" --target /tmp/nonexistent-rat-test-dir-$$ 2>&1) && {
    echo "Expected non-zero exit for bad target"
    exit 1
}

echo "$OUTPUT" | grep -qi "does not exist\|not.*directory\|not.*git" || {
    echo "Expected error message about missing directory"
    exit 1
}
