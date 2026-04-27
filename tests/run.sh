#!/usr/bin/env bash
# Test runner for roadmap-agent-toolkit
#
# Usage: ./tests/run.sh
#
# Runs all test_*.sh scripts in this directory. Each test script
# should exit 0 on success, non-zero on failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
ERRORS=()

printf "${BOLD}roadmap-agent-toolkit test suite${NC}\n"
printf "────────────────────────────────────────────\n\n"

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [ -f "$test_file" ] || continue
    test_name="$(basename "$test_file" .sh)"

    printf "  %-45s " "$test_name"
    if bash "$test_file" "$TOOLKIT_DIR" > /tmp/rat-test-output-$$ 2>&1; then
        printf "${GREEN}PASS${NC}\n"
        PASSED=$((PASSED + 1))
    else
        printf "${RED}FAIL${NC}\n"
        FAILED=$((FAILED + 1))
        ERRORS+=("$test_name")
        # Show failure output indented
        sed 's/^/    /' /tmp/rat-test-output-$$ | tail -20
    fi
    rm -f /tmp/rat-test-output-$$
done

printf "\n────────────────────────────────────────────\n"
printf "${GREEN}Passed: $PASSED${NC}  "
printf "${RED}Failed: $FAILED${NC}\n"

if [ "$FAILED" -gt 0 ]; then
    printf "\n${RED}Failing tests:${NC}\n"
    for e in "${ERRORS[@]}"; do
        printf "  - %s\n" "$e"
    done
    exit 1
fi

exit 0
