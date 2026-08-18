#!/bin/bash
set -uo pipefail

# ==============================================================================
# 04_audit_gpu_clock_cap.sh — Audit the GPU clock cap setup (read-only)
# ==============================================================================
# WHY
#   A single "is everything correct?" check that works whether or not you used
#   03_persist_gpu_clock_cap.sh. It inspects three layers and reports each:
#
#     [1] Unit installed  — the .service file is present in /etc/systemd/system
#     [2] Service enabled — enabled at boot (survives reboots)
#     [3] Service active  — running right now
#     [4] Cap in effect   — the GPU's max graphics clock is at/below your cap
#
# VERDICT / EXIT CODES
#   0  fully good     — persistent AND the cap is live
#   2  live, not pers — cap is in effect now but will NOT survive a reboot
#                        (run 03_persist_gpu_clock_cap.sh install)
#   1  broken         — the cap is not in effect
#
# USAGE
#   bash 04_audit_gpu_clock_cap.sh
#   MAX_CLOCK=2000 bash 04_audit_gpu_clock_cap.sh   # audit against a custom cap
#
# NOTE on the "cap in effect" check
#   We read `clocks.max.graphics` (the GPU's current max graphics clock). After
#   `nvidia-smi -lgc 0,<cap>` this should read at-or-below the cap. If the driver
#   instead reports the physical hardware max, treat the value below as a hint
#   and confirm with the raw `nvidia-smi -q -d CLOCK` section we print.
# ==============================================================================

EXPECTED_CAP="${MAX_CLOCK:-2200}"
UNIT_NAME="nvidia-clock-cap.service"
UNIT_DEST="/etc/systemd/system/$UNIT_NAME"

command -v nvidia-smi >/dev/null 2>&1 || {
    echo "Error: nvidia-smi not found on this system." >&2
    exit 1
}

PASS=0; WARN=0; FAIL=0
mark() { # $1=status $2=label $3=detail
    case "$1" in
        PASS) PASS=$((PASS+1)); printf '  [PASS] %s — %s\n' "$2" "$3" ;;
        WARN) WARN=$((WARN+1)); printf '  [WARN] %s — %s\n' "$2" "$3" ;;
        FAIL) FAIL=$((FAIL+1)); printf '  [FAIL] %s — %s\n' "$2" "$3" ;;
    esac
}

echo "============================================================"
echo "  DGX Spark GPU Clock Cap — Audit"
echo "============================================================"
echo "  Host:       $(hostname)"
echo "  Expected:   max graphics clock <= ${EXPECTED_CAP} MHz"
echo "============================================================"
echo ""

# --- [1] Unit installed ---
if [ -f "$UNIT_DEST" ]; then
    mark PASS "unit installed" "$UNIT_DEST present"
    UNIT_PRESENT=1
else
    mark FAIL "unit installed" "$UNIT_DEST missing (persistence not installed)"
    UNIT_PRESENT=0
fi

# --- [2] enabled ---
if [ "$UNIT_PRESENT" -eq 1 ]; then
    ENABLED="$(systemctl is-enabled "$UNIT_NAME" 2>/dev/null || true)"
    if [ "$ENABLED" = "enabled" ]; then
        mark PASS "service enabled" "enabled at boot"
    else
        mark FAIL "service enabled" "is-enabled='$ENABLED'"
    fi
    # --- [3] active ---
    ACTIVE="$(systemctl is-active "$UNIT_NAME" 2>/dev/null || true)"
    if [ "$ACTIVE" = "active" ]; then
        mark PASS "service active" "running"
    else
        mark FAIL "service active" "is-active='$ACTIVE'"
    fi
else
    mark WARN "service enabled" "skipped (unit not installed)"
    mark WARN "service active"  "skipped (unit not installed)"
fi

# --- [4] cap in effect ---
MAX_GRAPHICS="$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
CURRENT_GRAPHICS="$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
echo ""
echo "  GPU clocks: max_graphics=${MAX_GRAPHICS:-?} MHz | current_graphics=${CURRENT_GRAPHICS:-?} MHz"
echo "  --- nvidia-smi -q -d CLOCK (Max Clocks section) ---"
nvidia-smi -q -d CLOCK 2>/dev/null | awk '/^Max Clocks/{f=1;print;next} /^[A-Z]/{f=0} f' | sed 's/^/    /'
echo ""

if [[ "$MAX_GRAPHICS" =~ ^[0-9]+$ ]] && [ "$MAX_GRAPHICS" -le "$EXPECTED_CAP" ]; then
    CAP_LIVE=1
    mark PASS "cap in effect" "max graphics clock ${MAX_GRAPHICS} MHz <= cap ${EXPECTED_CAP} MHz"
else
    CAP_LIVE=0
    mark FAIL "cap in effect" "max graphics clock '${MAX_GRAPHICS:-?}' MHz is not <= cap ${EXPECTED_CAP} MHz"
fi

echo ""
echo "  Checks: ${PASS} passed, ${WARN} warnings, ${FAIL} failed"

# --- Overall verdict ---
echo ""
echo "============================================================"
if [ "$FAIL" -gt 0 ]; then
    if [ "$CAP_LIVE" -eq 0 ]; then
        echo "  VERDICT: BROKEN — the GPU clock cap is NOT in effect."
        echo "           Apply it now:  bash 02_cap_gpu_clock.sh apply"
        echo "           Make it stick: bash 03_persist_gpu_clock_cap.sh install"
        echo "============================================================"
        exit 1
    fi
    echo "  VERDICT: PARTIAL — cap is live but the systemd persistence is incomplete."
    echo "            See the [FAIL] lines above (likely a missing/failed unit)."
    echo "============================================================"
    exit 1
fi

if [ "$UNIT_PRESENT" -eq 1 ] && [ "$CAP_LIVE" -eq 1 ]; then
    echo "  VERDICT: GOOD — GPU clock cap is in effect AND persistent across reboots."
    echo "============================================================"
    exit 0
fi

echo "  VERDICT: LIVE BUT NOT PERSISTENT — the cap works right now but will"
echo "          CLEAR ON REBOOT. To make it permanent:"
echo "            bash 03_persist_gpu_clock_cap.sh install"
echo "============================================================"
exit 2
