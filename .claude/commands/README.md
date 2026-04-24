# `.claude/commands/` — slash commands

Slash commands are user-triggered workflows. When the user types `/<name>`, the agent loads the corresponding `<name>.md` file as instructions and executes it.

This kit ships one command as a reference implementation. Build your own for the workflows you run often.

## What's here

### `/security-review`
Runs a structured security review against the current branch's diff. Flow:

1. Compute the diff (`git diff <base>...HEAD`).
2. Filter to security-relevant files using `../lib/repo-state.sh`'s `classify_path`.
3. Spawn a skeptic-role security-auditor subagent with the checklist from `../skills/security-review/SKILL.md`.
4. Report findings as a structured report.
5. On SHIP verdict, offer to run `./mark_reviewed.sh --tier heavy` — the heavy-review sentinel.

See `security-review.md` for the full spec. The skill in `../skills/security-review/` owns the checklist; the command owns the spawn-and-report workflow.

## The command pattern

A slash command is a markdown file with frontmatter:

```yaml
---
description: One-line summary shown in the command list
argument-hint: [optional argument shape]
---

# /your-command

Instructions for the agent when this command fires. Usually:
1. What to read / compute
2. What subagent(s) to spawn, if any
3. What output format to produce
4. What side effects (writes, commits, sentinels) are allowed
```

The body is the prompt the agent follows. Keep commands focused — one workflow per command.

## When to build a new slash command vs a new skill

- **Skill** = behavioral rule the agent loads when a domain applies. "When you're writing Python, do X." Invoked automatically or by the agent's judgment.
- **Slash command** = workflow the user triggers explicitly. "Run this 5-step process now." Always user-invoked.

A skill can invoke a slash command (see `../skills/sdlc-plan/SKILL.md`, which calls `/security-review` as one of its gates). A slash command can reference a skill (see `security-review.md`, which uses the checklist from `../skills/security-review/SKILL.md`). They compose.
