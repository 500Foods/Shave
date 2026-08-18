#!/bin/bash
# Compatibility wrapper. The product CLI is shave/shave.
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - Align wrapper version with product CLI
# 1.2.0 - 2026-08-18 - Exec the shave/shave product CLI
# 1.1.0 - 2026-08-18 - Write .c next to the binary, -c, SHAVE_* overrides, skip unchanged builds
# 1.0.0 - 2025-07-06 - First stable release with core functionality

SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/shave" "$@"
