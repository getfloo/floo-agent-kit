---
description: Security review of the current branch diff. Reads the diff, spawns an adversarial security auditor subagent, reports findings. On approval, writes the heavy-review sentinel.
argument-hint: [optional base ref, defaults to origin/main]
---

# /security-review

Run a structured security review against the current branch's diff.

## Flow

1. **Compute the diff surface.**
   Use `git diff <base>...HEAD` where `<base>` defaults to `origin/main`. If the user supplied an argument, use it as the base.

   ```bash
   git fetch origin main --quiet 2>/dev/null || true
   BASE="${ARGUMENTS:-origin/main}"
   git diff "$BASE"...HEAD --name-only
   git diff "$BASE"...HEAD
   ```

2. **Filter to security-relevant files.**
   Source `.claude/lib/repo-state.sh` and use `classify_path` to identify sensitive-tier files. If no files in the diff are sensitive-tier, report that and exit without spawning a subagent — there's nothing to review.

3. **Spawn the adversarial security auditor.**
   Use the Agent tool with `subagent_type: general-purpose`. Prompt the subagent with the checklist from `.claude/skills/security-review/SKILL.md` plus the branch diff.

   Frame the subagent's role as **skeptical security auditor**. Its job is to find reasons the diff should NOT ship, not to rubber-stamp. The prompt should end with: *"Return a structured report in the output format defined in the SKILL.md. Be specific: file and line for every finding. Be honest: state PASS when a section looks clean."*

4. **Report findings.**
   Relay the subagent's report to the user. Do not summarize — paste the full structured report.

5. **Act on the verdict.**
   - **SHIP** with zero critical or high findings: offer to run `./mark_reviewed.sh --tier heavy` on the user's behalf. Do not run it without confirmation.
   - **SHIP WITH FIXES** or **DO NOT SHIP**: do NOT write the sentinel. List the fixes. Let the user direct the fix work. After fixes land, the user re-runs `/security-review`.

## Why a subagent

Running the review in the main agent context means the agent that wrote the code is also the agent that reviews it. A subagent with a cleaner context and a skeptic role is harder to self-justify to. Separate context, separate judgment.

## What this command does NOT replace

- It does not replace `adversarial-review` from the `sdlc-plan` gate catalog. That's a broader review (bugs, silent failures, architecture). `security-review` is specifically the attack-surface checklist.
- It does not decide whether the PR is "secure enough." It structures the review and gates the sentinel. The human + the agent together decide.

## Pairing with `sdlc-plan`

When the `sdlc-plan` advisor says `security-review: required`, invoke this command before `./mark_reviewed.sh --tier heavy`. The advisor names the gate; this command runs it.
