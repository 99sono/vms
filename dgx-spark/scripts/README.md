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
  `../09_a_update_spark01.sh` / `../09_b_update_spark02.sh`.
- Prompts before starting and before rebooting.

## Architecture

```
dgx-spark/
├── 05_a_disable_password_auth_on_spark01.sh  ← local wrapper (SCP/SSH, confirmation)
├── 09_a_update_spark01.sh                    ← local wrapper (SCP/SSH, confirmation)
├── _common.sh                                ← resolves target Spark from filename
├── scripts/
│   ├── README.md                 ← you are here
│   └── disable_passwords.sh      ← remote, one-off (runs on the VM)
└── maintenance/
    └── 01_update_spark.sh        ← remote, recurring (runs on the VM)
```

## Naming conventions

- **Local wrappers** are numbered `NN_` and come in **A/B pairs** — `_a_` targets
  spark01, `_b_` targets spark02 (e.g. `09_a_update_spark01.sh`).
- Each wrapper sources `_common.sh` (host resolution) and a shared `_NN_*.sh` module
  holding the actual SCP/SSH logic.
- **Remote scripts** have no number in `scripts/` (named by function), but use a
  `NN_` prefix in `maintenance/` to order recurring maintenance steps.