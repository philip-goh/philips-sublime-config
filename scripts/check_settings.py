#!/usr/bin/env python3
"""Validate every Sublime JSON file in this repo parses.

Sublime's JSON dialect allows // and /* */ comments plus trailing commas,
so plain json.loads() can't be used directly — strip those first.

This file lives in scripts/ on purpose: Sublime loads any top-level *.py
in Packages/User as a plugin, but ignores subdirectories.
"""

import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # PyYAML is only needed to validate .sublime-syntax files
    yaml = None

GLOBS = (
    "*.sublime-settings",
    "*.sublime-keymap",
    "*.sublime-project",
    "*.sublime-build",
    "*.sublime-syntax",
)


def strip_jsonc(text: str) -> str:
    out = []
    i, n = 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    files = sorted(f for g in GLOBS for f in root.glob(g))
    if not files:
        print("No Sublime JSON files found — wrong directory?", file=sys.stderr)
        return 1

    failed = False
    for f in files:
        try:
            if f.suffix == ".sublime-syntax":
                if yaml is None:
                    print(f"SKIP {f.name}: PyYAML not installed")
                    continue
                yaml.safe_load(f.read_text(encoding="utf-8"))
            else:
                json.loads(strip_jsonc(f.read_text(encoding="utf-8")))
            print(f"OK   {f.name}")
        except Exception as e:  # noqa: BLE001
            print(f"FAIL {f.name}: {e}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
