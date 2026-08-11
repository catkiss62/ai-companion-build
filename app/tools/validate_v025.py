#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

import validate_v024 as prev
import validate_tts_v025 as tts

ROOT = Path(__file__).resolve().parents[1]
base = prev.base


def fail(msg: str) -> None:
    raise AssertionError(msg)


def check_version_schema() -> None:
    pub = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.25\.0\+25\s*$', pub, re.M):
        fail('pubspec version != 0.25.0+25')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    if 'static const int schemaVersion = 17;' not in db:
        fail('v0.25 must keep database schema 17')
    if 'if (oldVersion < 18)' in db or '_createV18Tables' in db:
        fail('v0.25 unexpectedly introduced schema 18')
    more = (ROOT / 'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    inner = (ROOT / 'lib/features/inner/inner_page.dart').read_text(encoding='utf-8')
    if 'AI Companion · v0.25' not in more:
        fail('More version label != v0.25')
    if '她的内心 · v0.25 诊断' not in inner:
        fail('Inner diagnostic version label != v0.25')


def check_previous_features() -> None:
    prev.check_continuity_model_engine()
    prev.check_prompt_and_scheduling()
    prev.check_regressions()
    prev.check_test_sources()


def check_tts_contract(golden_apk: Path | None) -> None:
    manifest = tts.load_manifest()
    tts.check_source_payload(manifest)
    tts.check_no_shell()
    tts.check_wiring()
    tts.check_test_sources()
    if golden_apk is not None:
        tts.compare_golden_apk(golden_apk, manifest)


def run_executable_checks() -> None:
    subprocess.run([sys.executable, str(ROOT / 'tools/validate_tts_queue_v25.py')], check=True)
    subprocess.run([sys.executable, str(ROOT / 'tools/validate_tts_kotlin_v25.py')], check=True)


def compare_v024_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    allowed_changed = {
        'README.md',
        'docs/DEV_STATUS.md',
        'docs/ROADMAP.md',
        'docs/TEST_CHECKLIST.md',
        'docs/TTS_PORTING.md',
        'docs/TTS_SOURCE_APK_ANALYSIS.md',
        'docs/VOICE_PIPELINE.md',
        'lib/features/inner/inner_page.dart',
        'lib/features/more/companion_more_page.dart',
        'lib/features/settings/settings_page.dart',
        'lib/core/tts/native_tts_provider.dart',
        'lib/core/tts/tts_playback_queue.dart',
        'lib/core/tts/tts_provider.dart',
        'lib/core/tts/tts_service.dart',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        files = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in files if '/' in n]
        if not roots:
            fail('cannot infer v0.24 baseline root prefix')
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
                fail(f'unexpected v0.24 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.25 allowlist: {rel}')
            checked += 1
        return checked


def compare_tts_binary_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    manifest = json.loads((ROOT / 'docs/TTS_GOLDEN_MANIFEST_v0.25.json').read_text(encoding='utf-8'))
    rels = [f'android/app/src/main/assets/{r}' for r in manifest['assets']]
    rels += [f'android/app/src/main/jniLibs/arm64-v8a/{n}' for n in manifest['native_libraries']]
    with zipfile.ZipFile(baseline_zip) as zf:
        files = [n for n in zf.namelist() if not n.endswith('/')]
        prefix = next(n.split('/', 1)[0] for n in files if '/' in n)
        for rel in rels:
            name = f'{prefix}/{rel}'
            if name not in zf.namelist():
                fail(f'v0.24 baseline missing TTS payload: {rel}')
            if (ROOT / rel).read_bytes() != zf.read(name):
                fail(f'golden TTS binary/model payload changed from v0.24: {rel}')
    return len(rels)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline-zip', type=Path)
    ap.add_argument('--golden-apk', type=Path)
    args = ap.parse_args()

    checks = [
        ('XML/Manifest', base.check_xml_manifest),
        ('Dart relative imports', base.check_relative_imports),
        ('Dart/Kotlin delimiters', base.check_delimiters),
        ('Duplicate Dart declarations', base.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 17', check_version_schema),
        ('v0.24 continuity + prior milestone regressions', check_previous_features),
        ('Proactive pipeline', base.check_proactive_pipeline),
        ('Notification quick reply', base.check_notification_quick_reply),
        ('Proactive UX UI', base.check_ui),
        ('True overlay regression', base.check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn()
        print(f'[OK] {name}')

    check_tts_contract(args.golden_apk)
    print('[OK] v0.25 golden TTS integrity/wiring contract')
    run_executable_checks()
    print('[OK] executable queue model + Kotlin stub compile')

    frozen = compare_v024_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.24 frozen files byte-identical outside allowlist: {frozen}')
    binary_count = compare_tts_binary_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] frozen TTS model/runtime/native payload unchanged from v0.24: {binary_count}')
    print('v0.25 Native TTS Core Integration validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
