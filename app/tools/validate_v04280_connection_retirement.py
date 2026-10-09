#!/usr/bin/env python3
"""Guard the removal boundary: retired transport absent, shared restore core unchanged."""
from pathlib import Path
import hashlib
APP = Path(__file__).resolve().parents[1]
# Reviewed +323 restore core. +328 adds only reminder import and two message-commit guards
# in app_database.dart. +332 only extends PortableCompanionState field bounds with
# rightEarX/rightEarY/rightEarRotation; transactional restore/ownership is unchanged.
# Android restore/rollback tests cover the three added fields.
# +335 passes the isolated DB to media storage, excludes the media file lease
# from backups, and serializes restore with media ownership changes. Existing
# process-recovery tests plus shared-sticker backup tests cover this reviewed delta.
PROTECTED = {'lib/core/database/app_database.dart': 'fb552cbb8a065b0e5723b85ce5a464c877079e8fdfa715d8c80f932a59cb79bd', 'lib/core/sync/snapshot_service.dart': 'ac9baf75ad9066cdb8c94a5a21bab533f38419ede9606989859350bf5292c974', 'lib/core/sync/snapshot_restore_coordinator.dart': '80d547cc3203787187b310be75b943753e802bc31346ef6d19fdfbb7a2ed97ac', 'lib/core/sync/snapshot_cache_janitor.dart': '9e9dc7e44747f184b9359565512906ef24cb88666ac7c6456a92a9dfbd5f1d9b', 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt': '6cead2621c92ab42701dbe3e7081089e4a37648abb63fb2f96b1bad90f221002', 'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt': '3497404b13f2c388a276545db6342d16a44d8c17e18e2318dabfb84248a5dc84', 'android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt': 'a33deefe80a537f10e60c7b451ec30a43e134f3a8cd368252772b79898bcf9c6'}
for path, digest in PROTECTED.items():
    assert hashlib.sha256((APP / path).read_bytes()).hexdigest() == digest, path
native = APP / 'android/app/src/main/kotlin/com/aicompanion/localfirst'
assert not (native / 'NearbyTransferManager.kt').exists()
for path in [native / 'SystemBridge.kt', APP / 'lib/core/platform/android_bridge.dart', APP / 'lib/features/transfer/transfer_page.dart']:
    text = path.read_text()
    for retired in ('startNearby', 'nearby_events', 'NearbyTransferManager', 'confirmNearbyTakeover'):
        assert retired not in text, (path, retired)
assert 'play-services-nearby' not in (APP / 'android/app/build.gradle.kts').read_text()
manifest = (APP / 'android/app/src/main/AndroidManifest.xml').read_text()
for permission in ('BLUETOOTH_SCAN', 'BLUETOOTH_CONNECT', 'BLUETOOTH_ADVERTISE', 'NEARBY_WIFI_DEVICES', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
    assert 'android.permission.' + permission not in manifest
print('Nearby retired; +328 reminder commit guards reviewed; shared restore/ownership core preserved')
