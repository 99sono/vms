#!/bin/bash
set -euo pipefail

# ==============================================================================
# 03_persist_gpu_clock_cap.sh — Make the GPU clock cap survive reboots
# ==============================================================================
# WHY
#   `nvidia-smi -lgc` (see 02_cap_gpu_clock.sh) is non-persistent: the cap
#   clears on reboot. This script installs a small systemd oneshot service that
#   re-applies the cap automatically on every boot, so you never have to run it
#   by hand again.
#
# HOW IT AVOIDS AN INTERACTIVE EDITOR
#   We do NOT open `nano`. The unit file is already written and committed in the
#   repo at  <this dir>/systemd/nvidia-clock-cap.service  and, after the folder
#   upload, lives at  ~/scripts/maintenance/systemd/nvidia-clock-cap.service.
#   This script simply COPIES that file into /etc/systemd/system/ and enables it.
#
# USAGE
#   bash 03_persist_gpu_clock_cap.sh [install|uninstall|status]
#     install     (default) copy unit -> daemon-reload -> enable --now
#     uninstall             disable + remove the service
#     status                show whether the unit is installed/enabled/active
#
# SAFETY
#   * Verifies the nvidia-smi binary path referenced in the unit exists before
#     installing (so we never commit a service that points at the wrong binary).
#   * The copy is done with sudo install(1) so ownership/permissions are set
#     correctly for /etc/systemd/system.
# ==============================================================================

UNIT_NAME="nvidia-clock-cap.service"
UNIT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/systemd/$UNIT_NAME"
UNIT_DEST="/etc/systemd/system/$UNIT_NAME"
MODE="${1:-install}"

command -v nvidia-smi >/dev/null 2>&1 || {
    echo "Error: nvidia-smi not found on this system." >&2
    exit 1
}

echo "============================================================"
echo "  DGX Spark GPU Clock Cap — Persistence (systemd)"
echo "============================================================"
echo "  Host:     $(hostname)"
echo "  Mode:     $MODE"
echo "  Unit:     $UNIT_NAME"
echo "============================================================"
echo ""

case "$MODE" in
    install)
        if [ ! -f "$UNIT_SRC" ]; then
            echo "Error: Unit file not found at $UNIT_SRC" >&2
            echo "       Did the maintenance/ folder upload (10_sync_maintenance) run?" >&2
            exit 1
        fi

        # Pull the nvidia-smi path out of the unit and verify it exists.
        NVIDIA_SMI_PATH="$(grep -E '^ExecStart=' "$UNIT_SRC" | sed -E 's|^ExecStart=([^ ]+).*|\1|')"
        if [ ! -x "$NVIDIA_SMI_PATH" ]; then
            echo "Error: Unit references '$NVIDIA_SMI_PATH' but it is not executable here." >&2
            echo "       Actual nvidia-smi is at: $(command -v nvidia-smi)" >&2
            echo "       Fix the ExecStart path in $UNIT_SRC and re-run." >&2
            exit 1
        fi
        echo "  Verified nvidia-smi path in unit: $NVIDIA_SMI_PATH"

        # Copy the unit into place (correct owner/perms via install(1)).
        echo "  Copying $UNIT_SRC -> $UNIT_DEST"
        sudo install -m 0644 "$UNIT_SRC" "$UNIT_DEST"

        echo "  Reloading systemd..."
        sudo systemctl daemon-reload

        echo "  Enabling + starting $UNIT_NAME..."
        sudo systemctl enable --now "$UNIT_NAME"

        echo ""
        echo "  Installed and active. The cap now re-applies on every boot."
        echo "  Verify with:  bash 04_audit_gpu_clock_cap.sh"
        ;;

    uninstall)
        if [ ! -f "$UNIT_DEST" ]; then
            echo "  $UNIT_NAME is not installed. Nothing to remove."
            exit 0
        fi
        echo "  Disabling + stopping $UNIT_NAME..."
        sudo systemctl disable --now "$UNIT_NAME" 2>/dev/null || true
        echo "  Removing $UNIT_DEST"
        sudo rm -f "$UNIT_DEST"
        sudo systemctl daemon-reload
        echo "  Removed. The cap will no longer auto-apply on boot."
        echo "  (Any cap applied right now still holds until the next reboot or"
        echo "   until you run: bash 02_cap_gpu_clock.sh reset)"
        ;;

    status)
        if [ ! -f "$UNIT_DEST" ]; then
            echo "  Unit file:   NOT installed ($UNIT_DEST missing)"
            exit 1
        fi
        echo "  Unit file:   present at $UNIT_DEST"
        echo "  Enabled:     $(systemctl is-enabled "$UNIT_NAME" 2>/dev/null || echo unknown)"
        echo "  Active:      $(systemctl is-active "$UNIT_NAME" 2>/dev/null || echo unknown)"
        ;;

    *)
        echo "Usage: bash 03_persist_gpu_clock_cap.sh [install|uninstall|status]" >&2
        exit 2
        ;;
esac
