#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, re, sys, zipfile
from pathlib import Path

import validate_v028 as prev
import validate_v025 as tts_prev

ROOT = Path(__file__).resolve().parents[1]
base = prev.base

def fail(msg: str):
    raise AssertionError(msg)

def check_version_schema():
    pub=(ROOT/'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.28\.1\+29\s*$', pub, re.M):
        fail('pubspec version != 0.28.1+29')
    db=(ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    if 'static const int schemaVersion = 18;' not in db:
        fail('v0.28.1 must keep schema 18')
    more=(ROOT/'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    if 'AI Companion · v0.28.1' not in more:
        fail('More version label != v0.28.1')

def check_startup_recovery():
    main=(ROOT/'lib/main.dart').read_text(encoding='utf-8')
    required=(
        'runApp(const _StartupRecoveryRoot())',
        "const _StartupStep('Flutter 首帧'",
        "const _StartupStep('打开本地数据库'",
        "const _StartupStep('检查本机身份'",
        "const _StartupStep('进入主界面'",
        'AppDatabase.instance.database.timeout(const Duration(seconds: 30))',
        'AppDatabase.instance.ensureDeviceId().timeout(const Duration(seconds: 10))',
        'ErrorWidget.builder',
        'v0.28.1 · Startup Recovery',
    )
    for token in required:
        if token not in main:
            fail(f'startup recovery missing: {token}')
    run_pos=main.find('runApp(const _StartupRecoveryRoot())')
    db_pos=main.find('AppDatabase.instance.database.timeout')
    if run_pos < 0 or db_pos < 0 or run_pos > db_pos:
        fail('database work must occur after immediate runApp')
    prefix=main[:run_pos]
    if 'await AppDatabase' in prefix or '.ensureReady()' in prefix:
        fail('blocking database initialization remains before runApp')

    db=(ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in ('Future<Database>? _opening;', 'if (opening != null) return opening;', '_opening = pending;', 'identical(_opening, pending)'):
        if token not in db:
            fail(f'in-flight database open protection missing: {token}')

    runner=(ROOT/'lib/core/ai/durable_generation_runner.dart').read_text(encoding='utf-8')
    if "import '../models/desire_state.dart';" not in runner:
        fail('DriveKey compile import not persisted into v0.28.1 source')

def compare_freeze(baseline: Path | None) -> int:
    if baseline is None:
        return 0
    allowed={
        'README.md','pubspec.yaml','docs/DEV_STATUS.md','docs/ROADMAP.md','docs/TEST_CHECKLIST.md',
        'docs/STARTUP_RECOVERY_v0.28.1.md','lib/main.dart','lib/core/database/app_database.dart',
        'lib/core/ai/durable_generation_runner.dart','lib/core/diagnostics/preflight_diagnostics.dart',
        'lib/features/inner/inner_page.dart','lib/features/more/companion_more_page.dart',
        'lib/features/system/real_device_checkpoint_page.dart','tools/validate_v0281.py',
    }
    with zipfile.ZipFile(baseline) as z:
        names=[n for n in z.namelist() if not n.endswith('/')]
        prefix=next(n.split('/',1)[0] for n in names if '/' in n)
        checked=0
        for name in names:
            if not name.startswith(prefix+'/'):
                continue
            rel=name[len(prefix)+1:]
            if rel in allowed:
                continue
            cur=ROOT/rel
            if not cur.exists():
                fail(f'unexpected v0.28 file deletion: {rel}')
            if hashlib.sha256(cur.read_bytes()).digest()!=hashlib.sha256(z.read(name)).digest():
                fail(f'unexpected change outside v0.28.1 allowlist: {rel}')
            checked+=1
        return checked

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--baseline-zip',type=Path); args=ap.parse_args()
    checks=[
        ('XML/Manifest',base.check_xml_manifest),
        ('Dart relative imports',base.check_relative_imports),
        ('Dart/Kotlin delimiters',base.check_delimiters),
        ('Duplicate Dart declarations',base.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 18',check_version_schema),
        ('Startup recovery contract',check_startup_recovery),
        ('v0.27 native diagnostics',prev.prev.check_native_diagnostics),
        ('v0.27 native preflight bridge',prev.prev.check_native_preflight_bridge),
        ('No cloud/telemetry dependency',prev.prev.check_no_cloud_dependency),
        ('v0.26 bound snapshot protocol',prev.prev.prev.check_snapshot_protocol),
        ('Proactive pipeline',base.check_proactive_pipeline),
        ('Notification quick reply',base.check_notification_quick_reply),
        ('True overlay regression',base.check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn(); print('[OK]', name)
    frozen=compare_freeze(args.baseline_zip)
    if args.baseline_zip:
        print(f'[OK] v0.28 frozen files byte-identical outside v0.28.1 allowlist: {frozen}')
        tts=tts_prev.compare_tts_binary_freeze(args.baseline_zip)
        print(f'[OK] TTS model/runtime/native payload unchanged from v0.28: {tts}')
    print('v0.28.1 Startup Recovery validation passed.')

if __name__=='__main__':
    try:
        main()
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
