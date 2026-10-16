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
# +346 reviewed DB delta against beaf9ea: two additive read-only candidate
# queries and dependency-aware creative snapshot retention inside the existing
# user/job transaction. Export/import, schema and ownership are unchanged.
# prompt_candidate_capacity and creative_snapshot_retention regressions plus
# the full 1691 Flutter suite passed before this packaging-only version bump.
# +347 reviewed: additive form/revision columns; immutable generation snapshots,
# version-bound memory revisions and source pairs; retention CAS and fenced
# proactive lease renewal. Restore ownership/protocol remains unchanged.
# New SQLite export/import, stale-write and cancellation regressions are CI PENDING.
# +348: source versions/lifecycle and indexed derived links, media ownership,
# captured sources and atomic delivery. Targeted restore/lease regressions retained.
# +349 changes only the read-only browser SELECT to preserve its stored origin;
# backup/restore ownership code is unchanged, with actual SQLite provenance regression.
# +351: memory merge excludes withdrawn sources; no restore/schema/ownership
# delta. review_recovery and existing source/backup regressions validate this.
# +352: only import/call the exact-old-default spoken-dialogue migration.
# Database diff against +351 is exactly those two lines; restore/export,
# schema and ownership methods are unchanged. SQLite migration regressions
# cover preserved custom bodies/controls and one-shot behavior (392 focused tests passed).
# +354: optional source-identity isolation for exact memory duplicates, enabled
# only by the source-bound game-arrangement writer. The reviewed DB diff is
# one default-false argument, scoped duplicate selection and one stored marker.
# Restore/export/schema/ownership code is unchanged. Cross-save, ordinary
# reinforcement and actual export/import regressions passed in the 468-test suite.
PROTECTED = {'lib/core/database/app_database.dart': 'e274187b22dfb064b387da61cadb33342aebb198028fe7ada644dd26f22608f5', 'lib/core/sync/snapshot_service.dart': 'b149d23582191f4b7c6a4dcff44d2b244e5e2fba76e6f74656634e8b3ccdd975', 'lib/core/sync/snapshot_restore_coordinator.dart': '2a3fd1c8237774aa9c2d0e88e7d4dba28cea732388b495761403119be78d886d', 'lib/core/sync/snapshot_cache_janitor.dart': '9e9dc7e44747f184b9359565512906ef24cb88666ac7c6456a92a9dfbd5f1d9b', 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt': '6cead2621c92ab42701dbe3e7081089e4a37648abb63fb2f96b1bad90f221002', 'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt': '3497404b13f2c388a276545db6342d16a44d8c17e18e2318dabfb84248a5dc84', 'android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt': 'a33deefe80a537f10e60c7b451ec30a43e134f3a8cd368252772b79898bcf9c6'}
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
