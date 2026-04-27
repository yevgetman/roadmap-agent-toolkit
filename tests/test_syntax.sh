#!/usr/bin/env bash
# Test: install.sh has valid bash syntax
TOOLKIT_DIR="${1:-.}"
bash -n "$TOOLKIT_DIR/install.sh"
