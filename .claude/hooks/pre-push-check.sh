#!/usr/bin/env bash
# pre-push-check.sh — PreToolUse hook for Bash
#
# Trigger: PreToolUse (Bash — filters to `git push` commands only)
#
# Two gates:
#
#   1. Branch guard: pushing code changes directly to main is blocked.
#      Code must go through a branch + PR. Docs/config pushes to main
#      are allowed.
#
#   2. Test sentinel: any push that touches source directories listed in
#      PRODUCTION_DIRS requires a passing test run within the last 30 min.
#      The test script writes a sentinel file to .claude/.last_test when done.
#
# Customize:
#   - PRODUCTION_DIRS: directories that require a test run before push
#   - SENTINEL_FILE: path to the file your test script writes on success
#   - TEST_COMMAND: the command users should run (shown in error messages)

set -euo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | python3 -c '
import json
import sys

try:
    payload = json.loads(sys.stdin.read() or "{}")
except json.JSONDecodeError:
    payload = {}

tool_input = payload.get("tool_input", {}) if isinstance(payload, dict) else {}
command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
print(command)
')

emit_block() {
  python3 -c 'import json, sys; print(json.dumps({"decision": "block", "reason": sys.argv[1]}))' "$1"
}

# Only check git push commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+push|&&\s*git\s+push|\|\|\s*git\s+push'; then
  exit 0
fi

# ── Configuration ────────────────────────────────────────────────────────────
# Directories that contain production code. Pushes touching these require tests.
PRODUCTION_DIRS="src/ app/ lib/"   # customize for your project

# Sentinel file your test script writes when tests pass
SENTINEL_FILE="$CLAUDE_PROJECT_DIR/.claude/.last_test"

# Command users should run to pass the test gate
TEST_COMMAND="npm test"            # customize for your project

# ── Gate 1: branch guard ─────────────────────────────────────────────────────
PUSHING_TO_MAIN=0
if echo "$COMMAND" | grep -qE '\borigin\s+main\b|\borigin/main\b|main\s*$'; then
  PUSHING_TO_MAIN=1
fi

if [ "$PUSHING_TO_MAIN" -eq 1 ]; then
  CHANGED=$(git diff --name-only origin/main...HEAD 2>/dev/null || echo "")

  HAS_CODE=0
  for dir in $PRODUCTION_DIRS; do
    if echo "$CHANGED" | grep -qE "^${dir}"; then
      HAS_CODE=1
      break
    fi
  done

  if [ "$HAS_CODE" -eq 1 ]; then
    emit_block "Direct pushes to main are blocked for code changes. Use a branch + PR instead:

  git checkout -b feat/<short-desc>
  git push origin feat/<short-desc>

Docs and config-only changes may push to main directly."
    exit 0
  fi
fi

# ── Gate 2: test sentinel ────────────────────────────────────────────────────
CHANGED=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "unknown")
MAX_AGE=1800  # 30 minutes

NEEDS_TESTS=0
if [ "$CHANGED" = "unknown" ]; then
  NEEDS_TESTS=1
else
  for dir in $PRODUCTION_DIRS; do
    if echo "$CHANGED" | grep -qE "^${dir}"; then
      NEEDS_TESTS=1
      break
    fi
  done
fi

if [ "$NEEDS_TESTS" -eq 0 ]; then
  exit 0
fi

check_sentinel() {
  local sentinel="$1"
  [ -f "$sentinel" ] || return 1
  if [ "$(uname)" = "Darwin" ]; then
    local age=$(( $(date +%s) - $(stat -f %m "$sentinel") ))
  else
    local age=$(( $(date +%s) - $(stat -c %Y "$sentinel") ))
  fi
  [ "$age" -lt "$MAX_AGE" ]
}

if ! check_sentinel "$SENTINEL_FILE"; then
  emit_block "Run tests before pushing. Required: $TEST_COMMAND
(No passing test run in the last 30 minutes.)"
fi
