---
name: agent-experience-bar
description: Quality bar for building software surfaces that agents will use alongside humans. Use when designing or reviewing CLI commands, file structure, config shapes, docs, onboarding, dashboards, or any surface where "an agent would have to navigate this" is a real question. Enforces two non-negotiables: human appeal and agent usability, in the same product.
user-invocable: false
---

# Agent Experience Bar

> The agentic era doubles the bar. Products now have to satisfy two audiences at once — the human deciding whether to adopt, and the agent trying to get work done inside the product. A surface that wins one and loses the other is not done.

## Use This Skill When

- Evaluating whether a feature is ready to ship
- Designing or reviewing a CLI command (its shape, output, error messages)
- Designing or reviewing dashboard or GUI interactions
- Editing docs, onboarding, or repo/file structure that agents rely on
- Making scope decisions that touch website, dashboard, docs, or CLI
- Running a launch-readiness or polish pass

## The Thesis

There are two things that matter.

1. **A human lands on the product and wants to try it.**
   The website, docs, dashboard, and first-run experience are not support surfaces — they are the selling surface. They must create clarity, trust, and desire. The bar is not "works." The bar is "feels inevitable."

2. **An agent lands in the repo or CLI and can get work done.**
   The CLI, file structure, config model, and docs must feel obvious. An agent should be able to discover the right path without tribal knowledge or paper cuts. Output must be structured. Errors must name the fix.

If a change improves one side while degrading the other, it is not done.

## Non-Negotiables

### 1. Every capability exists in the CLI (or another agent-reachable surface)

- No UI-only capabilities for anything an agent might legitimately need to do.
- The UI may be the best discovery and inspection surface, but every action the UI can perform must also be reachable from a programmatic surface — CLI, API, or equivalent.
- Prefer one canonical command shape with strong `--json` / structured output over multiple overlapping commands doing the same thing.
- If a human can press a button, an agent can achieve the same outcome with a single tool call.

### 2. Agents discover the path on their own

- The CLI, file structure, and docs must work together as one system.
- Config lives in obvious files, with obvious names, in obvious places.
- Docs route to the moment of action, not dump theory and stop. A doc that ends with "and then you do the thing" without showing the command is a broken doc.
- Help text, command names, file names, repo layout, and UI labels use the same language. Three different words for the same concept is a bug.
- If an agent has to ask "where does this live?" or "which surface owns this?", the product is under-designed.

### 3. The UI is clean enough to sell the product

- The dashboard, landing page, and docs are part of go-to-market. Screenshots, demos, and first impressions matter.
- Layout, copy, empty states, loading states, and interactions should feel calm, precise, and high-trust.
- The reference bar is best-in-class modern SaaS polish — Linear, Notion, Vercel — not "shipped and works."
- Any UI that feels confusing, noisy, flimsy, or inconsistent is a product failure, not a minor polish item.

### 4. Paper cuts are not minor

- A repeated paper cut is a product bug, not a small annoyance.
- Fix the class of issue, not just the instance.
- Remove ambiguity, hidden state, and surprise.
- Error messages say what happened AND what to do next. "Something went wrong" is a failure mode, not an error message.
- Empty, loading, success, disabled, and failure states matter as much as the happy path. "Works but the loading state flashes" is a paper cut.

## What Great Looks Like

### For a human landing on the selling surface

- The website explains the product in under 30 seconds.
- The docs make the product model feel legible — they teach, not just reference.
- The dashboard looks like a serious product. Using it feels like buying in.
- The first path to value is obvious. No "follow these 12 steps to set up."

### For an agent landing in the repo or CLI

- The right command is easy to guess. (`<product> deploy`, `<product> logs`, `<product> env set`.)
- The config file is easy to find and named obviously.
- The docs point at the task, not at an abstraction.
- Output is structured, stable, and `--json`-friendly.
- The system has very few traps, dead ends, or hidden requirements.

## Launch Checks

Before shipping a product change, ask:

1. **Would this make someone more likely to try the product?**
   If this showed up in a screenshot, demo, or doc, would it increase trust?

2. **Would an agent know how to do this from the CLI and repo without hand-holding?**
   If not, the feature is incomplete.

3. **Is the ownership model obvious?**
   Dashboard, CLI, config file, and docs should reinforce one canonical path, not compete.

4. **Is there any paper cut left in the core path?**
   Confusing names, weak empty states, silent failures, missing confirmations, or generic errors all count.

5. **Does the UI feel good enough?**
   If the interaction feels cheap, awkward, noisy, or half-finished, it is not ready.

## Failure Patterns

Treat these as failures, not follow-ups:

- A feature exists in the dashboard but not the CLI.
- A feature exists in the CLI but docs do not route an agent to it.
- Config lives in surprising places or is split across too many surfaces.
- The dashboard uses vague language for an important action.
- Error states fall back to generic messages.
- Different surfaces use different words for the same concept.
- The happy path is polished, but loading, empty, failure, and permission states are rough.
- A workflow requires remembering hidden rules instead of reading them where the work happens.

## How To Use This In Practice

When touching a product surface, check the sibling surfaces too:

- New dashboard action → add or verify the CLI path, docs path, and naming parity.
- New CLI feature → verify docs route an agent to it and the dashboard uses the same language.
- New config concept → make the file ownership, docs, and UI explanation line up.
- Launch polish pass → review both the screenshot quality and the agent workflow quality.

Do not ship a surface-local win that creates cross-surface confusion.

## Short Version

Your product should look good enough that people want to try it, and feel obvious enough that agents prefer using it.

- Impressive but awkward for agents → fails.
- Powerful for agents but weak as a product people want to adopt → fails.
- Paper cuts, parity gaps, or confusing ownership → fails.

Both audiences, same product, same bar.
