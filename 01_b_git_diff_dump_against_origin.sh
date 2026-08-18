#!/bin/bash
# =============================================================================
# 01_b_git_diff_dump_against_origin.sh
# =============================================================================
# Dumps the full diff between origin/master and the current branch to a file.
# Feed that file to an AI assistant to auto-generate a well-structured merge
# request description (or a squash commit message) summarizing the changes.

OUTPUT_FILE="SQUASH_MESSAGE_HELPER.diff"

echo "📝 Generating diff against origin/master..."

# Generate the diff
git diff origin/master..HEAD > "$OUTPUT_FILE"

echo "✅ Diff saved to: $OUTPUT_FILE"
echo "Tip: feed $OUTPUT_FILE to an AI assistant to draft your MR description."
