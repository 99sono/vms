#!/bin/bash
# ==============================================================================
# Shared upload implementation — sourced by 03_a_* and 03_b_*.
# ==============================================================================
if [ -z "${1:-}" ]; then
    echo "Usage: $(basename "$0") <local_file_or_directory>"
    exit 1
fi

LOCAL_PATH="$1"
REMOTE_DEST="/home/$SPARK_USER/Downloads/"

echo "Uploading $LOCAL_PATH to $SPARK_USER@$SPARK_HOST:$REMOTE_DEST..."
scp -i "$EXPANDED_KEY_PATH" -r "$LOCAL_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_DEST"

echo "Upload complete."
