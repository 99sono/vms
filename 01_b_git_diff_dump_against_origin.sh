#!/bin/bash
# =============================================================================
# 07_b_git_diff_dump_against_origin.sh
# =============================================================================

OUTPUT_FILE="SQUASH_MESSAGE_HELPER.diff"

echo "📝 Generating diff against origin/master..."

# Generate the diff
git diff origin/master..HEAD > "$OUTPUT_FILE"

echo "✅ Diff saved to: $OUTPUT_FILE"
echo "You can use this file to help generate your squash commit message."
