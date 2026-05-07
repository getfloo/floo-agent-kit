# floo-agent-kit

Built by the [floo](https://getfloo.com) team. floo is the best place for agents to build and deploy software. We use this kit internally to ship high-quality software with agents.

A reference guide of the patterns we've proven in production: engineering guideline skills, a tiered code-review system, a security-review workflow, and a three-layer context architecture for keeping the agent's knowledge of your codebase coherent.

**Take one piece, take a few, take all of it.** Nothing here is all-or-nothing — every skill, hook, and doctrine section is independently adoptable. Copy what helps, ignore what doesn't, adapt the rest. **Star the repo** if you want to catch updates as we push them; this kit evolves as we learn.

---

## Apply this to your repo

Open your coding agent in the root of the repo you want to upgrade, and paste this prompt. Most of the kit (skills, doctrine, three-layer context) is agent-agnostic, but the hook reference implementations target Claude Code's hook lifecycle — other harnesses don't expose hooks the same way, so those pieces will need a port (see "Harness compatibility" below).

```text
Read the floo-agent-kit at https://github.com/getfloo/floo-agent-kit — start
with its README.md, AGENTS.md, and INDEX.md, then skim .claude/skills/,
.claude/hooks/, and .claude/lib/.

Then look at MY repo: what's already in AGENTS.md / CLAUDE.md (if anything),
what hooks exist under .claude/ (if any), what review and test setup is in
place, what the stack is, and which paths are sensitive (auth, routes,
schemas, migrations, deploy pipeline).

Produce a written plan — no edits yet — ranked by leverage, of which kit
pieces are worth adopting here and how each one would adapt to this
codebase. For each recommendation:

- name the kit file
- one-sentence summary of what it does
- WHY it's worth adopting, given what you saw in my repo
- the specific adaptation (path patterns to change, hook commands to swap
  in, doctrine to drop or rewrite)

Also flag pieces NOT worth adopting — already covered, doesn't fit the
stack, or too heavy for the team's current size.

Wait for me to approve before making any changes.
```

The agent will read the kit, scan your repo, and come back with a ranked plan. You decide what to adopt; nothing changes until you say so.

---

## Harness compatibility

The **patterns** here (tiered review, advisor-selected SDLC gates, agent-experience bar, security-review checklist, three-layer context) are agent-agnostic. They work with any AI coding agent.

The **reference implementations** of the hooks target Claude Code's hook lifecycle (`Stop`, `PreToolUse`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`) and use `.claude/settings.json` for wiring. If you run Codex, Cursor, or another harness, the hook scripts themselves need a small port, but the sentinel logic (`mark_reviewed.sh`, `.claude/lib/repo-state.sh`) is pure Bash and works anywhere.

The constitution file is `AGENTS.md` (with `CLAUDE.md` as a symlink so Claude Code picks it up too) — the standard cross-agent filename convention.

---

## What this is

A **reference library** for teams building with AI coding agents. The patterns are the ones that survived real production use. You read, decide, borrow.

## What this is NOT

- Not a framework. No CLI, no `install` step, no runtime.
- Not mandatory. Every piece is independently adoptable; the set is not all-or-nothing.
- Not a substitute for your own thinking. The patterns scale across stacks; the specifics won't.

## Who this is for

Teams shipping production software with AI coding agents, who want agent behavior that's reviewable, attested, and hard to fool. If your current agent setup is a single `AGENTS.md` and you're wondering "what else is worth adding?", start here.

---

## Index — file → topic

The fastest way to navigate. Each row points at one idea; open it if it's relevant.

| Topic | Where | Read when |
|---|---|---|
| How we think about agent work (ethos, conventions) | [`AGENTS.md`](./AGENTS.md) | First. |
| Three-layer context architecture | [`README.md`](#three-layer-context) (below) + [`docs/knowledge/README.md`](./docs/knowledge/README.md) | Right after. |
| Engineering guideline skills | [`.claude/skills/README.md`](./.claude/skills/README.md) | Pick what's relevant. |
| Tiered review pattern (self-review + heavy-review sentinels) | [`.claude/hooks/README.md`](./.claude/hooks/README.md) + [`mark_reviewed.sh`](./mark_reviewed.sh) | If you want the agent to self-attest before ending a turn. |
| Slash commands (incl. `/security-review`) | [`.claude/commands/README.md`](./.claude/commands/README.md) | If you're shipping security-sensitive code. |
| Plan-mode founder review | [`.claude/skills/plan-ceo-review/SKILL.md`](./.claude/skills/plan-ceo-review/SKILL.md) | When reviewing plans / designs. |
| Advisor-selected SDLC gates | [`.claude/skills/sdlc-plan/SKILL.md`](./.claude/skills/sdlc-plan/SKILL.md) + [`scripts/sdlc-plan.sh`](./scripts/sdlc-plan.sh) | When every PR runs every check and you want it smarter. |
| Agent-experience quality bar | [`.claude/skills/agent-experience-bar/SKILL.md`](./.claude/skills/agent-experience-bar/SKILL.md) | When building CLI / API surfaces agents will use. |
| Security-review checklist | [`.claude/skills/security-review/SKILL.md`](./.claude/skills/security-review/SKILL.md) + [`.claude/commands/security-review.md`](./.claude/commands/security-review.md) | Before auth/middleware/schema changes ship. |
| Autonomous agent loops | [`docs/autonomous-loop.md`](./docs/autonomous-loop.md) | If running long-running agent sessions. |
| KB routing hooks | [`docs/knowledge/README.md`](./docs/knowledge/README.md) + [`.claude/hooks/knowledge-*.py`](./.claude/hooks) | If you want the agent to auto-read docs when touching mapped code. |

A machine-readable duplicate of this table lives in [`INDEX.md`](./INDEX.md).

---

## Three-layer context

Most AI agent setups are a single constitution file with some rules. This kit organizes agent context into three layers so the rules scale as the codebase grows.

**Layer 1 — `AGENTS.md`**
The constitution. Ethos, conventions, workflow. Always loaded. Shapes everything the agent does. (`CLAUDE.md` is a symlink to this file so Claude Code loads it automatically.)

**Layer 2 — Skills (`.claude/skills/`)**
Behavioral rules for specific domains. When the agent touches Python code, it loads the Python skill. When it's reviewing a plan, it loads the plan-review skill. Skills tell the agent *how to act* in a given context.

**Layer 3 — Knowledge Base (`docs/knowledge/`)**
Canonical truth about how your system actually works. An `index.yaml` maps code paths to articles; when the agent is about to edit a mapped file, a preflight hook routes it to the relevant article first. KB tells the agent *how things work*.

The hooks wire all three layers together. Skills + KB + hooks compose.

---

## What's included

Everything is ship-as-you-want. No piece depends on another except where noted.

```
floo-agent-kit/
├── AGENTS.md                          # Layer 1 — constitution (primary)
├── CLAUDE.md                          # Symlink to AGENTS.md (Claude Code compat)
├── README.md                          # You are here
├── INDEX.md                           # Machine-readable file-to-topic map
├── mark_reviewed.sh                   # Review-sentinel writer
│
├── .claude/
│   ├── settings.json                  # Hook registrations (Claude Code format)
│   ├── lib/
│   │   └── repo-state.sh              # Tier classifier + diff hasher (shared)
│   ├── hooks/
│   │   ├── README.md                  # What each hook does
│   │   ├── evaluate-skills.sh         # Lists available skills per prompt
│   │   ├── knowledge-preflight.py     # Routes prompt → required KB articles
│   │   ├── knowledge-track.py         # Tracks files/docs touched per turn
│   │   ├── knowledge-postflight.py    # Reminds agent to update KB after edits
│   │   ├── pre-push-check.sh          # Blocks push without recent tests
│   │   ├── stop-review-check.sh       # Blocks Stop without self-review
│   │   ├── pre-pr-check.sh            # Blocks `gh pr create` without heavy review
│   │   ├── branch-guard.sh            # Blocks direct edits to main workspace
│   │   └── memory-guard.sh            # Warns on auto-memory directory drift
│   ├── skills/
│   │   ├── README.md
│   │   ├── plan-ceo-review/           # Founder-mode plan critique
│   │   ├── sdlc-plan/                 # Advisor-selected SDLC gates
│   │   ├── agent-experience-bar/      # Product quality bar for agents
│   │   └── security-review/           # Security checklist for a diff
│   └── commands/
│       ├── README.md
│       └── security-review.md         # /security-review slash command
│
├── scripts/
│   └── sdlc-plan.sh                   # Emits diff + gate catalog for advisor
│
└── docs/
    ├── autonomous-loop.md             # Wiring up autonomous agent sessions
    └── knowledge/
        ├── index.yaml                 # KB routing config (you fill this in)
        └── README.md                  # How to add KB articles
```

The hooks require Python 3 (stdlib only), Bash, and `jq`.

---

## Adoption, a la carte

This kit is not tier-by-tier. Take one piece, take all of them, take the ideas and write your own.

**Starter moves, ranked by leverage:**

1. Copy `AGENTS.md` and fill in the placeholders. The soul rules (boil the ocean, UX-first, security as a lens) work in any codebase.
2. Adopt the tiered review pattern: copy `mark_reviewed.sh`, `.claude/lib/repo-state.sh`, `.claude/hooks/stop-review-check.sh`. Register the Stop hook for your harness. The agent now has to read its own diff before ending the turn.
3. Add the `plan-ceo-review` skill. Plan quality is where most of the leverage lives.
4. Add KB routing once you have a few domains stable enough to document.

Or borrow none and just read through `.claude/skills/` + `.claude/hooks/` for ideas.

---

## Before adapting this into your own public repo

If you fork this kit and open it to the public, scrub both the working tree and Git history before release.

- Replace every placeholder in `AGENTS.md`, project description, conventions, deployment, skill routing.
- Edit `docs/knowledge/index.yaml` for your codebase; only add entries for domains you're willing to document publicly.
- Keep secrets, customer names, internal hostnames, private paths, incident notes, and proprietary runbooks out of skills and KB articles.
- Search the tree with terms like your company name, internal domains, local filesystem paths.
- Check Git history too. Deleted files and old commit authors are still visible once a repo is public.
- If history contains private material, publish from a fresh repository or rewrite history before opening access.

---

## Use this template

This repo is a GitHub template. Click "Use this template" to create your own starting point, then strip what you don't need.

If this kit saves you time, star the repo. We push updates as we learn.

---

Built by the [floo](https://getfloo.com) team.
