#!/bin/bash
set -euo pipefail
# ==============================================================================
# 03 - Upload to Spark Downloads
# ==============================================================================
# Purpose: Uploads a local file or directory to the VM's Downloads folder.
# Usage: ./03_upload_to_spark.sh <local_path>

# 1. Locate and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    exit 1
fi
source "$PRIVATE_ENV_FILE"

# 2. Validate input argument
if [ -z "$1" ]; then
    echo "Usage: $0 <local_file_or_directory>"
    exit 1
fi

# 3. Prepare paths
LOCAL_PATH="$1"
# Target directory on the VM
REMOTE_DEST="/home/$SPARK_USER/Downloads/"
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 4. Execute the upload using scp
# -i: Specifies the identity file
# -r: Recursive (allows uploading entire directories)
echo "Uploading $LOCAL_PATH to $SPARK_USER@$SPARK_HOST:$REMOTE_DEST..."
scp -i "$EXPANDED_KEY_PATH" -r "$LOCAL_PATH" "$SPARK_USER@$SPARK_HOST:$REMOTE_DEST"

echo "Upload complete."
