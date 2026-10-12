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
# +338 changes Thought text/evidence continuity only; restore methods are unchanged.
# SQLite regressions cover revision, idempotency, legacy repair and transfer lock.
# +339 adds CreativeContract.normalizeImport before any restore mutation; it
# validates source hashes/metadata and pauses imported jobs. Creative archive
# regressions cover invalid rows, old archives, private turns and stale players.
# +342 adds an optional bounded work snapshot to the existing user/job transaction;
# identity/session checks and stale-session rollback have SQLite regressions.
# +343 staged: private-work visibility guard and optional share publication in
# the existing proactive message transaction. Restore/export implementations
# are unchanged. New archive/atomic-share behavioral tests are CI PENDING.
# +345 reviewed: snapshot_service shares unchanged archive capacity defaults between
# export/import and rejects oversized complete bundles before delivery. Cleanup and
# source preservation are covered by capacity-overflow plus restore regressions.
# +345 DB delta: only extraction/inference/history lexical candidate selection
# now filters by cue before the existing caps. No writes, schema, backup or
# ownership methods changed; beyond-cap regressions cover all three readers.
# No restore ownership/schema/transfer behavior is changed.
PROTECTED = {'lib/core/database/app_database.dart': '96e5799f10a562692f826e45fb2c346f11200aea2b22b13534c5cdce0d8b3d03', 'lib/core/sync/snapshot_service.dart': 'ad9d0851fae1a68ac116f55be38695a5f08ecb8c17f1a5552ddf9e48e9607496', 'lib/core/sync/snapshot_restore_coordinator.dart': '80d547cc3203787187b310be75b943753e802bc31346ef6d19fdfbb7a2ed97ac', 'lib/core/sync/snapshot_cache_janitor.dart': '9e9dc7e44747f184b9359565512906ef24cb88666ac7c6456a92a9dfbd5f1d9b', 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt': '6cead2621c92ab42701dbe3e7081089e4a37648abb63fb2f96b1bad90f221002', 'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt': '3497404b13f2c388a276545db6342d16a44d8c17e18e2318dabfb84248a5dc84', 'android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt': 'a33deefe80a537f10e60c7b451ec30a43e134f3a8cd368252772b79898bcf9c6'}
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
