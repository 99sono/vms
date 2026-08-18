#!/bin/bash
# ==============================================================================
# Shared system-update logic — sourced by 09_a_* and 09_b_*.
# Syncs the whole maintenance/ folder to the Spark, then runs the update script.
# ==============================================================================
REMOTE_DIR="~/scripts/maintenance"
REMOTE_SCRIPT="01_update_spark.sh"

# The update script must exist locally (it is what we will execute).
if [ ! -f "$SCRIPT_DIR/maintenance/$REMOTE_SCRIPT" ]; then
    echo "Error: Remote update script not found at $SCRIPT_DIR/maintenance/$REMOTE_SCRIPT" >&2
    exit 1
fi

if [ ! -f "$EXPANDED_KEY_PATH" ]; then
    echo "Error: SSH private key not found at $EXPANDED_KEY_PATH" >&2
    exit 1
fi

echo ""
echo "============================================================"
echo "  DGX Spark System Update"
echo "============================================================"
echo ""
echo "  Target:    $SPARK_USER@$SPARK_HOST"
echo "  Script:    maintenance/$REMOTE_SCRIPT"
echo "  SSH key:   $EXPANDED_KEY_PATH"
echo ""
echo "  Actions:"
echo "    1. Sync the whole maintenance/ folder to $REMOTE_DIR/"
echo "    2. Run: apt update → dist-upgrade → fwupdmgr → reboot"
echo ""
echo "  NOTE: Your SSH session will drop when the system reboots."
echo ""

read -rp "  Proceed? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS]) echo "" ;;
    *)
        echo "  Aborted by user."
        exit 0
        ;;
esac

# --- Sync the maintenance folder (single source of truth) ---
upload_maintenance_dir
echo ""

# --- Execute remotely (with TTY for interactive prompts) ---
echo "  Starting update on $SPARK_HOST — keep this terminal open..."
echo "------------------------------------------------------------"
ssh -t -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" \
    "sudo bash $REMOTE_DIR/$REMOTE_SCRIPT"
REMOTE_EXIT=$?
echo "------------------------------------------------------------"
echo ""

# --- Interpret exit code ---
# SSH returns 255 when the connection is lost (e.g. system rebooted mid-session).
# Any other non-zero code is a real failure.
if [ $REMOTE_EXIT -eq 0 ]; then
    echo "  Update completed successfully."
elif [ $REMOTE_EXIT -eq 255 ]; then
    echo "  SSH connection dropped (exit 255)."
    echo "  This is expected if the system rebooted."
    echo "  Reconnect in ~2-5 minutes to verify the system is healthy."
else
    echo "  WARNING: Remote command exited with code $REMOTE_EXIT."
    echo "  The update may have failed. Check the Spark manually."
    exit $REMOTE_EXIT
fi
