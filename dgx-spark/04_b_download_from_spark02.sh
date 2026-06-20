#!/bin/bash
set -euo pipefail
# ==============================================================================
# 04b - Download from Spark 02 to Local Downloads
# ==============================================================================
# Usage: ./04_b_download_from_spark02.sh <remote_path>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_04_download.sh" "$@"
