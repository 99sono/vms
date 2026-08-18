#!/bin/bash
# ==============================================================================
# 05_diagnose_gpu_clock_cap.sh — ONE-OFF diagnostic (run ON the Spark)
# ==============================================================================
# WHY: The audit (04) reads `clocks.max.graphics` to detect the cap, but on the
#      GB10 that returned the hardware default (3003 MHz), not the -lgc lock.
#      This captures the real clock data so 04 can be pointed at the right field.
#
# WHAT IT DOES:
#   STATE A : dump all candidate clock fields (current)
#   STATE B : sudo nvidia-smi -rgc    (unlock) -> dump fields
#   STATE C : sudo nvidia-smi -lgc 0,CAP (lock) -> dump fields
#   FULL    : nvidia-smi -q -d CLOCK  (exact section names)
#   JOURNAL : recent systemd log for nvidia-clock-cap.service
#   It ENDS with the cap applied (locked) — the desired end state.
#
# USAGE: bash 05_diagnose_gpu_clock_cap.sh [CAP_MHZ]    # default 2200
#        (asks for your sudo password at the first toggle)
#
# PASTE THE WHOLE OUTPUT BACK SO THE AUDIT (04) CAN BE FIXED.
# ==============================================================================
set -uo pipefail

CAP="${1:-2200}"
UNIT_NAME="nvidia-clock-cap.service"
# Space-separated candidate clock fields to observe.
Q_FIELDS="clocks.graphics clocks.sm clocks.mem clocks.video \
          clocks.max.graphics clocks.max.sm clocks.max.mem \
          clocks.applications.graphics clocks.applications.sm \
          clocks.default_applications.graphics clocks.default_applications.sm"

echo "============================================================"
echo "  GPU clock-cap DIAGNOSTIC"
echo "============================================================"
echo "  Host:   $(hostname)"
echo "  Cap:    ${CAP} MHz"
echo "  nvidia: $(command -v nvidia-smi 2>/dev/null || echo 'NOT FOUND')"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "  Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)"
fi
echo "  NOTE: toggles the clock (rgc -> lgc) and ENDS with the cap applied."
echo "        Ctrl-C now if you don't want that."
echo "============================================================"
echo ""

dump_state() {
    local label="$1" f v
    echo "----- ${label} -----"
    for f in $Q_FIELDS; do
        v="$(nvidia-smi --query-gpu="$f" --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
        printf '     %-34s %s\n' "$f" "${v:-n/a}"
    done
    echo ""
}

echo "  [A] CURRENT (locked if the unit ran at boot):"
dump_state "STATE A — current"

echo "  [B] Unlocking: sudo nvidia-smi -rgc"
if sudo nvidia-smi -rgc 2>/dev/null; then echo "      -rgc OK"; else echo "      -rgc FAILED (check sudo)"; fi
dump_state "STATE B — unlocked (baseline)"

echo "  [C] Re-locking: sudo nvidia-smi -lgc 0,${CAP}"
if sudo nvidia-smi -lgc 0,"${CAP}" 2>/dev/null; then echo "      -lgc OK"; else echo "      -lgc FAILED (check sudo)"; fi
dump_state "STATE C — locked at ${CAP}"

echo "  [D] Full 'nvidia-smi -q -d CLOCK':"
echo "  -----------------------------------------------------------------"
nvidia-smi -q -d CLOCK 2>/dev/null | sed 's/^/    /'
echo "  -----------------------------------------------------------------"
echo ""

echo "  [E] Recent journal for ${UNIT_NAME}:"
if sudo journalctl -u "$UNIT_NAME" --no-pager -n 20 2>/dev/null; then
    :
else
    echo "    (no journal entries / not root — skipping)"
fi
echo ""
echo "============================================================"
echo "  DONE — ends with cap applied (locked at ${CAP} MHz)."
echo "  PASTE THIS WHOLE OUTPUT BACK. Compare STATE B vs STATE C: the field"
echo "  that drops from the ~3000s to ~${CAP} when locked is the one 04 must use."
echo "============================================================"
