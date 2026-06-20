#!/bin/bash
# ==============================================================================
# Shared SSH implementation — sourced by 01_a_* and 01_b_*.
# ==============================================================================
echo "Connecting to $SPARK_USER@$SPARK_HOST using key $EXPANDED_KEY_PATH..."
ssh -i "$EXPANDED_KEY_PATH" "$SPARK_USER@$SPARK_HOST"
