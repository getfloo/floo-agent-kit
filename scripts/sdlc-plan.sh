#!/usr/bin/env bash
#
# sdlc-plan.sh — emit the diff + gate catalog in a form the test-plan
# advisor subagent can read and turn into a per-PR gate plan.
#
# Used by the `sdlc-plan` skill. Pipe this into the advisor's prompt:
#
#   ./scripts/sdlc-plan.sh | pbcopy   # then paste as subagent input
#   # or from an agent session, have the agent run this and use the
#   # stdout as the Agent tool's prompt body.
#
# Output structure:
#   SECTION: repo state — branch, base ref
#   SECTION: files changed — name-only list
#   SECTION: unified diff — full diff, truncated to DIFF_MAX_LINES
#   SECTION: gate catalog — every gate the advisor is allowed to pick
#
# The gate catalog is declared inline here (not pulled from yaml) so
# this script stays single-file / no external deps. When you add a new
# gate to your SDLC, add it here and update the advisor prompt in the
# skill SKILL.md to describe when it applies.
#
# HOW TO ADAPT TO YOUR REPO:
#   1. Edit the BASE_REF default if your main branch is not origin/main.
#   2. Edit the gate catalog below — each entry should list a single gate
#      your pipeline supports. Delete gates you don't run. Add gates that
#      are specific to your stack (e.g. integration-tests, e2e-suite).
#   3. Keep the advisor prompt in SKILL.md in sync with the catalog here.

set -euo pipefail

: "${BASE_REF:=origin/main}"
: "${DIFF_MAX_LINES:=2000}"

cd "$(git rev-parse --show-toplevel)"

# Best-effort fetch; if offline/detached we still produce something useful.
git fetch origin main --quiet 2>/dev/null || true

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="main"
  if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    echo "ERROR: no base ref (tried origin/main and main)" >&2
    exit 1
  fi
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_SHA=$(git rev-parse HEAD)
BASE_SHA=$(git rev-parse "$BASE_REF")

# Files changed on this branch vs base.
FILES=$(git diff "$BASE_REF"...HEAD --name-only 2>/dev/null || echo "")

# Full unified diff, truncated if huge. The truncation note is preserved
# so the advisor knows context was cut — it can still make decisions on
# the change surface (file list) even when the full body is gone.
DIFF_BODY=$(git diff "$BASE_REF"...HEAD 2>/dev/null || echo "")
DIFF_LINES=$(printf '%s\n' "$DIFF_BODY" | wc -l | tr -d ' ')
if [ "$DIFF_LINES" -gt "$DIFF_MAX_LINES" ]; then
  DIFF_BODY=$(printf '%s\n' "$DIFF_BODY" | head -n "$DIFF_MAX_LINES")
  DIFF_BODY="$DIFF_BODY
[... diff truncated: $DIFF_LINES total lines, showing first $DIFF_MAX_LINES ...]"
fi

cat <<EOF
=== repo state ===
branch: $BRANCH
head:   $HEAD_SHA
base:   $BASE_REF ($BASE_SHA)

=== files changed ===
$FILES

=== gate catalog ===
gate_id: fast-unit-tests
    always_required: true
    command: run your unit test suite (the fast one that gates PRs locally)
    catches: unit regressions, type errors, lint violations
    cost: ~1-2min, near-zero tokens
gate_id: linting
    always_required: true
    command: run your project's linter and formatter in check mode
    catches: style, common bug classes (implicit returns, unused vars)
    cost: ~5s, zero tokens
gate_id: adversarial-review
    always_required: false
    command: launch an adversarial-posture code reviewer subagent via the Agent tool
    catches: bugs a skeptical reviewer would find; bias toward blocking rather than approving
    cost: ~1-2min, structured JSON output
    applies_when: route handlers / middleware / models / migrations / auth / payment / service-layer contracts materially change
    does_NOT_apply_when: comment or docstring edits, typo fixes, config-only changes, test-only additions
    note: pairs with silent-failure-audit for independent two-reviewer coverage on the same diff
gate_id: silent-failure-audit
    always_required: false
    command: launch a silent-failure-audit subagent via the Agent tool, then ./mark_reviewed.sh --tier heavy
    catches: silent failures, error-handling gaps, inappropriate fallbacks
    cost: ~1-2min, 20-40k tokens
    applies_when: same criteria as adversarial-review — pairs with it for independent-reviewer coverage
    note: independent reviews surface different issues than one review alone.
gate_id: migration-rehearsal
    always_required: false
    command: rehearse the migration against a prod-shaped data snapshot before shipping
    catches: migrations that pass on empty-state tests but fail on real data
    cost: ~15min wall-clock, near-zero tokens
    applies_when: any migration file added or modified
gate_id: contract-snapshot
    always_required: false
    command: generate API schema from routes, diff against a committed snapshot file
    catches: accidental route-shape changes / breaking API contract drift
    cost: ~5s
    applies_when: route or schema files modified
gate_id: smoke-expand
    always_required: false
    command: add smoke-test cases that exercise new/changed endpoints end-to-end
    catches: bugs in endpoints that unit-test mocks miss
    cost: one-time per new endpoint, ~5 lines
    applies_when: new endpoint added OR existing endpoint's request/response shape changed
gate_id: design-review
    always_required: false
    command: invoke a design-review skill/subagent on changed UI routes
    catches: visual/UX regressions
    cost: ~2-3min, ~10-20k tokens
    applies_when: UI code (not copy) changed
gate_id: security-review
    always_required: false
    command: invoke the /security-review slash-command
    catches: auth bypasses, input validation gaps, CSP gaps
    cost: ~2min, ~20-40k tokens
    applies_when: new admin endpoints, changes to auth/session/middleware, security-header changes, input validation surface changes

=== unified diff ===
$DIFF_BODY
EOF
