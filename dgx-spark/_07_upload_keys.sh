#!/bin/bash
# ==============================================================================
# Shared SSH keys upload — sourced by 07_a_* and 07_b_*.
# ==============================================================================
if [ -z "${UPLOAD_PRIVATE_KEY_PATH:-}" ]; then
    echo "Error: UPLOAD_PRIVATE_KEY_PATH is not set in $PRIVATE_ENV_FILE"
    exit 1
fi

LOCAL_PRIVATE_PATH="${UPLOAD_PRIVATE_KEY_PATH/#\~/$HOME}"
LOCAL_PUBLIC_PATH="${LOCAL_PRIVATE_PATH}.pub"

if [ ! -f "$LOCAL_PRIVATE_PATH" ]; then
    echo "Error: Private key not found at $LOCAL_PRIVATE_PATH"
    exit 1
fi

if [ ! -f "$LOCAL_PUBLIC_PATH" ]; then
    echo "Error: Public key not found at $LOCAL_PUBLIC_PATH"
    exit 1
fi

PRIVATE_FILENAME=$(basename "$LOCAL_PRIVATE_PATH")
PUBLIC_FILENAME=$(basename "$LOCAL_PUBLIC_PATH")

REMOTE_PRIVATE_DEST="/home/$SPARK_USER/.ssh/$PRIVATE_FILENAME"
REMOTE_PUBLIC_DEST="/home/$SPARK_USER/.ssh/$PUBLIC_FILENAME"

echo "Uploading keys to $SPARK_USER@$SPARK_HOST:/home/$SPARK_USER/.ssh/ ..."
scp -i "$EXPANDED_KEY_PATH" "$LOCAL_PRIVATE_PATH" "$LOCAL_PUBLIC_PATH" "$SPARK_USER@$SPARK_HOST:/home/$SPARK_USER/.ssh/"

echo "Setting permissions (600 for private, 644 for public)..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod 600 $REMOTE_PRIVATE_DEST && chmod 644 $REMOTE_PUBLIC_DEST"

echo "Upload and permission setup complete."
