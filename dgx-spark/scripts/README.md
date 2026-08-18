# `scripts/` & `maintenance/` — Remote-VM Scripts

These directories hold **remote-side scripts** — standalone shell scripts that get
uploaded to a DGX Spark and executed *there* (over SSH), not run locally on your
laptop.

## Separation of concerns

| Type | Lives in | Example | Role |
|------|----------|---------|------|
| **Local wrapper** | `dgx-spark/` | `05_a_disable_password_auth_on_spark01.sh` | Handles SCP upload, `ssh` execution, user confirmation, exit-code handling |
| **Remote script (one-off)** | `dgx-spark/scripts/` | `disable_passwords.sh` | Runs on the VM for a one-time configuration change |
| **Remote script (recurring)** | `dgx-spark/maintenance/` | `01_update_spark.sh` | Runs on the VM for repeatable maintenance (e.g. system updates) |

The local wrapper resolves which Spark to target from its filename (see
`_common.sh`), uploads the matching remote script, and runs it.

## `scripts/`

### `disable_passwords.sh`

**Purpose:** Hardens SSH by disabling password-based authentication, leaving only
public-key login enabled.

**Usage:**
- **Do NOT run directly.** It is uploaded and executed by the companion wrappers
  `../05_a_disable_password_auth_on_spark01.sh` / `../05_b_disable_password_auth_on_spark02.sh`.
- The wrapper handles SCP upload, SSH execution with `sudo`, and post-run cleanup.

**What it does on the remote VM:**
1. Verifies `~/.ssh/authorized_keys` is not empty (prevents lockout)
2. Checks if password auth is already disabled
3. Checks for config overrides in `/etc/ssh/sshd_config.d/`
4. Shows current SSH auth-related settings
5. Backs up and modifies `/etc/ssh/sshd_config`
6. Enforces strict permissions (`chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys`)
7. Validates with `sshd -t` and auto-reverts on failure

**Reusability:**
Designed to run on **any Ubuntu/Debian VM** managed by this project. Copy it into
the `scripts/` directory of another VM's folder and create a matching local wrapper.

## `maintenance/`

Recurring maintenance scripts that live *on* the Spark under `~/scripts/maintenance/`
and persist between runs.

### `01_update_spark.sh`

**Purpose:** Full DGX Spark OS + firmware update per the
[NVIDIA DGX Spark User Guide](https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html):
`apt update → apt dist-upgrade → fwupdmgr refresh → fwupdmgr upgrade → reboot`.

**Usage:**
- **Do NOT run directly.** It is uploaded and executed by
  `../09_a_update_spark01.sh` / `../09_b_update_spark02.sh` (which sync the whole
  `maintenance/` folder first). You can also sync the folder on its own without
  executing, via `../10_a_sync_maintenance_to_spark01.sh` / `../10_b_...`.
- Prompts before starting and before rebooting.

### `02_cap_gpu_clock.sh`

**Purpose:** Thermal control for the GB10. Caps the GPU graphics clock to keep the
package cooler under sustained inference load, with near-zero performance loss
(LLM decode is memory-bandwidth-bound).

**Usage (on the Spark, or over `ssh`):**
- `bash 02_cap_gpu_clock.sh [apply|reset|status] [MHz]`
- `apply` (default): `nvidia-smi -lgc 2200,2200` — caps max graphics clock to
  2200 MHz (default; override with a second arg). Non-persistent.
- `reset`: `nvidia-smi -rgc` — restores factory clocking.
- `status`: shows current + max graphics clocks and driver version.

No systemd unit is created here — persistence is a separate, explicit step (`03`).

### `03_persist_gpu_clock_cap.sh`

**Purpose:** Makes the clock cap from `02` survive reboots by installing the
`systemd/nvidia-clock-cap.service` unit.

**Usage (on the Spark, as root or with `sudo`):**
- `bash 03_persist_gpu_clock_cap.sh [install|uninstall|status] [MHz]`
- `install` (default): copies the unit to `/etc/systemd/system/`, enables +
  starts it (applies the cap immediately). Idempotent — re-running with a new
  MHz updates the `ExecStart` and reloads.
- `uninstall`: stops, disables, and removes the unit.
- `status`: reports whether the unit is installed / enabled / active.

### `04_audit_gpu_clock_cap.sh`

**Purpose:** Verifies the persistence setup is healthy and the cap is applied.
Safe to run anytime (no changes made). Works with or without passwordless sudo.

**Usage (on the Spark, or over `ssh`):**
- `bash 04_audit_gpu_clock_cap.sh`   (optionally `MAX_CLOCK=<mhz>` to audit a custom cap)
- Checks: unit present → enabled → **active** (active ⇒ the `-lgc` ran at boot) →
  cap in effect. Prints the current graphics clock (reference) and, if passwordless
  sudo is available, the most recent `gpuClkMax` journal line as proof.
- Exit codes: `0` = GOOD (in effect + persistent), `1` = BROKEN/PARTIAL (cap not
  applied, or persistence incomplete), `2` = live but not persistent.

> **GB10 note:** there is *no* `nvidia-smi` query field that reads back the `-lgc`
> lock (`clocks.max.graphics` shows the hardware max, e.g. 3003). The audit
> therefore treats **`service active`** as the "cap in effect" signal — a
> `oneshot`+`RemainAfterExit` unit is only `active` if its `ExecStart` completed.

### `05_diagnose_gpu_clock_cap.sh`

**Purpose:** One-off diagnostic (not part of normal operation). Dumps many clock
fields in three states (current / unlocked via `-rgc` / locked via `-lgc`) plus the
full `nvidia-smi -q -d CLOCK` section and the unit journal, to confirm which field
(if any) reflects the lock on a given driver. **Ends with the cap applied.**

**Usage (on the Spark):**
- `bash 05_diagnose_gpu_clock_cap.sh [MHz]`   (asks for sudo at the first toggle)

### `systemd/nvidia-clock-cap.service`

**Purpose:** Static `Oneshot` systemd unit that applies the clock cap at boot.
Installed by `03` — **do not edit by hand on the Spark**; edit it here, re-sync
with `../10_*`, and re-run `03 install`.

## Architecture

```
dgx-spark/
├── 05_a_disable_password_auth_on_spark01.sh  ← local wrapper (SCP/SSH, confirmation)
├── 09_a_update_spark01.sh                    ← local wrapper (syncs maintenance/ + runs 01)
├── 10_a_sync_maintenance_to_spark01.sh       ← local wrapper (syncs maintenance/, no execution)
├── _common.sh                                ← resolves Spark + provides upload_maintenance_dir()
├── scripts/
│   ├── README.md                   ← you are here
│   └── disable_passwords.sh        ← remote, one-off (runs on the VM)
└── maintenance/
    ├── 01_update_spark.sh          ← remote, recurring (full OS + firmware update)
    ├── 02_cap_gpu_clock.sh         ← remote, recurring (thermal clock cap)
    ├── 03_persist_gpu_clock_cap.sh ← remote, recurring (install/uninstall systemd unit)
    ├── 04_audit_gpu_clock_cap.sh    ← remote, recurring (verify persistence + cap applied)
    ├── 05_diagnose_gpu_clock_cap.sh ← remote, one-off (dump clock data; ends capped)
    └── systemd/
        └── nvidia-clock-cap.service ← static unit, copied by 03
```

## Naming conventions

- **Local wrappers** are numbered `NN_` and come in **A/B pairs** — `_a_` targets
  spark01, `_b_` targets spark02 (e.g. `09_a_update_spark01.sh`).
- Each wrapper sources `_common.sh` (host resolution) and a shared `_NN_*.sh` module
  holding the actual SCP/SSH logic.
- **Remote scripts** have no number in `scripts/` (named by function), but use a
  `NN_` prefix in `maintenance/` to order recurring maintenance steps.