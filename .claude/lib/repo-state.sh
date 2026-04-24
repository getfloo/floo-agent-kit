#!/usr/bin/env bash
# Shared helpers for the review-sentinel machinery. Sourced by:
#
#   - .claude/hooks/stop-review-check.sh  (reads sentinels at turn end)
#   - .claude/hooks/pre-pr-check.sh       (reads sentinels at PR creation)
#   - mark_reviewed.sh                    (writes sentinels)
#
# Keeping every consumer here guarantees they hash the same bytes — if they
# drift, mark_reviewed.sh would happily write a hash the hook never matches,
# and the agent would be blocked forever with no way out.
#
# ── HOW TO ADAPT TO YOUR REPO ───────────────────────────────────────────────
# Edit `classify_path()` below. The case patterns you see are illustrative,
# not prescriptive. The tiering PHILOSOPHY below the divider is what actually
# matters — follow it, tune the patterns to your codebase, and the hooks will
# do the right thing.

# ── Tiered classifier ───────────────────────────────────────────────────────
#
# Every changed file falls into one of three tiers:
#
#   exempt    — docs, config, lockfiles, markup/copy, assets. No review gate.
#   standard  — typical product code. Self-review gate at turn end.
#   sensitive — routes, models, schemas, migrations, auth, middleware, SQL.
#               Heavy review gate at PR creation.
#
# Tiering philosophy: a false-negative on "sensitive" (e.g. a new auth route
# slipping into the standard tier) is the expensive mistake — you'd merge it
# without heavy review. A false-positive (e.g. a refactor that's really
# standard but got bucketed sensitive) is only a friction cost. So when in
# doubt, pick the stricter tier.
#
# The question to ask when deciding where a path belongs: "if this file ships
# broken, what's the blast radius?" Anything that answers "production",
# "user data", or "auth" belongs in sensitive.

classify_path() {
  local path="$1"

  # ── Exempt: no review gate required ──────────────────────────────────────
  case "$path" in
    # Docs and agent-runner config
    docs/*|.claude/*) echo "exempt"; return ;;
    # Plain text / markdown
    *.md|*.txt|*.rst|*.mdx) echo "exempt"; return ;;
    # Lockfiles
    Cargo.lock|package-lock.json|pnpm-lock.yaml|uv.lock|poetry.lock|yarn.lock) echo "exempt"; return ;;
    # Git / editor / CI config
    .github/*|.gitignore|.gitattributes|.editorconfig) echo "exempt"; return ;;
    # Shell scripts, Makefiles, container definitions
    *.sh|Makefile|Dockerfile|docker-compose*) echo "exempt"; return ;;
    # Project config files
    pyproject.toml|Cargo.toml|package.json|tsconfig*|*.config.ts|*.config.js) echo "exempt"; return ;;
    # Declarative config (data files that matter live in standard/sensitive)
    *.yaml|*.yml|*.toml|*.json) echo "exempt"; return ;;
    # Assets and styles
    *.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|*.webp) echo "exempt"; return ;;
    *.css|*.scss|*.sass) echo "exempt"; return ;;
    */public/*|public/*) echo "exempt"; return ;;
    # Environment files (build-time config)
    *.env|*.env.*) echo "exempt"; return ;;
    # Test fixtures and mocks
    */fixtures/*|*__fixtures__*|*__mocks__*) echo "exempt"; return ;;
  esac

  # ── Sensitive: heavy review required at PR creation ──────────────────────
  # Customize for your stack. These are ILLUSTRATIVE examples.
  case "$path" in
    # HTTP route / endpoint handlers — contracts with the outside world
    */routes/*|*/handlers/*|*/controllers/*) echo "sensitive"; return ;;
    # Data models, migrations, schema definitions
    */models/*|*/migrations/*|*/schema/*) echo "sensitive"; return ;;
    *.sql) echo "sensitive"; return ;;
    # Serialization contracts (API request/response shapes)
    */schemas/*) echo "sensitive"; return ;;
    # Auth, session, tokens, encryption — substring match catches nested paths
    *auth/*|*auth.py|*auth.ts|*auth.tsx|*auth.rs|*auth.go) echo "sensitive"; return ;;
    *session*|*token*|*encryption*|*secrets*) echo "sensitive"; return ;;
    # Rate limiting, CORS, request middleware
    *middleware*|*rate_limit*|*cors*) echo "sensitive"; return ;;
  esac

  # ── Standard: typical product code ───────────────────────────────────────
  case "$path" in
    *.py) echo "standard"; return ;;
    *.ts|*.tsx) echo "standard"; return ;;
    *.rs) echo "standard"; return ;;
    *.go) echo "standard"; return ;;
    *.java|*.kt) echo "standard"; return ;;
    *.rb) echo "standard"; return ;;
  esac

  echo "exempt"
}

# Returns the highest tier present in a repo's diff (exempt|standard|sensitive).
# Tier precedence: sensitive > standard > exempt. Empty diff → exempt.
max_tier_for_repo() {
  local repo="$1"
  local tier="exempt"

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local t
    t=$(classify_path "$f")
    case "$t" in
      sensitive) echo "sensitive"; return ;;
      standard)
        [ "$tier" = "exempt" ] && tier="standard"
        ;;
    esac
  done < <({
    git -C "$repo" diff HEAD --name-only 2>/dev/null
    git -C "$repo" ls-files --others --exclude-standard 2>/dev/null
  } | sort -u)

  echo "$tier"
}

# Back-compat: returns 0 if path is any non-exempt tier.
is_code_file() {
  local t
  t=$(classify_path "$1")
  [ "$t" != "exempt" ]
}

# Is the given directory a git working tree? Handles both regular
# repositories (.git is a directory) and worktrees (.git is a file
# pointing to the shared repo's gitdir), which the naive `[ -d .git ]`
# check would silently skip.
is_git_repo() {
  local path="$1"
  [ -d "$path" ] && git -C "$path" rev-parse --git-dir >/dev/null 2>&1
}

# Content-addressable snapshot of the reviewable files (any non-exempt tier)
# a session has changed in a repo's working tree. Used by both self-review
# and heavy-review sentinels — the tier only determines WHICH sentinel is
# required, not WHAT is hashed. This way a self-review attestation remains
# valid even if the classifier later promotes a file from standard to
# sensitive (the hash doesn't depend on tier).
#
# Scope:
#   - tracked files modified vs HEAD (git diff HEAD), filtered to code
#   - untracked files, sorted for determinism, with contents inlined
compute_repo_state() {
  local repo="$1"

  local modified=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if is_code_file "$f"; then
      modified+=("$f")
    fi
  done < <(git -C "$repo" diff HEAD --name-only 2>/dev/null || {
    printf 'repo-state: warn: git diff HEAD failed in %s\n' "$repo" >&2
    true
  })

  if [ ${#modified[@]} -gt 0 ]; then
    git -C "$repo" diff HEAD -- "${modified[@]}" 2>/dev/null || true
  fi

  git -C "$repo" ls-files --others --exclude-standard 2>/dev/null | sort | while IFS= read -r f; do
    [ -z "$f" ] && continue
    if is_code_file "$f" && [ -f "$repo/$f" ]; then
      printf "\n--- UNTRACKED: %s ---\n" "$f"
      cat "$repo/$f" 2>/dev/null || true
    fi
  done
}
