#!/bin/bash
set -uo pipefail

# ==============================================================================
# 04_audit_gpu_clock_cap.sh — Audit the GPU clock cap setup (read-only)
# ==============================================================================
# WHY
#   A single "is everything correct?" check that works whether or not you used
#   03_persist_gpu_clock_cap.sh. It inspects four layers and reports each:
#
#     [1] Unit installed  — the .service file is present in /etc/systemd/system
#     [2] Service enabled — enabled at boot (survives reboots)
#     [3] Service active  — the unit ran successfully (cap applied at boot)
#     [4] Cap in effect   — established by [3] (see NOTE) + optional journal proof
#
# VERDICT / EXIT CODES
#   0  fully good     — persistent AND the cap was applied
#   2  live, not pers — cap applied now but will NOT survive a reboot
#                        (run 03_persist_gpu_clock_cap.sh install)
#   1  broken         — the cap is not in effect
#
# USAGE
#   bash 04_audit_gpu_clock_cap.sh
#   MAX_CLOCK=2000 bash 04_audit_gpu_clock_cap.sh   # audit against a custom cap
#
# NOTE on the "cap in effect" check  (important — read this)
#   On the DGX Spark (GB10, driver 580.x) there is NO nvidia-smi query field that
#   reads back the `-lgc` lock: `clocks.max.graphics` reports the hardware max
#   (e.g. 3003) and `clocks.applications.graphics` the factory app clock (2418),
#   NOT the 2200 lock. So we do NOT compare any clock reading against the cap —
#   that check would always be a false negative.
#
#   Instead, "cap in effect" is established by the fact that this unit is
#   Type=oneshot + RemainAfterExit=yes: `systemctl is-active` returns "active"
#   only if the ExecStart (`sudo nvidia-smi -lgc 0,<cap>`) ran to completion. A
#   failed run shows "failed". And `-lgc` persists until reboot or `-rgc`, so
#   "active since boot" == "cap currently in effect". (A manual
#   `02_cap_gpu_clock.sh reset` would clear the cap without changing unit state.)
#
#   As extra proof, if passwordless sudo is available the audit also prints the
#   most recent "GPU clocks set to (gpuClkMin 0, gpuClkMax N)" journal line. The
#   verdict does NOT depend on sudo.
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
echo "  Target cap: ${EXPECTED_CAP} MHz (via nvidia-smi -lgc 0,${EXPECTED_CAP})"
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
# GB10 exposes no query field for the -lgc lock, so we do NOT compare a clock
# reading against the cap (that would always be a false negative). Instead:
#   * current graphics clock is shown for reference only (it's ~200 MHz at idle);
#   * if passwordless sudo is available we print the most recent "gpuClkMax"
#     journal line as concrete proof of what the unit applied;
#   * CAP_LIVE is set by [3]: "service active" == the oneshot ExecStart
#     (nvidia-smi -lgc 0,cap) completed successfully == cap applied at boot.
CURRENT_GRAPHICS="$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
echo ""
echo "  GPU current graphics clock: ${CURRENT_GRAPHICS:-?} MHz (reference only — ~200 MHz at idle)"

JOURNAL_LINE=""
if command -v sudo >/dev/null 2>&1; then
    JOURNAL_LINE="$(sudo -n journalctl -u "$UNIT_NAME" --no-pager 2>/dev/null \
        | grep -Eo 'GPU clocks set to \("[^)]*\)' | tail -n 1)"
fi
if [ -n "$JOURNAL_LINE" ]; then
    echo "  Journal (sudo): ${JOURNAL_LINE}"
else
    echo "  Journal (sudo): not read (no passwordless sudo, or unit has not run)."
    echo "    To see it:  sudo journalctl -u $UNIT_NAME --no-pager | grep gpuClkMax"
fi

if [ "${UNIT_PRESENT:-0}" -eq 1 ] && [ "${ACTIVE:-}" = "active" ]; then
    CAP_LIVE=1
    mark PASS "cap in effect" "service active ⇒ -lgc 0,${EXPECTED_CAP} applied at boot (persists until reboot)"
else
    CAP_LIVE=0
    mark FAIL "cap in effect" "not confirmed — service not active (cap not applied this boot)"
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
    echo "  VERDICT: PARTIAL — cap is applied but the systemd persistence is incomplete."
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
