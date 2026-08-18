#!/bin/bash
# ==============================================================================
# Shared maintenance-sync logic — sourced by 10_a_* and 10_b_*.
# Uploads the ENTIRE local maintenance/ folder to the Spark (no execution).
# ==============================================================================
if [ ! -f "$EXPANDED_KEY_PATH" ]; then
    echo "Error: SSH private key not found at $EXPANDED_KEY_PATH" >&2
    exit 1
fi

echo ""
echo "============================================================"
echo "  Sync maintenance/ to Spark"
echo "============================================================"
echo ""
echo "  Target:   $SPARK_USER@$SPARK_HOST"
echo "  From:     $SCRIPT_DIR/maintenance/"
echo "  To:       ~/scripts/maintenance/"
echo ""
echo "  Files to be synced:"
( cd "$SCRIPT_DIR/maintenance" 2>/dev/null && find . -type f | sed 's|^\./|    - |' )
echo ""
echo "  This only UPLOADS — it does NOT run anything on the Spark."
echo "  After syncing, run what you need on the Spark, e.g.:"
echo "      ssh $SPARK_USER@$SPARK_HOST 'bash ~/scripts/maintenance/04_audit_gpu_clock_cap.sh'"
echo ""

read -rp "  Proceed? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS]) echo "" ;;
    *)
        echo "  Aborted by user."
        exit 0
        ;;
esac

upload_maintenance_dir

echo ""
echo "  Remote contents of ~/scripts/maintenance/:"
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" \
    "ls -1 ~/scripts/maintenance/" 2>/dev/null | sed 's/^/    /' \
    || echo "    (could not list remote directory)"
echo ""
echo "  Done."
