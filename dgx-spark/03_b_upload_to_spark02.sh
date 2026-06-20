#!/bin/bash
set -euo pipefail
# ==============================================================================
# 03b - Upload to Spark 02 Downloads
# ==============================================================================
# Usage: ./03_b_upload_to_spark02.sh <local_file_or_directory>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_03_upload.sh" "$@"
