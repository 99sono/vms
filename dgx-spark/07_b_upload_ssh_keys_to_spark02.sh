#!/bin/bash
set -euo pipefail
# ==============================================================================
# 07b - Upload SSH Keys to Spark 02
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_07_upload_keys.sh"
