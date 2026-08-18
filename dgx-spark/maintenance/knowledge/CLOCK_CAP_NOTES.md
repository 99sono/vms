# GPU Clock Cap on the DGX Spark (GB10) — the story & what we actually know

> Written after the spark01/spark02 investigation. The point is to make the one
> real question obvious and stop guessing from `nvidia-smi` numbers that don't
> mean what we expect on this platform.

## TL;DR — do we have a problem, or are we good?

- **Persistence: GOOD.** On both sparks the `nvidia-clock-cap.service` unit runs at
  boot, `nvidia-smi` accepts `-lgc 0,2200`, and reports
  `GPU clocks set to "(gpuClkMin 0, gpuClkMax 2200)"` + `All done.` + `Finished`.
  The cap command *survives reboots*.
- **Cap enforced under load: UNVERIFIED.** This is the *only* open question. Every
  clock reading we've captured was **idle** (~214 MHz), which is below the cap
  whether the lock works or not — so it proves nothing.
- **How to find out for sure:** run `06_load_test_gpu_clock_cap.sh` on a spark.
  It loads the GPU ~100% for 30s and reports the **peak** graphics clock.
  `peak <= 2200` → we're genuinely good. `peak > 2200` → the cap is a no-op on
  GB10 and we have a real problem (see bottom).

## Why this was confusing (the trap)

On a *normal* NVIDIA GPU, after `nvidia-smi -lgc 0,2200` the field
`clocks.max.graphics` drops to 2200, so "is the cap on?" is a one-liner.

**On GB10 (DGX Spark, driver 580.x) that is not true.** Both sparks show, with the
lock *confirmed applied* by the journal:

| field | value | what it really is |
|---|---|---|
| `clocks.max.graphics` | **3003** | hardware max — **ignores the lock** |
| `clocks.applications.graphics` | **2418** | factory app clock — **ignores the lock** (and it's *above* our 2200 cap) |
| `clocks.current.graphics` | ~214 | current (idle) — meaningless as evidence |

So the driver **accepts** `-lgc` (no error, friendly confirmation) but does not
reflect it in *any* query field. Consequences:

1. The original `04_audit` check (`clocks.max.graphics <= cap`) was a **guaranteed
   false negative**: 3003 is never <= 2200, so it always said `BROKEN` even when the
   unit ran perfectly. → **Fixed** in `b57afd1`: the audit now treats the
   `oneshot`+`RemainAfterExit` unit being **`active`** as "cap applied" (a oneshot
   is only `active` if its `ExecStart` ran to completion), and optionally prints the
   journal `gpuClkMax` line as proof.
2. We still cannot read "is the clock actually capped right now?" from a query
   field — we can only prove the *command ran*, not that the clock *obeys* it under
   load. That's why `06` (a load test) is the real check.

## What's been verified (both sparks)

- Unit installed, enabled, active (`systemctl is-active` = `active`).
- Journal: `GPU clocks set to "(gpuClkMin 0, gpuClkMax 2200)"` → `All done.` → `Finished`.
- No `clocks.*` field moves when the lock is applied (confirmed spark01 + spark02).

## The one test that settles it — `06_load_test_gpu_clock_cap.sh`

```
bash 06_load_test_gpu_clock_cap.sh          # 30s, cap 2200
DURATION=60 bash 06_load_test_gpu_clock_cap.sh   # longer if the peak looks off
```
What it does: confirms the unit is active → records the idle clock → runs
`stress-ng --gpu` (auto-installs if missing) → polls `clocks.current.graphics`
every 200 ms → reports the **peak**. Verdicts:
- `CAP ENFORCED` (peak <= cap, exit 0) → **we're good.**
- `CAP NOT ENFORCED` (peak > cap, exit 1) → **real problem.**
- `UNKNOWN` (exit 2) → clock unreadable; re-run longer.

Why under load matters: only a loaded GPU reveals its *maximum* operating clock.
Idle (214 MHz) is always below the cap, so it can never confirm enforcement.

## If the load test says "NOT ENFORCED" (next steps)

That would mean `-lgc` is accepted but not enforced on GB10. Options to pursue:
1. **Confirm with a second, independent load tool** (e.g. a PyTorch matmul loop or
   `cublas` busy-burn) to rule out a stress-ng quirk.
2. **Try `-lgc` with a tighter/standard clock** and re-test (some drivers only honor
   specific clock steps).
3. **Power-limit instead of clock-limit:** `nvidia-smi -pl <watts>` lowers the power
   budget, which throttles clocks and — more importantly for thermals — reduces
   heat. This is often the *better* lever for the actual goal (keep the Spark cool)
   and is more likely to be enforced than a clock lock.
4. **Thermal / governor checks:** confirm whether GB10 even exposes a user clock
   governor; on some SoC GPUs the clock is managed by a thermal controller that
   overrides user locks.

Until `06` is run, the honest status is: **persistence is done; enforcement is
unproven.** One 30-second run resolves it.
