#!/usr/bin/env bash
# Mark a repo's current diff as reviewed.
#
# Two tiers, two sentinel files:
#
#   --tier self   (default) → .claude/.review/<repo-key>.self
#     Main-agent self-attestation. Agent read the diff, ran tests/lint,
#     confirmed the change is coherent and matches your conventions.
#     Clears the Stop hook gate so the turn can end.
#
#   --tier heavy           → .claude/.review/<repo-key>.heavy
#     Subagent review complete on the current diff: your adversarial code
#     reviewer and silent-failure auditor both ran against this exact state
#     and all findings were addressed. Clears pre-pr-check.sh at `gh pr
#     create` time for sensitive-tier diffs (routes, models, schemas,
#     migrations, auth, etc.).
#
# Both sentinels store the same content-addressable hash of the reviewable
# files, computed via compute_repo_state() in .claude/lib/repo-state.sh —
# the tier flag only picks which file to write. Writing `--tier heavy`
# also writes the `.self` sentinel (heavy implies self-reviewed).
#
# Usage:
#   ./mark_reviewed.sh                              # self, this repo
#   ./mark_reviewed.sh --tier heavy                 # heavy, this repo
#   ./mark_reviewed.sh --repo ../other-repo         # self, different repo
#   ./mark_reviewed.sh --tier heavy --repo ../repo  # heavy, different repo
#   ./mark_reviewed.sh ../other-repo                # shorthand (self)
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET_REPO="$PROJECT_ROOT"
TIER="self"

while [ $# -gt 0 ]; do
  case "$1" in
    --tier)
      if [ -z "${2:-}" ]; then
        echo "error: --tier requires a value (self|heavy)" >&2
        exit 2
      fi
      TIER="$2"
      shift 2
      ;;
    --repo)
      if [ -z "${2:-}" ]; then
        echo "error: --repo requires a path" >&2
        exit 2
      fi
      TARGET_REPO="$(cd "$2" && pwd)"
      shift 2
      ;;
    -*)
      echo "error: unknown flag $1" >&2
      exit 2
      ;;
    *)
      TARGET_REPO="$(cd "$1" && pwd)"
      shift
      ;;
  esac
done

if [ "$TIER" != "self" ] && [ "$TIER" != "heavy" ]; then
  echo "error: --tier must be self or heavy (got: $TIER)" >&2
  exit 2
fi

# shellcheck source=.claude/lib/repo-state.sh
. "$PROJECT_ROOT/.claude/lib/repo-state.sh"

if ! is_git_repo "$TARGET_REPO"; then
  echo "error: $TARGET_REPO is not a git repository" >&2
  exit 2
fi

REVIEW_DIR="$PROJECT_ROOT/.claude/.review"
mkdir -p "$REVIEW_DIR"

# Must match the hash shape used by stop-review-check.sh and pre-pr-check.sh:
# capture-then-printf strips trailing newlines; a direct pipe would keep them
# and produce a divergent SHA that the hooks would never match.
DIFF_CONTENT=$(compute_repo_state "$TARGET_REPO" 2>/dev/null || echo "")
DIFF_HASH=$(printf "%s" "$DIFF_CONTENT" | git hash-object --stdin)
REPO_KEY="$(basename "$TARGET_REPO")"

echo "$DIFF_HASH" > "$REVIEW_DIR/$REPO_KEY.$TIER"

# Heavy implies self: a subagent-reviewed diff is also self-reviewed, so
# writing only `.heavy` would leave the Stop hook gate blocked on `.self`.
if [ "$TIER" = "heavy" ]; then
  echo "$DIFF_HASH" > "$REVIEW_DIR/$REPO_KEY.self"
fi

case "$TIER" in
  self)
    echo "✓ Marked $REPO_KEY diff $DIFF_HASH as self-reviewed (Stop hook cleared)"
    ;;
  heavy)
    echo "✓ Marked $REPO_KEY diff $DIFF_HASH as heavy-reviewed (pre-pr gate cleared; self sentinel also written)"
    ;;
esac
