#!/usr/bin/env python3
"""Track files and canonical docs touched during the current turn.

Trigger: PostToolUse (Read|Write|Edit|MultiEdit|Bash)
Reads: .claude/.turn-state.json, docs/knowledge/index.yaml
Writes: .claude/.turn-state.json (session state, gitignored)
Deps: stdlib only (json, os, re, sys, pathlib)

For each file path mentioned in the tool result, checks whether it maps to a
known KB domain via index.yaml `code_globs`. Accumulates touched files and
matched domains in the turn-state for the postflight hook to check.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path(__file__).resolve().parents[2]))
INDEX_PATH = PROJECT_DIR / "docs/knowledge/index.yaml"
STATE_PATH = PROJECT_DIR / ".claude/.turn-state.json"
PATH_TOKEN_RE = re.compile(r"(?:\.\.?/)?[A-Za-z0-9_./-]+\.(?:md|py|json|toml|ya?ml|sh|tsx?|rs|js|go|rb|java|cs)")


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


def _load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return {
            "prompt": "",
            "matched_domains": [],
            "required_docs": [],
            "invariants": [],
            "files_read": [],
            "files_edited": [],
            "docs_read": [],
            "docs_edited": [],
        }
    data = json.loads(STATE_PATH.read_text())
    return data if isinstance(data, dict) else {}


def _normalize_path(raw: str) -> str | None:
    if raw.startswith(("http://", "https://")):
        return None
    candidate = Path(raw)
    if not candidate.is_absolute():
        candidate = PROJECT_DIR / candidate
    try:
        relative = candidate.resolve(strict=False).relative_to(PROJECT_DIR.resolve(strict=False))
    except ValueError:
        return None
    return relative.as_posix()


def _collect_paths(payload: Any) -> list[str]:
    candidates: list[str] = []
    path_keys = {"path", "file_path", "filePath", "abs_path", "absPath"}
    command_keys = {"command", "cmd"}

    def walk(value: Any, key: str | None = None) -> None:
        if isinstance(value, dict):
            for k, child in value.items():
                walk(child, k)
        elif isinstance(value, list):
            for child in value:
                walk(child, key)
        elif isinstance(value, str):
            if key in path_keys:
                norm = _normalize_path(value)
                if norm:
                    candidates.append(norm)
            if key in command_keys:
                for token in PATH_TOKEN_RE.findall(value):
                    norm = _normalize_path(token)
                    if norm:
                        candidates.append(norm)

    walk(payload)
    return list(dict.fromkeys(candidates))


def _extract_tool_name(payload: Any) -> str:
    if isinstance(payload, dict):
        for key in ("tool_name", "toolName", "name"):
            val = payload.get(key)
            if isinstance(val, str):
                return val
        for child in payload.values():
            result = _extract_tool_name(child)
            if result:
                return result
    elif isinstance(payload, list):
        for child in payload:
            result = _extract_tool_name(child)
            if result:
                return result
    return ""


def _matches_any(rel_path: str, patterns: list[str]) -> bool:
    pure = PurePosixPath(rel_path)
    return any(pure.match(p) or rel_path == p for p in patterns)


def main() -> int:
    raw = sys.stdin.read().strip()
    payload = json.loads(raw) if raw else {}
    state = _load_state()
    entries = _load_index()
    touched = _collect_paths(payload)
    tool_name = _extract_tool_name(payload).lower()
    is_edit = tool_name in {"write", "edit", "multiedit"}

    read_bucket = state.setdefault("files_read", [])
    edit_bucket = state.setdefault("files_edited", [])
    docs_read = state.setdefault("docs_read", [])
    docs_edited = state.setdefault("docs_edited", [])
    matched_domains = state.setdefault("matched_domains", [])
    required_docs = state.setdefault("required_docs", [])

    for rel_path in touched:
        if rel_path.startswith("docs/knowledge/"):
            target = docs_edited if is_edit else docs_read
        else:
            target = edit_bucket if is_edit else read_bucket
        if rel_path not in target:
            target.append(rel_path)

        for entry in entries:
            globs = [p for p in entry.get("code_globs", []) if isinstance(p, str)]
            read_first = [d for d in entry.get("read_first", []) if isinstance(d, str)]
            if _matches_any(rel_path, globs) or rel_path in read_first:
                entry_id = str(entry.get("id", ""))
                if entry_id and entry_id not in matched_domains:
                    matched_domains.append(entry_id)
                for doc in read_first:
                    if doc not in required_docs:
                        required_docs.append(doc)

    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
