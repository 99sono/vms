#!/bin/bash
set -euo pipefail
# ==============================================================================
# 09b - Update DGX Spark 02 (OS + firmware)
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_09_update_spark.sh"
