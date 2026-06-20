#!/bin/bash
# ==============================================================================
# Shared disable-password implementation — sourced by 05_a_* and 05_b_*.
# ==============================================================================
REMOTE_SCRIPT_PATH="$SCRIPT_DIR/scripts/disable_passwords.sh"

if [ ! -f "$REMOTE_SCRIPT_PATH" ]; then
    echo "Error: Remote script not found at $REMOTE_SCRIPT_PATH"
    exit 1
fi

if [ ! -f "$EXPANDED_KEY_PATH" ]; then
    echo "Error: SSH private key not found at $EXPANDED_KEY_PATH"
    exit 1
fi

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

read -p "Proceed? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS]) echo "" ;;
    *)
        echo "Aborted by user."
        exit 0
        ;;
esac

ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "mkdir -p ~/scripts"
scp -i "$EXPANDED_KEY_PATH" "$REMOTE_SCRIPT_PATH" "$SPARK_USER@$SPARK_HOST:~/scripts/disable_passwords.sh"
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "chmod +x ~/scripts/disable_passwords.sh"

echo "Executing remote hardening script..."
ssh -t -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "sudo bash ~/scripts/disable_passwords.sh"
REMOTE_EXIT=$?

ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST" "rm -f ~/scripts/disable_passwords.sh"
exit $REMOTE_EXIT
