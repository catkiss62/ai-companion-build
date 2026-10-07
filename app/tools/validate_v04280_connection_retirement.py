#!/usr/bin/env python3
"""Guard the removal boundary: retired transport absent, shared restore core unchanged."""
from pathlib import Path
import hashlib
APP = Path(__file__).resolve().parents[1]
# Reviewed +323 restore core. +328 adds only reminder import and two message-commit guards
# in app_database.dart; restore/ownership methods and the other six files are unchanged.
PROTECTED = {'lib/core/database/app_database.dart': 'fb552cbb8a065b0e5723b85ce5a464c877079e8fdfa715d8c80f932a59cb79bd', 'lib/core/sync/snapshot_service.dart': '4863d5521b25f5bbbfe490f46aa63794bb792f945d6254dccf3ce550ad0ae35c', 'lib/core/sync/snapshot_restore_coordinator.dart': '069c2820b0b6cfccbe6125d64b4585eb6d992a3698381e9eb750dc24970cf32e', 'lib/core/sync/snapshot_cache_janitor.dart': '9e9dc7e44747f184b9359565512906ef24cb88666ac7c6456a92a9dfbd5f1d9b', 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt': '6cead2621c92ab42701dbe3e7081089e4a37648abb63fb2f96b1bad90f221002', 'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt': '3497404b13f2c388a276545db6342d16a44d8c17e18e2318dabfb84248a5dc84', 'android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt': 'c84b2ec18449544ce2ceb935b235490611cb144ca07ab7a9c2e45dd19a163657'}
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
