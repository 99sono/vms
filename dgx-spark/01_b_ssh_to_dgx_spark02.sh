#!/bin/bash
set -euo pipefail
# ==============================================================================
# 01b - SSH to DGX Spark 02
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
load_env_and_resolve_host
source "$SCRIPT_DIR/_01_ssh.sh"
