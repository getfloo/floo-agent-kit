---
name: sdlc-plan
description: Advisor-selected SDLC gate pattern. Before `gh pr create`, spawn a subagent that reads the branch diff + gate catalog and returns a JSON plan naming exactly the gates this PR requires. Run only those gates. Replaces the blanket "every sensitive file triggers heavy review" policy with per-diff judgment, cutting token cost on trivial sensitive-path PRs while keeping real risk covered.
user-invocable: true
---

# sdlc-plan

> The test-plan advisor. Before a PR lands, one subagent decides which parts of the kit to run against this particular diff.

---

## Why

The tiered review system's heavy-review sentinel (`pre-pr-check.sh`) fires on every PR that touches a sensitive-tier file. That's a blanket policy — a 3-line comment fix in a migration file triggers the same `adversarial-review + silent-failure-audit` cycle as a full auth middleware rewrite. Heavy review then comes back "ship it" on the comment fix for ~30-50k tokens of overhead.

The advisor pattern replaces the blanket with judgment: one cheaper subagent reads the diff + the catalog of available gates and returns a plan naming the gates this PR actually needs.

- **Trivial sensitive-path diff** (comment, docstring, test-only edit): plan says skip heavy review, skip smoke expansion. Just run fast unit tests.
- **Genuine-risk diff** (new route, migration that touches data, auth logic): plan says run heavy review + silent-failure-audit + migration rehearsal + expanded smoke.
- **Ambiguous diff**: plan defaults toward the heavier set. The advisor's bias is to err safe.

Token cost of one advisor call is less than one heavy-review call — so even if the advisor is wrong 20% of the time, the expected savings across many PRs is positive.

---

## When to invoke

Before every `gh pr create`. This skill is `user-invocable: true` so it can be triggered explicitly with `/sdlc-plan`.

The existing `pre-pr-check.sh` still gates sensitive-tier diffs on the `.heavy` sentinel. Running this skill produces the plan that tells you whether `./mark_reviewed.sh --tier heavy` is required for this particular PR.

---

## Flow

1. **Compute the diff surface.** `./scripts/sdlc-plan.sh` emits the branch diff (files + unified diff) and the gate catalog. The script is the single source of truth for both — don't hand-curate the diff in the agent, the script handles base-branch detection and truncation.

2. **Spawn the advisor subagent.** Use your harness's subagent mechanism (in Claude Code: the `Agent` tool with `subagent_type: general-purpose`). Feed it the script's stdout plus the prompt template below.

3. **Parse the plan.** The subagent returns a JSON object on its last line:
    ```json
    {
      "gates_required": ["fast-unit-tests", "linting", "adversarial-review"],
      "gates_skipped": ["migration-rehearsal", "contract-snapshot"],
      "rationale": {
        "adversarial-review": "New middleware changes the token-validation codepath on every request. Silent-failure-audit must look at this.",
        "migration-rehearsal": "No migration files changed.",
        "contract-snapshot": "Routes and schemas are untouched."
      },
      "risk_level": "high"
    }
    ```

4. **Persist the plan.** Write the JSON to `.claude/.review/<repo>.test-plan.json`. This gives humans + future agents an audit trail: "the advisor said skip heavy review on this one."

5. **Run the required gates.** For each gate id in `gates_required`, execute it. See the gate catalog for what each one does.

6. **Create the PR.** Now the sentinel the `pre-pr-check.sh` hook expects is in place (or legitimately absent if the plan said skip), and the PR can proceed.

---

## Gate catalog

Customize this list for your stack. The exact gates you ship depends on your test setup, language, and deploy tooling. Below is a reference set — delete what doesn't apply, add what's missing, keep the advisor prompt in sync.

| Gate | Always required? | Catches | Applies when |
|---|---|---|---|
| `fast-unit-tests` | yes | unit regressions, type errors | every PR |
| `linting` | yes | style, common bug classes | every PR |
| `adversarial-review` | no | bugs a skeptical reviewer would find | routes, middleware, models, migrations, auth, payment, service contracts |
| `silent-failure-audit` | no | swallowed errors, inappropriate fallbacks | pairs with `adversarial-review` — two independent reviews on the same diff |
| `migration-rehearsal` | no | migrations that fail on prod-shaped data | any migration file added or modified |
| `contract-snapshot` | no | accidental route-shape drift | route or schema files modified |
| `smoke-expand` | no | bugs in endpoints that unit-test mocks miss | new endpoint added or request/response shape changed |
| `design-review` | no | visual/UX regressions | UI code (not just copy) changed |
| `security-review` | no | auth bypasses, input validation gaps, CSP gaps | new admin endpoints, changes to auth/session/middleware, security-header changes |

**Pair `adversarial-review` + `silent-failure-audit` intentionally.** They run in parallel, on the same diff, as two subagents with different roles. Independent reviews surface different issues — both returning "approve" is a stronger signal than either one alone.

---

## Advisor prompt template

Paste this as the subagent prompt, prefixing the `sdlc-plan.sh` output:

```
You are the test-plan advisor for a PR about to land. Your job: read the branch diff and the gate catalog, return a JSON plan naming exactly the gates this PR requires.

Rules:
1. Default toward the heavier set when in doubt. False-negatives (missed gate) cost prod incidents; false-positives (extra gate run) cost tokens. The asymmetry is massive.
2. `fast-unit-tests` and `linting` are always required. Do not skip them.
3. `adversarial-review` required when the diff materially changes: route handlers, middleware, data models, migrations, auth flows, payment flows, service-layer contracts. Not required for: pure test additions, comment/docstring edits, typo fixes, config-only changes, documentation updates.
4. `silent-failure-audit` required alongside `adversarial-review` — same trigger criteria. Two independent subagent reviews surface different issues than one review alone.
5. `migration-rehearsal` required iff any migration file is added or modified.
6. `contract-snapshot` required iff any route or schema file is modified — the route shape may have changed.
7. `smoke-expand` required iff a new endpoint is added OR an endpoint's request/response shape changed. Not required for internal refactors.
8. `design-review` required iff UI code (not just copy) changed.
9. `security-review` required for: new admin endpoints, changes to auth/session/middleware, changes to security headers, changes to input validation.

Output a single JSON object on your FINAL line. No markdown fencing. Provide a brief rationale for every gate, whether required or skipped — future incident investigators read this. Be honest: if you're uncertain, say so and err toward the heavier set.

--- diff begins below ---
```

---

## Mapping to the review-sentinel system

- **Heavy-review sentinel** (`pre-pr-check.sh`) — still the mechanical gate at PR creation time. This skill decides whether you need to populate it.
- **`./mark_reviewed.sh --tier heavy`** — unchanged. The advisor's `adversarial-review: required` output is the signal to actually run the subagents and then mark.
- **`./scripts/sdlc-plan.sh`** — thin wrapper that emits the diff + catalog in a predictable shape.
- **`.claude/.review/<repo>.test-plan.json`** — the persisted plan. Not committed — this is per-PR, per-diff, ephemeral, mirrors the `.heavy` sentinel pattern.

---

## Interpreting adversarial-review findings

The main agent's job on any findings returned:

| Shape | Action |
|---|---|
| `verdict: "approve"`, zero findings | Ship. |
| `needs-attention`, confidence ≥ 0.7, critical path (auth/migration/payment/data/tenant-isolation) | **Must fix before PR.** No exceptions. |
| `needs-attention`, confidence ≥ 0.7, non-critical path | **Fix inline OR file a follow-up issue and link it in the PR body.** Never silently ignore. |
| `needs-attention`, confidence 0.4–0.7 | Evaluate. Usually fix. If disagreeing, record the rationale in the PR body so reviewers see the reasoning chain. |
| `needs-attention`, confidence < 0.4 | Document the disagreement in the PR body. Usually safe to ship, but the note is the audit trail. |

**The invariant that makes this trustworthy:** every finding has a disposition — fixed, follow-up issued, or rationale in the PR body. No silent ignoring. The advisor can be wrong sometimes; "I disagreed because X" is a legitimate response, "I disagreed silently" is not.

Record all adversarial findings + dispositions in the PR body under a `## Adversarial review findings` section. Post-mortems read this when a bug ships — if the advisor flagged it and was ignored without rationale, that's on the ignoring agent.

---

## What this skill does NOT replace

- **Pre-push hook** (`pre-push-check.sh`) — fast unit tests are always required. That gate is mechanical; the advisor doesn't override it.
- **Any post-merge CI** — the advisor decides gates at PR creation time, not after merge.

The advisor decides **optional extra gates**, not the mechanical baseline.

---

## Failure mode: advisor says skip and a bug ships

If the advisor says "skip heavy review" and a bug reaches prod that heavy review would have caught:

1. Post-mortem reads `.claude/.review/<repo>.test-plan.json` from the PR and sees the rationale. The failure is traceable.
2. Add the class of bug to the advisor prompt's rule set (e.g., "adversarial-review required when the diff touches the payments service").
3. The advisor's judgment improves over time as the rules accumulate.

This is the tradeoff. The blanket policy never misses this class but burns tokens every time. The advisor occasionally misses but costs much less.
