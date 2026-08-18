#!/bin/bash
set -euo pipefail
# ==============================================================================
# 10b - Sync maintenance/ folder to Spark 02 (upload only)
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_10_sync_maintenance.sh"
