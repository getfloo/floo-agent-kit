#!/usr/bin/env bash
# stop-review-check.sh — Stop hook.
#
# Gates turn-end on a SELF-REVIEW sentinel. The main agent attests it read
# the diff, ran the compiler/tests, and confirmed the change is coherent.
#
# Why a sentinel rather than "just run the checks": the harness has no way to
# know whether the agent actually looked at its own diff. A sentinel file
# keyed by the diff hash makes the attestation explicit and tamper-evident:
# if the diff changes, the sentinel goes stale and the agent has to re-attest.
#
# What this hook does NOT demand:
#
#   - Heavy subagent review — that's handled by pre-pr-check.sh, which
#     fires on `gh pr create` for branches that touch sensitive paths.
#
# A frontier agent is strong enough that a checklist self-attest catches most
# issues during a session; heavy review is valuable only at PR boundaries.
# The old "run every reviewer on every stop" gate was burning tokens and
# flow for diffs that didn't need it.
#
# Sentinel layout: $CLAUDE_PROJECT_DIR/.claude/.review/<repo-key>.self
# Contents: hash of the reviewable state at the time the agent ran
# `./mark_reviewed.sh` (default = self tier).
#
# Exempt diffs (docs/, .claude/, lockfiles, YAML, MDX) don't require any
# sentinel — see .claude/lib/repo-state.sh for the classifier.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"decision":"block","reason":"stop-review-check.sh requires jq. Install jq (brew install jq / apt install jq) or disable this hook in .claude/settings.json."}'
  exit 0
fi

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

REVIEW_DIR="$CLAUDE_PROJECT_DIR/.claude/.review"
mkdir -p "$REVIEW_DIR"

# shellcheck source=../lib/repo-state.sh
. "$CLAUDE_PROJECT_DIR/.claude/lib/repo-state.sh"

# Check a single repo. Appends to BLOCKED_REPOS if self-review sentinel is
# missing or stale for a non-exempt diff.
check_repo() {
  local repo_path="$1"
  local repo_key="$2"

  if ! is_git_repo "$repo_path"; then
    return 0
  fi

  local tier
  tier=$(max_tier_for_repo "$repo_path")
  if [ "$tier" = "exempt" ]; then
    return 0  # docs-only / config-only — no gate
  fi

  local diff
  diff=$(compute_repo_state "$repo_path" 2>/dev/null || echo "")
  if [ -z "$diff" ]; then
    return 0
  fi

  local current_hash
  current_hash=$(printf "%s" "$diff" | git hash-object --stdin 2>/dev/null || echo "")
  local sentinel="$REVIEW_DIR/$repo_key.self"

  if [ ! -f "$sentinel" ]; then
    BLOCKED_REPOS="${BLOCKED_REPOS}${repo_path}|${tier}|missing\n"
    return 1
  fi

  local recorded_hash
  recorded_hash=$(cat "$sentinel" 2>/dev/null || echo "")
  if [ "$recorded_hash" != "$current_hash" ]; then
    BLOCKED_REPOS="${BLOCKED_REPOS}${repo_path}|${tier}|stale\n"
    return 1
  fi

  return 0
}

BLOCKED_REPOS=""

check_repo "$CLAUDE_PROJECT_DIR" "$(basename "$CLAUDE_PROJECT_DIR")" || true

if [ -z "$BLOCKED_REPOS" ]; then
  exit 0
fi

REASON="Code changes are unreviewed. Run a self-review pass before ending the turn:\n\n  1. Read your diff (git diff).\n  2. Confirm the change is coherent — no dead code, no half-finished work, names are good.\n  3. Confirm tests + lint all pass.\n  4. Confirm it matches your project conventions (see CLAUDE.md).\n  5. Run \`./mark_reviewed.sh\` to record the attestation.\n\nDirty repos without a self-review sentinel:\n"
REASON="${REASON}$(printf "%b" "$BLOCKED_REPOS" | awk -F'|' 'NF==3 {printf "  - %s [tier: %s, sentinel: %s]\n", $1, $2, $3}')"
REASON="${REASON}\n\nHeavy review (adversarial code reviewer + silent-failure auditor subagents) is not required on every turn. It runs at PR creation for sensitive-tier diffs (routes, models, schemas, migrations, auth). See pre-pr-check.sh.\n\nIf the diff is genuinely docs-only or config-only, extend classify_path() in .claude/lib/repo-state.sh — do NOT delete the sentinel file."

jq -cn --arg reason "$(printf "%b" "$REASON")" '{
  "decision": "block",
  "reason": $reason
}'
