#!/bin/bash
set -euo pipefail
# ==============================================================================
# 06 - Upload .gitconfig to Spark
# ==============================================================================
# Purpose: Uploads your local ~/.gitconfig file to the VM's home directory.

# 1. Locate and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    echo "Please copy 00_env_setup_template.sh to 00_env_setup_private.sh and fill it out."
    exit 1
fi
source "$PRIVATE_ENV_FILE"

# 2. Prepare paths
# The path to .gitconfig is standard, so we use it directly.
LOCAL_PATH="$HOME/.gitconfig"
REMOTE_DEST="/home/$SPARK_USER/.gitconfig"
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 3. Execute the upload using scp
echo "Uploading $LOCAL_PATH to $SPARK_USER@$SPARK_HOST:$REMOTE_DEST..."
scp -i "$EXPANDED_KEY_PATH" "$LOCAL_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_DEST"

echo "Upload complete."
