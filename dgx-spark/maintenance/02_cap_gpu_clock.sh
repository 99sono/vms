#!/bin/bash
set -euo pipefail

# ==============================================================================
# 02_cap_gpu_clock.sh — Cap the DGX Spark GPU graphics clock (remote script)
# ==============================================================================
# WHAT THIS DOES
#   Locks the GPU *graphics clock* to a maximum ceiling (default 2200 MHz,
#   down from the GB10's ~2455 MHz peak) using:
#
#       sudo nvidia-smi -lgc <min>,<max>
#
#   and can restore factory dynamic clocking with:
#
#       sudo nvidia-smi -rgc
#
# USAGE
#   bash 02_cap_gpu_clock.sh [apply|reset|status]
#     apply   (default) cap the max graphics clock to MAX_CLOCK (2200 MHz)
#     reset               restore factory default dynamic clocking
#     status              show current clock caps + running clock/temp (read-only)
#
#   Override the cap value:  MAX_CLOCK=2000 bash 02_cap_gpu_clock.sh apply
#
# WHY THIS MATTERS ON THE DGX SPARK (GB10)
#   * The GB10 packs the CPU and GPU on a single die sharing one thermal budget.
#     Under sustained inference load (e.g. vLLM / DeepSeek) the package can hit
#     96C+ and trigger a hard, abrupt power-off.
#   * Capping the graphics clock at 2200 MHz cuts package power by >30%
#     (~47W -> ~32W) and cools the chip by roughly 6-10C, keeping it safely
#     below the thermal tripwire.
#   * LLM token generation (the *decode* phase) is memory-bandwidth-bound, not
#     compute-bound. Capping the clock slightly slows the *prefill* phase but
#     leaves memory bandwidth (and thus tokens/second) essentially unchanged —
#     you keep the speed, lose the heat.
#
# PERSISTENCE
#   nvidia-smi -lgc is NON-persistent: the cap clears on reboot. To make it
#   survive reboots, install the systemd unit via 03_persist_gpu_clock_cap.sh.
#   (This script is deliberately kept non-persistent so it can also be used to
#   quickly test the effect or temporarily reset to full clock.)
#
#   To make this persistent automatically in the future, add a systemd unit
#   (see 03_persist_gpu_clock_cap.sh) — keep the nvidia-smi command here in sync
#   with the unit's ExecStart.
#
# REFERENCE
#   Community-verified GB10 thermal cap (Ivan Fioravanti / MiaAI_Lab benchmark):
#     https://x.com/MiaAI_lab/status/2088731867813974250
#   NVIDIA forums (how to throttle a GPU):
#     https://forums.developer.nvidia.com/t/how-do-i-throttle-my-gpu/362756
# ==============================================================================

MAX_CLOCK="${MAX_CLOCK:-2200}"   # default ceiling in MHz
MODE="${1:-apply}"

command -v nvidia-smi >/dev/null 2>&1 || {
    echo "Error: nvidia-smi not found on this system." >&2
    exit 1
}

# --- Read-only clock/temperature snapshot (shared by all modes) ---
show_clocks() {
    nvidia-smi --query-gpu=clocks.max.graphics,clocks.current.graphics,clocks_event_reasons.active,temp.gpu,power.draw \
               --format=csv,noheader,nounits 2>/dev/null \
    | awk -F', *' '{printf "     max=%s MHz | current=%s MHz | throttle=%s | temp=%s C | power=%s W\n", $1, $2, $3, $4, $5}'
}

echo "============================================================"
echo "  DGX Spark GPU Clock Cap"
echo "============================================================"
echo "  Host:    $(hostname)"
echo "  Mode:    $MODE"
echo "  Cap:     ${MAX_CLOCK} MHz   (env override: MAX_CLOCK=<mhz>)"
echo "============================================================"
echo ""

case "$MODE" in
    status)
        echo "  Current state:"
        show_clocks
        echo ""
        # The detailed 'CLOCK' section shows whether a lock is active.
        echo "  --- nvidia-smi -q -d CLOCK (Max Graphics / Graphics Limit) ---"
        nvidia-smi -q -d CLOCK 2>/dev/null | grep -Ei 'Max Graphics|Graphics\s+:\s|Graphics Clocks Limit' || true
        ;;

    reset)
        echo "  Removing any active graphics clock lock (factory dynamic clocking)..."
        if sudo nvidia-smi -rgc; then
            echo "  Reset complete."
            echo ""
            show_clocks
        else
            echo "  Error: nvidia-smi -rgc failed." >&2
            exit 1
        fi
        ;;

    apply)
        echo "  Applying graphics clock cap: -lgc 0,${MAX_CLOCK}"
        echo "  (non-persistent — clears on reboot; see 03_persist_gpu_clock_cap.sh)"
        echo ""
        echo "  BEFORE:"
        show_clocks
        echo ""
        if sudo nvidia-smi -lgc 0,"$MAX_CLOCK"; then
            echo "  Applied."
            echo ""
            echo "  AFTER:"
            show_clocks
            echo ""
            echo "  Verify later with:  bash 02_cap_gpu_clock.sh status"
            echo "  Make it permanent with: bash 03_persist_gpu_clock_cap.sh install"
        else
            echo "  Error: nvidia-smi -lgc 0,${MAX_CLOCK} failed." >&2
            echo "  (If this GPU does not support clock locking, the driver" >&2
            echo "   may need to be loaded as a module with persistence enabled.)" >&2
            exit 1
        fi
        ;;

    *)
        echo "Usage: bash 02_cap_gpu_clock.sh [apply|reset|status]" >&2
        exit 2
        ;;
esac
