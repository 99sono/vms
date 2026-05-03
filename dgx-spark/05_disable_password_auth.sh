#!/bin/bash
set -euo pipefail
# ==============================================================================
# 05 - Disable Password Authentication
# ==============================================================================
# Purpose: Hardens SSH by disabling password-based login on the DGX Spark VM.
# Usage:   ./05_disable_password_auth.sh
# Notes:   - Requires sudo access on the remote VM
#          - Keep your current SSH session open until you verify a new one works!
#          - Automatically rolls back if config validation fails
# ==============================================================================

# 1. Determine the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 2. Path to the remote script (same directory)
REMOTE_SCRIPT_PATH="$SCRIPT_DIR/scripts/disable_passwords.sh"

# 3. Check if the remote script exists
if [ ! -f "$REMOTE_SCRIPT_PATH" ]; then
    echo "Error: Remote script not found at $REMOTE_SCRIPT_PATH"
    exit 1
fi

# 4. Determine the private env file
PRIVATE_ENV_FILE="$SCRIPT_DIR/00_env_setup_private.sh"

# 5. Check if the private environment configuration exists
if [ ! -f "$PRIVATE_ENV_FILE" ]; then
    echo "Error: Private environment file not found at $PRIVATE_ENV_FILE"
    echo "Please copy 00_env_setup_template.sh to 00_env_setup_private.sh and update the values."
    exit 1
fi

# 6. Load the configuration variables (SPARK_HOST, SPARK_USER, SSH_KEY_PATH)
source "$PRIVATE_ENV_FILE"

# 7. Handle tilde (~) expansion manually for the SSH key path
EXPANDED_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# 8. Verify the SSH private key exists locally
if [ ! -f "$EXPANDED_KEY_PATH" ]; then
    echo "Error: SSH private key not found at $EXPANDED_KEY_PATH"
    exit 1
fi

# 9. Show summary of what will be done
echo ""
echo "=============================================="
echo "  SSH Password Authentication Disabler"
echo "=============================================="
echo ""
echo "Target:    $SPARK_USER@$SPARK_HOST"
echo "Key:       $EXPANDED_KEY_PATH"
echo ""
echo "Actions:"
echo "  1. Check that authorized_keys is not empty"
echo "  2. Check if password auth is already disabled"
echo "  3. Check for config overrides in sshd_config.d/"
echo "  4. Show current SSH auth-related settings"
echo "  5. Backup and modify /etc/ssh/sshd_config"
echo "  6. Validate with sshd -t"
echo "  7. Reload SSH service (if validation passes)"
echo ""
echo "Safety:  The script will automatically ROLLBACK if validation fails."
echo ""

# 10. Confirm with user
read -p "Proceed? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS])
        echo ""
        ;;
    *)
        echo "Aborted by user."
        exit 0
        ;;
esac

# 11. Create ~/scripts/ directory on the remote VM
echo "Preparing remote script directory..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "mkdir -p ~/scripts"

# 12. Upload the remote script via SCP
echo "Uploading remote hardening script..."
scp -i "$EXPANDED_KEY_PATH" "$REMOTE_SCRIPT_PATH" "$SPARK_USER@$SPARK_HOST:~/scripts/disable_passwords.sh"

# 13. Make the remote script executable
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod +x ~/scripts/disable_passwords.sh"

# 14. Execute the remote script with TTY allocation for sudo
echo "Executing remote hardening script..."
ssh -t -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "sudo bash ~/scripts/disable_passwords.sh"
REMOTE_EXIT=$?

# 15. Clean up the remote script
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "rm -f ~/scripts/disable_passwords.sh"

# 16. Exit with the remote script's exit code
exit $REMOTE_EXIT