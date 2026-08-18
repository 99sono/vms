# VMs Tracker

This repository is used to keep track of Virtual Machines (VMs), providing a central location for connection scripts and environment configurations.

## Structure

- `dgx-spark/`: Scripts and templates for the DGX Spark VMs (spark01 / spark02).
  - `00_env_setup_template.sh`: Template for environment variables (host, user, SSH key path).
  - `00_env_setup_private.sh`: Private file (ignored by Git) containing actual credentials.
  - `01_a_ssh_to_dgx_spark01.sh` / `01_b_ssh_to_dgx_spark02.sh`: Open an interactive SSH session.
  - `02_a_upload_ssh_key_to_spark01.sh` / `02_b_...`: Upload your SSH public key for passwordless login.
  - `03_a_upload_to_spark01.sh` / `03_b_...`: Upload a local file or directory to the VM.
  - `04_a_download_from_spark01.sh` / `04_b_...`: Download a file or directory from the VM.
  - `05_a_disable_password_auth_on_spark01.sh` / `05_b_...`: Harden SSH (disable password auth).
  - `06_a_upload_gitconfig_to_spark01.sh` / `06_b_...`: Upload your `.gitconfig`.
  - `07_a_upload_ssh_keys_to_spark01.sh` / `07_b_...`: Upload additional SSH key pairs.
  - `08_a_download_cert_from_spark01.sh` / `08_b_...`: Download the nginx self-signed cert.
  - `09_a_update_spark01.sh` / `09_b_update_spark02.sh`: Full OS + firmware update (see below).
  - `10_a_sync_maintenance_to_spark01.sh` / `10_b_...`: Sync the whole `maintenance/` folder to the Spark (upload only, no execution).
  - `maintenance/`: Remote-side scripts that get uploaded to the Spark and executed there.
    - `01_update_spark.sh`: The full DGX Spark update sequence (apt + firmware + reboot).
    - `02_cap_gpu_clock.sh`: Cap/reset/status the GPU graphics clock for thermal control (see below).
    - `03_persist_gpu_clock_cap.sh`: Install/remove the systemd unit so the clock cap survives reboots.
    - `04_audit_gpu_clock_cap.sh`: Verify the unit is installed/enabled/active and the cap is applied.
    - `05_diagnose_gpu_clock_cap.sh`: One-off diagnostic that dumps clock data to confirm the lock (ends with the cap applied).
    - `systemd/nvidia-clock-cap.service`: Static unit copied by `03` (never hand-edited with `nano`).

### Naming convention

Every user-facing script comes in **A/B pairs**:

| Suffix | Target  |
|--------|---------|
| `_a_`  | spark01 |
| `_b_`  | spark02 |

Each wrapper sources `_common.sh` (which resolves the target host from the filename)
and a shared `_NN_*.sh` module that contains the actual logic.
Remote scripts that run **on** the Spark live in `dgx-spark/scripts/` (one-off)
or `dgx-spark/maintenance/` (recurring maintenance).

## Setup

1. Copy `00_env_setup_template.sh` in `dgx-spark/` to `00_env_setup_private.sh`.
2. Fill in the actual hostnames, username, and SSH key path.
3. Use the numbered scripts in order for initial setup:
   - **Step 1**: `./01_a_ssh_to_dgx_spark01.sh` — Connect for the first time.
   - **Step 2**: `./02_a_upload_ssh_key_to_spark01.sh` — Upload your SSH key.
   - **Steps 3–4**: Use `03` / `04` to transfer files as needed.
   - **Step 5**: `./05_a_disable_password_auth_on_spark01.sh` — Harden SSH.

### Updating a Spark (OS + firmware)

```bash
cd dgx-spark
./09_a_update_spark01.sh   # for spark01
# or
./09_b_update_spark02.sh   # for spark02
```

This uploads `maintenance/01_update_spark.sh` to `~/scripts/maintenance/` on the
target Spark, then runs it via `ssh -t` with `sudo`. The sequence (per the
[NVIDIA DGX Spark User Guide](https://docs.nvidia.com/dgx/dgx-spark/os-and-component-update.html)):

```
sudo apt update
sudo apt dist-upgrade      # required: GPU driver is baked into the NVIDIA kernel
sudo fwupdmgr refresh
sudo fwupdmgr upgrade
sudo reboot                # prompts for confirmation
```

`dist-upgrade` (not plain `upgrade`) is required because the DGX Spark's GPU driver
modules are compiled into the custom kernel and must be upgraded atomically.
The script prompts before executing and before rebooting. After the reboot your
SSH session drops (expected) — reconnect in ~2–5 minutes.

### Syncing maintenance scripts

```bash
cd dgx-spark
./10_a_sync_maintenance_to_spark01.sh   # for spark01
# or
./10_b_sync_maintenance_to_spark02.sh   # for spark02
```

Uploads the **entire** `maintenance/` folder to `~/scripts/maintenance/` on the
target Spark. This is upload-only — it does not run anything. (Running `09_*` to
update a Spark also syncs the folder first, so `09` and `10` never drift apart.)
After syncing, run what you need over SSH, e.g.:

```bash
ssh sono99@spark01 'bash ~/scripts/maintenance/02_cap_gpu_clock.sh status'
```

### GPU thermal control (clock cap)

The DGX Spark (GB10) shares one thermal budget between CPU and GPU. Under
sustained inference load it can spike past 96°C and hard power-off. Capping the
GPU graphics clock at 2200 MHz (from the ~2455 MHz peak) cuts package power by
>30% and cools the chip ~6–10°C, with essentially no loss of tokens/second
(LLM decode is memory-bandwidth-bound, not compute-bound).

```bash
# 1. Upload the maintenance folder to the Spark (once)
./10_a_sync_maintenance_to_spark01.sh

# 2. On the Spark (or over ssh):
bash ~/scripts/maintenance/02_cap_gpu_clock.sh apply      # cap now (non-persistent)
bash ~/scripts/maintenance/02_cap_gpu_clock.sh status     # check current clocks
bash ~/scripts/maintenance/02_cap_gpu_clock.sh reset      # back to factory clocking

# 3. Make the cap survive reboots (installs the systemd unit):
bash ~/scripts/maintenance/03_persist_gpu_clock_cap.sh install

# 4. Verify unit is installed + enabled + active and the cap is in effect:
bash ~/scripts/maintenance/04_audit_gpu_clock_cap.sh
```

See `maintenance/02_cap_gpu_clock.sh` for the full rationale and references.

