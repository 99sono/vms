#!/bin/bash
# ==============================================================================
# Shared download implementation — sourced by 04_a_* and 04_b_*.
# ==============================================================================
if [ -z "${1:-}" ]; then
    echo "Usage: $(basename "$0") <remote_file_or_directory_path>"
    echo "Example: $(basename "$0") /home/$SPARK_USER/Downloads/some_file.zip"
    exit 1
fi

REMOTE_SRC="$1"
LOCAL_DEST="$HOME/Downloads/"

echo "Downloading from $SPARK_USER@$SPARK_HOST:$REMOTE_SRC to $LOCAL_DEST..."
scp -i "$EXPANDED_KEY_PATH" -r "$SPARK_USER@$SPARK_HOST:$REMOTE_SRC" "$LOCAL_DEST"

echo "Download complete."
