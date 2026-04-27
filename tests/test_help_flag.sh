#!/usr/bin/env bash
# Test: install.sh --help exits 0 and shows usage
TOOLKIT_DIR="${1:-.}"

OUTPUT=$("$TOOLKIT_DIR/install.sh" --help 2>&1)
EXIT_CODE=$?

[ "$EXIT_CODE" -eq 0 ] || { echo "Expected exit 0, got $EXIT_CODE"; exit 1; }
echo "$OUTPUT" | grep -q "target" || { echo "Missing --target in help output"; exit 1; }
echo "$OUTPUT" | grep -q "config" || { echo "Missing --config in help output"; exit 1; }
echo "$OUTPUT" | grep -q "force" || { echo "Missing --force in help output"; exit 1; }
