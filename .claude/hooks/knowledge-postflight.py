#!/usr/bin/env python3
"""Warn when mapped code changes do not update canonical docs.

Trigger: PostToolUse (Write|Edit|MultiEdit)
Reads: .claude/.turn-state.json, docs/knowledge/index.yaml
Deps: stdlib only (json, os, sys, pathlib)

After any code edit, checks whether the edited files map to KB domains via
index.yaml. If required docs were not also read or edited in this turn,
emits a reminder to review/update the canonical docs.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path(__file__).resolve().parents[2]))
STATE_PATH = PROJECT_DIR / ".claude/.turn-state.json"
INDEX_PATH = PROJECT_DIR / "docs/knowledge/index.yaml"


def _load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {}
    data = json.loads(STATE_PATH.read_text())
    return data if isinstance(data, dict) else {}


def _load_index() -> list[dict[str, Any]]:
    if not INDEX_PATH.exists():
        return []
    text = INDEX_PATH.read_text()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        try:
            import yaml  # type: ignore[import-not-found]
            data = yaml.safe_load(text)
        except Exception:
            return []
    entries = data.get("entries", []) if isinstance(data, dict) else []
    return [e for e in entries if isinstance(e, dict)]


def main() -> int:
    state = _load_state()
    files_edited = [p for p in state.get("files_edited", []) if isinstance(p, str)]
    docs_touched = set(state.get("docs_read", []) + state.get("docs_edited", []))

    if not files_edited:
        return 0

    entries = _load_index()
    missing_docs: list[str] = []
    matched_domains: list[str] = []

    from pathlib import PurePosixPath

    def matches_any(rel_path: str, patterns: list[str]) -> bool:
        pure = PurePosixPath(rel_path)
        return any(pure.match(p) or rel_path == p for p in patterns)

    for entry in entries:
        globs = [p for p in entry.get("code_globs", []) if isinstance(p, str)]
        read_first = [d for d in entry.get("read_first", []) if isinstance(d, str)]
        if any(matches_any(f, globs) for f in files_edited):
            entry_id = str(entry.get("id", ""))
            if entry_id:
                matched_domains.append(entry_id)
            for doc in read_first:
                if doc not in docs_touched and doc not in missing_docs:
                    missing_docs.append(doc)

    if missing_docs:
        domains_text = ", ".join(matched_domains)
        docs_text = ", ".join(missing_docs)
        message = (
            f"knowledge-postflight: You edited code mapped to domain(s): {domains_text}. "
            f"Review and update canonical docs if facts changed: {docs_text}"
        )
        print(json.dumps({"systemMessage": message}))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
