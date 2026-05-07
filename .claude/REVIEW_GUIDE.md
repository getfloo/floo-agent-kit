# Review Guide

> **Single source of truth for the pre-PR review policy.** The agent reads this before `gh pr create` to pick the right `mark_reviewed.sh` tier. `AGENTS.md` points here — never duplicate the decision tree elsewhere.

---

## How review works

Two gating sentinels live in `.claude/.review/<repo>/`:

| Sentinel | Written by | Means |
|---|---|---|
| `.self` | `--tier self` (default) | End-of-turn agent attestation. Cleared between turns. |
| `.heavy` | `--tier heavy` | Adversarial review (code-reviewer + silent-failure-hunter subagents) attested clean on this exact diff. |

Both sentinels store a content-addressable hash of the diff. Any new commit invalidates them and re-fires the gate — there's no way to stale-pass a review.

For **sensitive-tier** diffs, `pre-pr-check.sh` requires `.heavy` to hash-match the current branch diff before `gh pr create` is allowed. Standard-tier diffs only need `.self`. Exempt-tier diffs (docs, lockfiles, test-only edits) skip both.

---

## Run reviewers in parallel — always

When a sensitive diff needs `.heavy`, kick the reviewer subagents off **concurrently** in a single message:

1. A `code-reviewer` subagent (your harness's adversarial-reviewer agent)
2. A `silent-failure-hunter` subagent (or equivalent — auditor for swallowed errors and inappropriate fallbacks)

Two independent reviews on the same diff surface different issues. Running them serially wastes wall-clock for no reason — they don't interact. The doctrine is **always parallel.**

When both return, address findings together. If the fix introduces new commits, re-run the same pair in parallel — each new commit invalidates the sentinel.

> **Doctrine: a second reviewer of a different model family.** Two reviewers from the same model family share priors and miss the same things by definition. The strongest pattern we've found is to add a third reviewer running on a *different* family (Claude + GPT-* via Codex CLI, or Claude + Gemini, etc.) and gate sensitive PRs on both attesting clean. The kit ships the single-family baseline; if you want to add the sentinel-pair model, see "Adding a second-reviewer family" below.

---

## Decision tree

Apply in order. The first rule that matches wins.

### Rule 1 — exempt-tier diffs (no review required)

If the diff is **only** docs (`docs/`, `*.md`, `*.mdx`), the kit's `.claude/` skills/hooks/policy, lockfiles, or test-only edits → `gh pr create` proceeds with no review tier.

The hook auto-detects via `classify_path()` and skips the gate.

### Rule 2 — standard-tier diffs (self-review only)

Product code outside the sensitive paths in Rule 3 → `gh pr create` proceeds with the default `--tier self` sentinel only. The pre-pr hook auto-detects and exits.

### Rule 3 — sensitive-tier diffs (heavy review required)

Sensitive paths should be mirrored in `.claude/lib/repo-state.sh` → `classify_path()`. Customize for your stack — the kit ships an illustrative classifier that catches:

- HTTP route / endpoint handlers (your contract with the outside world)
- Data models, schemas, database migrations
- Auth, session, token, encryption code
- Reverse proxies, gateways, ingress middleware

Other patterns worth promoting once you have the bandwidth (the kit's classifier doesn't promote these by default, but most production teams will want to):

- Frontend API clients (wire protocol with backend)
- CI workflow files (`.github/workflows/**`), `dependabot.yml`, `CODEOWNERS` — small files, big blast radius

The classifier is the source of truth — if you add a sensitive path here, add it to `classify_path()` too.

#### Rule 3a₀ — plan-stage review (advisory, BEFORE writing code)

**Use when ANY of these apply:**

- You're adding a new entry point (route, webhook handler, CLI command) that mirrors an existing one. The new path inherits the existing path's invariants by default — explicitly enumerate what those invariants are.
- The change crosses an auth boundary (different auth handle than adjacent code).
- The change touches multiple config shapes (multiple file types, env-override precedence, schema migrations).
- The change introduces new state transitions with safety implications.
- You're about to write more than ~100 lines of logic before getting a review.

**The pattern:** before opening any code editor, write a 200–500 word plan (paste it inline into the agent prompt or save as `PLAN.md`) that names:

1. **Inherited invariants** — what does the adjacent code path enforce, and which of those does my change need to mirror?
2. **Trust boundary diff** — who can trigger this code path vs. the existing one? What's the gap, and what asymmetric rule closes it?
3. **Cross-config shapes** — which file shapes does the existing surface read? Which does the new surface need to read?
4. **State transitions** — enumerate every (current, requested) pair and decide which are valid.
5. **Atomicity contract** — for each failure mode, list which side effects must NOT survive the failure.

Run that plan through review **before** implementation. A silent-failure-hunter on a 300-word plan catches a different class of bug than the same agent on a 600-line PR — and structural mistakes are ~10× cheaper to fix at planning time than during code review.

After plan review passes, proceed to Rule 3a.

#### Rule 3a — first-pass sensitive (no prior `.heavy` exists)

```
PARALLEL:
  Agent: your code-reviewer subagent (skeptic posture)
  Agent: your silent-failure-hunter subagent (audits swallowed errors)
THEN:
  Address all findings, re-run tests.
  ./mark_reviewed.sh --tier heavy
  If diff changed, restart from PARALLEL.
  gh pr create
```

#### Rule 3b — follow-up commits (rereview vs full)

After Rule 3a's `.heavy` exists, follow-up commits invalidate it. Decide rereview vs full re-review by **shape, not line count**:

**Rereview-OK iff ALL of these hold:**

1. The follow-up touches *only* lines flagged by the prior review (or directly adjacent lines required to land the fix — e.g., a new guard inserted between two flagged lines).
2. No new functions, new files, new control-flow branches, or new top-level constants the prior review didn't see.
3. New tests are *only* regression guards for the named findings, not coverage for unrelated logic.

**Default to full when in doubt.** The asymmetry is deliberate: rereview-when-full-was-needed lets a bug ship through. Full-when-rereview-was-fine costs a few minutes and some tokens. Optimize for catching bugs.

| Follow-up shape | Tier |
|---|---|
| Reverted one flagged line; added a one-liner regression test | rereview |
| Added a 5-line guard inside a function the prior review saw, plus a regression test | rereview |
| Added a new helper function (even small) called from the original code | **full** — review hasn't seen the helper |
| Closed a finding by introducing a new error branch with new copy and new tests | **full** — new logic |
| Closed a finding *and* added an unrelated test for a different module | **full** — second test isn't a regression guard |
| Doc-only change responding to a finding | rereview (no logic delta) |

The kit's baseline `mark_reviewed.sh` doesn't model rereview as a separate sentinel — every `--tier heavy` overwrites the previous `.heavy`. If you want chain-of-trust rereview tiers (so a rereview can't skip the initial heavy review), see "Adding rereview tiers" below.

### Rule 4 — never skip these

- `pre-push-check.sh` (test recency) — always runs.
- `branch-guard.sh` (worktree enforcement) — never overridable.
- `stop-review-check.sh` (self-review attestation) — always required at end-of-turn.

---

## Why this design

Earlier iterations tried to have a "gatekeeper" subagent write a JSON verdict file the hook would trust. Most agent-harness permission systems correctly identify that pattern as self-bypass and block the verdict-file writes. The sentinel-based design uses `mark_reviewed.sh` (a permission-allowed mechanism) as the only sentinel-writer:

1. The `.heavy` sentinel is an agent attestation that the review actually ran. Trust depends on the agent being honest about having run the review — same risk profile as any agent attestation.
2. To raise the trust floor, run an inline-verified review: have `mark_reviewed.sh` actually invoke a reviewer command (e.g. a CLI for a different model family) and write the sentinel only on clean exit. Now the sentinel is verified-not-self-reported.

Sentinels are content-addressable: they store a hash of the diff, so any new commit invalidates them and re-fires the gate.

---

## Adding a second-reviewer family (optional)

Two reviewers from the same model family miss the same things by definition. Adding a second family — Claude + GPT-*, Claude + Gemini, etc. — catches an uncorrelated set of bugs. The pattern:

1. Add a `--tier secondary` to `mark_reviewed.sh` that writes `.heavy.secondary`.
2. Have it invoke a configured CLI inline (read `KIT_SECONDARY_REVIEW_CMD` from env, or hardcode your CLI). Write the sentinel **only on clean exit.** This makes the second review *verified*, not self-reported.
3. Update `pre-pr-check.sh` to require BOTH `.heavy` AND `.heavy.secondary` for sensitive diffs.
4. Run the primary reviewers AND the secondary review in parallel — most second-family CLIs take 4–6 minutes wall-clock vs. 30–90 seconds for inline subagents, so serialize-cost is real. Kick the secondary off as a backgrounded `Bash` call alongside the foreground subagent calls.

When both attestations match the current branch-diff hash, the gate clears.

## Adding rereview tiers (optional)

If you find your follow-up commits are mostly small and the rereview/full shape rule applies cleanly, add `--tier rereview` (and `--tier secondary-rereview` if you have a second family) that:

1. Requires the `.heavy` sentinel to already exist (chain-of-trust).
2. Records the previous `.heavy` SHA so the gate can verify the rereview only covers commits since then.
3. Invokes the reviewer with `--base <prior-sha>` so it only reads the delta.

This makes follow-up rounds ~5× cheaper for the right shape. Without it, every commit forces a full re-review. The kit doesn't ship this by default because it's an optimization for repos with frequent multi-round PRs.

---

## Tuning the policy

To change what's sensitive: edit Rule 3's path list AND `classify_path()` in `.claude/lib/repo-state.sh` (the hook reads the latter — keep them in sync). To change the rereview decision: edit Rule 3b's table. To require additional skills on certain diffs: add a new advisory rule.
