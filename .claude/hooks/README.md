# `.claude/hooks/` — reference hook implementations

The files here are the hooks the floo team uses to gate agent behavior. They are **reference implementations**, not a framework. Copy what helps, delete what doesn't, tune the path patterns to your stack.

## Harness target

These hooks are wired for **Claude Code's hook lifecycle** (`Stop`, `PreToolUse`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`) and registered in `.claude/settings.json`. They read the `$CLAUDE_PROJECT_DIR` env var and hook-input JSON on stdin.

If you run Codex, Cursor, or another harness:
- The **sentinel logic** (`../lib/repo-state.sh`, `../../mark_reviewed.sh`) is pure Bash with no harness dependency. Works anywhere.
- The **hook scripts** need a port: replace `$CLAUDE_PROJECT_DIR` with your harness's equivalent, adapt the hook-input parsing, and wire them into your harness's pre/post-tool lifecycle.
- The **patterns** (self-review sentinel, heavy-review sentinel, tier classifier) are the parts worth copying even if the scripts aren't.

## What each hook does

### `evaluate-skills.sh` — UserPromptSubmit
Lists available skills at the top of every prompt so the agent knows what to invoke. Ships as-is; no customization needed unless you want to change how skills are discovered.

### `knowledge-preflight.py` — UserPromptSubmit
Reads `docs/knowledge/index.yaml` and surfaces required KB reading based on prompt keywords. Edit your `index.yaml` to match your codebase; the hook is generic.

### `knowledge-track.py` — PostToolUse (Read|Write|Edit|MultiEdit|Bash)
Records every file the agent touches in this turn. Feeds `knowledge-postflight.py`. Keep it — zero customization.

### `knowledge-postflight.py` — PostToolUse (Write|Edit|MultiEdit)
Reminds the agent to update a KB article when code mapped to that article was edited. Works in tandem with `knowledge-preflight.py`.

### `pre-push-check.sh` — PreToolUse (Bash)
Blocks `git push` when local tests haven't been run recently. Edit the `TEST_COMMAND` / `PRODUCTION_DIRS` constants inside the script for your stack.

### `stop-review-check.sh` — Stop
Blocks turn-end when the current diff is unreviewed. Checks for a `.self` sentinel in `.claude/.review/` keyed by the diff hash. The agent clears the gate by running `./mark_reviewed.sh`.

**This is the core of the tiered review pattern.** If you adopt only one non-trivial hook from this kit, adopt this one. See `../lib/repo-state.sh` for the tier classifier it depends on.

### `pre-pr-check.sh` — PreToolUse (Bash)
Blocks `gh pr create` when the branch diff touches sensitive-tier files and no `.heavy` sentinel exists. The agent clears the gate by running subagent-based heavy review and then `./mark_reviewed.sh --tier heavy`.

### `branch-guard.sh` — PreToolUse (Write|Edit|MultiEdit)
Blocks direct edits to production code in the main workspace — forces the agent into a worktree on a feature branch. Exempt paths (docs, config, skills) can still be edited directly.

### `memory-guard.sh` — SessionStart
Prints a warning at session start if files have accumulated in Claude Code's auto-memory directory. Encourages migration into the three-layer system (AGENTS.md / skills / KB) rather than a hidden fourth layer. **Claude Code-specific** — skip or port if your harness uses a different memory mechanism.

## The tiered review pattern in one paragraph

Every diff is classified as `exempt` (no gate), `standard` (self-review gate at Stop), or `sensitive` (heavy subagent review gate at PR creation). The classifier is in `../lib/repo-state.sh`. Two sentinel files in `.claude/.review/` record "I reviewed the diff with hash X": `.self` (main agent attests) and `.heavy` (subagents reviewed and agent addressed findings). `mark_reviewed.sh` writes the sentinels; the hooks read them.

The value is that review becomes **mechanical and attested**. The agent cannot end the turn without reading its own diff. It cannot ship a sensitive PR without running the review pair. The sentinels make the attestation explicit and tamper-evident (they break the moment the diff changes).

## Adopting one hook at a time

- Just want "agents must read their diff before ending the turn"? Copy `stop-review-check.sh`, `mark_reviewed.sh`, and `../lib/repo-state.sh`.
- Want to add "sensitive PRs require subagent review"? Additionally copy `pre-pr-check.sh`.
- Want to keep `main` clean from direct edits? Additionally copy `branch-guard.sh`.

Each is independent. Don't feel obligated to take the whole set.

## Dependencies

- `jq` is required for hooks that parse hook-input JSON. On macOS: `brew install jq`. On Debian/Ubuntu: `apt install jq`.
- `python3` is required for the `knowledge-*.py` hooks and `branch-guard.sh` (one line).
- No third-party Python packages required. Standard library only.
