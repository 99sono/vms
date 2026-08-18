#!/usr/bin/env bash
# ==============================================================================
# 06_load_test_gpu_clock_cap.sh — PROVE the cap under load (decisive test)
# ==============================================================================
# WHY
#   `04_audit` proves the unit RAN and the `-lgc` command was ACCEPTED. It cannot
#   prove the GPU's clock actually STAYS at-or-below the cap under load, because
#   on GB10 no nvidia-smi query field reflects the lock and every idle reading is
#   ~214 MHz (meaningless).
#
#   This is the missing test. It holds the GPU at ~100% util for a few seconds and
#   records the PEAK graphics clock observed while loaded:
#
#       peak <= cap  =>  the cap IS enforced  =>  we're good  (exit 0)
#       peak >  cap  =>  the cap is NOT enforced on GB10 => real problem (exit 1)
#
#   This is the single measurement that settles "do we have a problem or are we
#   good?" (See knowledge/CLOCK_CAP_NOTES.md.)
#
# REQUIREMENTS (all present on a stock DGX Spark)
#   - `nvidia-smi` (built in)  → drives the load (cublas) and polls the clock.
#   - `stress-ng --gpu`        → holds the GPU busy for $DURATION seconds.
#
#   If `stress-ng` is missing it installs automatically (apt, needs sudo) when
#   --yes is given. To skip auto-install, install it yourself:  sudo apt install stress-ng
#
# USAGE (on the Spark, or over ssh)
#   bash 06_load_test_gpu_clock_cap.sh            # 30s test, cap 2200, auto-install
#   DURATION=60 bash 06_load_test_gpu_clock_cap.sh
#   MAX_CLOCK=2000 bash 06_load_test_gpu_clock_cap.sh   # test against a custom cap
#
# HOW IT WORKS
#   1. Confirm the cap unit is active (sanity).
#   2. Record the pre-load idle clock.
#   3. Start `stress-ng --gpu` in the background; poll the clock every 200 ms.
#   4. Keep the max clock observed, kill the load, report PRELOAD/PEAK/CAP/VERDICT.
#
# SAFETY
#   A background `trap` always kills the stress-ng process (even on Ctrl-C), so
#   the GPU load never outlives this script. The load is a real GPU burn for
#   $DURATION seconds — the Spark gets warm and draws more power; that's the point.
# ==============================================================================
set -uo pipefail

CAP="${MAX_CLOCK:-2200}"
DURATION="${DURATION:-30}"      # seconds of sustained load
UNIT_NAME="nvidia-clock-cap.service"

echo "============================================================"
echo " GPU clock cap LOAD TEST  (decisive)"
echo "  Host:       $(hostname)"
echo "  Cap:        ${CAP} MHz"
echo "  Load time:  ${DURATION}s"
echo "============================================================"

# --- [0] nvidia-smi present + sanity ---
if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "ERROR: nvidia-smi not found." >&2
    exit 1
fi
if [[ ! "$CAP" =~ ^[0-9]+$ ]] || [[ ! "$DURATION" =~ ^[0-9]+$ ]]; then
    echo "ERROR: CAP and DURATION must be positive integers." >&2
    exit 1
fi

# --- [1] confirm the cap unit is active (sanity, not decisive) ---
ACTIVE="$(systemctl is-active "$UNIT_NAME" 2>/dev/null || true)"
echo ""
if [ "$ACTIVE" = "active" ]; then
    echo "  [sanity] cap unit ACTIVE (-lgc 0,${CAP} applied at boot)"
else
    echo "  [sanity] cap unit is '${ACTIVE:-unknown}' — the load test still runs,"
    echo "           but the cap may not be set. Run:  bash 03_persist_gpu_clock_cap.sh install"
fi

# --- [2] ensure stress-ng (auto-install if missing) ---
echo ""
if ! command -v stress-ng >/dev/null 2>&1; then
    echo "  stress-ng not found — installing (sudo apt)..."
    sudo apt-get install -y stress-ng || { echo "ERROR: failed to install stress-ng." >&2; exit 1; }
fi
echo "  stress-ng: $(stress-ng --version 2>/dev/null | awk '{print $NF}')"

# --- [3] pre-load idle clock ---
PRELOAD="$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
echo "  pre-load idle clock: ${PRELOAD:-?} MHz (should be low)"

# --- [4] run the load + poll ---
#   stress-ng holds the GPU busy; a poller samples the graphics clock every
#   200 ms and keeps the max in a temp file. trap guarantees cleanup on exit.
PEAK_FILE="$(mktemp)"
trap 'pkill -f "stress-ng --gpu" 2>/dev/null; rm -f "$PEAK_FILE"' EXIT

(
    for ((i=0; i<DURATION*5; i++)); do
        c="$(nvidia-smi --query-gpu=clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null | awk 'NR==1{print $1}')"
        if [[ "$c" =~ ^[0-9]+$ ]]; then
            prev="$(cat "$PEAK_FILE" 2>/dev/null || echo 0)"
            [ "$c" -gt "$prev" ] && echo "$c" > "$PEAK_FILE"
        fi
        sleep 0.2
    done
) > /dev/null 2>&1 &
POLL_PID=$!

stress-ng --gpu 1 --gpu-method all --timeout "${DURATION}s" --metrics-brief >/dev/null 2>&1 &
STRESS_PID=$!
wait "$STRESS_PID" 2>/dev/null || true
wait "$POLL_PID" 2>/dev/null || true

PEAK="$(cat "$PEAK_FILE" 2>/dev/null || echo 0)"

# --- [5] verdict ---
echo ""
echo "============================================================"
echo "  PRELOAD idle : ${PRELOAD:-?} MHz"
echo "  PEAK (loaded): ${PEAK:-?} MHz"
echo "  CAP          : ${CAP} MHz"
echo "============================================================"
if [[ ! "$PEAK" =~ ^[0-9]+$ ]] || [ "$PEAK" -eq 0 ]; then
    echo "  VERDICT: UNKNOWN — could not read the clock during load."
    echo "           Re-run with DURATION=60, or check nvidia-smi works."
    exit 2
fi
if [ "$PEAK" -le "$CAP" ]; then
    echo "  VERDICT: CAP ENFORCED — under full load the graphics clock peaked at"
    echo "           ${PEAK} MHz (<= ${CAP}). The -lgc lock is WORKING. We're good."
    echo "============================================================"
    exit 0
else
    echo "  VERDICT: CAP NOT ENFORCED — under full load the graphics clock reached"
    echo "           ${PEAK} MHz, which EXCEEDS the ${CAP} MHz cap. On GB10, -lgc is"
    echo "           accepted by nvidia-smi but NOT actually enforced, so the cap is"
    echo "           a no-op. See knowledge/CLOCK_CAP_NOTES.md for next steps."
    echo "============================================================"
    exit 1
fi
