#!/bin/bash
set -euo pipefail
# ==============================================================================
# Template for environment variables for DGX Spark.
# ==============================================================================
# USAGE: Copy this file to 00_env_setup_private.sh and fill in your actual details.
# This file serves as a blueprint and can be safely committed to source control.

# Hostnames/IPs for each Spark node.
export SPARK01_HOST="spark01-hostname.local"
export SPARK02_HOST="spark02-hostname.local"

# Your username on the DGX Spark VMs.
export SPARK_USER="your-username"

# Path to your local SSH private key.
# Relative paths starting with '~' are supported.
# Example: ~/.ssh/id_rsa
export SSH_KEY_PATH="~/.ssh/id_rsa"

# Path to the private SSH key to upload.
# The public key (private_key_path.pub) will also be uploaded automatically.
# Example: ~/.ssh/id_rsa or ~/.ssh/id_ed25519
export UPLOAD_PRIVATE_KEY_PATH="~/.ssh/your_private_key_filename"
