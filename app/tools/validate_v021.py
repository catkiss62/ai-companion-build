#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

import validate_v020 as old

ROOT = Path(__file__).resolve().parents[1]


def fail(msg: str) -> None:
    raise AssertionError(msg)


def check_version_schema() -> None:
    pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.21\.0\+21\s*$', pub, re.M):
        fail('pubspec version != 0.21.0+21')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    if 'static const int schemaVersion = 14;' not in db:
        fail('v0.21 must keep schema 14')
    if 'if (oldVersion < 14)' not in db or 'CREATE TABLE IF NOT EXISTS awareness_observations' not in db:
        fail('v0.20 schema-14 awareness migration regressed')


def check_companion_home_v021() -> None:
    app = (ROOT / 'lib/app.dart').read_text(encoding='utf-8')
    for token in (
        'CompanionHomePage(onOpenChat: _openChat)',
        "label: '她'",
        "label: '聊天'",
        "label: '更多'",
        "'/transfer'",
        "'/system'",
        "'/settings'",
        "'/inner'",
    ):
        if token not in app:
            fail(f'companion app shell missing: {token}')

    state = (ROOT / 'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    for token in (
        'CompanionCareView? currentCare',
        'RelationshipMomentView? recentRelationshipMoment',
        'RelationshipPresentation.currentCares(thoughts, limit: 1)',
        'RelationshipPresentation.sharedMoments(events, limit: 4)',
        'currentThoughtsForPresentation(limit: 24)',
        'recentRelationshipEvents(limit: 8)',
        'latestProactiveMessage()',
        'activeInteractionSession()',
        '第二份人生',
    ):
        if token not in state:
            fail(f'v0.21 Home relationship projection missing: {token}')
    for forbidden in ('DesireEngine(', 'desire.tick(', 'PerceptionEngine(', 'capture(', 'ProactiveEngine('):
        if forbidden in state:
            fail(f'Home must remain read-only: {forbidden}')

    home = (ROOT / 'lib/features/home/companion_home_page.dart').read_text(encoding='utf-8')
    for token in (
        'eyebrow: care.label',
        "eyebrow: '你们最近留下的'",
        'RelationshipPage()',
        "'最近她主动来找你'",
        "'她还记着这件事'",
        '她最近一次感知这台设备',
    ):
        if token not in home:
            fail(f'v0.21 Home relationship UI missing: {token}')
    for forbidden in ('LinearProgressIndicator', 'DriveKey.values', 'baseline', 'busyScore', 'thought.strength'):
        if forbidden in home:
            fail(f'raw diagnostic HUD leaked into Home: {forbidden}')

    more = (ROOT / 'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    for token in ("title: '你们之间'", '她仍在意的事、没说完的话与共同经历', 'AI Companion · v0.21'):
        if token not in more:
            fail(f'v0.21 More copy missing: {token}')


def check_relationship_presentation_v021() -> None:
    projection = (ROOT / 'lib/core/relationship/relationship_presentation.dart').read_text(encoding='utf-8')
    for token in (
        'class CompanionCareView',
        'class RelationshipMomentView',
        'class RelationshipPresentation',
        "source.startsWith('perception/')",
        "source.startsWith('relationship/')",
        "source == 'self_drive/thread'",
        "source == 'self_drive/memory'",
        "source.startsWith('conversation_turn:')",
        'thought.canDriveIntent',
        'sameDisplayText',
        'thought.isSnoozed',
        'relationshipKindLabel',
        'sessionKindLabel',
    ):
        if token not in projection:
            fail(f'relationship projection contract missing: {token}')

    page = (ROOT / 'lib/features/relationship/relationship_page.dart').read_text(encoding='utf-8')
    for token in (
        "AppBar(title: const Text('你们之间'))",
        "'不是好感度'",
        "'她现在还放在心上的'",
        "'上次同步时她还放在心上的'",
        "'还没说完的事'",
        "'共同经历'",
        "'临时互动只影响当前场景，不会覆盖现实里的她。'",
        'RelationshipPresentation.sessionKindLabel',
    ):
        if token not in page:
            fail(f'partner-facing relationship page missing: {token}')
    for forbidden in ('intensity.toStringAsFixed', 'valence.toStringAsFixed', '强度 ', '倾向'):
        if forbidden in page:
            fail(f'raw relationship numeric leaked into daily page: {forbidden}')

    state = (ROOT / 'lib/features/relationship/relationship_companion_state.dart').read_text(encoding='utf-8')
    for token in (
        'RelationshipCompanionSnapshot',
        "getSetting('active_brain')",
        "getSetting('transfer_lock')",
        'currentCares: RelationshipPresentation.currentCares',
        'sharedMoments: RelationshipPresentation.sharedMoments',
        '当前念头和临时场景可能不是最新',
    ):
        if token not in state:
            fail(f'relationship snapshot/standby safety missing: {token}')

    inner = (ROOT / 'lib/features/inner/inner_page.dart').read_text(encoding='utf-8')
    for token in (
        'Relationship Event 原始诊断',
        'e.valence.toStringAsFixed(2)',
        'e.intensity.toStringAsFixed(2)',
        '这些数值只用于开发诊断',
    ):
        if token not in inner:
            fail(f'raw relationship diagnostics were not preserved under Advanced: {token}')


    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'Future<List<CompanionThought>> currentThoughtsForPresentation({int limit = 30})',
        "lifecycle_state IN ('active','fixation')",
        '(snoozed_until IS NULL OR snoozed_until <= ?)',
        "orderBy: 'strength DESC, updated_at DESC'",
    ):
        if token not in db:
            fail(f'companion-facing Thought read model missing: {token}')

    tests = (ROOT / 'test/relationship_presentation_v21_test.dart').read_text(encoding='utf-8')
    for token in (
        'daily relationship cares hide raw perception thoughts',
        'snoozed and non-driving thoughts stay out of companion-facing view',
        'topic key prevents duplicate relationship themes',
        'shared moments expose labels and summaries without numeric scores',
    ):
        if token not in tests:
            fail(f'v0.21 Dart test source missing: {token}')


def tts_paths() -> list[Path]:
    return old.tts_paths()


def compare_v020_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    allowed_changed = {
        'README.md',
        'docs/DEV_STATUS.md',
        'docs/ROADMAP.md',
        'docs/TEST_CHECKLIST.md',
        'lib/core/database/app_database.dart',
        'lib/features/home/companion_home_page.dart',
        'lib/features/home/companion_home_state.dart',
        'lib/features/inner/inner_page.dart',
        'lib/features/more/companion_more_page.dart',
        'lib/features/relationship/relationship_page.dart',
        'test/companion_home_state_test.dart',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        file_names = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in file_names if '/' in n]
        if not roots:
            fail('cannot infer v0.20 baseline root prefix')
        prefix = roots[0]
        checked = 0
        for name in file_names:
            if not name.startswith(prefix + '/'):
                continue
            rel = name[len(prefix) + 1:]
            if rel in allowed_changed:
                continue
            current = ROOT / rel
            if not current.exists():
                fail(f'unexpected v0.20 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.21 allowlist: {rel}')
            checked += 1
        return checked


def compare_tts(baseline_zip: Path | None) -> int:
    paths = tts_paths()
    for path in paths:
        if not path.exists():
            fail(f'missing TTS file: {path.relative_to(ROOT)}')
    if baseline_zip is None:
        return len(paths)
    with zipfile.ZipFile(baseline_zip) as zf:
        names = set(zf.namelist())
        candidates = [n.split('/android/app/src/main/', 1)[0] for n in names if '/android/app/src/main/' in n]
        if not candidates:
            fail('cannot infer baseline root prefix')
        prefix = sorted(set(candidates), key=len)[0]
        changed: list[str] = []
        missing: list[str] = []
        for path in paths:
            rel = path.relative_to(ROOT).as_posix()
            name = f'{prefix}/{rel}'
            if name not in names:
                missing.append(rel)
                continue
            if hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                changed.append(rel)
        if changed or missing:
            fail(f'TTS regression changed={changed} missing={missing}')
    return len(paths)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline-zip', type=Path)
    args = ap.parse_args()
    checks = [
        ('XML/Manifest', old.check_xml_manifest),
        ('Dart relative imports', old.check_relative_imports),
        ('Dart/Kotlin delimiters', old.check_delimiters),
        ('Duplicate Dart declarations', old.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 14', check_version_schema),
        ('Proactive intent model/policy', old.check_intent_model_policy),
        ('Proactive pipeline', old.check_proactive_pipeline),
        ('Notification quick reply', old.check_notification_quick_reply),
        ('Proactive UX UI', old.check_ui),
        ('Companion Home v0.21', check_companion_home_v021),
        ('Reference Library / companion copy v0.19', old.check_reference_library_v019),
        ('Perception Context / daily awareness v0.20', old.check_awareness_context_v020),
        ('Relationship / inner-state presentation v0.21', check_relationship_presentation_v021),
        ('True overlay regression', old.check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn()
        print(f'[OK] {name}')
    frozen = compare_v020_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.20 frozen files byte-identical outside allowlist: {frozen}')
    count = compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files unchanged: {count}')
    print('v0.21 Relationship / Inner-state companion presentation validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
