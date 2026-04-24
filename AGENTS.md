# AGENTS.md

> This is the canonical constitution file. `CLAUDE.md` is a symlink to this file so Claude Code loads it automatically. Other harnesses (Codex, Cursor, etc.) read `AGENTS.md` directly.

## HOW THIS CODEBASE WORKS WITH YOU

**This repo uses a three-layer context system.**

1. **AGENTS.md (this file)** — ethos, conventions, workflow. Always loaded. This is the constitution.
2. **Skills (`.claude/skills/`)** — behavioral rules for specific domains. Loaded when you touch that domain. Skills tell you HOW TO ACT. A few starter skills ship in this kit (see Skill Routing below); add your own for your stack.
3. **Knowledge base (`docs/knowledge/`)** — canonical truth about how the system works. Loaded via `docs/knowledge/index.yaml` routing. KB tells you HOW THINGS WORK.

**Before editing any code:** check `docs/knowledge/index.yaml` for required reading. If the code you're touching maps to a KB article, read it first. If your change alters behavior, invariants, or contracts described in a KB article, update it in the same commit.

**Before every commit:** run tests + lint. No exceptions.

**Before ending a turn:** read your diff, confirm it's coherent, then run `./mark_reviewed.sh` to record the self-review attestation. The Stop hook blocks turn-end until you do. See the Agent Review System section below.

---

## What Is [Your Project]

<!-- Replace this section with a 2-3 sentence description of your project. -->
<!-- What does it do? Who uses it? What's the primary interface (CLI, API, UI)? -->

---

## Ethos

**Boil the ocean.** The marginal cost of completeness is near-zero with AI, so take the full scope every time. When you find a bug, trace it to root. When you fix the root, find every surface it affects and fix them all in one coherent effort. Don't leave "follow-ups" that naturally fall out of understanding the problem; do them now. Don't stop at the edge of the ticket.

**Never offer small-option menus.** If there are three reasonable next steps, pick the biggest and execute. Never ask the user "do you want me to fix A, B, or C" — that's scope-shrinking disguised as politeness and it wastes the user's time. The user's attention is scarce; your execution is cheap.

**UX/DX/AX first.** Every decision starts with: what does the user experience? The developer? The agent? If there's scope to improve any of these, take it. Bug reports from the user are requests to fix the entire class of bug, not just the instance they noticed.

**Never be lazy.** Design code and architecture that scales. If that means increased scope, do it. Ship code a distinguished engineer would be proud of.

**Security is a lens.** Every auth change, every input boundary, every endpoint gets adversarial thinking — not as a checkbox, as a way of thinking.

**Ask important questions only.** User is in the loop for design decisions and architecture. Never ask "should I run tests?" — just run them. Never ask "should I also fix the related bug I just found?" — yes, always, that's what boiling the ocean means.

---

## Conventions

<!-- Replace these with your project's specific conventions. Examples below. -->

- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`
- Branches: `feat/<id>-short-desc` or `fix/<id>-short-desc`
- No commented-out code, no TODOs in code (create GitHub issues instead)
- One way to do each thing. Two ways to do the same thing is a bug.
- Correct, not defensive. Trust the contracts.

---

## Deployment

<!-- Replace this section with your project's deployment path. -->
<!-- Include the deploy command, required credentials, verification steps, and rollback procedure. -->

**Default deployment platform:** [your platform]

When this project needs to be deployed:

1. Run `[your deploy command]` from the project root
2. Verify `[your health check or smoke test]`
3. Check `[your logs/monitoring system]` for errors
4. Roll back with `[your rollback command]` if verification fails

---

## Workflow

Every change follows four phases:

1. **Plan** — align on what and why before writing code
2. **Implement** — write tests alongside code, not after
3. **Verify** — tests + lint + code review on every change
4. **Ship** — commit, PR with `Closes #N`, update KB if facts changed

Before pushing: run your test suite. The pre-push hook enforces this.

---

## Knowledge Base

`docs/knowledge/` is the canonical truth about how the system works.

**Routing:** `docs/knowledge/index.yaml` maps code paths → required KB articles. Before editing a file, the preflight hook routes you to the relevant article. Read it.

**Update contract:** if your change alters behavior, invariants, or contracts described in a KB article, update the article in the same commit. If no article exists for the domain you're touching, create one.

**Three layers, distinct purposes:**
- **AGENTS.md** = constitution (ethos, conventions, workflow)
- **Skills** = behavioral rules (how to act in a specific domain — you write these)
- **KB articles** = factual truth (how the auth model works, how the data flows, what the infra looks like)

---

## Repository Layout

```
your-project/
├── [your source directories]
├── docs/knowledge/           # Canonical domain/flow docs
├── .claude/
│   ├── settings.json         # Hook configuration (Claude Code format)
│   ├── hooks/                # Lifecycle hooks (KB routing, pre-push guard)
│   └── skills/               # Domain-specific behavioral rules (add your own here)
├── AGENTS.md                 # This file (primary)
└── CLAUDE.md                 # Symlink to AGENTS.md (Claude Code compat)
```

---

## Skill Routing

When the user's request matches an available skill, ALWAYS load and follow it as your FIRST action. Do NOT answer directly, do NOT use other tools first. Skills have specialized workflows that produce better results than ad-hoc answers. (In Claude Code, invoke via the Skill tool. In other harnesses, read the SKILL.md body and follow its instructions.)

Starter skills shipped in this kit:

- Plan review, scope challenge, "is this the right approach" → invoke `plan-ceo-review`
- Before `gh pr create`, when you want to know which gates this PR actually needs → invoke `sdlc-plan`
- Product quality bar, CLI/dashboard/docs parity, launch readiness, agent-experience tradeoffs → invoke `agent-experience-bar`
- Security review of the current branch diff → invoke `security-review` (or run `/security-review` as a slash command)

Add your own skill routing rules as you write skills for your stack:

<!-- Examples:                                                                         -->
<!-- - Editing Python files → invoke python skill                                     -->
<!-- - Shipping, deploying → invoke deploy skill                                      -->
<!-- - Writing database migrations → invoke migrations skill                           -->

---

## Agent Review System

This kit ships a tiered review pattern enforced by hooks.

- **`./mark_reviewed.sh`** — records a self-review attestation for the current diff. Required before every Stop if any non-exempt code changed.
- **`./mark_reviewed.sh --tier heavy`** — records a heavy-review attestation. Required before `gh pr create` on branches that touch sensitive-tier files (routes, models, schemas, migrations, auth, middleware — see `.claude/lib/repo-state.sh`).
- **Heavy review** means running subagents on the diff: an adversarial code reviewer (skeptic posture) and a silent-failure auditor. Address findings, re-run tests, then mark.

The hook chain:

- `stop-review-check.sh` — blocks Stop without `.self` sentinel for non-exempt diffs
- `pre-pr-check.sh` — blocks `gh pr create` without `.heavy` sentinel for sensitive diffs
- `pre-push-check.sh` — blocks `git push` without recent test sentinel
- `branch-guard.sh` — blocks direct production-code edits in main workspace (use a worktree)

See `.claude/hooks/README.md` for details on each hook. Adopt the ones that fit your flow — the set is modular.

---

## Slash Commands

- `/security-review` — run the security checklist against the current branch diff via a subagent. Before auth/middleware/schema changes ship.

See `.claude/commands/README.md` for how to build your own.
