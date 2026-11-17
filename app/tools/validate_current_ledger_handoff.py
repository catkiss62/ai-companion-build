#!/usr/bin/env python3
"""Current source identity and handoff entries, plus immutable history checks."""
from __future__ import annotations

import json
import re
from pathlib import Path
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
    # Preserve strings while removing comments; declarations inside comments must
    # never satisfy current identity. This is a lexer for these constant reads,
    # not a general Dart parser.
    token = r'''("""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|//[^\n]*|/\*[\s\S]*?\*/'''
    return re.sub(token, lambda m: m.group(1) if m.group(1) and not m.group(1).startswith(('\"\"\"', "'''")) else ' ' + '\n' * m.group(0).count('\n'), text)


def validate_current(root: Path = ROOT) -> None:
    ledger = (root / CURRENT).read_text(encoding='utf-8')
    snapshot = ledger.split('## 当前接班快照\n', 1)
    require(len(snapshot) == 2, 'missing current handoff snapshot')
    snapshot = re.split(r'^## ', snapshot[1], maxsplit=1, flags=re.MULTILINE)[0]
    require(snapshot.count(START) == snapshot.count(END) == 1, 'current identity markers must occur once in snapshot')
    identity = snapshot.split(START, 1)[1].split(END, 1)[0].strip()
    require(identity.startswith('```json\n') and identity.endswith('\n```'), 'identity must be a JSON block')
    identity = json.loads(identity[8:-4])
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
        links = re.findall(r'\]\(([^)]+)\)', text)
        ledger_links = [p for p in links if '总账' in p]
        require(bool(ledger_links) and 'AI_Companion_总账_v4.md' in ledger_links[0], f'{name}: first ledger link must be current v4')
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
