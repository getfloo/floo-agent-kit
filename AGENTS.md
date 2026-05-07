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

## PR shape: smaller PRs, not smaller thinking

The plan can be big. The PR should be reviewable, deployable, and mechanically verified. Agents can produce a 2,000-line diff before a human has finished coffee — and a reviewer (human or agent) on a 2,000-line diff stops finding bugs and starts summarizing intent. That's the failure mode small PRs prevent. Doctrine adapted from Google's Small CLs guidance and GitHub's review docs, sharpened for an agent-driven SDLC.

**Every PR should be the smallest complete, reviewable, deployable unit of value.**

**Target shape:**
- One user-visible behavior or one internal invariant per PR.
- Tests ship in the **same PR** as the behavior. Never "tests coming later."
- Doc / KB / skill updates ship in the **same PR** as the behavior change.
- Every PR is green and deployable on its own. No "half a feature that only works after PR 4 lands" unless explicitly hidden behind a flag or inert scaffold.

**Size guidance (meaningful changed lines, excluding generated files, lockfiles, snapshots):**
- ≤ ~400 lines: ideal.
- 400–800 lines: fine if it's one coherent vertical slice.
- > 800 lines or > ~12 files touched: needs a PR plan up-front; default to splitting.
- Mechanical refactors, generated files, lockfiles, formatting: **isolate from behavior changes.** A rename + a behavior change in one PR is two PRs disguised as one.

**Good splits (vertical slices):**
- PR 1: additive schema / model change, no behavior change.
- PR 2: backend behavior + tests.
- PR 3: client surface (CLI, dashboard, SDK) + tests.
- PR 4: cleanup / deprecation removal.
- PR 5: docs / external positioning if customer-facing.

**Bad splits (don't do):**
- Backend without tests, "tests coming later."
- API change without client update.
- Migration that breaks old code (without flag or fallback).
- Client surface that depends on an unmerged backend.
- Six PRs where no single PR is understandable alone.

**PR body template:**

```markdown
## What changed
## Why
## Risk tier            (exempt | standard | sensitive — match classify_path)
## Files reviewers should scrutinize
## Tests run
## Known non-goals
```

**The trap to avoid:** a too-small PR that hides the design. The doctrine isn't "ship the smallest possible diff" — it's "every PR is the smallest *complete* unit of value." A PR shipping a new helper without the existing callers becoming wrappers, the tests, and the doc is an incomplete unit; ship the whole vertical slice even if it's 800 lines.

---

## Production-shape correctness

A test that runs against an in-memory DB + mocked external services + clean fixture data passes; the same code path against a real Postgres + real third-party tokens + production-shaped data fails. That gap is the most expensive class of bug an agent-driven SDLC ships, because it survives every fast-test gate and only fires in production. The rules below are the gap-closers we've found load-bearing.

### Schema and data migrations

Migrations are the highest-stakes class of change in any repo: irreversible by design, blocking every deploy behind them when they fail. An in-memory or alternative-dialect DB is insufficient — different type system, different constraint enforcement, no historical-data fixtures.

1. **Every migration is run against a real instance of the production-shape DB before merge.** Until pre-merge CI does this automatically, the burden is on the author: run the migration locally against a DB seeded with a prod-shaped row sample, and record the command + output in the PR description.

2. **Adding a CHECK / NOT NULL / UNIQUE constraint over an existing table requires explicit handling of historical rows.** Pick one — and write which one in the migration's docstring:
   - Prove existing data already satisfies the constraint (query + count in the PR description).
   - Use the DB's "validate later" form (`NOT VALID` in Postgres; equivalent elsewhere) and follow up with a separate validate-constraint migration once those rows are reconciled.
   - Backfill bad rows in the same migration, *before* the constraint statement.

   **Read your own diff.** If the migration would reject a row your docstring describes, the migration is broken.

3. **JSON / JSONB / VARCHAR / cross-dialect coercions are landmines.** Different DB engines (and different ORM layers) tokenize and coerce these differently. **Bind typed parameters via your ORM's typed-param mechanism** rather than hand-rolling SQL casts. Let the ORM serialize per-dialect.

### Boundary contracts (auth, third-party tokens, external APIs)

When an external system owns the payload shape:

1. **Test what the spec guarantees, not what your fixture happens to have.** A typical OAuth/OIDC access token has required claims (`sub`, `iss`, `exp`) and optional claims (`aud`, `email`, `sid`). A mock token that always includes the optional claims proves nothing about the validator's behavior on real tokens that don't. Write tests for *both* presence and absence.

2. **Don't strict-validate optional claims.** If a third party can change token shape over time, reject only what you can prove is wrong. Validate required claims always; check optional claims only if present. A single line that strict-validates an optional claim can break every login overnight when the upstream stops emitting it.

3. **Severity discipline.** Per-attempt failures of a critical user flow log at `ERROR`, not `WARNING`. Most error-tracking integrations capture `ERROR+` by default. A single user's normal session expiry is `WARNING`. "Every login is failing the same way" is `ERROR` — and "every X is failing the same way" must page someone, not sit silent.

### Operational tooling that mutates production state

Any one-shot reconciler, classifier, IAM revocation, or migration script that touches prod state is one config typo away from an outage. Three rules:

1. **Default to dry-run.** Any one-shot operational tool that mutates production state must have a dry-run mode that prints the full set of resources it would touch, with no side effects. Dry-run is the *default*; an explicit `--apply` (or equivalent) is required to mutate.

2. **Test the classifier exhaustively before first prod run.** Any function that decides "in scope vs. out of scope" needs unit tests enumerating every realistic resource-name pattern that exists in production today — including bare-name variants, hyphenated env variants, and edge-case names. The most damaging ops-tooling outages are caused by a one-character classifier bug that passed all the tests because the tests didn't cover the production naming variant.

3. **Pre-flight checklist before first prod apply.** Before running an operational tool against prod for the first time, the operator (human or agent) must answer in writing:
   - What's the input set?
   - What does dry-run say it will do?
   - What's the worst-case scenario if the classifier is wrong?
   - What's the recovery path?
   - Is the recovery path automatable, or does it require manual cloud-console commands?

   If the recovery is "manual cloud-console," the tool needs an inverse reconciler before its first run.

### Post-incident closure

When an incident happens, two things must land in the same week before the incident is "over":

1. A test that would have caught the specific bug (regression guard).
2. A doctrine entry — in this file, in a skill, or in a KB article — that would have prevented the *pattern*.

If only (1) lands, the next variant of the same pattern still ships. If only (2) lands, there's no proof the pattern actually got addressed. Both, or it's not closed.

---

## No half-built gates

A workflow that references a secret or variable must have that secret provisioned in the same PR that lands the reference, or the workflow doesn't exist. There is no allowlist, no "we'll provision before declaring it live" comment, no skip-with-warning fallback that pretends the gate exists when it doesn't.

A gate is either fully wired — provisioned + tested + alerting on real failures — or it is deleted.

Half-built gates are worse than missing gates: they consume cognitive bandwidth, log-noise budget, and reader trust without producing a single bit of signal. When a feature comes back later, it lands as one atomic PR with the secret, the wiring, the alert, and a real assertion that the gate fires when it should.

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

This kit ships a tiered review pattern enforced by hooks. **`.claude/REVIEW_GUIDE.md` is the single source of truth for the decision tree** — read it before opening a sensitive PR; don't reconstruct the rules from this summary.

- **`./mark_reviewed.sh`** — records a self-review attestation for the current diff. Required before every Stop if any non-exempt code changed.
- **`./mark_reviewed.sh --tier heavy`** — records a heavy-review attestation. Required before `gh pr create` on branches that touch sensitive-tier files (routes, models, schemas, migrations, auth, middleware — see `.claude/lib/repo-state.sh`).
- **Heavy review** means running subagents on the diff in parallel: an adversarial code reviewer (skeptic posture) and a silent-failure auditor. Address findings, re-run tests, then mark.

The hook chain:

- `stop-review-check.sh` — blocks Stop without `.self` sentinel for non-exempt diffs
- `pre-pr-check.sh` — blocks `gh pr create` without `.heavy` sentinel for sensitive diffs
- `pre-push-check.sh` — blocks `git push` without recent test sentinel
- `branch-guard.sh` — blocks direct production-code edits in main workspace (use a worktree)

See `.claude/hooks/README.md` for hook implementation details. `.claude/REVIEW_GUIDE.md` covers the policy: when each tier applies, the parallel-reviewers doctrine, plan-stage review for non-trivial sensitive work, the rereview-vs-full shape rule, and optional upgrade paths (second-reviewer family, rereview tiers).

---

## Slash Commands

- `/security-review` — run the security checklist against the current branch diff via a subagent. Before auth/middleware/schema changes ship.

See `.claude/commands/README.md` for how to build your own.
