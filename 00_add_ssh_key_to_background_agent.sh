#!/bin/bash
# Script to start SSH agent and add key persistently

# Start SSH agent and save environment variables to a file
ssh-agent -s > ~/.ssh/agent-env

# Source the environment variables to make them available in the script
source ~/.ssh/agent-env

# Add the SSH key
ssh-add ~/.ssh/id_ed25519 2>/dev/null

echo "SSH agent started and key added. To use the agent in your shell, run:"
echo "source ~/.ssh/agent-env"
