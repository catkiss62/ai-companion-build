import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../emotion/emotion_contract.dart';
import '../models/chat_message.dart';
import '../models/companion_album.dart';
import '../platform/android_bridge.dart';
import '../models/emotion_episode.dart';
import '../models/autonomous_action.dart';
import '../models/public_web_candidate.dart';
import '../models/message_attachment.dart';
import '../models/awareness_observation.dart';
import '../models/conversation_summary.dart';
import '../models/desire_state.dart';
import '../models/daily_continuity.dart';
import '../models/memory_item.dart';
import '../memory/memory_retrieval_policy.dart';
import '../models/perception_snapshot.dart';
import '../models/personality_trial.dart';
import '../models/post_turn_job.dart';
import '../models/generation_job.dart';
import '../models/maintenance_run.dart';
import '../models/reference_item.dart';
import '../models/reference_document.dart';
import '../models/rule_layer.dart';
import '../models/proactive_feedback.dart';
import '../models/thought_lifecycle_event.dart';
import '../rules/rule_layer_defaults.dart';
import '../relationship/relationship_age.dart';
import '../personality/personality_catalog.dart';
import '../models/relationship_event.dart';
import '../models/interaction_session.dart';
import '../models/thought.dart';
import '../models/unfinished_thread.dart';
import '../models/somatic_state.dart';
import '../somatic/somatic_policy.dart';
import '../sync/transfer_identity.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String dbName = 'ai_companion.db';
  // Historical validator compatibility token: static const int schemaVersion = 24;
  // Historical validator compatibility token: static const int schemaVersion = 25;
  // Historical validator compatibility token: static const int schemaVersion = 26;
  // Historical validator compatibility token: static const int schemaVersion = 27;
  // Historical validator compatibility token: static const int schemaVersion = 28;
  // Historical validator compatibility token: static const int schemaVersion = 29;
  // Historical validator compatibility token: static const int schemaVersion = 30;
  // Historical validator compatibility token: static const int schemaVersion = 31;
  // Historical validator compatibility token: static const int schemaVersion = 32;
  // Historical validator compatibility token: static const int schemaVersion = 33;
  static const int schemaVersion = 34;

  Database? _db;
  Future<Database>? _opening;
  final Uuid _uuid = Uuid();
  final Map<String, String> _ownedLeaseTokens = <String, String>{};
  Future<String>? _leaseOwnerEpochFuture;

  Future<Database> get database async {
    final ready = _db;
    if (ready != null) return ready;
    final opening = _opening;
    if (opening != null) return opening;

    final pending = _open();
    _opening = pending;
    try {
      final opened = await pending;
      _db = opened;
      return opened;
    } finally {
      if (identical(_opening, pending)) _opening = null;
    }
  }

  Future<String> get databasePath async {
    final root = await getDatabasesPath();
    return p.join(root, dbName);
  }

  Future<Database> _open() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        final journalRows = await db.rawQuery('PRAGMA journal_mode = WAL');
        final journalMode = journalRows.isEmpty
            ? ''
            : journalRows.first.values.first?.toString().toLowerCase() ?? '';
        if (journalMode != 'wal') {
          throw StateError('SQLite WAL mode unavailable (journal_mode=$journalMode)');
        }
        await db.rawQuery('PRAGMA synchronous = NORMAL');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE memory_items ADD COLUMN confidence REAL NOT NULL DEFAULT 0.7",
      );
      await db.execute(
        "ALTER TABLE memory_items ADD COLUMN source TEXT NOT NULL DEFAULT 'conversation'",
      );
      await db.execute(
        "ALTER TABLE memory_items ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
      );
      await db.execute('ALTER TABLE memory_items ADD COLUMN updated_at INTEGER');
      await db.execute(
        'UPDATE memory_items SET updated_at = created_at WHERE updated_at IS NULL',
      );

      await db.execute(
        "ALTER TABLE thoughts ADD COLUMN source TEXT NOT NULL DEFAULT 'internal'",
      );
      await db.execute('ALTER TABLE thoughts ADD COLUMN last_fed_at INTEGER');
      await db.execute(
        'UPDATE thoughts SET last_fed_at = updated_at WHERE last_fed_at IS NULL',
      );

      await _createV2Tables(db);
      await db.insert(
        'settings',
        {'key': 'memory_consolidation_enabled', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.insert(
        'settings',
        {'key': 'self_drive_enabled', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
      // Normalize indexes for databases that originated from the v0.1 schema.
      await db.execute('DROP INDEX IF EXISTS idx_memory_kind');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_memory_kind ON memory_items(kind, status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_thoughts_strength ON thoughts(strength DESC, updated_at DESC)',
      );
      for (final entry in const <String, String>{
        'perception_enabled': '1',
        'ai_self_reflection_enabled': '1',
        'tts_enabled': '0',
        'auto_tts': '0',
        'tts_streaming_enabled': '0',
        'proactive_tts_policy': 'silent',
        'last_proactive_spoken_message_id': '',
        'tts_speed': '1.0',
        'tts_volume': '1.0',
        'tts_replacements_json': '{"Yuki":"有希"}',
        'relationship_continuity_enabled': '1',
        'session_tracking_enabled': '1',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE memory_items ADD COLUMN subject_key TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE memory_items ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE memory_items ADD COLUMN superseded_by TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_memory_subject ON memory_items(kind, subject_key, status)',
      );
      await _createV4Tables(db);
      for (final entry in const <String, String>{
        'relationship_continuity_enabled': '1',
        'session_tracking_enabled': '1',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 5) {
      for (final entry in const <String, String>{
        'tts_streaming_enabled': '0',
        'proactive_tts_policy': 'silent',
        'last_proactive_spoken_message_id': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE memory_items ADD COLUMN retention_score REAL NOT NULL DEFAULT 1.0',
      );
      await db.execute('ALTER TABLE memory_items ADD COLUMN retention_checked_at INTEGER');
      await db.execute(
        'UPDATE memory_items SET retention_checked_at = updated_at WHERE retention_checked_at IS NULL',
      );
      await db.execute('ALTER TABLE relationship_events ADD COLUMN internalized_at INTEGER');
      // Legacy v0.6 relationship history already influenced the user-visible
      // relationship context. Do not replay months of old events as fresh
      // Desire pulses immediately after upgrading.
      await db.execute(
        'UPDATE relationship_events SET internalized_at = created_at WHERE internalized_at IS NULL',
      );
      await _createV6Tables(db);
      for (final entry in const <String, String>{
        'memory_fading_enabled': '1',
        'reference_library_enabled': '1',
        'last_memory_maintenance_at': '0',
        'rule_layers_enabled': '1',
        'thought_lifecycle_enabled': '1',
        'proactive_adaptation_enabled': '1',
        'proactive_feedback_expiry_hours': '10',
        'proactive_notification_privacy': 'smart',
        'thought_consolidation_enabled': '1',
        'last_thought_consolidation_at': '0',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 7) {
      await _createV7Tables(db);
      final columns = await db.rawQuery('PRAGMA table_info(reference_items)');
      final hasDocumentId = columns.any((row) => row['name'] == 'document_id');
      if (!hasDocumentId) {
        await db.execute('ALTER TABLE reference_items ADD COLUMN document_id TEXT');
      }
      final legacySources = await db.rawQuery(
        "SELECT DISTINCT source_name FROM reference_items WHERE document_id IS NULL AND source_name IS NOT NULL AND source_name <> ''",
      );
      for (final source in legacySources) {
        final sourceName = source['source_name'] as String;
        final rows = await db.query(
          'reference_items',
          where: 'source_name = ? AND document_id IS NULL',
          whereArgs: [sourceName],
          orderBy: 'created_at ASC',
        );
        if (rows.isEmpty) continue;
        final docId = _uuid.v4();
        final raw = rows.map((e) => e['content'] as String? ?? '').where((e) => e.trim().isNotEmpty).join('\n\n');
        final created = rows.first['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final updated = rows.last['updated_at'] as int? ?? created;
        await db.insert('reference_documents', {
          'id': docId,
          'name': sourceName,
          'kind': 'legacy_reference',
          'aliases': '',
          'raw_content': raw,
          'enabled': 1,
          'created_at': created,
          'updated_at': updated,
        });
        await db.update(
          'reference_items',
          {'document_id': docId},
          where: 'source_name = ? AND document_id IS NULL',
          whereArgs: [sourceName],
        );
      }
      await _seedRuleLayers(db);
      await db.insert(
        'settings',
        {'key': 'rule_layers_enabled', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    if (oldVersion < 8) {
      final thoughtColumns = await db.rawQuery('PRAGMA table_info(thoughts)');
      final names = thoughtColumns.map((row) => row['name'] as String).toSet();
      Future<void> addThoughtColumn(String name, String sql) async {
        if (!names.contains(name)) await db.execute('ALTER TABLE thoughts ADD COLUMN $sql');
      }
      await addThoughtColumn('lifecycle_state', "lifecycle_state TEXT NOT NULL DEFAULT 'active'");
      await addThoughtColumn('action_count', 'action_count INTEGER NOT NULL DEFAULT 0');
      await addThoughtColumn('last_acted_at', 'last_acted_at INTEGER');
      await addThoughtColumn('last_satisfied_at', 'last_satisfied_at INTEGER');
      await addThoughtColumn('last_resurfaced_at', 'last_resurfaced_at INTEGER');
      await addThoughtColumn('resurfaced_count', 'resurfaced_count INTEGER NOT NULL DEFAULT 0');
      await addThoughtColumn('residual_strength', 'residual_strength REAL NOT NULL DEFAULT 0');
      await addThoughtColumn('last_outbound_message_id', 'last_outbound_message_id TEXT');
      await db.execute(
        "UPDATE thoughts SET lifecycle_state = CASE WHEN kind = 'fixation' THEN 'fixation' ELSE 'active' END WHERE lifecycle_state IS NULL OR lifecycle_state = ''",
      );
      await _createV8Tables(db);
      for (final entry in const <String, String>{
        'thought_lifecycle_enabled': '1',
        'proactive_adaptation_enabled': '1',
        'proactive_feedback_expiry_hours': '10',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 9) {
      final thoughtColumns = await db.rawQuery('PRAGMA table_info(thoughts)');
      final thoughtNames = thoughtColumns.map((row) => row['name'] as String).toSet();
      if (!thoughtNames.contains('topic_key')) {
        await db.execute("ALTER TABLE thoughts ADD COLUMN topic_key TEXT NOT NULL DEFAULT ''");
      }
      if (!thoughtNames.contains('merged_count')) {
        await db.execute('ALTER TABLE thoughts ADD COLUMN merged_count INTEGER NOT NULL DEFAULT 0');
      }
      if (!thoughtNames.contains('last_merged_at')) {
        await db.execute('ALTER TABLE thoughts ADD COLUMN last_merged_at INTEGER');
      }
      if (!thoughtNames.contains('snoozed_until')) {
        await db.execute('ALTER TABLE thoughts ADD COLUMN snoozed_until INTEGER');
      }

      final threadColumns = await db.rawQuery('PRAGMA table_info(unfinished_threads)');
      final threadNames = threadColumns.map((row) => row['name'] as String).toSet();
      if (!threadNames.contains('topic_key')) {
        await db.execute("ALTER TABLE unfinished_threads ADD COLUMN topic_key TEXT NOT NULL DEFAULT ''");
      }

      final feedbackColumns = await db.rawQuery('PRAGMA table_info(proactive_feedback)');
      final feedbackNames = feedbackColumns.map((row) => row['name'] as String).toSet();
      Future<void> addFeedbackColumn(String name, String sql) async {
        if (!feedbackNames.contains(name)) {
          await db.execute('ALTER TABLE proactive_feedback ADD COLUMN $sql');
        }
      }
      await addFeedbackColumn('topic_key', "topic_key TEXT NOT NULL DEFAULT ''");
      await addFeedbackColumn('thread_id', 'thread_id TEXT');
      await addFeedbackColumn('response_quality', 'response_quality REAL');
      await addFeedbackColumn('outcome', "outcome TEXT NOT NULL DEFAULT 'pending'");
      await addFeedbackColumn('outcome_score', 'outcome_score REAL');
      await addFeedbackColumn('processed_at', 'processed_at INTEGER');
      await db.execute('''
        UPDATE proactive_feedback
        SET outcome = CASE
          WHEN response_bucket = 'no_response' THEN 'no_response'
          WHEN user_response_message_id IS NOT NULL THEN 'response_received'
          ELSE 'pending'
        END,
        processed_at = CASE
          WHEN response_bucket = 'no_response' THEN sent_at
          ELSE processed_at
        END
      ''');
      await _createV9Tables(db);
      for (final entry in const <String, String>{
        'thought_consolidation_enabled': '1',
        'last_thought_consolidation_at': '0',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 10) {
      final threadColumns = await db.rawQuery('PRAGMA table_info(unfinished_threads)');
      final threadNames = threadColumns.map((row) => row['name'] as String).toSet();
      Future<void> addThreadColumn(String name, String sql) async {
        if (!threadNames.contains(name)) {
          await db.execute('ALTER TABLE unfinished_threads ADD COLUMN $sql');
        }
      }
      await addThreadColumn('followup_due_at', 'followup_due_at INTEGER');
      await addThreadColumn('followup_seeded_at', 'followup_seeded_at INTEGER');
      await addThreadColumn('followup_count', 'followup_count INTEGER NOT NULL DEFAULT 0');
      await addThreadColumn('last_followup_at', 'last_followup_at INTEGER');
      await addThreadColumn('retired_at', 'retired_at INTEGER');
      await addThreadColumn('retire_reason', "retire_reason TEXT NOT NULL DEFAULT ''");

      await _createV10Tables(db);
      for (final entry in const <String, String>{
        'long_running_maintenance_enabled': '1',
        'last_long_running_maintenance_at': '0',
        'deferred_followup_enabled': '1',
        'max_deferred_followups': '1',
        'post_turn_queue_enabled': '1',
        'background_error_count': '0',
        'last_background_error': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 11) {
      await _createV11Tables(db);
      for (final entry in const <String, String>{
        'durable_generation_enabled': '1',
        'generation_max_attempts': '0',
        'last_generation_recovery_error': '',
        'post_turn_max_attempts': '0',
        'last_async_worker_error': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 12) {
      final columns = await db.rawQuery('PRAGMA table_info(post_turn_jobs)');
      final names = columns.map((row) => row['name'] as String).toSet();
      Future<void> addColumn(String name, String sql) async {
        if (!names.contains(name)) {
          await db.execute('ALTER TABLE post_turn_jobs ADD COLUMN $sql');
        }
      }
      await addColumn('run_token', "run_token TEXT NOT NULL DEFAULT ''");
      await addColumn('result_json', "result_json TEXT NOT NULL DEFAULT ''");
      await addColumn('started_at', 'started_at INTEGER');
      await addColumn('heartbeat_at', 'heartbeat_at INTEGER');
      await addColumn('next_retry_at', 'next_retry_at INTEGER');
      await addColumn('model_completed_at', 'model_completed_at INTEGER');
      await addColumn('desire_applied_at', 'desire_applied_at INTEGER');
      final threadColumns = await db.rawQuery('PRAGMA table_info(unfinished_threads)');
      final threadNames = threadColumns.map((row) => row['name'] as String).toSet();
      if (!threadNames.contains('followup_run_token')) {
        await db.execute("ALTER TABLE unfinished_threads ADD COLUMN followup_run_token TEXT NOT NULL DEFAULT ''");
      }
      if (!threadNames.contains('followup_claimed_at')) {
        await db.execute('ALTER TABLE unfinished_threads ADD COLUMN followup_claimed_at INTEGER');
      }
      if (!threadNames.contains('proactive_outcome_message_id')) {
        await db.execute('ALTER TABLE unfinished_threads ADD COLUMN proactive_outcome_message_id TEXT');
      }
      await db.execute(
        "UPDATE post_turn_jobs SET status = 'retry_wait', run_token = '', next_retry_at = updated_at, last_error = 'v012_running_recovered' WHERE status = 'running'",
      );
      // Older builds did not fence summary consolidation across Flutter
      // engines. Collapse any duplicate range before adding the unique index.
      await db.execute('''
        DELETE FROM conversation_summaries
        WHERE rowid NOT IN (
          SELECT MIN(rowid) FROM conversation_summaries GROUP BY from_at, to_at
        )
      ''');
      await _createV12Tables(db);
      for (final entry in const <String, String>{
        'post_turn_max_attempts': '0',
        'last_async_worker_error': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 13) {
      final messageColumns = await db.rawQuery('PRAGMA table_info(messages)');
      final messageNames = messageColumns.map((row) => row['name'] as String).toSet();
      if (!messageNames.contains('proactive_intent')) {
        await db.execute("ALTER TABLE messages ADD COLUMN proactive_intent TEXT NOT NULL DEFAULT ''");
      }
      if (!messageNames.contains('proactive_delivery')) {
        await db.execute("ALTER TABLE messages ADD COLUMN proactive_delivery TEXT NOT NULL DEFAULT ''");
      }
      final feedbackColumns = await db.rawQuery('PRAGMA table_info(proactive_feedback)');
      final feedbackNames = feedbackColumns.map((row) => row['name'] as String).toSet();
      if (!feedbackNames.contains('intent_kind')) {
        await db.execute("ALTER TABLE proactive_feedback ADD COLUMN intent_kind TEXT NOT NULL DEFAULT ''");
      }
      if (!feedbackNames.contains('delivery_style')) {
        await db.execute("ALTER TABLE proactive_feedback ADD COLUMN delivery_style TEXT NOT NULL DEFAULT ''");
      }
      await db.execute('''
        UPDATE proactive_feedback
        SET intent_kind = CASE
          WHEN thread_id IS NOT NULL AND thread_id <> '' THEN 'followup'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'attachment' THEN 'miss_you'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'curiosity' THEN 'curiosity'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'reflection' THEN 'share_thought'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'duty' THEN 'followup'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'social' THEN 'social_share'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'libido' THEN 'intimacy_invitation'
          WHEN (SELECT drive_key FROM thoughts WHERE thoughts.id = proactive_feedback.thought_id) = 'stress' THEN 'emotional_reach'
          ELSE 'gentle_ping'
        END,
        delivery_style = CASE WHEN delivery_style = '' THEN 'normal' ELSE delivery_style END
        WHERE intent_kind = ''
      ''');
      await db.execute('''
        UPDATE messages
        SET proactive_intent = COALESCE(
              (SELECT intent_kind FROM proactive_feedback
               WHERE proactive_feedback.proactive_message_id = messages.id),
              CASE WHEN is_proactive = 1 THEN 'gentle_ping' ELSE '' END
            ),
            proactive_delivery = CASE
              WHEN is_proactive = 1 THEN 'normal'
              ELSE ''
            END
        WHERE proactive_intent = '' AND is_proactive = 1
      ''');
      await _createV13Tables(db);
      await db.insert(
        'settings',
        {'key': 'proactive_notification_privacy', 'value': 'smart'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    if (oldVersion < 14) {
      await _createV14Tables(db);
    }

    if (oldVersion < 15) {
      await db.execute(
        "ALTER TABLE memory_items ADD COLUMN semantic_type TEXT NOT NULL DEFAULT 'current_fact'",
      );
      await db.execute(
        'ALTER TABLE memory_items ADD COLUMN evidence_count INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE memory_items ADD COLUMN first_observed_at INTEGER');
      await db.execute('ALTER TABLE memory_items ADD COLUMN last_evidence_at INTEGER');
      await db.execute(
        'ALTER TABLE memory_items ADD COLUMN fact_version INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "UPDATE memory_items SET semantic_type = 'shared_experience' WHERE kind = 'shared_experience'",
      );
      await db.execute(
        'UPDATE memory_items SET first_observed_at = created_at WHERE first_observed_at IS NULL',
      );
      await db.execute(
        'UPDATE memory_items SET last_evidence_at = updated_at WHERE last_evidence_at IS NULL',
      );
      await db.execute("""
        UPDATE memory_items
        SET fact_version = (
          SELECT COUNT(*)
          FROM memory_items AS older
          WHERE memory_items.subject_key <> ''
            AND older.kind = memory_items.kind
            AND older.subject_key = memory_items.subject_key
            AND (older.created_at < memory_items.created_at
              OR (older.created_at = memory_items.created_at AND older.id <= memory_items.id))
        )
        WHERE memory_items.subject_key <> ''
      """);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_memory_semantic ON memory_items(semantic_type, status, updated_at DESC)',
      );
      await _createV15Tables(db);
    }
    if (oldVersion < 16) {
      final feedbackColumns = await db.rawQuery('PRAGMA table_info(proactive_feedback)');
      final feedbackNames = feedbackColumns.map((row) => row['name'] as String).toSet();
      Future<void> addFeedbackColumn(String name, String sql) async {
        if (!feedbackNames.contains(name)) {
          await db.execute('ALTER TABLE proactive_feedback ADD COLUMN $sql');
        }
      }
      await addFeedbackColumn(
        'context_hour_bucket',
        "context_hour_bucket TEXT NOT NULL DEFAULT ''",
      );
      await addFeedbackColumn(
        'context_activity',
        "context_activity TEXT NOT NULL DEFAULT 'unknown'",
      );
      await addFeedbackColumn(
        'context_busy',
        'context_busy REAL NOT NULL DEFAULT 0',
      );
      await addFeedbackColumn('timing_fit', 'timing_fit REAL');
      await addFeedbackColumn('topic_fit', 'topic_fit REAL');
      await _createV16Tables(db);
    }
    if (oldVersion < 17) {
      await _createV17Tables(db);
      for (final entry in const <String, String>{
        'daily_continuity_enabled': '1',
        'last_daily_continuity_refresh_at': '0',
        'last_daily_continuity_error': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 18) {
      await _createV18Tables(db);
      for (final entry in <String, String>{
        'state_lineage_id': _uuid.v4(),
        'state_generation': '0',
        'pending_outbound_snapshot_id': '',
        'pending_outbound_generation': '0',
        'pending_import_snapshot_id': '',
        'pending_import_lineage_id': '',
        'pending_import_source_device_id': '',
        'pending_import_generation': '0',
        'pending_import_state_sha256': '',
        'last_takeover_snapshot_id': '',
        'last_takeover_source_device_id': '',
        'last_takeover_at': '0',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 20) {
      // Preserve user-visible content/reasoning while rebuilding the message
      // table without v19's retired experimental compatibility columns.
      await db.execute('''
        CREATE TABLE messages_v20 (
          id TEXT PRIMARY KEY,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          reasoning_content TEXT NOT NULL DEFAULT '',
          model TEXT,
          created_at INTEGER NOT NULL,
          is_proactive INTEGER NOT NULL DEFAULT 0,
          proactive_intent TEXT NOT NULL DEFAULT '',
          proactive_delivery TEXT NOT NULL DEFAULT '',
          device_id TEXT
        )
      ''');
      await db.execute('''
        INSERT INTO messages_v20 (
          id, role, content, reasoning_content, model, created_at,
          is_proactive, proactive_intent, proactive_delivery, device_id
        )
        SELECT
          id, role, content, reasoning_content, model, created_at,
          is_proactive, proactive_intent, proactive_delivery, device_id
        FROM messages
      ''');
      await db.execute('DROP TABLE messages');
      await db.execute('ALTER TABLE messages_v20 RENAME TO messages');
      await db.execute(
        'CREATE INDEX idx_messages_created_at ON messages(created_at)',
      );
      await db.delete(
        'settings',
        where: 'key LIKE ?',
        whereArgs: ['companion_voice%'],
      );
    }
    if (oldVersion < 21) {
      await _createV21Tables(db);
    }
    if (oldVersion < 22) {
      final messageColumns = await db.rawQuery('PRAGMA table_info(messages)');
      if (!messageColumns.any((row) => row['name'] == 'expects_reply')) {
        await db.execute(
          'ALTER TABLE messages ADD COLUMN expects_reply INTEGER NOT NULL DEFAULT 1',
        );
      }
      await _createV22Tables(db);
    }
    if (oldVersion < 23) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(message_attachments)',
      );
      final names = columns.map((row) => row['name']).toSet();
      if (!names.contains('vision_status')) {
        await db.execute(
          "ALTER TABLE message_attachments ADD COLUMN vision_status TEXT NOT NULL DEFAULT 'pending'",
        );
      }
      if (!names.contains('vision_summary')) {
        await db.execute(
          "ALTER TABLE message_attachments ADD COLUMN vision_summary TEXT NOT NULL DEFAULT ''",
        );
      }
      if (!names.contains('vision_model')) {
        await db.execute(
          "ALTER TABLE message_attachments ADD COLUMN vision_model TEXT NOT NULL DEFAULT ''",
        );
      }
      if (!names.contains('vision_error')) {
        await db.execute(
          "ALTER TABLE message_attachments ADD COLUMN vision_error TEXT NOT NULL DEFAULT ''",
        );
      }
      if (!names.contains('vision_attempts')) {
        await db.execute(
          'ALTER TABLE message_attachments ADD COLUMN vision_attempts INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!names.contains('vision_updated_at')) {
        await db.execute(
          'ALTER TABLE message_attachments ADD COLUMN vision_updated_at INTEGER',
        );
      }
      await db.update(
        'message_attachments',
        {
          'vision_status': 'failed',
          'vision_error': '这是旧版本保存的图片；如需识别，请手动重试。',
          'vision_updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: "vision_status = 'pending' AND vision_attempts = 0",
      );
      await db.update(
        'message_attachments',
        {
          'vision_status': 'failed',
          'vision_error': '应用在识图过程中退出，请重试。',
          'vision_updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: "vision_status = 'analyzing'",
      );
    }

    if (oldVersion < 24) {
      await _createV24Tables(db);
    }
    if (oldVersion < 25) {
      await _createV25Tables(db);
      for (final entry in const <String, String>{
        'public_web_discovery_enabled': '1',
        'last_public_web_discovery_at': '0',
        'last_public_web_discovery_success_at': '0',
        'last_public_web_discovery_outcome': 'never',
        'last_public_web_discovery_error': '',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    if (oldVersion < 26) {
      await _createV26Tables(db);
    }
    if (oldVersion < 27) {
      final messageColumns = await db.rawQuery('PRAGMA table_info(messages)');
      if (!messageColumns.any((row) => row['name'] == 'segments_json')) {
        await db.execute(
          "ALTER TABLE messages ADD COLUMN segments_json TEXT NOT NULL DEFAULT ''",
        );
      }
      for (final entry in const <String, String>{
        'personality_base_key': 'neutral',
        'personality_posture_key': 'equal',
        'tts_reading_scope': 'dialogue_only',
        'chat_visual_stage_enabled': '1',
        'chat_background_mode': 'auto',
        'chat_panel_opacity': '0.72',
        'chat_panel_fraction': '0.62',
        'chat_typewriter_enabled': '1',
        'chat_typewriter_ms': '56',
        'emotion_sound_enabled': '0',
        'emotion_sound_volume': '0.15',
        'show_emotion_label': '1',
      }.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      // v26 adoption wrote the variable personality directly into the core
      // rule. Recover its sta