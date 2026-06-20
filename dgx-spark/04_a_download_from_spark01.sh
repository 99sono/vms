#!/bin/bash
set -euo pipefail
# ==============================================================================
# 04a - Download from Spark 01 to Local Downloads
# ==============================================================================
# Usage: ./04_a_download_from_spark01.sh <remote_path>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_04_download.sh" "$@"
