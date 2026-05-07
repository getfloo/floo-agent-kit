# INDEX

Machine-readable file-to-topic map for this kit. Mirrors the index table in `README.md`. Format: `path | topic | when to read`.

```
AGENTS.md | Agent ethos, conventions, workflow | First read. (CLAUDE.md is a symlink to AGENTS.md for Claude Code.)
README.md | Overview + three-layer architecture | Right after AGENTS.md.
.claude/skills/README.md | Engineering guideline skills overview | Pick what's relevant.
.claude/hooks/README.md | Hook reference implementations overview | If you want a review system.
.claude/commands/README.md | Slash command overview | If you're shipping security-sensitive code.
docs/knowledge/README.md | How to add KB articles | If you want context-aware docs.
docs/autonomous-loop.md | Autonomous agent session wiring | If running long-running sessions.

.claude/skills/plan-ceo-review/SKILL.md | Founder-mode plan review (4 posture modes, 11 sections) | When reviewing plans/designs.
.claude/skills/sdlc-plan/SKILL.md | Advisor-selected SDLC gate pattern | To make PR review smarter per-diff.
.claude/skills/agent-experience-bar/SKILL.md | Quality bar for agent-facing + human-facing surfaces | When designing CLI/dashboard/docs.
.claude/skills/security-review/SKILL.md | Structured security-review checklist for a diff | Before auth/middleware/schema changes ship.

.claude/commands/security-review.md | /security-review slash command — runs the security checklist via a subagent | User-triggered workflow.

.claude/REVIEW_GUIDE.md | Single source of truth for the pre-PR review policy | Read before opening a sensitive PR. Covers the decision tree, parallel-reviewers doctrine, plan-stage review, rereview-vs-full shape rule, and optional upgrade paths.
.claude/lib/repo-state.sh | Tier classifier + content-addressable diff hasher | Shared library for the review hooks.
.claude/hooks/stop-review-check.sh | Blocks Stop without self-review sentinel | Core of the tiered review pattern.
.claude/hooks/pre-pr-check.sh | Blocks `gh pr create` without heavy-review sentinel for sensitive diffs | Pairs with stop-review-check.
.claude/hooks/pre-push-check.sh | Blocks `git push` without recent tests | Universal.
.claude/hooks/branch-guard.sh | Blocks direct edits to production code in main workspace | Forces worktree discipline.
.claude/hooks/memory-guard.sh | Warns on harness auto-memory directory drift (Claude Code-specific; port or skip for other harnesses) | Enforces three-layer system.
.claude/hooks/evaluate-skills.sh | Lists available skills on every prompt | KB-layer foundation.
.claude/hooks/knowledge-preflight.py | Routes prompt → required KB articles | KB-layer foundation.
.claude/hooks/knowledge-track.py | Records files/docs touched per turn | KB-layer foundation.
.claude/hooks/knowledge-postflight.py | Reminds agent to update KB after code edits | KB-layer foundation.

mark_reviewed.sh | Writes .self and .heavy review sentinels | Paired with stop-review-check and pre-pr-check.
scripts/sdlc-plan.sh | Emits branch diff + gate catalog for the SDLC advisor | Paired with sdlc-plan skill.

.claude/settings.json | Hook registrations (Claude Code format) — example wiring | Reference for how to wire up the hooks you choose. Other harnesses need their own equivalent.
```
