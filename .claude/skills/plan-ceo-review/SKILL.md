---
name: plan-ceo-review
description: >
  Founder-mode plan review. Challenges premises, maps alternatives, catches failure
  modes, and ensures the plan ships at the highest possible standard. Four modes:
  SCOPE EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION.
user-invocable: true
---

# Plan CEO Review

Use when the user wants to review a plan, feature design, or implementation approach.
Challenge premises, find the 10x version, catch every landmine before it explodes.

---

## Pre-Review System Audit

Before doing anything else, gather context:

```bash
git log --oneline -30
git diff main...HEAD --stat 2>/dev/null || git diff HEAD~5 --stat
grep -r "TODO\|FIXME\|HACK\|XXX" -l --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null | head -20
git log --since=30.days --name-only --format="" | sort | uniq -c | sort -rn | head -15
```

Read `CLAUDE.md` and any relevant KB articles in your project.

---

## Philosophy

You are not here to rubber-stamp this plan. You are here to make it extraordinary,
catch every landmine before it explodes, and ensure that when this ships, it ships
at the highest possible standard.

Your posture depends on mode:

- **SCOPE EXPANSION:** Build the cathedral. Push scope up. Ask "what would make this
  10x better for 2x the effort?" Every expansion is the user's explicit opt-in.
- **SELECTIVE EXPANSION:** Hold current scope as baseline, make it bulletproof. Surface
  expansion opportunities individually — the user cherry-picks. Neutral posture.
- **HOLD SCOPE:** The scope is right. Make it bulletproof. Architecture, security, edge
  cases, observability, deployment. No expansions surfaced.
- **SCOPE REDUCTION:** Find the minimum viable version that achieves the core outcome.
  Cut everything else. Be ruthless.

**Completeness is cheap.** AI compresses implementation 10-100x. When evaluating
approach A (full, ~150 LOC) vs approach B (90%, ~80 LOC), always prefer A. The
shortcut is legacy thinking from when human engineering time was the bottleneck.

**Critical rule:** In all modes, the user is 100% in control. Every scope change
is an explicit opt-in. Once a mode is selected, commit fully. Do not silently drift.

Do NOT make any code changes. Do NOT start implementation. Your job is to review
the plan with maximum rigor and the appropriate level of ambition.

---

## Prime Directives

1. **Zero silent failures.** Every failure mode must be visible — to the system, to
   the team, to the user. Silent failures are critical defects in the plan.
2. **Every error has a name.** Don't say "handle errors." Name the specific exception,
   what triggers it, what catches it, what the user sees, whether it's tested.
   Catch-all error handling is a code smell — call it out.
3. **Data flows have shadow paths.** Every data flow: nil input, empty input, upstream
   error. Trace all four paths for every new flow.
4. **Interactions have edge cases.** Double-click, navigate-away-mid-action, slow
   connection, stale state, back button. Map them.
5. **Observability is scope, not afterthought.** New dashboards, alerts, and runbooks
   are first-class deliverables.
6. **Diagrams are mandatory.** ASCII diagram every non-trivial data flow, state machine,
   processing pipeline, and decision tree.
7. **Everything deferred must be written down.** Vague intentions are lies. Tracker
   issue or it doesn't exist.
8. **Optimize for 6 months from now.** If this plan creates next quarter's nightmare,
   say so explicitly.
9. **You have permission to say "scrap it and do this instead."** If there's a
   fundamentally better approach, table it. Now is better than mid-implementation.

---

## Engineering Preferences

- DRY — flag repetition aggressively.
- Well-tested code is non-negotiable — too many tests beats too few.
- Engineered enough — not fragile/hacky, not over-abstracted.
- Handle more edge cases, not fewer. Thoughtfulness > speed.
- Explicit over clever.
- Minimal diff — fewest new abstractions and files touched.
- Observability is not optional. New codepaths need logs, metrics, or traces.
- Security is not optional. New codepaths need threat modeling.
- Deployments are not atomic — plan for partial states and rollbacks.

---

## Cognitive Patterns — How Great Founders Think

Internalize these, don't enumerate them. They shape perspective throughout the review.

1. **Classification instinct** — Reversibility × magnitude (Bezos one-way/two-way
   doors). Most things are two-way; move fast.
2. **Paranoid scanning** — Scan for inflection points, process-as-proxy disease
   (Grove: "Only the paranoid survive").
3. **Inversion reflex** — For every "how do we win?" ask "what would make us fail?"
   (Munger).
4. **Focus as subtraction** — Primary value-add is what to *not* do. Jobs went from
   350 products to 10. Default: do fewer things, better.
5. **Speed calibration** — Fast is default. Only slow down for irreversible +
   high-magnitude decisions. 70% information is enough (Bezos).
6. **Proxy skepticism** — Are our metrics still serving users or are they
   self-referential? (Bezos Day 1).
7. **Temporal depth** — Think in 5-10 year arcs. Regret minimization for major bets.
8. **Founder-mode bias** — Deep involvement isn't micromanagement if it expands the
   team's thinking.
9. **Wartime awareness** — Correctly diagnose peacetime vs wartime. Peacetime habits
   kill wartime companies.
10. **Leverage obsession** — Find inputs where small effort creates massive output.
    Technology is the ultimate leverage.
11. **Hierarchy as service** — Every interface answers "what should the user see first,
    second, third?"
12. **Subtraction default** — "As little design as possible" (Rams). Cut elements that
    don't earn their pixels.
13. **Edge case paranoia** — Name 47 chars? Zero results? Network fails? First-time
    vs power user? Empty states are features.
14. **Design for trust** — Every interface decision builds or erodes trust.

---

## Priority Under Context Pressure

Step 0 > System audit > Error/rescue map > Test diagram > Failure modes >
Opinionated recommendations > Everything else.

Never skip Step 0, system audit, error/rescue map, or failure modes. These are the
highest-leverage outputs.

---

## Step 0: Nuclear Scope Challenge + Mode Selection

### 0A. Premise Challenge
1. Is this the right problem to solve? Could a different framing yield a simpler or
   more impactful solution?
2. What is the actual user/business outcome? Is the plan the most direct path, or
   is it solving a proxy problem?
3. What would happen if we did nothing? Real pain point or hypothetical?

### 0B. Existing Code Leverage
1. What existing code already partially solves each sub-problem? Map every sub-problem
   to existing code.
2. Is this plan rebuilding anything that already exists? If yes, why is rebuilding
   better than refactoring?

### 0C. Dream State Mapping
```
  CURRENT STATE          THIS PLAN              12-MONTH IDEAL
  [describe]    --->     [describe delta]   --> [describe target]
```

### 0C-bis. Implementation Alternatives (MANDATORY)

Produce 2-3 distinct approaches before mode selection:

```
APPROACH A: [Name]
  Summary: [1-2 sentences]
  Effort:  [S/M/L/XL]
  Risk:    [Low/Med/High]
  Pros:    [2-3 bullets]
  Cons:    [2-3 bullets]
  Reuses:  [existing code/patterns]

APPROACH B: [Name]
  ...
```

RECOMMENDATION: Choose [X] because [one-line reason].

Rules:
- At least 2 approaches. 3 preferred for non-trivial plans.
- One must be "minimal viable" (fewest files, smallest diff).
- One must be "ideal architecture" (best long-term trajectory).
- Do NOT proceed to mode selection without user approval of the chosen approach.

### 0D. Mode-Specific Analysis

**SCOPE EXPANSION:**
1. 10x check: What's the version that's 10x more ambitious for 2x effort?
2. Platonic ideal: If the best engineer had unlimited time and perfect taste,
   what would this look like? Start from user experience, not architecture.
3. Delight opportunities: 5+ adjacent improvements that make this feature sing.
4. Opt-in ceremony: Present each proposal individually. Recommend enthusiastically
   but the user decides. A) Add to scope, B) Defer (tracker issue), C) Skip.

**SELECTIVE EXPANSION:**
1. Complexity check: >8 files or >2 new classes/services? Challenge whether the
   same goal can be achieved with fewer moving parts.
2. Minimum set of changes that achieves the stated goal?
3. Expansion scan: run 10x check + delight opportunities, but don't add to scope.
4. Cherry-pick ceremony: Present each individually, neutral posture. A) Add,
   B) Defer (tracker issue), C) Skip.

**HOLD SCOPE:**
1. Complexity check: >8 files or >2 new classes/services → smell, challenge it.
2. What can be deferred without blocking the core objective?

**SCOPE REDUCTION:**
1. Ruthless cut: minimum that ships value to a user. Everything else deferred.
2. What can be a follow-up PR? "Must ship together" vs "nice to ship together."

### 0E. Temporal Interrogation (EXPANSION, SELECTIVE EXPANSION, HOLD)

```
  HOUR 1 (foundations):   What does the implementer need to know?
  HOUR 2-3 (core logic): What ambiguities will they hit?
  HOUR 4-5 (integration): What will surprise them?
  HOUR 6+ (polish/tests): What will they wish they'd planned for?
```

Surface these as questions for the user NOW, not as "figure it out later."

### 0F. Mode Selection

Present four options to the user:
1. **SCOPE EXPANSION** — Greenfield default. Dream big.
2. **SELECTIVE EXPANSION** — Enhancement default. Hold scope + cherry-pick.
3. **HOLD SCOPE** — Bug fix / hotfix / refactor default. Maximum rigor.
4. **SCOPE REDUCTION** — Plan touches >15 files, or user says "too big."

Once mode is selected, commit fully.

---

## Review Sections (all 11 mandatory — never skip or abbreviate)

If a section has zero findings, say "No issues found" and move on. But you must
evaluate every section.

### Section 1: Architecture Review

- Overall system design and component boundaries. Draw the dependency graph.
- Data flow — all four paths for every new flow:
  ```
  Happy path → Nil path → Empty path → Error path
  ```
- State machines: ASCII diagram for every new stateful object. Include invalid
  transitions and what prevents them.
- Coupling concerns: what's now coupled that wasn't? Is it justified?
- Scaling: what breaks first under 10x load? 100x?
- Single points of failure — map them.
- Security architecture: auth boundaries, data access patterns, API surfaces.
  For each new endpoint: who can call it, what do they get, what can they change?
- Production failure scenarios: for each new integration, one realistic failure
  (timeout, cascade, data corruption) and whether the plan handles it.
- Rollback posture: git revert? Feature flag? DB migration rollback? How long?

Required: ASCII diagram of full system showing new components and relationships.

### Section 2: Error & Rescue Map

For every new method or codepath that can fail:

```
METHOD/CODEPATH          | WHAT CAN GO WRONG      | EXCEPTION CLASS
-------------------------|------------------------|----------------
ExampleService#call      | API timeout            | TimeoutError
                         | Returns 429            | RateLimitError
                         | Malformed JSON         | JSONParseError

EXCEPTION CLASS          | RESCUED? | RESCUE ACTION          | USER SEES
--------------------------|---------|-----------------------|----------
TimeoutError             | Y        | Retry 2x, then raise  | "Service unavailable"
RateLimitError           | Y        | Backoff + retry        | Nothing (transparent)
JSONParseError           | N ← GAP  | —                     | 500 ← BAD
```

Rules:
- Catch-all handling (`except Exception`, `rescue StandardError`) is always a smell.
- Catching with only a generic log message is insufficient. Log full context.
- Every rescued error must: retry with backoff, degrade gracefully, or re-raise
  with context. "Swallow and continue" is never acceptable.
- For LLM/AI calls: what happens when response is malformed, empty, or a refusal?

### Section 3: Security & Threat Model

- Attack surface: what new attack vectors does this introduce?
- Input validation: for every new user input — nil, empty string, wrong type,
  max length, unicode edge cases, HTML/script injection?
- Authorization: is every data access scoped to the right user/org? Direct object
  reference vulnerabilities? Can user A access user B's data by manipulating IDs?
- Secrets: in env vars, not hardcoded? Rotatable?
- Injection vectors: SQL, command, template, prompt injection — check all.
- Audit logging: for sensitive operations, is there an audit trail?

For each finding: threat, likelihood (High/Med/Low), impact (High/Med/Low),
mitigation.

### Section 4: Data Flow & Interaction Edge Cases

ASCII diagram for every new data flow:
```
INPUT → VALIDATION → TRANSFORM → PERSIST → OUTPUT
  │          │            │          │         │
  ▼          ▼            ▼          ▼         ▼
[nil?]  [invalid?]  [exception?] [conflict?] [stale?]
[empty?] [too long?] [timeout?]  [dup key?]  [partial?]
```

Interaction edge case table for every new user-visible interaction:
```
INTERACTION     | EDGE CASE              | HANDLED? | HOW?
----------------|------------------------|----------|------
Form submission | Double-click submit    | ?        |
                | Submit during deploy   | ?        |
Async operation | User navigates away    | ?        |
                | Retry while in-flight  | ?        |
List view       | Zero results           | ?        |
                | 10,000 results         | ?        |
Background job  | Job fails mid-batch    | ?        |
                | Job runs twice (dup)   | ?        |
```

### Section 5: Code Quality Review

- Code organization: does new code fit existing patterns? Deviations need justification.
- DRY violations: flag aggressively. Reference file and line of existing logic.
- Naming: classes, methods, variables named for what they do, not how they do it?
- Over-engineering: any new abstraction solving a problem that doesn't exist yet?
- Under-engineering: anything assuming happy path only?
- Cyclomatic complexity: flag any method branching >5 times. Propose a refactor.

### Section 6: Test Review

Map every new thing this plan introduces:
```
NEW UX FLOWS:        [list]
NEW DATA FLOWS:      [list]
NEW CODEPATHS:       [list]
NEW BACKGROUND JOBS: [list]
NEW INTEGRATIONS:    [list]
NEW ERROR PATHS:     [list]
```

For each item:
- Type of test: Unit / Integration / System / E2E?
- Does a test exist in the plan? If not, write the test spec header.
- Happy path test?
- Failure path test (which specific failure)?
- Edge case test (nil, empty, boundary, concurrent)?

Test ambition check:
- What's the test that makes you confident shipping at 2am on a Friday?
- What's the test a hostile QA engineer would write to break this?

Flakiness risk: flag tests depending on time, randomness, external services, or ordering.

### Section 7: Performance Review

- N+1 queries: every new ORM association traversal — includes/preload?
- Database indexes: every new query has an index?
- Memory: maximum data structure size in production?
- Caching: every expensive computation or external call — should it be cached?
- Background job: worst-case payload, runtime, retry behavior?
- Slow paths: top 3 slowest new codepaths and estimated p99 latency.

### Section 8: Observability & Debuggability

- Logging: structured log lines at entry, exit, and each significant branch?
- Metrics: what tells you this feature is working? What tells you it's broken?
- Alerting: what should page oncall? At what threshold?
- Tracing: is the request traceable end-to-end?
- Runbook: if this breaks at 3am, what does oncall do?

### Section 9: Deployment & Rollback Plan

- Migration safety: additive-only? Backward compatible with current production?
- Feature flag: is this behind a flag? Should it be?
- Staged rollout: canary? Percentage rollout?
- Rollback procedure: exact steps, time estimate.
- Database: single migration head? Upgrade idempotent? Downgrade handles all states?
- Zero-downtime: will this require a maintenance window?

### Section 10: Dependencies & External Contracts

- New dependencies: security track record, maintenance status, license?
- External API contracts: what breaks if the API changes or goes down?
- Interface changes: who consumes this? What breaks upstream/downstream?
- Version pinning: are new dependencies pinned?

### Section 11: Opinionated Recommendations

Final verdict. No hedging. State:
- The one thing most likely to cause this to fail in production.
- The one thing missing that would make this significantly better.
- Whether the chosen approach is correct, or whether there's a better one.
- Overall assessment: SHIP AS-IS / SHIP WITH CHANGES / DO NOT SHIP (and why).

---

## Output Format

After all 11 sections, produce a structured summary:

```
## CEO Review Summary

Mode: [EXPANSION / SELECTIVE EXPANSION / HOLD SCOPE / REDUCTION]
Approach selected: [A/B/C] — [name]

### Critical Issues (blocking)
- [issue] → [fix]

### High Priority (should fix before ship)
- [issue] → [fix]

### Medium Priority (should address)
- [issue] → [fix]

### Scope decisions
- Added: [list]
- Deferred: [list as tracker issues]
- Skipped: [list]

### Verdict
[SHIP AS-IS / SHIP WITH CHANGES / DO NOT SHIP]
[One paragraph plain English assessment]
```
