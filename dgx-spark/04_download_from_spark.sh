#!/bin/bash
set -euo pipefail
# ==============================================================================
# 04 - Download from Spark to Local Downloads
# ==============================================================================
# Purpose: Downloads a file or directory from the VM to your local ~/Downloads.
# Usage: ./04_download_from_spark.sh <remote_path>

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
    echo "Usage: $0 <remote_file_or_directory_path>"
    echo "Example: ./04_download_from_spark.sh /home/$SPARK_USER/Downloads/some_file.zip"
    exit 1
fi

# 3. Prepare paths
REMOTE_SRC="$1"
# Fixed local destination for downloads
LOCAL_DEST="$HOME/Downloads/"
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 4. Execute the download using scp
# -i: Specifies the identity file
# -r: Recursive (allows downloading entire directories)
echo "Downloading from $SPARK_USER@$SPARK_HOST:$REMOTE_SRC to $LOCAL_DEST..."
scp -i "$EXPANDED_KEY_PATH" -r "$SPARK_USER@$SPARK_HOST:$REMOTE_SRC" "$LOCAL_DEST"

echo "Download complete."
