#!/usr/bin/env bash
# branch-guard.sh — PreToolUse hook for Write|Edit|MultiEdit
#
# Blocks writes to production code files outside a git worktree. Enforces
# that all production code changes happen on a feature branch, not directly
# on the default branch.
#
# "Production code" = files that is_code_file() classifies as reviewable
# (anything non-exempt — see .claude/lib/repo-state.sh).
#
# Exempt paths (.claude/, docs/, *.md, lockfiles, configs) can still be
# written directly on the main workspace — those are the "direct commit"
# path per the typical agent workflow.
#
# The worktree check is path-based: any file_path containing
# /.claude/worktrees/ is inside a worktree and therefore on a feature
# branch. No branch-name lookup needed.
#
# Why this exists: without it, an agent will happily edit production code
# directly on main during an autonomous session. That bypasses the PR
# review flow and leaves no audit trail. The worktree convention forces
# every code change onto a reviewable branch.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  # jq is required. Fail open — block nothing — rather than deadlock.
  exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# No file path in the tool call — nothing to gate.
if [ -z "$FILE" ]; then
  exit 0
fi

# Files inside a worktree are always on a feature branch. Allow them.
if echo "$FILE" | grep -qF "/.claude/worktrees/"; then
  exit 0
fi

# Load the canonical is_code_file() helper. Fail open if missing.
LIB="$CLAUDE_PROJECT_DIR/.claude/lib/repo-state.sh"
if [ ! -f "$LIB" ]; then
  exit 0
fi
# shellcheck source=../lib/repo-state.sh
. "$LIB"

# Compute the path relative to the repo root so is_code_file() can
# match against patterns like "routes/foo.py".
REL_PATH=$(python3 -c "
import os, sys
try:
    rel = os.path.relpath(sys.argv[1], sys.argv[2])
    print(rel)
except Exception:
    print(sys.argv[1])
" "$FILE" "$CLAUDE_PROJECT_DIR" 2>/dev/null || echo "$FILE")

# A relative path starting with ".." is outside this repo — let it through.
case "$REL_PATH" in
  ..*) exit 0 ;;
esac

if is_code_file "$REL_PATH"; then
  jq -cn --arg file "$REL_PATH" '{
    "decision": "block",
    "reason": (
      "branch-guard: production code cannot be written directly in the main workspace.\n\n" +
      "Create a worktree first, then make your changes there:\n\n" +
      "  git worktree add .claude/worktrees/<name> -b feat/<name>\n\n" +
      "Why: all production code must live on a feature branch so the Stop hook\n" +
      "can enforce review before the turn ends. Worktrees guarantee this.\n\n" +
      "Exempt (can edit on main): .claude/, docs/, *.md, lockfiles, configs.\n\n" +
      "Blocked file: " + $file
    )
  }'
fi
