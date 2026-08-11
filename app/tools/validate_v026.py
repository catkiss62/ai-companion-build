#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, re, subprocess, sys, zipfile
from pathlib import Path
import validate_v025 as prev

ROOT=Path(__file__).resolve().parents[1]
base=prev.base

def fail(msg:str): raise AssertionError(msg)

def check_version_schema():
    pub=(ROOT/'pubspec.yaml').read_text()
    if not re.search(r'^version:\s*0\.26\.0\+26\s*$',pub,re.M): fail('pubspec version != 0.26.0+26')
    db=(ROOT/'lib/core/database/app_database.dart').read_text()
    for token in (
        'static const int schemaVersion = 18;',
        'if (oldVersion < 18)',
        '_createV18Tables(db)',
        'CREATE TABLE IF NOT EXISTS transfer_receipts',
        'snapshot_id TEXT PRIMARY KEY',
        "'state_lineage_id': _uuid.v4()",
        "'state_generation': '0'",
        'reserveTransferSnapshot(String snapshotId)',
        'activatePendingImportedBrain',
        'forceLocalBrainTakeover',
        'pauseAfterManualTransferExport',
        'localTransferReceipt',
    ):
        if token not in db: fail(f'v18 transfer schema/ownership contract missing: {token}')
    more=(ROOT/'lib/features/more/companion_more_page.dart').read_text()
    inner=(ROOT/'lib/features/inner/inner_page.dart').read_text()
    if 'AI Companion · v0.26' not in more: fail('More version label != v0.26')
    if '她的内心 · v0.26 诊断' not in inner: fail('Inner diagnostic version label != v0.26')

def check_snapshot_protocol():
    s=(ROOT/'lib/core/sync/snapshot_service.dart').read_text()
    for token in (
        "'protocol_version': 2",
        "'snapshot_id': snapshotId",
        "'lineage_id': identity.lineageId",
        "'source_device_id': identity.deviceId",
        "'source_generation': identity.generation",
        "'target_activation_generation': identity.generation + 1",
        "'state_sha256': digest",
        "'state_bytes': jsonBytes.length",
        'transferReceipt(metadata.snapshotId)',
        'metadata.sourceGeneration <= localIdentity.generation',
        'SnapshotLineageMismatch',
        'SnapshotStaleException',
        "'pending_import_snapshot_id': metadata.snapshotId",
        'localTransferReceipt: receipt',
        "'active_brain': '0'",
        "'transfer_lock': '1'",
        '状态包内部 settings 与 manifest 身份不一致',
    ):
        if token not in s: fail(f'snapshot v2 protocol missing: {token}')

def check_nearby_bound_takeover():
    n=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NearbyTransferManager.kt').read_text()
    for token in (
        'ai_companion_takeover_v3',
        'SnapshotSession(',
        'pendingTakeovers',
        'outgoingSessions',
        'targetActivationGeneration != sourceGeneration + 1L',
        'snapshot_session_mismatch',
        'stale_or_mismatched_ack',
        'NativeEventStore.fenceForTakeover(',
        'source_state_no_longer_matches',
        'MAX_CONTROL_BYTES',
    ):
        if token not in n: fail(f'bound Nearby takeover missing: {token}')
    for forbidden in ('AI_COMPANION_TAKEOVER_REQUEST_V2','AI_COMPANION_TAKEOVER_ACK_V2'):
        if forbidden in n: fail(f'legacy unbound takeover token remains: {forbidden}')
    overlay=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text()
    for token in ('fun stopForStandby(context: Context)','NativeEventStore.isActiveBrain(context)'):
        if token not in overlay: fail(f'standby overlay ownership guard missing: {token}')
    if 'setOverlayUserEnabled(context, false)' in n:
        fail('Nearby takeover must not erase the user overlay preference')
    store=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt').read_text()
    for token in (
        'fun fenceForTakeover(',
        'fun isActiveBrain(context: Context): Boolean',
        'db.beginTransaction()',
        'pending_outbound_snapshot_id',
        'pending_outbound_generation',
        'replaceSetting(db, "active_brain", "0")',
        'replaceSetting(db, "transfer_lock", "0")',
    ):
        if token not in store: fail(f'native atomic source fence missing: {token}')

def check_manual_fallback():
    c=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt').read_text()
    for token in ('AES/GCM/NoPadding','PBKDF2WithHmacSHA256','210_000','cipher.updateAAD(header)','passphrase.fill'):
        if token not in c: fail(f'manual encryption missing: {token}')
    bridge=(ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt').read_text()
    for token in ('"saveManualSnapshot"','"openManualSnapshot"','Intent.ACTION_CREATE_DOCUMENT','Intent.ACTION_OPEN_DOCUMENT','ManualSnapshotCrypto.encrypt','ManualSnapshotCrypto.decrypt'):
        if token not in bridge: fail(f'manual document bridge missing: {token}')
    page=(ROOT/'lib/features/transfer/transfer_page.dart').read_text()
    for token in ('导出加密接管包','打开加密接管包','pauseAfterManualTransferExport','activatePendingImportedBrain','AES-256-GCM','本次包已作废','suspendOverlayForStandby','reconcileOverlayAfterTakeover'):
        if token not in page: fail(f'transfer UI hardening missing: {token}')

def check_previous_features_and_tts():
    prev.check_previous_features()
    prev.check_tts_contract(None)

def run_executable_checks():
    for script in (
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
        'README.md','pubspec.yaml','docs/DEV_STATUS.md','docs/ROADMAP.md','docs/TEST_CHECKLIST.md',
        'docs/ARCHITECTURE.md','docs/TRANSFER_HARDENING_v0.26.md','docs/INTERNAL_VALIDATION_v0.26.md',
        'lib/features/inner/inner_page.dart','lib/features/more/companion_more_page.dart',
        'lib/features/transfer/transfer_page.dart','lib/core/database/app_database.dart',
        'lib/core/sync/snapshot_service.dart','lib/core/platform/android_bridge.dart',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NearbyTransferManager.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt',
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
            if not cur.exists(): fail(f'unexpected v0.25 file deletion: {rel}')
            if hashlib.sha256(cur.read_bytes()).digest()!=hashlib.sha256(z.read(name)).digest():
                fail(f'unexpected change outside v0.26 allowlist: {rel}')
            checked+=1
        return checked

def compare_tts_payload(baseline:Path|None)->int:
    return prev.compare_tts_binary_freeze(baseline)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--baseline-zip',type=Path); args=ap.parse_args()
    checks=[
        ('XML/Manifest',base.check_xml_manifest),
        ('Dart relative imports',base.check_relative_imports),
        ('Dart/Kotlin delimiters',base.check_delimiters),
        ('Duplicate Dart declarations',base.check_adjacent_duplicate_dart_declarations),
        ('Version/schema 18',check_version_schema),
        ('Snapshot protocol v2',check_snapshot_protocol),
        ('Nearby bound takeover v3',check_nearby_bound_takeover),
        ('Encrypted manual fallback',check_manual_fallback),
        ('v0.24 continuity + older feature + TTS contracts',check_previous_features_and_tts),
        ('Proactive pipeline',base.check_proactive_pipeline),
        ('Notification quick reply',base.check_notification_quick_reply),
        ('Proactive UX UI',base.check_ui),
        ('True overlay regression',base.check_true_overlay_regression),
    ]
    for name,fn in checks:
        fn(); print('[OK]',name)
    run_executable_checks(); print('[OK] executable transfer/manual/TTS checks')
    frozen=compare_freeze(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] v0.25 frozen files byte-identical outside allowlist: {frozen}')
    tts=compare_tts_payload(args.baseline_zip)
    if args.baseline_zip: print(f'[OK] frozen TTS model/runtime/native payload unchanged from v0.25: {tts}')
    print('v0.26 Phone↔Tablet Sync Integrity validation passed.')
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}',file=sys.stderr); raise
