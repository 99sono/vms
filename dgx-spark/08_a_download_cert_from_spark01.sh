#!/bin/bash
set -euo pipefail
# ==============================================================================
# 08a - Download nginx-selfsigned.crt from Spark 01
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_08_download_cert.sh"
