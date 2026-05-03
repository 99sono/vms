#!/bin/bash
set -euo pipefail
# ==============================================================================
# 02 - Upload SSH Key
# ==============================================================================
# Purpose: Copies your local public key to the VM's authorized_keys file.
# This allows for passwordless login in subsequent sessions.

# 1. Locate and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    exit 1
fi
source "$PRIVATE_ENV_FILE"

# 2. Prepare the public key path
# We expand the private key path and append '.pub'
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
PUB_KEY_PATH="${EXPANDED_KEY_PATH}.pub"

# 3. Verify the public key exists locally
if [ ! -f "$PUB_KEY_PATH" ]; then
    echo "Error: Public key not found at $PUB_KEY_PATH"
    echo "Please ensure you have generated your SSH keys (e.g., using ssh-keygen)."
    exit 1
fi

# 4. Upload the key using ssh-copy-id
# -i: Specifies the public key to copy
echo "Uploading public key $PUB_KEY_PATH to $SPARK_USER@$SPARK_HOST..."
ssh-copy-id -i "$PUB_KEY_PATH" "$SPARK_USER@$SPARK_HOST"

echo "Success: Your key should now be authorized on the VM."
