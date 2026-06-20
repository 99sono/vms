#!/bin/bash
# ==============================================================================
# Shared SSH key upload — sourced by 02_a_* and 02_b_*.
# ==============================================================================
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
PUB_KEY_PATH="${EXPANDED_KEY_PATH}.pub"

if [ ! -f "$PUB_KEY_PATH" ]; then
    echo "Error: Public key not found at $PUB_KEY_PATH"
    echo "Please ensure you have generated your SSH keys (e.g., using ssh-keygen)."
    exit 1
fi

echo "Uploading public key $PUB_KEY_PATH to $SPARK_USER@$SPARK_HOST..."
ssh-copy-id -i "$PUB_KEY_PATH" "$SPARK_USER@$SPARK_HOST"

echo "Success: Your key should now be authorized on the VM."
