#!/bin/bash
# =============================================================================
# 01_a_git_number_of_commits_ahead.sh
# =============================================================================
# Prints how many commits the current branch is ahead of origin/master.
# Use the number it prints to squash commits with:
#     git rebase -i HEAD~<N>

# Get the count of commits ahead of origin/master
COUNT=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo "0")

echo "📊 You are currently ahead of origin/master by: $COUNT commit(s)"

if [ "$COUNT" -gt 0 ]; then
    echo ""
    echo "To squash these commits, run:"
    echo "    git rebase -i HEAD~$COUNT"
else
    echo "✅ Your branch is up-to-date with origin/master."
fi
