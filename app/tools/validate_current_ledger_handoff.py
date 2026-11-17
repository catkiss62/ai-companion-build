#!/usr/bin/env python3
"""Current source identity and handoff entries, plus immutable history checks."""
from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlsplit, unquote
from validate_historical_ledgers import main as validate_history

ROOT = Path(__file__).resolve().parents[2]
CURRENT = 'app/docs/ledger/AI_Companion_总账_v4.md'
START = '<!-- CURRENT_SOURCE_IDENTITY -->'
END = '<!-- END_CURRENT_SOURCE_IDENTITY -->'


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError(message)


def one(pattern: str, text: str, label: str) -> str:
    values = re.findall(pattern, text, re.MULTILINE)
    require(len(values) == 1, f'{label}: expected exactly one declaration, got {len(values)}')
    return values[0]


def dart_code(text: str) -> str:
    """Remove nested comments and multiline strings for constant inspection.

    Keep single-line strings for buildLabel. Preserve newlines and token spacing;
    this is deliberately not a Dart expression evaluator.
    """
    out = []
    i = 0
    size = len(text)

    def blank(start: int, end: int) -> str:
        return ''.join('\n' if c == '\n' else ' ' for c in text[start:end])

    while i < size:
        start = i
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = size if end < 0 else end
            out.append(blank(start, i))
        elif text.startswith('/*', i):
            depth = 1
            i += 2
            while i < size and depth:
                if text.startswith('/*', i):
                    depth += 1
                    i += 2
                elif text.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            require(depth == 0, 'unterminated Dart block comment')
            out.append(blank(start, i))
        elif text[i] in "\"'" or (text[i] == 'r' and i + 1 < size and text[i + 1] in "\"'"):
            raw = text[i] == 'r'
            if raw:
                i += 1
            quote = text[i]
            triple = text.startswith(quote * 3, i)
            delimiter = quote * (3 if triple else 1)
            i += len(delimiter)
            closed = False
            while i < size:
                if not raw and text[i] == '\\':
                    i += 2
                elif text.startswith(delimiter, i):
                    i += len(delimiter)
                    closed = True
                    break
                else:
                    i += 1
            require(closed, 'unterminated Dart string')
            out.append(blank(start, i) if triple else text[start:i])
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def unique_json_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'duplicate identity JSON key: {key}')
        result[key] = value
    return result


def validate_current(root: Path = ROOT) -> None:
    ledger = (root / CURRENT).read_text(encoding='utf-8')
    snapshot = ledger.split('## 当前接班快照\n', 1)
    require(len(snapshot) == 2, 'missing current handoff snapshot')
    snapshot = re.split(r'^## ', snapshot[1], maxsplit=1, flags=re.MULTILINE)[0]
    require(snapshot.count(START) == snapshot.count(END) == 1, 'current identity markers must occur once in snapshot')
    identity = snapshot.split(START, 1)[1].split(END, 1)[0].strip()
    require(identity.startswith('```json\n') and identity.endswith('\n```'), 'identity must be a JSON block')
    identity = json.loads(identity[8:-4], object_pairs_hook=unique_json_object)
    require(set(identity) == {'app_version', 'schema'}, 'unexpected current identity fields')
    version = one(r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$', (root/'app/pubspec.yaml').read_text(), 'pubspec version')
    schema = one(r'^\s*static\s+const\s+int\s+schemaVersion\s*=\s*(\d+)\s*;', dart_code((root/'app/lib/core/database/app_database.dart').read_text()), 'schemaVersion')
    build = one(r"^\s*static\s+const\s+(?:String\s+)?buildLabel\s*=\s*'v([^']+)'\s*;", dart_code((root/'app/lib/core/agent/agent_self_reader.dart').read_text()), 'buildLabel')
    require(identity['app_version'] == version == build, 'current version differs between ledger, pubspec and self-reader')
    require(type(identity['schema']) is int and identity['schema'] == int(schema), 'current schema differs from real declaration')
    entries = ['README.md', 'app/README.md', 'AI_START_HERE.md', 'app/docs/BUILDING.md', 'app/docs/DOCUMENTATION_MAP.md', 'app/docs/maintenance/INDEX.md']
    for name in entries:
        text = (root/name).read_text(encoding='utf-8')
        # Historical sections may retain old links; only the current introduction
        # must point to v4 before any historical ledger link.
        text = re.split(r'^#{1,6}\s+历史', text, maxsplit=1, flags=re.MULTILINE)[0]
        links = re.findall(r'\]\(([^)]+)\)', text)
        ledger_links = [p for p in links if '总账' in p]
        require(bool(ledger_links), f'{name}: first ledger link must be current v4')
        target = urlsplit(ledger_links[0])
        require(not target.scheme and not target.netloc and not target.query,
                f'{name}: first ledger link must be local current v4')
        resolved = (root/name).parent / unquote(target.path)
        require(resolved.resolve() == (root/CURRENT).resolve(),
                f'{name}: first ledger link must resolve to canonical current v4')
    docs = [root/n for n in entries] + sorted((root/'app/docs/maintenance').glob('*.md'))
    for path in docs:
        for target in re.findall(r'\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
            if '://' in target or target.startswith('#'):
                continue
            target = target.split('#', 1)[0]
            resolved = (path.parent/target).resolve()
            require(resolved.is_relative_to(root.resolve()) and resolved.exists(), f'{path.relative_to(root)}: missing/outside local link {target}')
    print(f'current handoff: OK (v{version}, schema{schema})')


def main() -> None:
    validate_current()
    validate_history()


if __name__ == '__main__':
    main()
