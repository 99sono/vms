#!/bin/bash
# ==============================================================================
# Shared system-update logic — sourced by 09_a_* and 09_b_*.
# Uploads the remote update script to the Spark, then runs it interactively.
# ==============================================================================
REMOTE_DIR="~/scripts/maintenance"
REMOTE_SCRIPT="01_update_spark.sh"
LOCAL_SCRIPT_PATH="$SCRIPT_DIR/maintenance/$REMOTE_SCRIPT"

if [ ! -f "$LOCAL_SCRIPT_PATH" ]; then
    echo "Error: Remote update script not found at $LOCAL_SCRIPT_PATH" >&2
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
echo "    1. Upload $REMOTE_SCRIPT to $REMOTE_DIR/"
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

# --- Upload the remote script ---
echo "  Uploading $REMOTE_SCRIPT to $SPARK_HOST..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "mkdir -p $REMOTE_DIR"
scp -i "$EXPANDED_KEY_PATH" "$LOCAL_SCRIPT_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_DIR/$REMOTE_SCRIPT"
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod +x $REMOTE_DIR/$REMOTE_SCRIPT"
echo "  Upload complete."
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
