#!/bin/bash
# ==============================================================================
# Shared helpers for DGX Spark scripts (must be sourced, not executed directly).
# Determines the target Spark node from the calling script's filename.
# ==============================================================================

load_env_and_resolve_host() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

    if [ ! -f "$PRIVATE_ENV_FILE" ]; then
        echo "Error: Private environment file not found at $PRIVATE_ENV_FILE" >&2
        echo "Please copy 00_env_setup_template.sh to 00_env_setup_private.sh and update the values." >&2
        exit 1
    fi

    source "$PRIVATE_ENV_FILE"

    # Determine target from the calling script's filename
    local script_name
    script_name="$(basename "${BASH_SOURCE[1]}")"

    case "$script_name" in
        *spark01*|*_a_*)
            SPARK_HOST="$SPARK01_HOST"
            ;;
        *spark02*|*_b_*)
            SPARK_HOST="$SPARK02_HOST"
            ;;
        *)
            echo "Error: Cannot determine target from script name '$script_name'." >&2
            echo "       Filename must contain 'spark01'/'_a_' or 'spark02'/'_b_'." >&2
            exit 1
            ;;
    esac

    EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
}
