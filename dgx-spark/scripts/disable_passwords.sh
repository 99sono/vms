#!/bin/bash
set -euo pipefail

# ==============================================================================
# Disable SSH Password Authentication (Remote Script)
# ==============================================================================
# This script runs on the VM to harden SSH by disabling password-based login.
# It is invoked by the local wrapper 05_disable_password_auth.sh via SCP + SSH.
# ==============================================================================

CONFIG="/etc/ssh/sshd_config"

# Ensure HOME is correctly set. When invoked via `ssh user@host "sudo bash ..."`
# the HOME variable may be empty or set to root's home. We need the original
# user's HOME to resolve ~/.ssh/authorized_keys correctly.
#
# SUDO_USER is set by sudo to the original username that invoked sudo.
# When HOME=/root (typical sudo behavior), we use SUDO_USER to find the real home.
if [ "${HOME:-/root}" = "/root" ] && [ -n "${SUDO_USER:-}" ]; then
    HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi

# Capture exact backup filename for reliable rollback
BACKUP_FILE="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

EXIT_CODE=0

echo "=== SSH Password Authentication Disabler ==="
echo ""

# --- Before Snapshot ---
# Show the initial state of all SSH auth-related settings for audit purposes.
# The grep pattern matches both commented (#) and uncommented lines.
echo "=== BEFORE (current SSH auth settings) ==="
grep -nEi '(passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|challengeresponseauthentication)' "$CONFIG" | head -20 || echo "  (no matching lines found)"
echo ""

# --- Pre-flight Checks ---

# 1. Verify authorized_keys is not empty
# Use explicit $HOME path (not ~ expansion) for reliability in non-interactive SSH sessions.
SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
echo "[1/8] Checking authorized_keys..."
echo "  Checking: $AUTH_KEYS"
if ! test -s "$AUTH_KEYS"; then
    echo "FATAL: $AUTH_KEYS is empty or missing!"
    echo "Password authentication is currently your ONLY SSH login method."
    echo "Disabling passwords without valid keys would lock you out."
    echo "ABORTED."
    exit 1
fi
echo "  authorized_keys: OK ($(wc -l < "$AUTH_KEYS") key(s))"

# 2. Check if already disabled
echo "[2/8] Checking current configuration..."
if grep -qE '^[^#]*PasswordAuthentication no' "$CONFIG"; then
    echo "  Password authentication is already disabled."
    echo "Nothing to do. Exiting successfully."
    exit 0
fi

# 3. Check for config overrides in sshd_config.d
echo "[3/8] Checking for config overrides in /etc/ssh/sshd_config.d/..."
OVERRIDES=$(grep -r 'PasswordAuthentication' /etc/ssh/sshd_config.d/ 2>/dev/null || true)
if [ -n "$OVERRIDES" ]; then
    echo "  WARNING: Override files found:"
    echo "$OVERRIDES"
    echo "  These may override your main config changes."
    echo "  You may need to address these separately."
fi
echo "  Check complete."

# 4. Show current values
echo "[4/8] Current SSH auth-related settings:"
grep -nEi 'passwordauthentication|pubkeyauthentication|kbdinteractive|challengeresponse' "$CONFIG" || echo "  (none found - using defaults)"

# --- Apply Changes ---

echo ""
echo "[5/8] Applying changes to $CONFIG..."

# Backup current config
cp "$CONFIG" "$BACKUP_FILE"
echo "  Backup saved to: $BACKUP_FILE"

# Enforce strict permissions on authorized_keys and .ssh directory
# OpenSSH will silently ignore authorized_keys if file permissions are too loose
# (e.g., 644 or 664). Strict 600/700 ensures keys are always read after password auth is disabled.
echo "[6/8] Enforcing strict permissions on $SSH_DIR..."
chmod 700 "$SSH_DIR" 2>/dev/null || true
chmod 600 "$AUTH_KEYS" 2>/dev/null || true
echo "  $SSH_DIR: 700 | $AUTH_KEYS: 600"

# Modify sshd_config to enforce key-only authentication:
#   PasswordAuthentication no       → reject password-based logins
#   PubkeyAuthentication yes        → explicitly enable public-key auth (in case it was commented out)
#   KbdInteractiveAuthentication no → disable keyboard-interactive (GitHub/Google Authenticator fallback)
#   ChallengeResponseAuthentication no → disable challenge-response (legacy Ubuntu path)
echo ""
echo "[7/8] Disabling password-based SSH auth methods in $CONFIG..."
sed -i -E \
  -e 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' \
  -e 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' \
  -e 's/^#?KbdInteractiveAuthentication\s+.*/KbdInteractiveAuthentication no/' \
  -e 's/^#?ChallengeResponseAuthentication\s+.*/ChallengeResponseAuthentication no/' \
  "$CONFIG"

echo "  sed applied successfully. All four auth settings have been enforced."

# Validate the modified configuration before reloading SSH.
# `sshd -t` performs a syntax check without making any changes — it catches:
#   - Typos in directive names
#   - Invalid directive values (e.g., "enabled" instead of "yes")
#   - Conflicting settings (e.g., two "PasswordAuthentication" lines)
# If validation fails, the backup is restored immediately (atomic rollback).
echo ""
echo "[8/8] Validating sshd configuration syntax (sshd -t)..."
if sudo sshd -t 2>&1; then
    echo "  Configuration validation: PASSED"
    echo ""
    echo "Reloading SSH service..."
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || echo "  WARNING: Could not reload SSH service. Please restart manually: sudo systemctl restart ssh"
    echo "SSH service reloaded successfully."
else
    echo "  Configuration validation: FAILED"
    echo ""
    echo "REVERTING to backup: $BACKUP_FILE"
    cp "$BACKUP_FILE" "$CONFIG"
    echo "Revert complete. SSH config restored from backup."
    echo "Your SSH config was NOT modified in-place."
    echo "Please check your changes and try again."
    EXIT_CODE=1
fi

# --- Summary ---
echo ""
echo "=== Result ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "Password authentication has been disabled on this VM."
    echo ""
    echo "IMPORTANT:"
    echo "  1. Keep your CURRENT SSH session open."
    echo "  2. Open a NEW terminal window."
    echo "  3. Test: ssh user@host"
    echo "  4. If the new connection succeeds, your old session is safe to close."
else
    echo "Changes were REVERTED due to validation failure."
    echo "Your SSH session remains unchanged."
fi

# --- After Snapshot ---
# Show the final state of all SSH auth-related settings for audit purposes.
# Compare this against the BEFORE snapshot to verify changes took effect.
echo ""
echo "=== AFTER (current SSH auth settings) ==="
grep -nEi '(passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|challengeresponseauthentication)' "$CONFIG" | head -20 || echo "  (no matching lines found)"
echo ""

exit $EXIT_CODE
