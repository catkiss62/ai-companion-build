#!/usr/bin/env python3
"""Guard the removal boundary: retired transport absent, shared restore core unchanged."""
# +370 reviewed: additive, rebuildable chat catalog; export includes metadata/version,
# import validates before mutation and rebuilds in the existing restore transaction.
# No source text deletion or restore ownership change; new ZIP/legacy/stale-read tests apply.
from pathlib import Path
import hashlib
APP = Path(__file__).resolve().parents[1]
# +359 reviewed DB delta: import and invoke the one-time natural-chat worldbook migration;
# no schema, restore, transaction ownership or transfer changes.
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
# +355: read-only chat Thought candidates and topic/text writes exclude MCP/web
# evidence identities. Notebook uses existing settings; schema/export/restore
# ownership methods remain unchanged. SQLite source and archive regressions added.
# +358 reviewed: optional read-only memory retrieval bypasses recall counters only
# when explicitly requested; one new archive lease is reset by existing import
# and snapshot normalization. Schema/transfer ownership/rollback are unchanged.
# Actual archive restore/stale-write tests and the original restore suite apply.
# +360 reviewed: one startup call to the approved one-shot natural-chat revision.
# No schema, transfer, restore or ownership behavior changes; SQLite rollback
# and idempotency regressions cover the migration transaction.
# +362 reviewed: ordinary proactive feedback and thought action share the message
# transaction; same public-web helper reused. Restore/schema/ownership unchanged.
# New commit/rollback regressions and existing restore CI remain required.
# +364 reviewed: twelve additive DB lines import/call the exact spoken migration,
# validate passive recall sources before existing ordinary/proactive commits, and
# consume those references inside the winning message transactions. No schema,
# transfer, import/export or recovery method changed. 671 focused tests passed,
# including ordinary/proactive commit, cancelled ownership, source edits/deletion
# and actual backup restore invalidation. Final full restore CI remains required.
# +367 reviewed: one job-scoped manual final-provider setting and a winning
# message transaction fence reject second-channel text after the user's choice.
# No schema, restore/export, transfer or tool-authorization change. Production
# runner takeover/stop/late-response regressions and full restore suite apply.
# +371 reviewed: only import and call for the approved exact-clause prompt
# migration. Schema, snapshots, transfer and transaction ownership unchanged.
# +372: reviewed additive raw-history commit guards and persistent room-background
# media ownership exclusions; snapshot validates image/config binding. No schema,
# crypto, transfer ownership or restore-journal changes. Real ZIP/GC/stale-save
# regressions added; current CI is pending, not claimed passed.
# +374 reviewed: atomic failed-reply DS selection and question/presence lifecycle only.
# No schema, export/import, restore journal, encryption or transfer-owner changes.
# New real SQLite/runner recovery tests and the unchanged archive suite apply.
# +376 reviewed: running recovery checks the current exclusive chat lease;
# retry timing follows lease liveness and explicit DS selection clears retry wait.
# Schema/transfer/restore and tool receipts remain unchanged; real SQLite
# orphan/live/replaced/Stop and runner regressions plus full restore CI apply.
# +378 reviewed: cancellation fences inside user/job commit, per-job final effort,
# approved one-shot worldbook refresh, speech claim cleared on import and job
# snapshot pruning only. No schema/crypto/restore journal/transfer-owner changes.
# Existing restore suite and new real SQLite rollback/cancel/config tests apply.
# +380 reviewed: valid-source SQL before caps, shared prompt admission, automatic
# memory permit versions on feature changes, and source-time guards for current
# revisions/lifecycle. No schema, export/import, restore or crypto changes.
# New actual SQLite/QQ/source/permit tests await CI; not claimed passed.
# +381 reviewed: additive isolated QQ tables/snapshot validation, source-bound App commits,
# source-order successor recall, fresh restore epoch and explicit QQ pause on restore.
# No signing/crypto/transfer ownership weakening. New SQLite, runtime and media regressions await CI.
# +385 reviewed DB delta: schema64 and isolated QQ work/receipt/style/SVG tables.
# Existing export/import iterates QqArchiveSchema.tables; source validation and
# restored work revocation remain in the QQ adapter. Crypto/transfer core unchanged.
# +387 reviewed DB delta: schema65 adds QQ context_meta with idempotent migration.
# Old backup defaults and provenance roundtrip have real SQLite/Flutter regressions;
# crypto, transfer ownership and restore-journal files remain byte-identical.
# +390 reviewed DB delta: schema66 creates isolated QQ outgoing-voice metadata.
# Only version and idempotent QqArchiveSchema.create upgrade call change here;
# portable table iteration/validation covers text transcripts and child cleanup.
# Crypto, restore journal and transfer ownership stay byte-identical; full restore CI required.
# +392 reviewed DB delta: schema67 adds isolated QQ attention/reply tasks, event media owners,
# and bounded web-share refresh state. Media GC/export/import and final source guards are
# covered by recovery tests; snapshot service adds the same owner validator.
# Snapshot crypto/transfer/restore journal remain unchanged.
# +397 reviewed DB delta: readiness queries require the exact active, unsnoozed web Thought.
# No schema, snapshot, crypto, transfer or restore-journal changes. Production SQLite
# queue tests cover missing/dormant/snoozed/active/expired binding boundaries.
PROTECTED = {'lib/core/database/app_database.dart': '3134932f07863418f091738f3cb736f5892ca1d41cb7f032d4a576a2a3e6d77d', 'lib/core/sync/snapshot_service.dart': '14fe97be8307f76f83e9a66455a75315323477f01225f63ef3ec5e6fe3a70f91', 'lib/core/sync/snapshot_restore_coordinator.dart': '349681da10209ffb6b2108934e3b907091c7ac1015d7551b840796f80d9435c2', 'lib/core/sync/snapshot_cache_janitor.dart': '9e9dc7e44747f184b9359565512906ef24cb88666ac7c6456a92a9dfbd5f1d9b', 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeEventStore.kt': '6cead2621c92ab42701dbe3e7081089e4a37648abb63fb2f96b1bad90f221002', 'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt': '3497404b13f2c388a276545db6342d16a44d8c17e18e2318dabfb84248a5dc84', 'android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt': 'a33deefe80a537f10e60c7b451ec30a43e134f3a8cd368252772b79898bcf9c6'}
# +384 reviewed: additive QQ schema63 note source ranges and edit revision, with
# old-source token compatibility; no encryption/restore-journal/transfer-owner changes.
# QQ raw/note migration, cross-month cleanup and existing restore CI cover it.
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
