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

# ------------------------------------------------------------------------------
# upload_maintenance_dir
#   Uploads the ENTIRE local dgx-spark/maintenance/ folder to
#   ~/scripts/maintenance/ on the target Spark (mkdir -> scp -r -> chmod +x).
#   Must be called AFTER load_env_and_resolve_host so that SPARK_HOST,
#   SPARK_USER, EXPANDED_KEY_PATH and SCRIPT_DIR are set.
#   This is the single source of truth for syncing maintenance scripts.
# ------------------------------------------------------------------------------
upload_maintenance_dir() {
    local src_dir="$SCRIPT_DIR/maintenance"
    local dest_dir="~/scripts/maintenance"

    if [ ! -d "$src_dir" ]; then
        echo "Error: Local maintenance directory not found at $src_dir" >&2
        return 1
    fi

    if [ ! -f "$EXPANDED_KEY_PATH" ]; then
        echo "Error: SSH private key not found at $EXPANDED_KEY_PATH" >&2
        return 1
    fi

    echo "  Syncing maintenance/ -> $SPARK_USER@$SPARK_HOST:$dest_dir"
    ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "mkdir -p $dest_dir"
    # 'src_dir/.' uploads the *contents* of the folder (no nested maintenance/).
    scp -i "$EXPANDED_KEY_PATH" -r "$src_dir/." "$SPARK_USER@$SPARK_HOST:$dest_dir/"
    ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod +x $dest_dir/*.sh"
    echo "  Sync complete."
}

