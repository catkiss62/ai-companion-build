#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

import validate_v022 as prev

ROOT = Path(__file__).resolve().parents[1]
base = prev.old.old


def fail(msg: str) -> None:
    raise AssertionError(msg)


def check_version_schema() -> None:
    pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.23\.0\+23\s*$', pub, re.M):
        fail('pubspec version != 0.23.0+23')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'static const int schemaVersion = 16;',
        'if (oldVersion < 16)',
        "context_hour_bucket TEXT NOT NULL DEFAULT ''",
        "context_activity TEXT NOT NULL DEFAULT 'unknown'",
        'context_busy REAL NOT NULL DEFAULT 0',
        'timing_fit REAL',
        'topic_fit REAL',
        '_createV16Tables(db)',
        'idx_proactive_context_hour',
        'idx_proactive_context_activity',
        "if (table == 'proactive_feedback' && version < 16)",
    ):
        if token not in db:
            fail(f'v16 schema/import contract missing: {token}')


def check_proactive_v023() -> None:
    model = (ROOT / 'lib/core/models/proactive_intent.dart').read_text(encoding='utf-8')
    for key in ('gentle_ping','miss_you','followup','share_thought','curiosity','social_share','intimacy_invitation','emotional_reach'):
        if f"'{key}'" not in model: fail(f'intent missing: {key}')
    policy = (ROOT / 'lib/core/desire/proactive_presentation.dart').read_text(encoding='utf-8')
    for token in ('DriveKey.libido => ProactiveIntentKind.intimacyInvitation', 'userBusy || rhythm.preferLowPressure', 'sensitiveContext'):
        if token not in policy: fail(f'presentation policy regression: {token}')

    feedback = (ROOT / 'lib/core/models/proactive_feedback.dart').read_text(encoding='utf-8')
    for token in ('contextHourBucket', 'contextActivity', 'contextBusy', 'timingFit', 'topicFit'):
        if token not in feedback: fail(f'v16 feedback model missing: {token}')

    rhythm = (ROOT / 'lib/core/desire/proactive_rhythm_engine.dart').read_text(encoding='utf-8')
    for token in (
        'class ProactiveRhythmContext', 'hourBucketFor(DateTime instant)',
        'activeAwarenessObservations(', 'recentProactiveFeedback(limit: 180)',
        'recentProactiveFeedbackByTopic(topicKey, limit: 36)',
        'recentProactiveFeedbackByIntent(intentKind, limit: 40)',
        'priorWeight: 3.0', 'ageDays / 45.0',
        "row.outcome == 'no_response' ? 0.45 : 1.0",
        "'no_response' => -0.18", "'no_response' => 0.0",
        '.clamp(-0.055, 0.095)', '.clamp(-0.040, 0.090)',
        '.clamp(-0.020, 0.045)', '.clamp(-0.070, 0.120)',
        'contextHourBucket: sentContext.hourBucket',
        'contextActivity: sentContext.activityContext',
        'contextBusy: sentContext.busyScore',
    ):
        if token not in rhythm: fail(f'v0.23 rhythm contract missing: {token}')
    capture = rhythm.split('Future<void> captureUserResponse', 1)[1].split('Future<ProactiveRhythmProfile> profile', 1)[0]
    if 'proactive_adaptation_enabled' in capture:
        fail('adaptation toggle still disables proactive response binding')

    engine = (ROOT / 'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    for token in (
        'sentToday >= 8', 'sentLastTwoHours >= 2', "decision: 'daily_ceiling'",
        "decision: 'short_window_ceiling'", 'rhythm.currentContext(',
        'context: rhythmContext', 'longIdleRelief', '.clamp(0.52, 0.76)',
        'final busyMultiplier = userBusy ? 0.72 : 1.0;',
    ):
        if token not in engine: fail(f'proactive spam/recovery/context contract missing: {token}')

    extractor = (ROOT / 'lib/core/ai/memory_extractor.dart').read_text(encoding='utf-8')
    for token in ('"timing_fit"', '"topic_fit"', '_defaultTimingFit', '_defaultTopicFit',
                  'timingFit: outcomeData.timingFit', 'topicFit: outcomeData.topicFit'):
        if token not in extractor: fail(f'feedback semantic extraction missing: {token}')


def check_home_regression() -> None:
    prev.check_companion_home_regression.__globals__['ROOT'] = ROOT
    # Inline the only version-sensitive More check while retaining the v0.21 read model.
    app = (ROOT / 'lib/app.dart').read_text(encoding='utf-8')
    for token in ('CompanionHomePage(onOpenChat: _openChat)', "label: '她'", "label: '聊天'", "label: '更多'"):
        if token not in app: fail(f'Home shell regression: {token}')
    state = (ROOT / 'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    for token in ('RelationshipPresentation.currentCares(thoughts, limit: 1)', 'currentThoughtsForPresentation(limit: 24)', 'recentRelationshipEvents(limit: 8)'):
        if token not in state: fail(f'Home read model regression: {token}')
    more = (ROOT / 'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    for token in ("title: '你们之间'", '她仍在意的事、没说完的话与共同经历', 'AI Companion · v0.23'):
        if token not in more: fail(f'More regression: {token}')


def check_test_sources() -> None:
    dart = (ROOT / 'test/proactive_rhythm_v16_test.dart').read_text(encoding='utf-8')
    for token in ('v16 proactive feedback keeps timing and activity context', 'v16 daypart buckets stay coarse and deterministic', 'legacy v15 proactive feedback remains neutral for new context fields'):
        if token not in dart: fail(f'v0.23 Dart test source missing: {token}')
    sql = (ROOT / 'tools/validate_proactive_rhythm_v16_sql.py').read_text(encoding='utf-8')
    for token in ('no-response is weak timing evidence, not topic rejection', 'timing rejection and topic rejection adapt different dimensions',
                  'short negative streak cannot cause a large personality swing', 'time-of-day and activity contexts learn independent comfort windows',
                  '45-day half-life', 'anti-silence threshold recovery and 2h/24h spam ceilings stay bounded', 'phone/tablet state transfer preserves rhythm context'):
        if token not in sql: fail(f'v0.23 SQLite simulation source missing: {token}')


def compare_v022_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None: return 0
    allowed_changed = {
        'README.md', 'docs/DEV_STATUS.md', 'docs/ROADMAP.md', 'docs/TEST_CHECKLIST.md',
        'lib/core/ai/memory_extractor.dart', 'lib/core/database/app_database.dart',
        'lib/core/desire/proactive_engine.dart', 'lib/core/desire/proactive_rhythm_engine.dart',
        'lib/core/models/proactive_feedback.dart', 'lib/features/inner/inner_page.dart',
        'lib/features/more/companion_more_page.dart', 'lib/features/settings/settings_page.dart',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        files = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in files if '/' in n]
        if not roots: fail('cannot infer v0.22 baseline root prefix')
        prefix = roots[0]
        checked = 0
        for name in files:
            if not name.startswith(prefix + '/'): continue
            rel = name[len(prefix)+1:]
            if rel in allowed_changed: continue
            current = ROOT / rel
            if not current.exists(): fail(f'unexpected v0.22 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.23 allowlist: {rel}')
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
        ('Version/schema 16', check_version_schema),
        ('v0.22 MemoryItem model', prev.check_memory_model),
        ('v0.22 conflict/evidence semantics', prev.check_conflict_semantics),
        ('v0.22 retrieval semantics', prev.check_retrieval_semantics),
        ('v0.22 memory UI', prev.check_memory_ui),
        ('Proactive Rhythm v0.23', check_proactive_v023),
        ('Proactive pipeline', base.check_proactive_pipeline),
        ('Notification quick reply', base.check_notification_quick_reply),
        ('Proactive UX UI', base.check_ui),
        ('Companion Home regression', check_home_regression),
        ('Reference Library v0.19', base.check_reference_library_v019),
        ('Perception Context v0.20', base.check_awareness_context_v020),
        ('Relationship presentation v0.21', prev.old.check_relationship_presentation_v021),
        ('v0.23 test sources', check_test_sources),
        ('True overlay regression', base.check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn(); print(f'[OK] {name}')
    frozen = compare_v022_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.22 frozen files byte-identical outside allowlist: {frozen}')
    count = prev.old.compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files unchanged: {count}')
    print('v0.23 Proactive Rhythm Learning / Local Feedback validation passed.')
    return 0

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
