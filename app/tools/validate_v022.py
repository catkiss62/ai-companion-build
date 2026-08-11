#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

import validate_v021 as old

ROOT = Path(__file__).resolve().parents[1]


def fail(msg: str) -> None:
    raise AssertionError(msg)


def check_version_schema() -> None:
    pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.22\.0\+22\s*$', pub, re.M):
        fail('pubspec version != 0.22.0+22')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'static const int schemaVersion = 15;',
        'if (oldVersion < 15)',
        "ALTER TABLE memory_items ADD COLUMN semantic_type TEXT NOT NULL DEFAULT 'current_fact'",
        'ALTER TABLE memory_items ADD COLUMN evidence_count INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE memory_items ADD COLUMN first_observed_at INTEGER',
        'ALTER TABLE memory_items ADD COLUMN last_evidence_at INTEGER',
        'ALTER TABLE memory_items ADD COLUMN fact_version INTEGER NOT NULL DEFAULT 1',
        'CREATE TABLE IF NOT EXISTS memory_evidence',
        'UNIQUE(memory_id, source, evidence_text)',
        "'memory_evidence',",
        "if (table == 'memory_items' && version < 15)",
    ):
        if token not in db:
            fail(f'v15 schema/import contract missing: {token}')




def check_companion_home_regression() -> None:
    app = (ROOT / 'lib/app.dart').read_text(encoding='utf-8')
    for token in (
        'CompanionHomePage(onOpenChat: _openChat)',
        "label: '她'", "label: '聊天'", "label: '更多'",
        "'/transfer'", "'/system'", "'/settings'", "'/inner'",
    ):
        if token not in app:
            fail(f'companion shell regression: {token}')
    state = (ROOT / 'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    for token in (
        'RelationshipPresentation.currentCares(thoughts, limit: 1)',
        'currentThoughtsForPresentation(limit: 24)',
        'recentRelationshipEvents(limit: 8)',
        'latestProactiveMessage()',
        'activeInteractionSession()',
    ):
        if token not in state:
            fail(f'Home read model regression: {token}')
    home = (ROOT / 'lib/features/home/companion_home_page.dart').read_text(encoding='utf-8')
    for token in (
        'eyebrow: care.label', "eyebrow: '你们最近留下的'",
        'RelationshipPage()', "'最近她主动来找你'", "'她还记着这件事'",
    ):
        if token not in home:
            fail(f'Home UI regression: {token}')
    more = (ROOT / 'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    for token in ("title: '你们之间'", '她仍在意的事、没说完的话与共同经历', 'AI Companion · v0.22'):
        if token not in more:
            fail(f'More regression: {token}')

def check_memory_model() -> None:
    model = (ROOT / 'lib/core/models/memory_item.dart').read_text(encoding='utf-8')
    for token in (
        "this.semanticType = 'current_fact'",
        'this.evidenceCount = 1',
        'this.factVersion = 1',
        "bool get isCurrentFact => semanticType == 'current_fact' && status == 'active'",
        "bool get isInference => semanticType == 'inference' && status == 'active'",
        "bool get isSharedExperience => semanticType == 'shared_experience'",
        "bool get isHistorical => status == 'superseded'",
        "row['semantic_type']",
        "row['evidence_count']",
        "row['first_observed_at']",
        "row['last_evidence_at']",
        "row['fact_version']",
    ):
        if token not in model:
            fail(f'MemoryItem v15 semantic field missing: {token}')


def check_conflict_semantics() -> None:
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        "const semanticTypes = {'current_fact', 'inference', 'shared_experience'}",
        "const evidenceModes = {'auto', 'append', 'reinforce', 'replace'}",
        "if (kind == 'shared_experience') semantic = 'shared_experience'",
        "if (semantic == 'current_fact' && confidence < 0.68 && !pinned)",
        "where: 'memory_id = ? AND source = ? AND evidence_text = ?'",
        "'evidence_count': existing.evidenceCount + 1",
        "'last_evidence_at': now",
        "where: 'kind = ? AND subject_key = ? AND status = ?'",
        "if (sameSubject.any((row) => (row['pinned'] as int? ?? 0) == 1)) return",
        "'status': 'superseded'",
        "'superseded_by': id",
        "'fact_version': factVersion",
        'memoryCandidatesForExtraction(',
        'relevantMemoryInferences(',
        'relevantHistoricalMemories(',
        'memoryEvidenceFor(',
        'memoryInferencesByKind(',
        "throw StateError('current_fact_subject_conflict')",
        "'relation': 'manual_edit_previous'",
        "semantic_type IN ('current_fact','shared_experience')",
    ):
        if token not in db:
            fail(f'memory conflict/evidence contract missing: {token}')

    extractor = (ROOT / 'lib/core/ai/memory_extractor.dart').read_text(encoding='utf-8')
    for token in (
        '【相关既有长期记忆】',
        'memoryCandidatesForExtraction(',
        'current_fact / inference / shared_experience',
        'reinforce：同一已经确认层级的事实/偏好/经历',
        '"action":"replace"',
        "const semantics = {'current_fact', 'inference', 'shared_experience'}",
        "const actions = {'append', 'reinforce', 'replace'}",
        'semanticType: semantic',
        'evidenceMode: action',
        'targetMemoryId:',
    ):
        if token not in extractor:
            fail(f'post-turn memory semantic prompt/application missing: {token}')

    reflection = (ROOT / 'lib/core/self/ai_self_reflection_engine.dart').read_text(encoding='utf-8')
    for token in (
        'action=reinforce',
        'action=replace',
        'semantic=inference',
        'evidence=${e.evidenceCount}',
        'semanticType:',
        'evidenceMode:',
        'targetMemoryId:',
    ):
        if token not in reflection:
            fail(f'AI Self v15 conflict semantics missing: {token}')


def check_retrieval_semantics() -> None:
    brain = (ROOT / 'lib/core/memory/memory_brain.dart').read_text(encoding='utf-8')
    for token in (
        'relevantMemoryInferences(query, limit: 3)',
        'relevantHistoricalMemories(query, limit: 3)',
        '用户当前稳定资料（当前事实）',
        '相关共同经历（发生过的事件，不代表当前偏好仍未变化）',
        '不确定推断（可能不准确，只能当作线索，不能当成已确认事实）',
        '历史事实版本（只表示过去曾成立/曾记录，不能当成当前事实）',
    ):
        if token not in brain:
            fail(f'Prompt retrieval semantic label missing: {token}')

    ctx = (ROOT / 'lib/core/memory/memory_context.dart').read_text(encoding='utf-8')
    for token in ('required this.inferences', 'required this.history', 'final List<MemoryItem> inferences', 'final List<MemoryItem> history'):
        if token not in ctx:
            fail(f'MemoryContext v15 field missing: {token}')

    maintenance = (ROOT / 'lib/core/memory/memory_maintenance_engine.dart').read_text(encoding='utf-8')
    for token in (
        'item.evidenceCount',
        'item.isInference ? 0.52 : 1.0',
        'if (item.isInference) return 75.0',
    ):
        if token not in maintenance:
            fail(f'inference/evidence retention policy missing: {token}')


def check_memory_ui() -> None:
    page = (ROOT / 'lib/features/memory/memory_page.dart').read_text(encoding='utf-8')
    for token in (
        "if (item.status == 'superseded') return '历史版本'",
        "'inference' => '不确定推断'",
        "_ => '当前事实'",
        'memoryEvidenceFor(item.id, limit: 8)',
        '版本 v${item.factVersion}',
        '证据 ${item.evidenceCount} 次',
        "title: const Text('最近证据')",
        '已有同一事实键的当前版本',
    ):
        if token not in page:
            fail(f'Memory UI v15 semantic/evidence view missing: {token}')


def check_test_sources() -> None:
    dart = (ROOT / 'test/memory_v15_semantics_test.dart').read_text(encoding='utf-8')
    for token in (
        'v15 memory exposes current fact version and evidence semantics',
        'v15 historical and inference states are explicit',
        'legacy shared experience rows infer v15 semantic safely',
    ):
        if token not in dart:
            fail(f'v15 Dart test source missing: {token}')
    sql = (ROOT / 'tools/validate_memory_v15_sql.py').read_text(encoding='utf-8')
    for token in (
        'v14 -> v15 memory semantic migration',
        'current fact replacement preserves historical version',
        'uncertain inference coexists',
        'evidence uniqueness prevents retry',
        'repeated full-state import remains idempotent',
        'manual restore guard prevents two current facts',
        'manual edit preserves migrated pre-v15 content as evidence',
    ):
        if token not in sql:
            fail(f'v15 SQLite test source missing: {token}')


def compare_v021_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    allowed_changed = {
        'README.md',
        'docs/DEV_STATUS.md',
        'docs/ROADMAP.md',
        'docs/TEST_CHECKLIST.md',
        'lib/core/ai/memory_extractor.dart',
        'lib/core/database/app_database.dart',
        'lib/core/memory/memory_brain.dart',
        'lib/core/memory/memory_context.dart',
        'lib/core/memory/memory_maintenance_engine.dart',
        'lib/core/models/memory_item.dart',
        'lib/core/self/ai_self_reflection_engine.dart',
        'lib/features/inner/inner_page.dart',
        'lib/features/memory/memory_page.dart',
        'lib/features/more/companion_more_page.dart',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        file_names = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in file_names if '/' in n]
        if not roots:
            fail('cannot infer v0.21 baseline root prefix')
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
                fail(f'unexpected v0.21 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.22 allowlist: {rel}')
            checked += 1
        return checked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline-zip', type=Path)
    args = ap.parse_args()
    checks = [
        ('XML/Manifest', old.old.check_xml_manifest),
        ('Dart relative imports', old.old.check_relative_imports),
        ('Dart/Kotlin delimiters', old.old.check_delimiters),
        ('Duplicate Dart declarations', old.old.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 15', check_version_schema),
        ('v0.22 MemoryItem model', check_memory_model),
        ('v0.22 conflict/evidence semantics', check_conflict_semantics),
        ('v0.22 retrieval semantics', check_retrieval_semantics),
        ('v0.22 memory UI', check_memory_ui),
        ('v0.22 test sources', check_test_sources),
        ('Proactive intent model/policy', old.old.check_intent_model_policy),
        ('Proactive pipeline', old.old.check_proactive_pipeline),
        ('Notification quick reply', old.old.check_notification_quick_reply),
        ('Proactive UX UI', old.old.check_ui),
        ('Companion Home v0.21 regression', check_companion_home_regression),
        ('Reference Library / companion copy v0.19', old.old.check_reference_library_v019),
        ('Perception Context / daily awareness v0.20', old.old.check_awareness_context_v020),
        ('Relationship / inner-state presentation v0.21', old.check_relationship_presentation_v021),
        ('True overlay regression', old.old.check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn()
        print(f'[OK] {name}')
    frozen = compare_v021_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.21 frozen files byte-identical outside allowlist: {frozen}')
    count = old.compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files unchanged: {count}')
    print('v0.22 Long-term Memory Consolidation / Conflict Semantics validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
