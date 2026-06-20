#!/bin/bash
set -euo pipefail
# ==============================================================================
# 02a - Upload SSH Key to Spark 01
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_02_upload_key.sh"
