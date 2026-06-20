#!/bin/bash
# ==============================================================================
# Shared gitconfig upload — sourced by 06_a_* and 06_b_*.
# ==============================================================================
LOCAL_PATH="$HOME/.gitconfig"
REMOTE_DEST="/home/$SPARK_USER/.gitconfig"

echo "Uploading $LOCAL_PATH to $SPARK_USER@$SPARK_HOST:$REMOTE_DEST..."
scp -i "$EXPANDED_KEY_PATH" "$LOCAL_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_DEST"

echo "Upload complete."
