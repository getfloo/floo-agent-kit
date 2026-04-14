# The Autonomous Loop

An autonomous loop lets Claude work independently on long-running tasks, pausing to ask questions or surface blockers via a message channel, then continuing.

This is a pattern, not a working implementation — the specifics depend on your communication channel (Slack, Discord, GitHub Issues, a webhook). This doc describes the concept so you can wire it up for your stack.

---

## The Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    Autonomous Loop                       │
│                                                          │
│  1. Claude starts work on a task                         │
│  2. Hits a decision point or blocker                     │
│  3. Posts question to message channel                    │
│  4. Continues working on something else (or sleeps)      │
│  5. Polls channel for replies                            │
│  6. Reads reply, resumes blocked task                    │
│  7. Repeat                                               │
└─────────────────────────────────────────────────────────┘
```

The key insight: Claude should **never stop working because it hit one blocker**. It should post the question, move to unblocked work, and check for replies periodically.

---

## What To Escalate vs What To Decide Alone

**Decide alone (no escalation needed):**
- Which file to edit
- How to structure a test
- Whether to add a helper function
- Fixing a lint error

**Post and keep working (non-blocking):**
- "I found a bug in a related area while fixing X — should I fix it now or file an issue?"
- "There are two approaches here, I'll go with A, let me know if you'd prefer B"
- "I'm about to refactor Y — just FYI"

**Post and wait (blocking):**
- Missing credentials (API key, database access, cloud auth)
- Architecture decision that would be expensive to reverse
- Destructive operations (deleting data, force-pushing, dropping tables)
- "Am I solving the right problem?"

---

## Wiring It Up

### Slack

1. Create a Slack app with a bot token and write permissions to a channel
2. Use the Slack MCP server or raw API to post and read messages
3. In your CLAUDE.md, add:

```markdown
**When you need help:** post to Slack `#your-channel`, then continue working on something else.
Check the channel for responses every 20-30 minutes when idle.
```

4. Store the channel ID and bot token as environment variables

### Discord

Same pattern — use the Discord API or an MCP server to post to a channel.

### GitHub Issues

Post a comment on the issue being worked on. Check for replies by polling the issue's comment thread.

### Webhook / Custom

POST to any endpoint you control. Poll a GET endpoint for replies. Works for custom dashboards, mobile apps, or any notification system.

---

## Polling Interval

- **Active task in progress:** no polling needed, Claude is working
- **Waiting on a reply:** check every 10-15 minutes
- **Idle (no active task):** check every 20-30 minutes

Never poll faster than necessary. Never stop polling unless the user explicitly says to.

---

## The Rule That Makes It Work

**Never stop the loop because you think the user is done for the day.**

If there's work queued, keep working. If there's nothing to work on, wait. If you've been idle for a while and there's nothing in the channel, schedule a check for 20-30 minutes later. The user will tell you when to stop — you don't decide that.

---

## Example CLAUDE.md Additions

```markdown
## Autonomous Mode

When working autonomously:

**When you need help:** post to [your channel], then continue working on something else.
Check the channel for responses every 20 minutes when idle.

**What to escalate:**
- Missing credentials → post and WAIT (do not work around it)
- Architecture decisions → post and continue with your best judgment, flag it
- Destructive operations → post and WAIT for explicit approval

**Never stop the loop.** Even if idle, schedule the next check. The user decides when to stop.
```
