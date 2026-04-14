#!/usr/bin/env python3
"""Route a prompt to canonical knowledge docs before implementation.

Trigger: UserPromptSubmit
Reads: docs/knowledge/index.yaml
Writes: .claude/.turn-state.json (session state, gitignored)
Deps: stdlib only (json, os, sys, pathlib)

Matching strategy: keyword match against each entry's `prompt_keywords` array.
If the prompt contains any of the keywords (case-insensitive), the entry matches
and its `read_first` articles are surfaced as required reading.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path(__file__).resolve().parents[2]))
INDEX_PATH = PROJECT_DIR / "docs/knowledge/index.yaml"
STATE_PATH = PROJECT_DIR / ".claude/.turn-state.json"


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


def _extract_prompt(payload: Any) -> str:
    """Pull the longest prompt-like string from the hook payload."""
    preferred_keys = {"prompt", "user_prompt", "userPrompt", "message", "text"}
    collected: list[str] = []

    def walk(node: Any, parent_key: str | None = None) -> None:
        if isinstance(node, dict):
            for key, child in node.items():
                if isinstance(child, str) and key in preferred_keys:
                    collected.append(child)
                walk(child, key)
        elif isinstance(node, list):
            for child in node:
                walk(child, parent_key)
        elif isinstance(node, str) and parent_key in preferred_keys:
            collected.append(node)

    walk(payload)
    return max(collected, key=len) if collected else ""


def _matched_entries(prompt: str, entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized = prompt.lower()
    return [
        entry for entry in entries
        if any(
            kw.lower() in normalized
            for kw in entry.get("prompt_keywords", [])
            if isinstance(kw, str)
        )
    ]


def _write_state(prompt: str, matches: list[dict[str, Any]]) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    state = {
        "prompt": prompt,
        "matched_domains": [entry["id"] for entry in matches],
        "required_docs": [
            doc
            for entry in matches
            for doc in entry.get("read_first", [])
            if isinstance(doc, str)
        ],
        "invariants": [
            inv
            for entry in matches
            for inv in entry.get("invariants", [])
            if isinstance(inv, str)
        ],
        "files_read": [],
        "files_edited": [],
        "docs_read": [],
        "docs_edited": [],
    }
    STATE_PATH.write_text(json.dumps(state, indent=2, sort_keys=True))


def main() -> int:
    raw = sys.stdin.read().strip()
    payload = json.loads(raw) if raw else {}
    entries = _load_index()
    prompt = _extract_prompt(payload)
    matches = _matched_entries(prompt, entries)
    _write_state(prompt, matches)

    if not matches:
        message = "knowledge-preflight: No canonical docs matched this prompt."
    else:
        docs = list(dict.fromkeys(
            doc for entry in matches for doc in entry.get("read_first", []) if isinstance(doc, str)
        ))
        invariants = list(dict.fromkeys(
            inv for entry in matches for inv in entry.get("invariants", []) if isinstance(inv, str)
        ))
        docs_text = ", ".join(docs)
        inv_text = " | ".join(invariants[:3])
        message = f"knowledge-preflight: Read {docs_text} before editing."
        if inv_text:
            message += f" Preserve invariants: {inv_text}"

    print(json.dumps({"systemMessage": message}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
