#!/bin/bash
set -euo pipefail

# ==============================================================================
# DGX Spark System Update (Remote Script)
# ==============================================================================
# Performs a full DGX Spark OS + firmware update per NVIDIA documentation:
#   1. sudo apt update
#   2. sudo apt dist-upgrade
#   3. sudo fwupdmgr refresh
#   4. sudo fwupdmgr upgrade
#   5. sudo reboot (with user confirmation)
#
# This script runs ON the Spark, uploaded by the local wrapper:
#   09_a_update_spark01.sh / 09_b_update_spark02.sh
#
# Reference:
#   https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html
# ==============================================================================

# --- Safety: require a TTY for the interactive prompts ---
if [ ! -t 0 ]; then
    echo "Error: This script requires an interactive terminal (TTY)." >&2
    echo "The local wrapper already uses 'ssh -t'; if you ran this manually," >&2
    echo "make sure you are in an interactive SSH session." >&2
    exit 1
fi

# --- Header ---
echo "============================================================"
echo "  DGX Spark System Update"
echo "============================================================"
echo ""
echo "  Host:   $(hostname)"
echo "  Date:   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  Kernel: $(uname -r)"
echo ""
echo "  This will perform the following steps:"
echo "    [1/5] sudo apt update"
echo "    [2/5] sudo apt dist-upgrade"
echo "    [3/5] sudo fwupdmgr refresh"
echo "    [4/5] sudo fwupdmgr upgrade"
echo "    [5/5] sudo reboot  (with confirmation)"
echo ""
echo "  NOTE: 'dist-upgrade' (not 'upgrade') is required on DGX Spark"
echo "        because the GPU driver modules are baked into the"
echo "        custom NVIDIA kernel and must move forward together."
echo ""
echo "  WARNING: Keep your SSH session open until the reboot completes."
echo "           After reboot the system may take a few minutes"
echo "           to come back online."
echo ""

read -rp "  Proceed with full system update? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS]) ;;
    *)
        echo "  Aborted by user. No changes made."
        exit 0
        ;;
esac

# --- Step 1: apt update ---
echo ""
echo "=== [1/5] apt update ==="
sudo apt update

# --- Step 2: apt dist-upgrade ---
echo ""
echo "=== [2/5] apt dist-upgrade ==="
sudo apt dist-upgrade -y

# --- Step 3: fwupdmgr refresh ---
echo ""
echo "=== [3/5] fwupdmgr refresh ==="
sudo fwupdmgr refresh

# --- Step 4: fwupdmgr upgrade ---
echo ""
echo "=== [4/5] fwupdmgr upgrade ==="
sudo fwupdmgr upgrade

# --- Step 5: Reboot (with confirmation) ---
echo ""
echo "============================================================"
echo "  All updates installed successfully!"
echo "============================================================"
echo ""
read -rp "  Reboot now? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS])
        echo ""
        echo "  Rebooting in 5 seconds..."
        echo "  Your SSH session will drop — this is expected."
        echo "  Reconnect once the system is back online (~2-5 min)."
        echo ""
        # Detach the reboot so the SSH connection drops cleanly
        # and we don't get a spurious "connection reset" error.
        ( sleep 5 && exec sudo reboot ) &
        disown
        exit 0
        ;;
    *)
        echo ""
        echo "  Reboot skipped."
        echo "  Run 'sudo reboot' manually when you are ready."
        exit 0
        ;;
esac
