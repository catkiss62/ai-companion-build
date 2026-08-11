#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

import validate_v023 as prev
import validate_v021 as tts_base

ROOT = Path(__file__).resolve().parents[1]
base = prev.base
memory = prev.prev
relationship = prev.prev.old


def fail(msg: str) -> None:
    raise AssertionError(msg)


def check_version_schema() -> None:
    pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.24\.0\+24\s*$', pub, re.M):
        fail('pubspec version != 0.24.0+24')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'static const int schemaVersion = 17;',
        'if (oldVersion < 17)',
        '_createV17Tables(db)',
        'CREATE TABLE IF NOT EXISTS daily_continuity',
        'local_day TEXT NOT NULL UNIQUE',
        "shared_moments_json TEXT NOT NULL DEFAULT '[]'",
        "carried_threads_json TEXT NOT NULL DEFAULT '[]'",
        "cares_json TEXT NOT NULL DEFAULT '[]'",
        "awareness_json TEXT NOT NULL DEFAULT '[]'",
        'quiet_day INTEGER NOT NULL DEFAULT 0',
        'source_fingerprint TEXT NOT NULL DEFAULT',
        'finalized_at INTEGER',
        'idx_daily_continuity_day',
        "'daily_continuity',",
        "'daily_continuity_enabled': '1'",
        "'last_daily_continuity_refresh_at': '0'",
    ):
        if token not in db:
            fail(f'v17 daily continuity schema/import contract missing: {token}')


def check_continuity_model_engine() -> None:
    model = (ROOT / 'lib/core/models/daily_continuity.dart').read_text(encoding='utf-8')
    for token in (
        'class DailyContinuityMoment',
        'class DailyContinuityThread',
        'class DailyContinuityCare',
        'class DailyContinuityRecord',
        "row['shared_moments_json']",
        "row['carried_threads_json']",
        "row['awareness_json']",
        'bool get isFinalized',
        'class DailyContinuitySaveResult',
    ):
        if token not in model:
            fail(f'daily continuity model missing: {token}')

    engine = (ROOT / 'lib/core/continuity/daily_continuity_engine.dart').read_text(encoding='utf-8')
    for token in (
        'class DailyContinuityEngine',
        "static const _leaseKey = 'daily_continuity_lease_until'",
        "getSetting('daily_continuity_enabled')",
        'relationshipEventsBetween(',
        'currentThoughtsForPresentation(limit: 40)',
        'dailyContinuityBefore(',
        'activeUnfinishedThreads(limit: 12)',
        'awarenessObservationsBetween(',
        'messageCountBetween(dayStart, dayEnd)',
        'upsertDailyContinuityIfBrainOwned(',
        'existing?.isFinalized == true',
        'seenTopics.contains(key)',
        'if (!updatedToday && seenRecently) continue;',
        'quietDay = moments.isEmpty && carriedThreads.isEmpty && cares.isEmpty',
        "'last_daily_continuity_refresh_at'",
        '_fingerprint(payload)',
    ):
        if token not in engine:
            fail(f'daily continuity engine contract missing: {token}')
    for forbidden in ('DeepSeekClient', 'jsonCompletion(', 'apiKey:', 'reasoning_content'):
        if forbidden in engine:
            fail(f'daily continuity must remain local/deterministic: {forbidden}')

    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'Future<DailyContinuityRecord?> dailyContinuityForDay',
        'Future<List<DailyContinuityRecord>> latestDailyContinuity',
        'Future<List<DailyContinuityRecord>> dailyContinuityBefore',
        'Future<DailyContinuitySaveResult> upsertDailyContinuityIfBrainOwned',
        "await setting('transfer_lock') == '1'",
        "await setting('active_brain') == '0'",
        "where: 'local_day = ?'",
        "if (existing['finalized_at'] != null)",
    ):
        if token not in db:
            fail(f'daily continuity ownership/exactly-once DB guard missing: {token}')


def check_prompt_and_scheduling() -> None:
    prompt = (ROOT / 'lib/core/ai/prompt_builder.dart').read_text(encoding='utf-8')
    for token in (
        'latestDailyContinuity(limit: 2)',
        'DailyContinuityPresentation.formatForPrompt(dailyContinuity)',
    ):
        if token not in prompt:
            fail(f'bounded prompt continuity missing: {token}')

    presentation = (ROOT / 'lib/core/continuity/daily_continuity_presentation.dart').read_text(encoding='utf-8')
    for token in (
        '不是新的事实来源',
        '不是 AI 日记',
        'records.take(2)',
        '不要把安静自动解释成疏远、降温或关系退步',
        '不要逐条复述',
    ):
        if token not in presentation:
            fail(f'daily continuity prompt safety copy missing: {token}')

    extractor = (ROOT / 'lib/core/ai/memory_extractor.dart').read_text(encoding='utf-8')
    for token in (
        'DailyContinuityEngine dailyContinuity',
        'dailyContinuity.maybeRefresh(force: true)',
        'refreshContinuity: false',
        'AI 单方面复述旧事',
    ):
        if token not in extractor:
            fail(f'post-turn continuity/anti-recursion contract missing: {token}')

    proactive = (ROOT / 'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    for token in (
        'DailyContinuityEngine dailyContinuity',
        'dailyContinuity.maybeRefresh()',
        'derived continuity refresh must never suppress',
    ):
        if token not in proactive:
            fail(f'heartbeat continuity contract missing: {token}')

    maintenance = (ROOT / 'lib/core/maintenance/long_running_maintenance_engine.dart').read_text(encoding='utf-8')
    for token in (
        "table: 'daily_continuity'",
        "timeColumn: 'window_start'",
        'maxAge: const Duration(days: 180)',
        'maxRows: 220',
    ):
        if token not in maintenance:
            fail(f'daily continuity retention bound missing: {token}')


def check_companion_ui() -> None:
    home_state = (ROOT / 'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    for token in (
        'DailyContinuityRecord? recentContinuity',
        'latestDailyContinuity(limit: 1)',
        'duplicatesContinuity',
    ):
        if token not in home_state:
            fail(f'Home continuity projection missing: {token}')

    home = (ROOT / 'lib/features/home/companion_home_page.dart').read_text(encoding='utf-8')
    for token in (
        "'上次同步留下的连续性'",
        'DailyContinuityPresentation.compactSummary(continuity)',
        'DailyContinuityPresentation.dayLabel(continuity)',
    ):
        if token not in home:
            fail(f'Home continuity UI missing: {token}')

    rel_state = (ROOT / 'lib/features/relationship/relationship_companion_state.dart').read_text(encoding='utf-8')
    for token in (
        'List<DailyContinuityRecord> dailyContinuity',
        'latestDailyContinuity(limit: 5)',
    ):
        if token not in rel_state:
            fail(f'Relationship continuity state missing: {token}')

    page = (ROOT / 'lib/features/relationship/relationship_page.dart').read_text(encoding='utf-8')
    for token in (
        "title: '最近几天'",
        '不是每天自动写一篇日记',
        'class _DailyContinuityCard',
        "'上次同步'",
        "'已整理'",
    ):
        if token not in page:
            fail(f'Relationship daily continuity UI missing: {token}')

    more = (ROOT / 'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    if 'AI Companion · v0.24' not in more:
        fail('More version label != v0.24')
    inner = (ROOT / 'lib/features/inner/inner_page.dart').read_text(encoding='utf-8')
    if '她的内心 · v0.24 诊断' not in inner:
        fail('Inner diagnostic version label != v0.24')


def check_regressions() -> None:
    # Keep prior milestone contracts, excluding their version-sensitive Home/More checks.
    memory.check_memory_model()
    memory.check_conflict_semantics()
    memory.check_retrieval_semantics()
    memory.check_memory_ui()
    prev.check_proactive_v023()
    base.check_reference_library_v019()
    base.check_awareness_context_v020()
    relationship.check_relationship_presentation_v021()


def check_test_sources() -> None:
    dart = (ROOT / 'test/daily_continuity_v17_test.dart').read_text(encoding='utf-8')
    for token in (
        'v17 daily continuity decodes factual bounded payload',
        'quiet day presentation never implies relationship regression',
        'prompt continuity remains capped to two day records',
    ):
        if token not in dart:
            fail(f'v0.24 Dart test source missing: {token}')
    sql = (ROOT / 'tools/validate_daily_continuity_v17_sql.py').read_text(encoding='utf-8')
    for token in (
        'retry/exactly-once keeps one UNIQUE row per local day',
        'finalized yesterday is immutable across later retries',
        'standby/transfer lock blocks durable continuity writes inside transaction',
        'unresolved thread carry-forward avoids daily repetition',
        'quiet day is stored as neutral continuity',
        'phone/tablet full-state transfer preserves daily continuity rows',
        'continuity retention remains bounded',
    ):
        if token not in sql:
            fail(f'v0.24 SQLite simulation source missing: {token}')


def compare_v023_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    allowed_changed = {
        'README.md',
        'docs/DEV_STATUS.md',
        'docs/ROADMAP.md',
        'docs/TEST_CHECKLIST.md',
        'lib/core/ai/memory_extractor.dart',
        'lib/core/ai/prompt_builder.dart',
        'lib/core/database/app_database.dart',
        'lib/core/desire/proactive_engine.dart',
        'lib/core/maintenance/long_running_maintenance_engine.dart',
        'lib/features/home/companion_home_page.dart',
        'lib/features/home/companion_home_state.dart',
        'lib/features/inner/inner_page.dart',
        'lib/features/more/companion_more_page.dart',
        'lib/features/relationship/relationship_companion_state.dart',
        'lib/features/relationship/relationship_page.dart',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        files = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in files if '/' in n]
        if not roots:
            fail('cannot infer v0.23 baseline root prefix')
        prefix = roots[0]
        checked = 0
        for name in files:
            if not name.startswith(prefix + '/'):
                continue
            rel = name[len(prefix) + 1:]
            if rel in allowed_changed:
                continue
            current = ROOT / rel
            if not current.exists():
                fail(f'unexpected v0.23 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.24 allowlist: {rel}')
            checked += 1
        return checked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline-zip', type=Path)
    args = ap.parse_args()
    checks = [
        ('XML/Manifest', base.check_xml_manifest),
        ('Dart relative imports', base.check_relative_imports),
        ('Dart/Kotlin delimiters', base.check_delimiters),
        ('Duplicate Dart declarations', base.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 17', check_version_schema),
        ('Daily continuity model/engine', check_continuity_model_engine),
        ('Prompt/scheduling/retention', check_prompt_and_scheduling),
        ('Companion continuity UI', check_companion_ui),
        ('Prior milestone regressions', check_regressions),
        ('Proactive pipeline', base.check_proactive_pipeline),
        ('Notification quick reply', base.check_notification_quick_reply),
        ('Proactive UX UI', base.check_ui),
        ('True overlay regression', base.check_true_overlay_regression),
        ('v0.24 test sources', check_test_sources),
    ]
    for name, fn in checks:
        fn()
        print(f'[OK] {name}')
    frozen = compare_v023_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.23 frozen files byte-identical outside allowlist: {frozen}')
    tts_count = tts_base.compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files unchanged: {tts_count}')
    print('v0.24 Companion Continuity / Daily Reflection validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
