# VMs Tracker

This repository is used to keep track of Virtual Machines (VMs), providing a central location for connection scripts and environment configurations.

## Structure

- `dgx-spark/`: Scripts and templates for the DGX Spark VM.
  - `00_env_setup_template.sh`: Template for environment variables (host, user, SSH key path).
  - `00_env_setup_private.sh`: Private file (ignored by Git) containing actual credentials.
  - `01_ssh_to_dgx_spark.sh`: Opens an interactive SSH session to the DGX Spark VM.
  - `02_upload_ssh_key.sh`: Uploads your SSH public key to the VM for passwordless login.
  - `03_upload_to_spark.sh`: Uploads a local file or directory to the VM's Downloads folder.
  - `04_download_from_spark.sh`: Downloads a file or directory from the VM to your local machine.

## Setup

1. Copy the `00_env_setup_template.sh` in the `dgx-spark/` folder to `00_env_setup_private.sh`.
2. Fill in the actual hostname, username, and SSH key path in `00_env_setup_private.sh`.
3. Use the numbered scripts in order:
   - **Step 1**: `./01_ssh_to_dgx_spark.sh` — Connect to the VM for the first time.
   - **Step 2**: `./02_upload_ssh_key.sh` — Upload your SSH public key for passwordless login.
   - **Steps 3–4**: Use `03` and `04` to transfer files to/from the VM as needed.
