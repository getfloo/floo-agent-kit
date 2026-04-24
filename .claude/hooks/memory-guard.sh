#!/usr/bin/env bash
# memory-guard.sh — SessionStart hook.
#
# This kit uses a three-layer context system (CLAUDE.md + skills + KB). The
# Claude Code harness "auto memory" directory is deliberately NOT a fourth
# layer — it duplicates content and is invisible to humans + other agents.
#
# If new files appear in that memory directory since the last migration,
# print a warning so the agent migrates them into the right layer (KB,
# skill, or CLAUDE.md) and deletes them before continuing.
#
# The harness stores auto-memory at:
#   ~/.claude/projects/<slug>/memory/
# where <slug> is the absolute project path with "/" replaced by "-".
#
# This hook derives the slug from $CLAUDE_PROJECT_DIR at runtime so it
# works on any machine without hardcoding a path.

set -u

if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  exit 0
fi

# Slug = absolute project path with each "/" replaced by "-", e.g.
# /Users/you/Projects/myrepo → -Users-you-Projects-myrepo
SLUG=$(printf '%s' "$CLAUDE_PROJECT_DIR" | sed 's|/|-|g')
MEMORY_DIR="${HOME}/.claude/projects/${SLUG}/memory"

if [ ! -d "${MEMORY_DIR}" ]; then
    exit 0
fi

# Only MEMORY.md (the stub) is allowed in this directory.
stray=$(find "${MEMORY_DIR}" -maxdepth 1 -type f ! -name 'MEMORY.md' 2>/dev/null)

if [ -n "${stray}" ]; then
    cat <<EOF
## ⚠️  Memory directory drift detected

The following files exist in the auto-memory directory but should NOT:

${stray}

This repo does not use auto memory. Translate each file into the right layer and delete it:
  - Ethos / collaboration rule    → CLAUDE.md
  - Tool / domain behavior rule   → .claude/skills/<name>/SKILL.md
  - Factual truth about the repo  → docs/knowledge/...

Then delete the file from ${MEMORY_DIR}.
EOF
fi

exit 0
