#!/usr/bin/env bash
# pre-pr-check.sh — PreToolUse hook for Bash.
#
# Heavy-review gate at PR creation.
#
# When the agent runs `gh pr create`, we check the branch diff against the
# repo's base branch (default: origin/main). If any changed file is in the
# `sensitive` tier — routes, models, schemas, migrations, auth, middleware,
# SQL, etc. — a `.heavy` sentinel must exist for this exact diff. The
# sentinel is written by `./mark_reviewed.sh --tier heavy` after the agent
# has run its adversarial code reviewer + silent-failure auditor subagents
# on the full branch diff.
#
# Why here and not at every Stop: stop-review-check.sh gates on a
# self-review sentinel only (a frontier agent catches most issues in the
# diff it just wrote). Heavy subagent review is reserved for the moment
# we're about to ship a durable contract change to main.
#
# Standard-tier diffs (typical product code with no sensitive paths) are
# NOT gated here — the self-review sentinel from the Stop hook is the
# only gate. Exempt-tier diffs (docs/copy/config only) have no gate at
# any stage.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0  # if jq is unavailable, fall through silently rather than deadlock
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only trigger on `gh pr create` invocations.
if ! echo "$COMMAND" | grep -qE '(^|[[:space:]&|;])gh[[:space:]]+pr[[:space:]]+create\b'; then
  exit 0
fi

# shellcheck source=../lib/repo-state.sh
. "$CLAUDE_PROJECT_DIR/.claude/lib/repo-state.sh"

REPO="$CLAUDE_PROJECT_DIR"
REPO_KEY="$(basename "$REPO")"

# Figure out the base ref. Most PRs target origin/main; fall back gracefully
# if the remote hasn't been fetched (best effort).
BASE_REF="origin/main"
git -C "$REPO" fetch origin main --quiet 2>/dev/null || true
if ! git -C "$REPO" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="main"
  if ! git -C "$REPO" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    exit 0  # can't determine base; let the push happen rather than false-block
  fi
fi

# Compute the branch diff tier: any sensitive file in the full branch-vs-base
# file list promotes the whole PR to "sensitive."
TIER="exempt"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  t=$(classify_path "$f")
  case "$t" in
    sensitive) TIER="sensitive"; break ;;
    standard) [ "$TIER" = "exempt" ] && TIER="standard" ;;
  esac
done < <(git -C "$REPO" diff "$BASE_REF"...HEAD --name-only 2>/dev/null)

if [ "$TIER" != "sensitive" ]; then
  exit 0  # heavy review not required for standard or exempt PRs
fi

# Sensitive PR — demand a .heavy sentinel whose hash matches the current
# working-tree reviewable state. This is intentionally the working-tree
# hash (not the committed branch diff) to stay consistent with the rest
# of the review-sentinel machinery; the agent should run mark_reviewed
# after the final commit but before `gh pr create`, while the working
# tree is clean and HEAD == the PR head.
REVIEW_DIR="$REPO/.claude/.review"
SENTINEL="$REVIEW_DIR/$REPO_KEY.heavy"

DIFF_CONTENT=$(compute_repo_state "$REPO" 2>/dev/null || echo "")
CURRENT_HASH=$(printf "%s" "$DIFF_CONTENT" | git hash-object --stdin 2>/dev/null || echo "")

if [ ! -f "$SENTINEL" ]; then
  REASON="PR touches sensitive-tier files (routes, models, schemas, migrations, auth, middleware) and requires heavy review before \`gh pr create\`.\n\nLaunch your subagent review pair in parallel via the Agent tool:\n  1. Adversarial code reviewer — skeptic posture, looks for reasons to block\n  2. Silent-failure auditor — looks for swallowed errors, inappropriate fallbacks\n\nAddress all findings. Re-run tests. Then record the attestation:\n\n  ./mark_reviewed.sh --tier heavy\n\nOnce the sentinel matches the current diff, re-run \`gh pr create\`.\n\nIf this PR is genuinely not sensitive (the classifier mis-tiered it), extend classify_path() in .claude/lib/repo-state.sh — do NOT write the sentinel without running review."
  jq -cn --arg reason "$(printf "%b" "$REASON")" '{"decision":"block","reason":$reason}'
  exit 0
fi

RECORDED_HASH=$(cat "$SENTINEL" 2>/dev/null || echo "")
if [ "$RECORDED_HASH" != "$CURRENT_HASH" ]; then
  REASON="PR touches sensitive-tier files and the heavy-review sentinel is stale — the diff has changed since the last review pass.\n\nRe-run heavy review on the current diff:\n  1. Adversarial code reviewer\n  2. Silent-failure auditor\n\nAddress findings, re-run tests, then:\n\n  ./mark_reviewed.sh --tier heavy\n\nRecorded hash: $RECORDED_HASH\nCurrent hash:  $CURRENT_HASH"
  jq -cn --arg reason "$(printf "%b" "$REASON")" '{"decision":"block","reason":$reason}'
  exit 0
fi

exit 0
