#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, re, subprocess, sys, zipfile
from pathlib import Path
import validate_v026 as prev
import validate_v025 as tts_prev

ROOT=Path(__file__).resolve().parents[1]
base=prev.base

def fail(msg:str): raise AssertionError(msg)

def check_version_schema():
    pub=(ROOT/'pubspec.yaml').read_text()
    if not re.search(r'^version:\s*0\.27\.0\+27\s*$',pub,re.M): fail('pubspec version != 0.27.0+27')
    db=(ROOT/'lib/core/database/app_database.dart').read_text()
    if 'static const int schemaVersion = 18;' not in db: fail('v0.27 must not change schema 18')
    more=(ROOT/'lib/features/more/companion_more_page.dart').read_text()
    inner=(ROOT/'lib/features/inner/inner_page.dart').read_text()
    if 'AI Companion · v0.27' not in more: fail('More version label != v0.27')
    if '她的内心 · v0.27 诊断' not in inner: fail('Inner version label != v0.27')

def check_preflight_contract():
    service=(ROOT/'lib/core/diagnostics/preflight_diagnostics.dart').read_text()
    for token in (
        "ai-companion-redacted-preflight-v1",
        "relationshipPlaintextIncluded': false",
        "messageBodiesIncluded': false",
        "rawNotificationTextIncluded': false",
        "rawAccessibilityTextIncluded': false",
        "apiSecretsIncluded': false",
        "fullOwnershipIdsIncluded': false",
        'transferStateIdentity()',
        'pendingImportedTransfer()',
        'postTurnJobStats()',
        'memoryStats()',
        'android.preflightStatus()',
        'tts.verifyArtifacts()',
        'tts.initialize()',
        'runtimeDiagnostics(limit: 120)',
        'saveDiagnosticReport(',
    ):
        if token not in service: fail(f'preflight service contract missing: {token}')
    for forbidden in (
        'recentMessages(', 'messageById(', 'recentRelationshipEvents(', 'referenceDocuments(',
        'referenceItems(', 'activeThoughts(', 'recentDeviceEvents(', 'getRecentUsage(',
        '.speak(', '.preview(', 'apiKey', 'secureConfig',
    ):
        if forbidden in service: fail(f'preflight service may expose content or trigger audio: {forbidden}')
    ui=(ROOT/'lib/features/system/preflight_diagnostics_page.dart').read_text()
    for token in ('快速自检','深度自检','保存脱敏诊断报告','不会合成或播放测试语音','最多保留 160 条、30 天'):
        if token not in ui: fail(f'preflight UI missing: {token}')
    app=(ROOT/'lib/app.dart').read_text()
    if "'/preflight'" not in app or 'PreflightDiagnosticsPage' not in app: fail('preflight route missing')
    system=(ROOT/'lib/features/system/system_page.dart').read_text()
    if "pushNamed('/preflight')" not in system: fail('SystemPage preflight entry missing')

def check_native_diagnostics():
    store=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt').read_text()
    for token in (
        'MAX_EVENTS = 160','MAX_AGE_MS = 30L * 24L * 60L * 60L * 1000L',
        'RuntimeDiagnosticStore','recordNearby','DiagnosticRedaction.fingerprint',
        'if (type == "endpointFound" || type == "endpointLost") return',
    ):
        if token not in store: fail(f'native diagnostic ring missing: {token}')
    red=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/DiagnosticRedaction.kt').read_text()
    for token in ('SHA-256','<fingerprint>','<id>','<path>','.take(180)'):
        if token not in red: fail(f'diagnostic redaction missing: {token}')
    nearby=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NearbyTransferManager.kt').read_text()
    if 'RuntimeDiagnosticStore.recordNearby(context, type, extra)' not in nearby: fail('Nearby phase diagnostics not persisted')
    tts=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt').read_text()
    for token in ('golden_integrity_failed','golden_integrity_verified','jni_mnn_ready','jni_mnn_init_failed','"tts", "speak", "error"'):
        if token not in tts: fail(f'TTS diagnostic phase missing: {token}')

def check_native_preflight_bridge():
    probe=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NativePreflightProbe.kt').read_text()
    for token in (
        'backgroundRestricted','batteryOptimizationIgnored','permissionsGranted','missingPermissions',
        'googlePlayServicesAvailable','bluetoothEnabled','locationEnabled','outputDevices','runtimeDiagnosticCount',
        'ACCESS_LOCAL_NETWORK',
    ):
        if token not in probe: fail(f'Native preflight probe missing: {token}')
    bridge=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt').read_text()
    for token in (
        '"preflightStatus"','"runtimeDiagnostics"','"clearRuntimeDiagnostics"','"saveDiagnosticReport"',
        'Intent.ACTION_CREATE_DOCUMENT','REQUEST_DIAGNOSTIC_SAVE','NativePreflightProbe.nearbyPermissionNames()',
    ):
        if token not in bridge: fail(f'SystemBridge diagnostics bridge missing: {token}')
    dart=(ROOT/'lib/core/platform/android_bridge.dart').read_text()
    for token in ('preflightStatus()','runtimeDiagnostics({int limit = 120})','clearRuntimeDiagnostics()','saveDiagnosticReport({'):
        if token not in dart: fail(f'Dart AndroidBridge preflight method missing: {token}')

def check_no_cloud_dependency():
    pub=(ROOT/'pubspec.yaml').read_text()
    # v0.27 should not add any dependency relative to the local-first v0.26 set.
    for forbidden in ('firebase_', 'supabase', 'sentry', 'datadog', 'amplitude', 'mixpanel'):
        if forbidden in pub.lower(): fail(f'cloud/telemetry dependency added: {forbidden}')

def run_executable_checks():
    for script in (
        'validate_preflight_redaction_v27.py',
        'validate_preflight_kotlin_v27.py',
        'validate_runtime_diagnostic_store_kotlin_v27.py',
        'validate_transfer_v18_sql.py',
        'validate_manual_crypto_v26.py',
        'validate_transfer_kotlin_v26.py',
        'validate_tts_queue_v25.py',
        'validate_tts_kotlin_v25.py',
    ):
        subprocess.run([sys.executable,str(ROOT/'tools'/script)],check=True)

def compare_freeze(baseline:Path|None)->int:
    if baseline is None: return 0
    allowed={
        'README.md','pubspec.yaml','docs/DEV_STATUS.md','docs/ROADMAP.md','docs/TEST_CHECKLIST.md','docs/ARCHITECTURE.md',
        'docs/PREFLIGHT_DIAGNOSTICS_v0.27.md','docs/INTERNAL_VALIDATION_v0.27.md',
        'lib/app.dart','lib/core/platform/android_bridge.dart','lib/core/diagnostics/preflight_diagnostics.dart',
        'lib/features/system/system_page.dart','lib/features/system/preflight_diagnostics_page.dart',
        'lib/features/inner/inner_page.dart','lib/features/more/companion_more_page.dart',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NativePreflightProbe.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/DiagnosticRedaction.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NearbyTransferManager.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt',
        'tools/validate_v027.py','tools/validate_preflight_redaction_v27.py','tools/validate_preflight_kotlin_v27.py',
        'tools/validate_runtime_diagnostic_store_kotlin_v27.py',
        'tools/validate_tts_kotlin_v25.py','tools/validate_transfer_kotlin_v26.py',
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
            if not cur.exists(): fail(f'unexpected v0.26 file deletion: {rel}')
            if hashlib.sha256(cur.read_bytes()).digest()!=hashlib.sha256(z.read(name)).digest():
                fail(f'unexpected change outside v0.27 allowlist: {rel}')
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
        ('Preflight privacy/UI contract',check_preflight_contract),
        ('Bounded native diagnostic ring',check_native_diagnostics),
        ('Native permission/audio/report bridge',check_native_preflight_bridge),
        ('No cloud/telemetry dependency',check_no_cloud_dependency),
        ('v0.26 bound snapshot protocol',prev.check_snapshot_protocol),
        ('v0.26 Nearby takeover ownership',prev.check_nearby_bound_takeover),
        ('v0.26 encrypted fallback',prev.check_manual_fallback),
        ('v0.24 continuity + older feature + TTS contracts',prev.check_previous_features_and_tts),
        ('Proactive pipeline',base.check_proactive_pipeline),
        ('Notification quick reply',base.check_notification_quick_reply),
        ('True overlay regression',base.check_true_overlay_regression),
    ]
    for name,fn in checks:
        fn(); print('[OK]',name)
    run_executable_checks(); print('[OK] executable preflight/transfer/TTS checks')
    frozen=compare_freeze(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] v0.26 frozen files byte-identical outside v0.27 allowlist: {frozen}')
    tts=tts_prev.compare_tts_binary_freeze(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] TTS model/runtime/native payload unchanged from v0.26: {tts}')
    print('v0.27 Real-device Readiness / Preflight Diagnostics validation passed.')
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}',file=sys.stderr); raise
