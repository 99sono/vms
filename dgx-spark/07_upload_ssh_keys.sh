#!/bin/bash
set -euo pipefail
# ==============================================================================
# 07 - Upload SSH Keys (Private & Public) to Spark
# ==============================================================================
# Purpose: Uploads local private and public SSH keys to the VM's .ssh directory and sets permissions.

# 1. Locate and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    echo "Please copy 00_env_setup_template.sh to 00_env_setup_private.sh and fill it out."
    exit 1
fi
source "$PRIVATE_ENV_FILE"

# 2. Validate environment variable
if [ -z "${UPLOAD_PRIVATE_KEY_PATH:-}" ]; then
    echo "Error: UPLOAD_PRIVATE_KEY_PATH is not set in $PRIVATE_ENV_FILE"
    exit 1
fi

# 3. Prepare paths
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

EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 4. Execute the upload using scp
echo "Uploading keys to $SPARK_USER@$SPARK_HOST:/home/$SPARK_USER/.ssh/ ..."
scp -i "$EXPANDED_KEY_PATH" "$LOCAL_PRIVATE_PATH" "$LOCAL_PUBLIC_PATH" "$SPARK_USER@$SPARK_HOST:/home/$SPARK_USER/.ssh/"

# 5. Set permissions on the remote keys
echo "Setting permissions (600 for private, 644 for public)..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod 600 $REMOTE_PRIVATE_DEST && chmod 644 $REMOTE_PUBLIC_DEST"

echo "Upload and permission setup complete."
