#!/bin/bash
set -euo pipefail
# ==============================================================================
# 01 - SSH to DGX Spark
# ==============================================================================
# Purpose: Opens an interactive SSH session with the DGX Spark VM.

# 1. Determine the directory of this script to find the private env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

# 2. Check if the private environment configuration exists
if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    echo "Please copy 00_env_setup_template.sh to 00_env_setup_private.sh and update the values."
    exit 1
fi

# 3. Load the configuration variables (SPARK_HOST, SPARK_USER, SSH_KEY_PATH)
source "$PRIVATE_ENV_FILE"

# 4. Handle tilde (~) expansion manually for the SSH key path
# Bash does not automatically expand '~' when it's inside a quoted variable.
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 5. Connect to the VM
# -i: Specifies the identity file (private key)
echo "Connecting to $SPARK_USER@$SPARK_HOST using key $EXPANDED_KEY_PATH..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST"
