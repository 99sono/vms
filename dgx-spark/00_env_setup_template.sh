#!/bin/bash
set -euo pipefail
# ==============================================================================
# Template for environment variables for DGX Spark.
# ==============================================================================
# USAGE: Copy this file to 00_env_setup_private.sh and fill in your actual details.
# This file serves as a blueprint and can be safely committed to source control.

# The hostname or IP address of the DGX Spark VM.
# Example: hostname.local
export SPARK_HOST="spark-hostname.local"

# Your username on the DGX Spark VM.
# Example: johndoe
export SPARK_USER="your-username"

# Path to your local SSH private key.
# Relative paths starting with '~' are supported.
# Example: ~/.ssh/id_rsa
export SSH_KEY_PATH="~/.ssh/id_rsa"

# Path to the private SSH key to upload.
# The public key (private_key_path.pub) will also be uploaded automatically.
# Example: ~/.ssh/id_rsa or ~/.ssh/id_ed25519
export UPLOAD_PRIVATE_KEY_PATH="~/.ssh/your_private_key_filename"
