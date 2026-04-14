# CLAUDE.md

## HOW THIS CODEBASE WORKS WITH YOU

**This repo uses a three-layer context system.**

1. **CLAUDE.md (this file)** — ethos, conventions, workflow. Always loaded. This is the constitution.
2. **Skills (`.claude/skills/`)** — behavioral rules for specific domains. Loaded when you touch that domain. Skills tell you HOW TO ACT. No skills are included in this template — add your own for your stack.
3. **Knowledge base (`docs/knowledge/`)** — canonical truth about how the system works. Loaded via `docs/knowledge/index.yaml` routing. KB tells you HOW THINGS WORK.

**Before editing any code:** check `docs/knowledge/index.yaml` for required reading. If the code you're touching maps to a KB article, read it first. If your change alters behavior, invariants, or contracts described in a KB article, update it in the same commit.

**Before every commit:** run tests + lint. No exceptions.

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
- **CLAUDE.md** = constitution (ethos, conventions, workflow)
- **Skills** = behavioral rules (how to act in a specific domain — you write these)
- **KB articles** = factual truth (how the auth model works, how the data flows, what the infra looks like)

---

## Repository Layout

```
your-project/
├── [your source directories]
├── docs/knowledge/           # Canonical domain/flow docs
├── .claude/
│   ├── settings.json         # Hook configuration
│   ├── hooks/                # Lifecycle hooks (KB routing, pre-push guard)
│   └── skills/               # Domain-specific behavioral rules (add your own here)
└── CLAUDE.md                 # This file
```

---

## Skill Routing

<!-- Add routing rules here once you've created skills in .claude/skills/. Example: -->
<!--                                                                                  -->
<!-- When the user's request matches an available skill, invoke it first.             -->
<!--                                                                                  -->
<!-- Key routing rules:                                                               -->
<!-- - Editing Python files → invoke python skill                                     -->
<!-- - Shipping, deploying → invoke deploy skill                                      -->
<!-- - QA, testing → invoke qa skill                                                  -->
