# `.claude/skills/` — engineering guideline skills

Skills are behavioral rules the agent loads when the domain applies. They answer "how should I act when I'm about to do X?" and live alongside the codebase so the rules version with the code.

This kit ships four skills. Each is a **reference implementation** — read it, copy it, adapt it to your project.

## What's here

### `plan-ceo-review/` — founder-mode plan critique
Use when the user asks you to review a plan, feature design, or implementation approach. Challenges premises, maps 2-3 alternatives, runs through 11 review sections (architecture, error handling, security, performance, observability, rollback, etc.), ends with a SHIP / SHIP WITH CHANGES / DO NOT SHIP verdict.

Four posture modes: SCOPE EXPANSION (greenfield — dream big), SELECTIVE EXPANSION (cherry-pick improvements), HOLD SCOPE (bug fix — maximum rigor), SCOPE REDUCTION (ruthless cut).

**Highest-value skill to adopt.** Plan quality is where most of the leverage lives.

### `sdlc-plan/` — advisor-selected SDLC gates
Use before `gh pr create`. Spawns a cheap subagent that reads the branch diff + a gate catalog (unit tests, linting, adversarial review, silent-failure audit, migration rehearsal, contract snapshot, design review, security review) and returns a JSON plan naming which gates this particular PR actually needs.

Replaces the "every sensitive file triggers heavy review" blanket policy with per-diff judgment. Token cost of one advisor call is less than one heavy-review call, so even with occasional misses the expected savings are positive.

Paired with `../../scripts/sdlc-plan.sh` which emits the diff + catalog in the exact shape the advisor expects.

### `agent-experience-bar/` — product quality bar for the agentic era
Use when shaping or reviewing any product surface agents will use alongside humans — CLI commands, docs, config shapes, dashboards, onboarding. Enforces two non-negotiables: humans want to try the product, agents can get work done inside it.

Core tests: every UI capability has a programmatic path, agents discover the right command without tribal knowledge, docs route to the moment of action, paper cuts are bugs.

### `security-review/` — structured security checklist for a diff
Use before shipping code that touches an attack surface. Walks a checklist covering secrets, database/query safety, auth/session, input validation, CORS/CSP, injection vectors beyond SQL, error disclosure, audit logging. Produces a structured report with a verdict.

Paired with `../commands/security-review.md`, the slash command that runs the skill against the current branch diff via a subagent with a skeptic role.

## What's NOT here

Deliberately:

- **No language-specific skill.** Python / TypeScript / Rust behavior rules live in your project, not a generic kit. Write your own as you discover the patterns that matter for your stack.
- **No deploy skill.** Deployment is so platform-specific that a generic version is close to useless.
- **No project conventions skill.** Those belong in `AGENTS.md`.

The skills that ship here are the ones where the pattern transfers even when the stack doesn't.

## Reading order

1. `plan-ceo-review` — you'll use it on the first plan.
2. `agent-experience-bar` — shapes every product decision downstream.
3. `security-review` + `../commands/security-review.md` — before any auth-touching work.
4. `sdlc-plan` + `../../scripts/sdlc-plan.sh` — once the review system is in place and you want to make it smarter per-PR.

## Adding your own

New skill = new directory + a `SKILL.md` with this frontmatter:

```yaml
---
name: your-skill-name
description: >
  One-sentence summary of when to use this skill. This is what the agent
  reads in the skill list to decide whether to invoke.
user-invocable: true  # or false if it's automatic only
---
```

Keep skills focused. One skill per domain. If your skill has three sections that don't overlap, it's three skills.
