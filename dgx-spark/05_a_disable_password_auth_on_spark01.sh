#!/bin/bash
set -euo pipefail
# ==============================================================================
# 05a - Disable Password Auth on Spark 01
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_05_disable_password.sh"
