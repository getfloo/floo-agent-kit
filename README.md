# floo-agent-kit

A scaffolding system for AI coding agents. Gives your agent persistent, context-aware memory of your codebase through a three-layer architecture: a CLAUDE.md/AGENTS.md constitution, domain-specific skills, and a knowledge base with hook-based routing.

Built by the [floo](https://getfloo.com) team.

---

## What This Is

Most AI agent setups are a flat CLAUDE.md with some rules. This goes further:

**Layer 1 — CLAUDE.md**
The constitution. Ethos, conventions, workflow. Always loaded. Contains the rules that shape everything the agent does in your project.

**Layer 2 — Skills (`.claude/skills/`)**
Behavioral rules for specific domains. When the agent touches Python code, it reads the Python skill. When it's about to deploy, it reads the deploy skill. Skills override general conventions for their domain. You write these for your stack — this kit doesn't include any, because the right rules depend entirely on what you're building.

**Layer 3 — Knowledge Base (`docs/knowledge/`)**
Canonical truth about how your system works. `index.yaml` maps code paths to KB articles. Before the agent edits a file, it reads the relevant article. After it edits, it's reminded to update the article if anything changed.

The hooks wire all three layers together automatically.

---

## What's Included

This kit ships Layer 1 (CLAUDE.md template) and Layer 3 (KB routing hooks + an empty starter index). Layer 2 is intentionally empty — you write skills for your own stack.

```
floo-agent-kit/
├── CLAUDE.md                       # Template — fill in the placeholder sections
├── .claude/
│   ├── settings.json               # Hook registration — copy and adapt
│   └── hooks/
│       ├── evaluate-skills.sh      # Lists available skills on every prompt
│       ├── knowledge-preflight.py  # Routes prompt → required KB articles
│       ├── knowledge-postflight.py # Reminds agent to update KB after code changes
│       ├── knowledge-track.py      # Tracks files touched per turn
│       └── pre-push-check.sh       # Blocks pushes without passing tests
└── docs/
    ├── knowledge/
    │   ├── index.yaml              # KB routing config — add entries for your codebase
    │   └── README.md               # How to add entries and write KB articles
    └── autonomous-loop.md          # How to wire up autonomous agent sessions
```

The hooks require Python 3 and Bash. Python code uses only the standard library, and no hook requires third-party packages.

---

## Adoption Tiers

### Tier 1 — CLAUDE.md template (5 minutes, zero setup)

Copy `CLAUDE.md` to your repo root. Fill in the placeholder sections. Done.

The soul rules (boil the ocean, UX-first, security as a lens) work in any codebase. The project-specific sections are clearly marked as placeholders.

### Tier 2 — KB routing (10-30 minutes)

Add the knowledge base and routing hooks. The agent now reads canonical docs before touching mapped code.

1. Copy `docs/knowledge/` to your repo
2. Edit `docs/knowledge/index.yaml` — add entries for your actual codebase
3. Write KB articles for your most complex domains (see `docs/knowledge/README.md` for the format)
4. Copy `.claude/hooks/knowledge-preflight.py` and `.claude/hooks/knowledge-track.py`
5. Register them in `.claude/settings.json` (copy the example in this repo)

### Tier 3 — Full system (30-60 minutes)

Everything in Tier 2, plus skills and the pre-push guard.

1. Copy `.claude/hooks/knowledge-postflight.py` and `.claude/hooks/evaluate-skills.sh`, register both
2. Copy `.claude/hooks/pre-push-check.sh` — edit `PRODUCTION_DIRS` and `TEST_COMMAND`, register it
3. Write skills for your stack in `.claude/skills/` — one directory per domain, each with a `SKILL.md`

---

## The Hooks

| Hook | Trigger | What it does |
|------|---------|-------------|
| `evaluate-skills.sh` | Every prompt | Lists available skills so the agent knows what to invoke |
| `knowledge-preflight.py` | Every prompt | Checks `index.yaml` and surfaces required reading based on prompt keywords |
| `knowledge-track.py` | After every tool use | Tracks which files and docs were touched this turn |
| `knowledge-postflight.py` | After code edits | Reminds the agent to update KB if mapped code was changed |
| `pre-push-check.sh` | Before `git push` | Blocks pushes to main without tests; requires test sentinel |

---

## The CLAUDE.md Soul Rules

Six rules in the template that shape how the agent approaches work:

- **Boil the ocean** — take the full scope, don't leave follow-ups that fall out of understanding the problem
- **Never offer small-option menus** — pick the best option and execute
- **UX/DX/AX first** — every decision starts with what the user experiences
- **Never be lazy** — ship code a distinguished engineer would be proud of
- **Security is a lens** — adversarial thinking throughout, not at the end
- **Ask important questions only** — don't ask before running tests; do ask before architecture decisions

---

## GitHub Template

This repo is a GitHub template. Click "Use this template" to create your own repo with this structure as a starting point.

---

## Before Publishing Your Adapted Repo

If you fork or adapt this kit into your own public repository, scrub both the working tree and Git history before release.

- Replace every placeholder in `CLAUDE.md`, especially project description, deployment, conventions, and skill routing.
- Add your own `docs/knowledge/index.yaml` entries only for domains you are comfortable documenting publicly.
- Keep secrets, customer names, internal hostnames, private paths, incident notes, and proprietary runbooks out of skills and KB articles.
- Search the current tree with terms such as `secret`, `token`, `password`, your company name, internal domains, and local filesystem paths.
- Check Git history too. Deleted files and old commit authors are still visible when an existing repository is made public.
- If history contains private material, publish from a fresh repository or rewrite history before opening access.

---

Built by the [floo](https://getfloo.com) team.
