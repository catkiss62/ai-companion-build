#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, re, subprocess, sys, zipfile
from pathlib import Path
import validate_v027 as prev
import validate_v025 as tts_prev

ROOT=Path(__file__).resolve().parents[1]
base=prev.base

def fail(msg:str): raise AssertionError(msg)

def check_version_schema():
    pub=(ROOT/'pubspec.yaml').read_text()
    if not re.search(r'^version:\s*0\.28\.0\+28\s*$',pub,re.M): fail('pubspec version != 0.28.0+28')
    db=(ROOT/'lib/core/database/app_database.dart').read_text()
    if 'static const int schemaVersion = 18;' not in db: fail('v0.28 must keep schema 18')
    more=(ROOT/'lib/features/more/companion_more_page.dart').read_text()
    inner=(ROOT/'lib/features/inner/inner_page.dart').read_text()
    if 'AI Companion · v0.28' not in more: fail('More version label != v0.28')
    if '她的内心 · v0.28 诊断' not in inner: fail('Inner version label != v0.28')

def check_checkpoint_contract():
    page=(ROOT/'lib/features/system/real_device_checkpoint_page.dart').read_text()
    for token in (
        '第一次综合真机验收','运行快速自检','运行深度自检','播放测试语音',
        'Yuki','tts.preview(_ttsProbeText)','getPerceptionState()','/system','/transfer','/preflight',
        '手机 ↔ 平板顶号接管','需要两台 Android',
    ):
        if token not in page: fail(f'checkpoint page missing: {token}')
    for forbidden in ('insert(', 'update(', 'delete(', 'setSetting(', 'recentMessages(', 'sendMessage('):
        if forbidden in page: fail(f'checkpoint page directly mutates relationship/database state: {forbidden}')
    app=(ROOT/'lib/app.dart').read_text()
    if "'/checkpoint'" not in app or 'RealDeviceCheckpointPage' not in app: fail('checkpoint route missing')
    system=(ROOT/'lib/features/system/system_page.dart').read_text()
    if "pushNamed('/checkpoint')" not in system: fail('SystemPage checkpoint entry missing')
    preflight=(ROOT/'lib/core/diagnostics/preflight_diagnostics.dart').read_text()
    if 'AI Companion v0.28 · REDACTED LOCAL DIAGNOSTIC REPORT' not in preflight:
        fail('diagnostic report header not updated to v0.28')

def check_build_probe():
    probe=(ROOT/'tools/check_android_build_env.py').read_text()
    for token in ('flutter','dart','java','adb','ANDROID_HOME','gradle-wrapper.jar','build-ready'):
        if token not in probe: fail(f'build environment probe missing: {token}')

def run_previous_executable_checks():
    # Keep the expensive checks explicit so a timeout in a top-level aggregator
    # never gets mistaken for a source failure.
    scripts=(
        'validate_preflight_redaction_v27.py','validate_preflight_kotlin_v27.py',
        'validate_runtime_diagnostic_store_kotlin_v27.py','validate_transfer_v18_sql.py',
        'validate_manual_crypto_v26.py','validate_transfer_kotlin_v26.py',
        'validate_tts_queue_v25.py','validate_tts_kotlin_v25.py',
    )
    for script in scripts:
        subprocess.run([sys.executable,str(ROOT/'tools'/script)],check=True)

def compare_freeze(baseline:Path|None)->int:
    if baseline is None: return 0
    allowed={
        'README.md','pubspec.yaml','docs/DEV_STATUS.md','docs/ROADMAP.md','docs/TEST_CHECKLIST.md','docs/BUILDING.md',
        'docs/REAL_DEVICE_CHECKPOINT_v0.28.md','docs/INTERNAL_VALIDATION_v0.28.md',
        'lib/app.dart','lib/features/system/system_page.dart','lib/features/system/real_device_checkpoint_page.dart',
        'lib/core/diagnostics/preflight_diagnostics.dart','lib/features/inner/inner_page.dart','lib/features/more/companion_more_page.dart',
        'tools/check_android_build_env.py','tools/validate_v028.py',
    }
    with zipfile.ZipFile(baseline) as z:
        names=[n for n in z.namelist() if not n.endswith('/')]
        prefix=next(n.split('/',1)[0] for n in names if '/' in n)
        checked=0
        for name in names:
            if not name.startswith(prefix+'/'): continue
            rel=name[len(prefix)+1:]
            if rel in allowed: continue
            cur=ROOT/rel
            if not cur.exists(): fail(f'unexpected v0.27 file deletion: {rel}')
            if hashlib.sha256(cur.read_bytes()).digest()!=hashlib.sha256(z.read(name)).digest():
                fail(f'unexpected change outside v0.28 allowlist: {rel}')
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
        ('Checkpoint harness contract',check_checkpoint_contract),
        ('Build environment probe contract',check_build_probe),
        ('v0.27 preflight privacy/UI contract',prev.check_preflight_contract),
        ('v0.27 native diagnostics',prev.check_native_diagnostics),
        ('v0.27 native preflight bridge',prev.check_native_preflight_bridge),
        ('No cloud/telemetry dependency',prev.check_no_cloud_dependency),
        ('v0.26 bound snapshot protocol',prev.prev.check_snapshot_protocol),
        ('Proactive pipeline',base.check_proactive_pipeline),
        ('Notification quick reply',base.check_notification_quick_reply),
        ('True overlay regression',base.check_true_overlay_regression),
    ]
    for name,fn in checks:
        fn(); print('[OK]',name)
    run_previous_executable_checks(); print('[OK] executable preflight/transfer/TTS checks')
    frozen=compare_freeze(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] v0.27 frozen files byte-identical outside v0.28 allowlist: {frozen}')
    tts=tts_prev.compare_tts_binary_freeze(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] TTS model/runtime/native payload unchanged from v0.27: {tts}')
    print('v0.28 First Real-device Checkpoint Harness validation passed.')
    return 0

if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}',file=sys.stderr); raise
