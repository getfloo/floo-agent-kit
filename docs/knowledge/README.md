# Knowledge Base

This directory contains canonical documentation about how your system works. It is the source of truth that Claude reads before touching the corresponding code.

## How It Works

`index.yaml` maps code paths to KB articles. When Claude is about to edit a file, the `knowledge-preflight.py` hook checks whether that file maps to a KB domain. If it does, Claude reads the article first.

When Claude edits mapped code, the `knowledge-postflight.py` hook reminds it to update the article if anything changed.

## Adding an Entry

Add a new object to the `entries` array in `index.yaml`:

```json
{
  "id": "billing",
  "kind": "domain",
  "description": "Billing, subscriptions, and payment processing.",
  "prompt_keywords": ["billing", "subscription", "payment", "stripe", "invoice"],
  "code_globs": ["src/billing/**", "src/routes/billing*"],
  "test_globs": ["tests/test_billing*"],
  "read_first": ["docs/knowledge/billing.md"],
  "invariants": [
    "Never charge a user without an explicit confirmation event.",
    "All payment amounts are stored in cents (integer), not dollars (float)."
  ]
}
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier for this domain |
| `kind` | Yes | `"domain"` (data model) or `"flow"` (process) |
| `description` | No | One-line description |
| `prompt_keywords` | Yes | Words in the user's prompt that trigger this entry |
| `code_globs` | Yes | Glob patterns for source files in this domain |
| `test_globs` | No | Glob patterns for test files |
| `read_first` | Yes | KB articles to read before touching this code |
| `invariants` | No | Statements that must remain true — Claude will be reminded to preserve them |

## Writing KB Articles

A KB article is a Markdown file in this directory. It should answer: **what is true about this domain that a developer needs to know before changing it?**

Good KB articles contain:
- Data model overview (what the key entities are and how they relate)
- Invariants (what must always be true)
- Non-obvious constraints (things that aren't visible in the code alone)
- Historical decisions (why things are the way they are)

**Update contract:** If you change behavior, invariants, or contracts described in a KB article, update the article in the same commit. The article is wrong until you update it.

## Article Template

Create KB articles following this structure:

```markdown
# [Domain Name]

## Overview
[1-3 sentences: what this is and why it exists]

## Data Model
[Key entities and how they relate]

## Invariants
[Numbered list of things that must always be true]

## Non-obvious Constraints
[Anything that would surprise a developer unfamiliar with this code]

## Common Mistakes
[What people get wrong and why]
```
