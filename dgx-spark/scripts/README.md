# `scripts/` — Remote VM Configuration Scripts

## Purpose

This directory contains **remote VM configuration scripts** — standalone shell scripts designed to be uploaded to and executed on remote VMs, not run locally.

## Separation of Concerns

| Type | Example | Purpose |
|------|---------|---------|
| **Local Wrapper** | `../05_disable_password_auth.sh` | Handles SCP upload, SSH execution, user confirmation |
| **Remote Script** | `disable_passwords.sh` | Runs on the VM, performs actual configuration changes |

## Scripts

### `disable_passwords.sh`

**Purpose:** Hardens SSH by disabling password-based authentication, leaving only public-key login enabled.

**Usage:**
- **Do NOT run directly.** This script is meant to be uploaded and executed by the companion wrapper `../05_disable_password_auth.sh`.
- The wrapper handles SCP upload, SSH execution with sudo, and cleanup.

**What it does on the remote VM:**
1. Verifies `~/.ssh/authorized_keys` is not empty (prevents lockout)
2. Checks if password auth is already disabled
3. Checks for config overrides in `/etc/ssh/sshd_config.d/`
4. Shows current SSH auth-related settings
5. Backs up and modifies `/etc/ssh/sshd_config`
6. Enforces strict permissions (`chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys`)
7. Validates with `sshd -t` and auto-reverts on failure

**Reusability:**
This script is designed to be reused on **any Ubuntu/Debian VM** managed by this project. Simply copy it to the `scripts/` directory of another VM's folder and create a matching `0N_*.sh` local wrapper to upload and execute it.

## Architecture

```
dgx-spark/
├── 05_disable_password_auth.sh   ← Local wrapper (handles SCP/SSH, user confirmation)
└── scripts/
    ├── README.md                 ← You are here
    └── disable_passwords.sh      ← Remote script (runs on the VM)
```

## Naming Convention

- **Local wrappers** are prefixed with `NN_` (e.g., `01_*.sh`, `05_*.sh`) for sequential execution order.
- **Remote scripts** have no prefix — they are named by function (e.g., `disable_passwords.sh`).