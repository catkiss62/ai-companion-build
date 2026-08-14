import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/awareness_observation.dart';
import '../models/conversation_summary.dart';
import '../models/desire_state.dart';
import '../models/daily_continuity.dart';
import '../models/memory_item.dart';
import '../models/perception_snapshot.dart';
import '../models/post_turn_job.dart';
import '../models/generation_job.dart';
import '../models/maintenance_run.dart';
import '../models/reference_item.dart';
import '../models/reference_document.dart';
import '../models/rule_layer.dart';
import '../models/proactive_feedback.dart';
import '../models/thought_lifecycle_event.dart';
import '../rules/rule_layer_defaults.dart';
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
  static const int schemaVersion = 21;

  Database? _db;
  Future<Database>? _opening;
  final Uuid _uuid = Uuid();
  final Map<String, String> _ownedLeaseTokens = <String, String>{};

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

  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE messages (
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
    await db.execute(
      'CREATE INDEX idx_messages_created_at ON messages(created_at)',
    );

    await db.execute('''
      CREATE TABLE memory_items (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        content TEXT NOT NULL,
        importance REAL NOT NULL DEFAULT 0.5,
        confidence REAL NOT NULL DEFAULT 0.7,
        tags TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'conversation',
        status TEXT NOT NULL DEFAULT 'active',
        subject_key TEXT NOT NULL DEFAULT '',
        pinned INTEGER NOT NULL DEFAULT 0,
        superseded_by TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_recalled_at INTEGER,
        recall_count INTEGER NOT NULL DEFAULT 0,
        retention_score REAL NOT NULL DEFAULT 1.0,
        retention_checked_at INTEGER,
        semantic_type TEXT NOT NULL DEFAULT 'current_fact',
        evidence_count INTEGER NOT NULL DEFAULT 1,
        first_observed_at INTEGER,
        last_evidence_at INTEGER,
        fact_version INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_memory_kind ON memory_items(kind, status)',
    );
    await db.execute(
      'CREATE INDEX idx_memory_subject ON memory_items(kind, subject_key, status)',
    );
    await db.execute(
      'CREATE INDEX idx_memory_semantic ON memory_items(semantic_type, status, updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE thoughts (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        drive_key TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'flit',
        strength REAL NOT NULL DEFAULT 0.25,
        born_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        fed_count INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'internal',
        last_fed_at INTEGER,
        lifecycle_state TEXT NOT NULL DEFAULT 'active',
        action_count INTEGER NOT NULL DEFAULT 0,
        last_acted_at INTEGER,
        last_satisfied_at INTEGER,
        last_resurfaced_at INTEGER,
        resurfaced_count INTEGER NOT NULL DEFAULT 0,
        residual_strength REAL NOT NULL DEFAULT 0,
        last_outbound_message_id TEXT,
        topic_key TEXT NOT NULL DEFAULT '',
        merged_count INTEGER NOT NULL DEFAULT 0,
        last_merged_at INTEGER,
        snoozed_until INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_thoughts_strength ON thoughts(strength DESC, updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE desire_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE device_events (
        id TEXT PRIMARY KEY,
        device_id TEXT,
        source TEXT NOT NULL,
        event_type TEXT NOT NULL,
        app_package TEXT,
        summary TEXT,
        occurred_at INTEGER NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_device_events_time ON device_events(occurred_at)',
    );

    await db.execute('''
      CREATE TABLE proactive_history (
        id TEXT PRIMARY KEY,
        trigger_reason TEXT NOT NULL,
        decision TEXT NOT NULL,
        message_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createV2Tables(db);
    await _createV3Tables(db);
    await _createV4Tables(db);
    await db.execute('ALTER TABLE relationship_events ADD COLUMN internalized_at INTEGER');
    await _createV6Tables(db);
    await _createV7Tables(db);
    await _createV8Tables(db);
    await _createV9Tables(db);
    await _createV10Tables(db);
    await _createV11Tables(db);
    await _createV12Tables(db);
    await _createV13Tables(db);
    await _createV14Tables(db);
    await _createV15Tables(db);
    await _createV16Tables(db);
    await _createV17Tables(db);
    await _createV18Tables(db);
    await _createV21Tables(db);
    await _seedRuleLayers(db);

    final initial = DesireSnapshot();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('desire_state', {
      'id': 1,
      'json': initial.encode(),
      'updated_at': now,
    });
    await db.insert('settings', {'key': 'active_brain', 'value': '1'});
    await db.insert('settings', {'key': 'model', 'value': 'deepseek-v4-flash'});
    await db.insert('settings', {'key': 'reasoning_effort', 'value': 'high'});
    await db.insert('settings', {'key': 'auto_memory', 'value': '1'});
    await db.insert('settings', {'key': 'memory_consolidation_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'self_drive_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'transfer_lock', 'value': '0'});
    await db.insert('settings', {'key': 'state_lineage_id', 'value': _uuid.v4()});
    await db.insert('settings', {'key': 'state_generation', 'value': '0'});
    await db.insert('settings', {'key': 'pending_outbound_snapshot_id', 'value': ''});
    await db.insert('settings', {'key': 'pending_outbound_generation', 'value': '0'});
    await db.insert('settings', {'key': 'pending_import_snapshot_id', 'value': ''});
    await db.insert('settings', {'key': 'pending_import_lineage_id', 'value': ''});
    await db.insert('settings', {'key': 'pending_import_source_device_id', 'value': ''});
    await db.insert('settings', {'key': 'pending_import_generation', 'value': '0'});
    await db.insert('settings', {'key': 'pending_import_state_sha256', 'value': ''});
    await db.insert('settings', {'key': 'last_takeover_snapshot_id', 'value': ''});
    await db.insert('settings', {'key': 'last_takeover_source_device_id', 'value': ''});
    await db.insert('settings', {'key': 'last_takeover_at', 'value': '0'});
    await db.insert('settings', {'key': 'perception_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'ai_self_reflection_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'tts_enabled', 'value': '0'});
    await db.insert('settings', {'key': 'auto_tts', 'value': '0'});
    await db.insert('settings', {'key': 'tts_streaming_enabled', 'value': '0'});
    await db.insert('settings', {'key': 'proactive_tts_policy', 'value': 'silent'});
    await db.insert('settings', {'key': 'last_proactive_spoken_message_id', 'value': ''});
    await db.insert('settings', {'key': 'tts_speed', 'value': '1.0'});
    await db.insert('settings', {'key': 'tts_volume', 'value': '1.0'});
    await db.insert('settings', {'key': 'tts_replacements_json', 'value': '{\"Yuki\":\"有希\"}'});
    await db.insert('settings', {'key': 'relationship_continuity_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'session_tracking_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'memory_fading_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'reference_library_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'last_memory_maintenance_at', 'value': '0'});
    await db.insert('settings', {'key': 'rule_layers_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'thought_lifecycle_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'proactive_adaptation_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'proactive_feedback_expiry_hours', 'value': '10'});
    await db.insert('settings', {'key': 'proactive_notification_privacy', 'value': 'smart'});
    await db.insert('settings', {'key': 'thought_consolidation_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'last_thought_consolidation_at', 'value': '0'});
    await db.insert('settings', {'key': 'long_running_maintenance_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'last_long_running_maintenance_at', 'value': '0'});
    await db.insert('settings', {'key': 'deferred_followup_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'max_deferred_followups', 'value': '1'});
    await db.insert('settings', {'key': 'post_turn_queue_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'background_error_count', 'value': '0'});
    await db.insert('settings', {'key': 'last_background_error', 'value': ''});
    await db.insert('settings', {'key': 'durable_generation_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'generation_max_attempts', 'value': '0'});
    await db.insert('settings', {'key': 'last_generation_recovery_error', 'value': ''});
    await db.insert('settings', {'key': 'post_turn_max_attempts', 'value': '0'});
    await db.insert('settings', {'key': 'last_async_worker_error', 'value': ''});
    await db.insert('settings', {'key': 'daily_continuity_enabled', 'value': '1'});
    await db.insert('settings', {'key': 'last_daily_continuity_refresh_at', 'value': '0'});
    await db.insert('settings', {'key': 'last_daily_continuity_error', 'value': ''});
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversation_summaries (
        id TEXT PRIMARY KEY,
        from_at INTEGER NOT NULL,
        to_at INTEGER NOT NULL,
        summary TEXT NOT NULL,
        key_points TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_summaries_to_at ON conversation_summaries(to_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS unfinished_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        detail TEXT NOT NULL,
        importance REAL NOT NULL DEFAULT 0.5,
        status TEXT NOT NULL DEFAULT 'active',
        source_message_id TEXT,
        topic_key TEXT NOT NULL DEFAULT '',
        followup_due_at INTEGER,
        followup_seeded_at INTEGER,
        followup_run_token TEXT NOT NULL DEFAULT '',
        followup_claimed_at INTEGER,
        proactive_outcome_message_id TEXT,
        followup_count INTEGER NOT NULL DEFAULT 0,
        last_followup_at INTEGER,
        retired_at INTEGER,
        retire_reason TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_threads_status ON unfinished_threads(status, importance DESC, updated_at DESC)',
    );
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS perception_snapshots (
        id TEXT PRIMARY KEY,
        summary TEXT NOT NULL,
        device_id TEXT,
        device_label TEXT,
        current_package TEXT,
        busy_score REAL NOT NULL DEFAULT 0,
        notification_count INTEGER NOT NULL DEFAULT 0,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        occurred_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_perception_time ON perception_snapshots(occurred_at DESC)',
    );
  }

  Future<void> _createV4Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS relationship_events (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        summary TEXT NOT NULL,
        intensity REAL NOT NULL DEFAULT 0.5,
        valence REAL NOT NULL DEFAULT 0,
        source_message_id TEXT,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_relationship_time ON relationship_events(created_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS interaction_sessions (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        premise TEXT NOT NULL DEFAULT '',
        boundaries_json TEXT NOT NULL DEFAULT '[]',
        continuity_note TEXT NOT NULL DEFAULT '',
        source_message_id TEXT,
        started_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        ended_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_status ON interaction_sessions(status, updated_at DESC)',
    );
  }

  Future<void> _createV6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reference_items (
        id TEXT PRIMARY KEY,
        document_id TEXT,
        source_name TEXT NOT NULL,
        section TEXT NOT NULL DEFAULT 'other',
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '',
        weight REAL NOT NULL DEFAULT 0.55,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reference_enabled ON reference_items(enabled, weight DESC, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reference_source ON reference_items(source_name, section)',
    );
  }

  Future<void> _createV7Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reference_documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'character',
        aliases TEXT NOT NULL DEFAULT '',
        raw_content TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reference_documents_enabled ON reference_documents(enabled, updated_at DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rule_layers (
        key TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        load_policy TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        locked INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createV8Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS thought_lifecycle_events (
        id TEXT PRIMARY KEY,
        thought_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT '',
        message_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thought_lifecycle_time ON thought_lifecycle_events(thought_id, created_at DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proactive_feedback (
        id TEXT PRIMARY KEY,
        proactive_message_id TEXT NOT NULL UNIQUE,
        thought_id TEXT,
        topic_key TEXT NOT NULL DEFAULT '',
        thread_id TEXT,
        intent_kind TEXT NOT NULL DEFAULT '',
        delivery_style TEXT NOT NULL DEFAULT '',
        sent_at INTEGER NOT NULL,
        user_response_message_id TEXT,
        response_latency_seconds INTEGER,
        response_bucket TEXT NOT NULL DEFAULT 'pending',
        user_text_length INTEGER NOT NULL DEFAULT 0,
        response_quality REAL,
        outcome TEXT NOT NULL DEFAULT 'pending',
        outcome_score REAL,
        processed_at INTEGER,
        context_hour_bucket TEXT NOT NULL DEFAULT '',
        context_activity TEXT NOT NULL DEFAULT 'unknown',
        context_busy REAL NOT NULL DEFAULT 0,
        timing_fit REAL,
        topic_fit REAL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_feedback_sent ON proactive_feedback(sent_at DESC)',
    );
  }

  Future<void> _createV9Tables(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thought_topic ON thoughts(drive_key, topic_key, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thread_topic ON unfinished_threads(status, topic_key, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_topic ON proactive_feedback(topic_key, sent_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_response ON proactive_feedback(user_response_message_id)',
    );
  }

  Future<void> _createV10Tables(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_thread_followup ON unfinished_threads(status, followup_due_at, followup_count, importance DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS post_turn_jobs (
        id TEXT PRIMARY KEY,
        user_message_id TEXT NOT NULL,
        assistant_message_id TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NOT NULL DEFAULT '',
        run_token TEXT NOT NULL DEFAULT '',
        result_json TEXT NOT NULL DEFAULT '',
        started_at INTEGER,
        heartbeat_at INTEGER,
        next_retry_at INTEGER,
        model_completed_at INTEGER,
        desire_applied_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_post_turn_jobs_status ON post_turn_jobs(status, updated_at ASC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_runs (
        id TEXT PRIMARY KEY,
        started_at INTEGER NOT NULL,
        completed_at INTEGER NOT NULL,
        retired_threads INTEGER NOT NULL DEFAULT 0,
        pruned_lifecycle INTEGER NOT NULL DEFAULT 0,
        pruned_feedback INTEGER NOT NULL DEFAULT 0,
        pruned_history INTEGER NOT NULL DEFAULT 0,
        pruned_perceptions INTEGER NOT NULL DEFAULT 0,
        pruned_device_events INTEGER NOT NULL DEFAULT 0,
        pruned_jobs INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_runs_time ON maintenance_runs(completed_at DESC)',
    );
  }

  Future<void> _createV11Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS generation_jobs (
        id TEXT PRIMARY KEY,
        user_message_id TEXT NOT NULL UNIQUE,
        assistant_message_id TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        model TEXT NOT NULL,
        reasoning_effort TEXT NOT NULL DEFAULT 'high',
        thinking INTEGER NOT NULL DEFAULT 1,
        partial_reasoning TEXT NOT NULL DEFAULT '',
        partial_content TEXT NOT NULL DEFAULT '',
        run_token TEXT NOT NULL DEFAULT '',
        device_id TEXT,
        created_at INTEGER NOT NULL,
        started_at INTEGER,
        updated_at INTEGER NOT NULL,
        completed_at INTEGER,
        last_checkpoint_at INTEGER,
        next_retry_at INTEGER,
        last_error TEXT NOT NULL DEFAULT '',
        resume_reason TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_generation_jobs_status ON generation_jobs(status, next_retry_at, updated_at ASC)',
    );
  }

  Future<void> _createV12Tables(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_post_turn_retry ON post_turn_jobs(status, next_retry_at, updated_at ASC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_summary_range_unique ON conversation_summaries(from_at, to_at)',
    );
  }


  Future<void> _createV13Tables(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_intent ON proactive_feedback(intent_kind, sent_at DESC)',
    );
  }

  Future<void> _createV14Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS awareness_observations (
        id TEXT PRIMARY KEY,
        device_id TEXT,
        kind TEXT NOT NULL,
        summary TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.5,
        window_start INTEGER NOT NULL,
        window_end INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        dedupe_key TEXT NOT NULL UNIQUE,
        source_fingerprint TEXT NOT NULL DEFAULT '',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_awareness_active ON awareness_observations(expires_at DESC, confidence DESC, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_awareness_kind ON awareness_observations(kind, updated_at DESC)',
    );
  }

  Future<void> _createV15Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_evidence (
        id TEXT PRIMARY KEY,
        memory_id TEXT NOT NULL,
        source TEXT NOT NULL,
        evidence_text TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0.7,
        relation TEXT NOT NULL DEFAULT 'created',
        observed_at INTEGER NOT NULL,
        FOREIGN KEY(memory_id) REFERENCES memory_items(id) ON DELETE CASCADE,
        UNIQUE(memory_id, source, evidence_text)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memory_evidence_memory ON memory_evidence(memory_id, observed_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memory_evidence_source ON memory_evidence(source, observed_at DESC)',
    );
  }

  Future<void> _createV16Tables(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_context_hour ON proactive_feedback(context_hour_bucket, sent_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_proactive_context_activity ON proactive_feedback(context_activity, sent_at DESC)',
    );
  }

  Future<void> _createV17Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_continuity (
        id TEXT PRIMARY KEY,
        local_day TEXT NOT NULL UNIQUE,
        window_start INTEGER NOT NULL,
        window_end INTEGER NOT NULL,
        shared_moments_json TEXT NOT NULL DEFAULT '[]',
        carried_threads_json TEXT NOT NULL DEFAULT '[]',
        cares_json TEXT NOT NULL DEFAULT '[]',
        awareness_json TEXT NOT NULL DEFAULT '[]',
        message_count INTEGER NOT NULL DEFAULT 0,
        relationship_event_count INTEGER NOT NULL DEFAULT 0,
        quiet_day INTEGER NOT NULL DEFAULT 0,
        source_fingerprint TEXT NOT NULL DEFAULT '',
        finalized_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_continuity_day ON daily_continuity(window_start DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_continuity_updated ON daily_continuity(updated_at DESC)',
    );
  }

  Future<void> _createV18Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfer_receipts (
        snapshot_id TEXT PRIMARY KEY,
        lineage_id TEXT NOT NULL,
        source_device_id TEXT NOT NULL,
        source_generation INTEGER NOT NULL,
        state_sha256 TEXT NOT NULL,
        target_device_id TEXT NOT NULL,
        target_lineage_before TEXT NOT NULL DEFAULT '',
        target_generation_before INTEGER NOT NULL DEFAULT 0,
        imported_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transfer_receipts_lineage_generation ON transfer_receipts(lineage_id, source_generation DESC)',
    );
  }

  Future<void> _createV21Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS somatic_events (
        id TEXT PRIMARY KEY,
        turn_id TEXT NOT NULL,
        channel TEXT NOT NULL,
        action TEXT NOT NULL DEFAULT '',
        part TEXT NOT NULL DEFAULT '',
        scene_key TEXT NOT NULL,
        direction TEXT NOT NULL,
        source TEXT NOT NULL,
        narrative TEXT NOT NULL,
        intensity REAL NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY(turn_id) REFERENCES messages(id) ON DELETE CASCADE,
        UNIQUE(turn_id, direction, scene_key)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_somatic_events_active ON somatic_events(channel, expires_at DESC, created_at ASC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS somatic_aggregates (
        channel TEXT PRIMARY KEY,
        value REAL NOT NULL,
        scene_key TEXT NOT NULL,
        narrative TEXT NOT NULL,
        last_event_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_somatic_aggregates_active ON somatic_aggregates(expires_at DESC, value DESC)',
    );
  }

  Future<void> _seedRuleLayers(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final layer in defaultRuleLayers) {
      await db.insert(
        'rule_layers',
        {
          'key': layer.key,
          'title': layer.title,
          'content': layer.content,
          'load_policy': layer.loadPolicy,
          'enabled': 1,
          'locked': layer.locked ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> ensureReady() async {
    await database;
    await ensureDeviceId();
  }

  Future<String> ensureDeviceId() async {
    final existing = await getSetting('device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await setSetting('device_id', id);
    return id;
  }

  Future<String> ensureStateLineageId() async {
    final existing = await getSetting('state_lineage_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await setSetting('state_lineage_id', id);
    return id;
  }

  Future<TransferStateIdentity> transferStateIdentity() async {
    final deviceId = await ensureDeviceId();
    final lineageId = await ensureStateLineageId();
    final generation = int.tryParse(await getSetting('state_generation') ?? '') ?? 0;
    return TransferStateIdentity(
      lineageId: lineageId,
      generation: generation,
      deviceId: deviceId,
    );
  }

  /// Reserve a monotonically increasing state generation for one frozen
  /// outbound takeover snapshot. `transfer_lock=1` is mandatory so no writer
  /// can create state after the generation is reserved but before export.
  Future<TransferStateIdentity> reserveTransferSnapshot(String snapshotId) async {
    if (snapshotId.trim().isEmpty) {
      throw ArgumentError.value(snapshotId, 'snapshotId', 'must not be empty');
    }
    final deviceId = await ensureDeviceId();
    final lineageId = await ensureStateLineageId();
    final db = await database;
    return db.transaction<TransferStateIdentity>((txn) async {
      Future<String> setting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? '' : rows.first['value'] as String? ?? '';
      }

      if (await setting('transfer_lock') != '1') {
        throw StateError('生成接管状态包前必须先冻结本机写入。');
      }
      if (await setting('active_brain') == '0') {
        throw StateError('只有当前 Active Brain 可以生成接管状态包。');
      }
      final currentLineage = await setting('state_lineage_id');
      if (currentLineage.isNotEmpty && currentLineage != lineageId) {
        throw StateError('关系谱系在生成状态包时发生变化。');
      }
      final current = int.tryParse(await setting('state_generation')) ?? 0;
      final next = current + 1;
      for (final entry in <String, String>{
        'state_lineage_id': lineageId,
        'state_generation': '$next',
        'pending_outbound_snapshot_id': snapshotId,
        'pending_outbound_generation': '$next',
      }.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return TransferStateIdentity(
        lineageId: lineageId,
        generation: next,
        deviceId: deviceId,
      );
    });
  }

  Future<TransferReceipt?> transferReceipt(String snapshotId) async {
    final db = await database;
    final rows = await db.query(
      'transfer_receipts',
      where: 'snapshot_id = ?',
      whereArgs: [snapshotId],
      limit: 1,
    );
    return rows.isEmpty ? null : TransferReceipt.fromDb(rows.first);
  }

  Future<PendingImportedTransfer?> pendingImportedTransfer() async {
    final snapshotId = await getSetting('pending_import_snapshot_id') ?? '';
    final lineageId = await getSetting('pending_import_lineage_id') ?? '';
    final sourceDeviceId = await getSetting('pending_import_source_device_id') ?? '';
    final sourceGeneration = int.tryParse(await getSetting('pending_import_generation') ?? '') ?? 0;
    final stateSha256 = await getSetting('pending_import_state_sha256') ?? '';
    if (snapshotId.isEmpty || lineageId.isEmpty || sourceGeneration <= 0 || stateSha256.isEmpty) {
      return null;
    }
    return PendingImportedTransfer(
      snapshotId: snapshotId,
      lineageId: lineageId,
      sourceDeviceId: sourceDeviceId,
      sourceGeneration: sourceGeneration,
      stateSha256: stateSha256,
    );
  }

  Future<bool> isPristineForLineageAdoption() async {
    final db = await database;
    const tables = <String>[
      'messages',
      'memory_items',
      'unfinished_threads',
      'thoughts',
      'relationship_events',
      'interaction_sessions',
      'reference_documents',
      'reference_items',
      'daily_continuity',
    ];
    for (final table in tables) {
      final rows = await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
      if (rows.isNotEmpty) return false;
    }
    return true;
  }

  /// Activate exactly the snapshot that was imported into standby. The
  /// generation bump creates a new ownership epoch, making the just-consumed
  /// snapshot (and every older replay) stale immediately after activation.
  Future<int> activatePendingImportedBrain({String? expectedSnapshotId}) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      Future<String> setting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? '' : rows.first['value'] as String? ?? '';
      }

      final snapshotId = await setting('pending_import_snapshot_id');
      final lineageId = await setting('pending_import_lineage_id');
      final sourceDeviceId = await setting('pending_import_source_device_id');
      final importedGeneration = int.tryParse(await setting('pending_import_generation')) ?? 0;
      final stateSha256 = await setting('pending_import_state_sha256');
      final currentLineage = await setting('state_lineage_id');
      final currentGeneration = int.tryParse(await setting('state_generation')) ?? 0;
      if (snapshotId.isEmpty || lineageId.isEmpty || importedGeneration <= 0 || stateSha256.isEmpty) {
        throw StateError('本机没有等待接管的已导入状态。');
      }
      if (expectedSnapshotId != null && expectedSnapshotId != snapshotId) {
        throw StateError('接管确认与本机等待的状态包不一致。');
      }
      if (currentLineage != lineageId || currentGeneration != importedGeneration) {
        throw StateError('本机状态代次已变化，拒绝使用旧接管确认。');
      }
      if (await setting('active_brain') != '0') {
        throw StateError('本机已经是 Active Brain，拒绝重复接管。');
      }
      final nextGeneration = importedGeneration + 1;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in <String, String>{
        'state_generation': '$nextGeneration',
        'active_brain': '1',
        'transfer_lock': '0',
        'pending_import_snapshot_id': '',
        'pending_import_lineage_id': '',
        'pending_import_source_device_id': '',
        'pending_import_generation': '0',
        'pending_import_state_sha256': '',
        'pending_outbound_snapshot_id': '',
        'pending_outbound_generation': '0',
        'last_takeover_snapshot_id': snapshotId,
        'last_takeover_source_device_id': sourceDeviceId,
        'last_takeover_at': '$now',
      }.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return nextGeneration;
    });
  }

  /// Explicit local recovery for a device that was intentionally pushed to
  /// standby (for example after exporting an encrypted manual transfer file).
  /// Bumping generation invalidates the exported snapshot if the user chooses
  /// to resume this device instead.
  Future<int> forceLocalBrainTakeover() async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?, ?)',
        whereArgs: const ['active_brain', 'state_generation', 'state_lineage_id'],
      );
      final settings = <String, String>{};
      for (final row in rows) {
        settings[row['key'] as String] = row['value'] as String? ?? '';
      }
      if (settings['active_brain'] != '0') {
        throw StateError('本机已经是 Active Brain。');
      }
      final current = int.tryParse(settings['state_generation'] ?? '') ?? 0;
      final next = current + 1;
      for (final entry in <String, String>{
        'state_generation': '$next',
        'active_brain': '1',
        'transfer_lock': '0',
        'pending_import_snapshot_id': '',
        'pending_import_lineage_id': '',
        'pending_import_source_device_id': '',
        'pending_import_generation': '0',
        'pending_import_state_sha256': '',
        'pending_outbound_snapshot_id': '',
        'pending_outbound_generation': '0',
      }.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return next;
    });
  }

  Future<void> pauseAfterManualTransferExport({
    required String snapshotId,
    required String lineageId,
    required int generation,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      Future<String> setting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? '' : rows.first['value'] as String? ?? '';
      }
      if (await setting('state_lineage_id') != lineageId ||
          (int.tryParse(await setting('state_generation')) ?? -1) != generation ||
          await setting('pending_outbound_snapshot_id') != snapshotId ||
          await setting('transfer_lock') != '1') {
        throw StateError('手动接管包已经不是本机当前冻结的状态。');
      }
      await txn.insert(
        'settings',
        {'key': 'active_brain', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'settings',
        {'key': 'transfer_lock', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> insertMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Persist short-lived body-sense events after the durable user turn exists.
  /// Deterministic event IDs make a recovered generation attempt idempotent.
  Future<int> recordSomaticEvents(
    List<SomaticEvent> events, {
    DateTime? now,
  }) async {
    if (events.isEmpty) return 0;
    final db = await database;
    final instant = now ?? DateTime.now();
    return db.transaction<int>((txn) async {
      final settingRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{
        for (final row in settingRows)
          if (row['key'] is String)
            row['key'] as String: row['value'] as String? ?? '',
      };
      if (settings['active_brain'] == '0' || settings['transfer_lock'] == '1') {
        return 0;
      }

      await txn.delete(
        'somatic_events',
        where: 'expires_at <= ?',
        whereArgs: [instant.millisecondsSinceEpoch],
      );
      await txn.delete(
        'somatic_aggregates',
        where: 'expires_at <= ?',
        whereArgs: [instant.millisecondsSinceEpoch],
      );

      var inserted = 0;
      for (final event in events) {
        final turn = await txn.query(
          'messages',
          columns: ['role'],
          where: 'id = ?',
          whereArgs: [event.turnId],
          limit: 1,
        );
        if (turn.isEmpty || turn.first['role'] != 'user') continue;
        final existing = await txn.query(
          'somatic_events',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [event.id],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await txn.insert(
          'somatic_events',
          event.toDb(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        inserted += 1;
        await _mergeSomaticEvent(txn, event, instant);
      }
      return inserted;
    });
  }

  Future<List<SomaticAggregate>> activeSomaticAggregates({
    DateTime? now,
  }) async {
    final db = await database;
    final instant = now ?? DateTime.now();
    final rows = await db.query(
      'somatic_aggregates',
      where: 'expires_at > ?',
      whereArgs: [instant.millisecondsSinceEpoch],
      orderBy: 'value DESC, updated_at DESC',
    );
    return rows.map(SomaticAggregate.fromDb).toList(growable: false);
  }

  Future<void> _mergeSomaticEvent(
    DatabaseExecutor txn,
    SomaticEvent event,
    DateTime now,
  ) async {
    final rows = await txn.query(
      'somatic_aggregates',
      where: 'channel = ?',
      whereArgs: [event.channel.name],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0.0
        : SomaticPolicy.decay(
            (rows.first['value'] as num?)?.toDouble() ?? 0.0,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              rows.first['updated_at'] as int,
            ),
            now: now,
          );
    final aggregate = SomaticAggregate(
      channel: event.channel,
      value: SomaticPolicy.mergePulse(current, event.intensity),
      sceneKey: event.sceneKey,
      narrative: event.narrative,
      lastEventId: event.id,
      updatedAt: now,
      expiresAt: event.expiresAt,
    );
    await txn.insert(
      'somatic_aggregates',
      aggregate.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _rebuildSomaticAggregates(
    DatabaseExecutor txn,
    DateTime now,
  ) async {
    await txn.delete('somatic_aggregates');
    final rows = await txn.query(
      'somatic_events',
      where: 'expires_at > ?',
      whereArgs: [now.millisecondsSinceEpoch],
      orderBy: 'created_at ASC, id ASC',
    );
    for (final row in rows) {
      final event = SomaticEvent.fromDb(row);
      await _mergeSomaticEvent(txn, event, event.createdAt);
    }
  }

  Future<GenerationJob> createGenerationTurn({
    required ChatMessage user,
    required String assistantMessageId,
    required String model,
    required String reasoningEffort,
    bool thinking = true,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final jobId = _uuid.v4();
    await db.transaction((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{};
      for (final row in settingsRows) {
        final key = row['key'];
        if (key is String) settings[key] = row['value'] as String? ?? '';
      }
      if (settings['transfer_lock'] == '1') {
        throw StateError('设备转移已经开始，暂时不能创建新的聊天任务。');
      }
      if (settings['active_brain'] == '0') {
        throw StateError('当前设备不是 Active Brain。');
      }
      final blocking = await txn.query(
        'generation_jobs',
        columns: ['id'],
        where: "status IN ('pending','running','retry_wait')",
        limit: 1,
      );
      if (blocking.isNotEmpty) {
        throw StateError('上一轮 AI 回复仍在生成或等待恢复。');
      }
      await txn.insert(
        'messages',
        user.toDb(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.insert('generation_jobs', {
        'id': jobId,
        'user_message_id': user.id,
        'assistant_message_id': assistantMessageId,
        'status': 'pending',
        'attempts': 0,
        'model': model,
        'reasoning_effort': reasoningEffort,
        'thinking': thinking ? 1 : 0,
        'partial_reasoning': '',
        'partial_content': '',
        'run_token': '',
        'device_id': user.deviceId,
        'created_at': now,
        'started_at': null,
        'updated_at': now,
        'completed_at': null,
        'last_checkpoint_at': null,
        'next_retry_at': null,
        'last_error': '',
        'resume_reason': '',
      });
    });
    return (await generationJobById(jobId))!;
  }

  Future<GenerationJob?> generationJobById(String id) async {
    final db = await database;
    final rows = await db.query(
      'generation_jobs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GenerationJob.fromDb(rows.first);
  }

  Future<GenerationJob?> generationJobForUserMessage(String userMessageId) async {
    final db = await database;
    final rows = await db.query(
      'generation_jobs',
      where: 'user_message_id = ?',
      whereArgs: [userMessageId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : GenerationJob.fromDb(rows.first);
  }

  Future<GenerationJob?> blockingGenerationJob() async {
    final db = await database;
    final rows = await db.query(
      'generation_jobs',
      where: "status IN ('pending','running','retry_wait')",
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : GenerationJob.fromDb(rows.first);
  }

  /// Returns a failed generation only when it belongs to the latest user turn.
  /// Historical failures from older builds must not suddenly block a user who
  /// has already continued the conversation past that gap.
  Future<GenerationJob?> failedGenerationNeedingAttention() async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT g.*
      FROM generation_jobs g
      JOIN messages u ON u.id = g.user_message_id AND u.role = 'user'
      WHERE g.status = 'failed'
        AND NOT EXISTS (
          SELECT 1 FROM messages newer
          WHERE newer.role = 'user' AND newer.created_at > u.created_at
        )
        AND NOT EXISTS (
          SELECT 1 FROM messages a WHERE a.id = g.assistant_message_id
        )
      ORDER BY g.created_at DESC
      LIMIT 1
    """);
    return rows.isEmpty ? null : GenerationJob.fromDb(rows.first);
  }

  Future<bool> retryFailedGenerationJob(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<bool>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{
        for (final row in settingsRows)
          if (row['key'] is String)
            row['key'] as String: row['value'] as String? ?? '',
      };
      if (settings['transfer_lock'] == '1' || settings['active_brain'] == '0') {
        return false;
      }
      final competing = await txn.query(
        'generation_jobs',
        columns: ['id'],
        where: "id <> ? AND status IN ('pending','running','retry_wait')",
        whereArgs: [id],
        limit: 1,
      );
      if (competing.isNotEmpty) return false;
      final assistant = await txn.rawQuery(
        'SELECT 1 FROM messages WHERE id = (SELECT assistant_message_id FROM generation_jobs WHERE id = ?) LIMIT 1',
        [id],
      );
      if (assistant.isNotEmpty) return false;
      final changed = await txn.update(
        'generation_jobs',
        {
          'status': 'pending',
          'run_token': '',
          'next_retry_at': null,
          'last_error': '',
          'resume_reason': 'manual_retry',
          'updated_at': now,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'failed'],
      );
      return changed == 1;
    });
  }

  Future<bool> abandonFailedGenerationJob(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<bool>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{
        for (final row in settingsRows)
          if (row['key'] is String)
            row['key'] as String: row['value'] as String? ?? '',
      };
      if (settings['transfer_lock'] == '1' || settings['active_brain'] == '0') {
        return false;
      }
      final changed = await txn.update(
        'generation_jobs',
        {
          'status': 'cancelled',
          'run_token': '',
          'next_retry_at': null,
          'resume_reason': 'manual_abandon',
          'updated_at': now,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'failed'],
      );
      return changed == 1;
    });
  }

  /// Terminally fences one reply and withdraws its user turn when Stop wins.
  ///
  /// This is intentionally valid for pending, running, and retry-wait jobs.
  /// Clearing run_token and deleting the user message in one transaction means
  /// future prompts, memory extraction and either chat surface cannot observe
  /// a half-turn. If completion commits first, its completed status makes this
  /// operation a no-op so a finished pair is never partially deleted.
  Future<bool> cancelGenerationJobByUser(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'generation_jobs',
        columns: ['status', 'user_message_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final status = rows.first['status'] as String? ?? '';
      final userMessageId = rows.first['user_message_id'] as String? ?? '';
      var cancelled = status == 'cancelled_by_user';
      if (!cancelled) {
        final changed = await txn.update(
          'generation_jobs',
          {
            'status': 'cancelled_by_user',
            'partial_reasoning': '',
            'partial_content': '',
            'run_token': '',
            'next_retry_at': null,
            'last_error': '',
            'resume_reason': 'cancelled_by_user',
            'completed_at': now,
            'updated_at': now,
          },
          where: "id = ? AND status IN ('pending','running','retry_wait')",
          whereArgs: [id],
        );
        cancelled = changed == 1;
      }
      if (!cancelled) return false;

      // Idempotently clean a prior partial cancellation as well. Completed
      // jobs can never reach this branch, preserving completion-vs-stop order.
      if (userMessageId.isNotEmpty) {
        await txn.delete(
          'post_turn_jobs',
          where: 'user_message_id = ?',
          whereArgs: [userMessageId],
        );
        await txn.delete(
          'messages',
          where: 'id = ? AND role = ?',
          whereArgs: [userMessageId, 'user'],
        );
        // ON DELETE CASCADE withdraws this turn's sense events. Rebuilding the
        // short-lived aggregate in the same transaction removes any ghost
        // sensation before another prompt can observe it.
        await _rebuildSomaticAggregates(
          txn,
          DateTime.fromMillisecondsSinceEpoch(now),
        );
      }
      return true;
    });
  }

  /// Cheap cross-engine fence check used while a streaming request is active.
  Future<bool> isGenerationRunCurrent(
    String id, {
    required String runToken,
  }) async {
    if (runToken.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      'generation_jobs',
      columns: ['id'],
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<GenerationJob?> nextRecoverableGenerationJob({
    Duration runningStaleAfter = const Duration(minutes: 2),
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleBefore = DateTime.now()
        .subtract(runningStaleAfter)
        .millisecondsSinceEpoch;
    final rows = await db.query(
      'generation_jobs',
      where: "status = 'pending' OR (status = 'retry_wait' AND (next_retry_at IS NULL OR next_retry_at <= ?)) OR (status = 'running' AND updated_at <= ?)",
      whereArgs: [now, staleBefore],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : GenerationJob.fromDb(rows.first);
  }

  Future<Duration?> nextGenerationRecoveryDelay() async {
    final db = await database;
    final rows = await db.query(
      'generation_jobs',
      columns: ['status', 'next_retry_at', 'updated_at'],
      where: "status IN ('pending','running','retry_wait')",
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final status = row['status'] as String? ?? 'pending';
    if (status == 'pending') return Duration.zero;
    final now = DateTime.now();
    if (status == 'retry_wait') {
      final ms = row['next_retry_at'] as int?;
      if (ms == null) return Duration.zero;
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      return at.isAfter(now) ? at.difference(now) : Duration.zero;
    }
    final updated = DateTime.fromMillisecondsSinceEpoch(
      row['updated_at'] as int? ?? now.millisecondsSinceEpoch,
    );
    final staleAt = updated.add(const Duration(minutes: 2));
    return staleAt.isAfter(now) ? staleAt.difference(now) : Duration.zero;
  }

  Future<GenerationJob?> claimGenerationJob(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final localDeviceId = await ensureDeviceId();
    final runToken = _uuid.v4();
    return db.transaction<GenerationJob?>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{};
      for (final row in settingsRows) {
        final key = row['key'];
        if (key is String) settings[key] = row['value'] as String? ?? '';
      }
      if (settings['transfer_lock'] == '1' || settings['active_brain'] == '0') {
        return null;
      }
      final rows = await txn.query(
        'generation_jobs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final current = GenerationJob.fromDb(rows.first);
      if (current.isTerminal) return null;
      if (current.status == 'retry_wait' &&
          current.nextRetryAt != null &&
          current.nextRetryAt!.isAfter(DateTime.now())) {
        return null;
      }
      if (current.status == 'running' &&
          DateTime.now().difference(current.updatedAt) < const Duration(minutes: 2)) {
        return null;
      }
      final resumeReason = current.status == 'running'
          ? 'stale_running_recovered'
          : current.attempts > 0
              ? 'retry_after_failure'
              : current.resumeReason;
      await txn.update(
        'generation_jobs',
        {
          'status': 'running',
          'attempts': current.attempts + 1,
          'started_at': now,
          'updated_at': now,
          'last_checkpoint_at': now,
          'next_retry_at': null,
          'partial_reasoning': '',
          'partial_content': '',
          'run_token': runToken,
          'last_error': '',
          'resume_reason': resumeReason,
          'device_id': localDeviceId,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final updated = await txn.query(
        'generation_jobs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return GenerationJob.fromDb(updated.first);
    });
  }

  Future<bool> checkpointGenerationJob(
    String id, {
    required String runToken,
    required String partialReasoning,
    required String partialContent,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await db.update(
      'generation_jobs',
      {
        'partial_reasoning': partialReasoning,
        'partial_content': partialContent,
        'last_checkpoint_at': now,
        'updated_at': now,
      },
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
    );
    return changed > 0;
  }

  Future<bool> completeGenerationJobIfCurrent({
    required String jobId,
    required String runToken,
    required ChatMessage assistant,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<bool>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{};
      for (final row in settingsRows) {
        final key = row['key'];
        if (key is String) settings[key] = row['value'] as String? ?? '';
      }
      if (settings['transfer_lock'] == '1' || settings['active_brain'] == '0') {
        return false;
      }
      final jobs = await txn.query(
        'generation_jobs',
        where: 'id = ?',
        whereArgs: [jobId],
        limit: 1,
      );
      if (jobs.isEmpty) return false;
      final job = GenerationJob.fromDb(jobs.first);
      if (job.runToken != runToken || runToken.isEmpty) return false;
      if (job.status == 'completed') {
        final existing = await txn.query(
          'messages',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [job.assistantMessageId],
          limit: 1,
        );
        return existing.isNotEmpty;
      }
      if (job.status != 'running') return false;
      if (assistant.id != job.assistantMessageId) return false;

      final existing = await txn.query(
        'messages',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [assistant.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert(
          'messages',
          assistant.toDb(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      final queueSetting = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: const ['post_turn_queue_enabled'],
        limit: 1,
      );
      final queueEnabled =
          queueSetting.isEmpty || (queueSetting.first['value'] as String? ?? '1') != '0';
      if (queueEnabled) {
        await txn.insert(
          'post_turn_jobs',
          {
            'id': _uuid.v4(),
            'user_message_id': job.userMessageId,
            'assistant_message_id': assistant.id,
            'status': 'pending',
            'attempts': 0,
            'last_error': '',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      final completed = await txn.update(
        'generation_jobs',
        {
          'status': 'completed',
          'partial_reasoning': assistant.reasoningContent,
          'partial_content': assistant.content,
          'completed_at': now,
          'last_checkpoint_at': now,
          'updated_at': now,
          'next_retry_at': null,
          'last_error': '',
        },
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [jobId, 'running', runToken],
      );
      if (completed != 1) {
        // Throwing rolls back the assistant/post-turn inserts in this same
        // SQLite transaction. Returning false here would incorrectly leave a
        // visible assistant message without a completed generation job.
        throw StateError('generation_commit_ownership_lost');
      }
      return true;
    });
  }

  Future<GenerationJob?> failGenerationJob(
    String id, {
    required String runToken,
    required String error,
    required bool recoverable,
  }) async {
    if (runToken.isEmpty) return null;
    final db = await database;
    // 0 means unlimited retries for transient/credential failures. A durable
    // user turn must not become a permanent conversation hole just because the
    // phone stayed offline for a few hours. Non-recoverable protocol/format
    // errors still fail immediately.
    final maxAttempts =
        int.tryParse(await getSetting('generation_max_attempts') ?? '') ?? 0;
    return db.transaction<GenerationJob?>((txn) async {
      final rows = await txn.query(
        'generation_jobs',
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [id, 'running', runToken],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final job = GenerationJob.fromDb(rows.first);
      final configuredLimit = maxAttempts <= 0 ? null : maxAttempts.clamp(1, 100);
      final canRetry = recoverable &&
          (configuredLimit == null || job.attempts < configuredLimit);
      final now = DateTime.now();
      DateTime? retryAt;
      if (canRetry) {
        final seconds = job.attempts <= 1
            ? 15
            : job.attempts == 2
                ? 60
                : job.attempts == 3
                    ? 300
                    : job.attempts == 4
                        ? 900
                        : 3600;
        retryAt = now.add(Duration(seconds: seconds));
      }
      final changed = await txn.update(
        'generation_jobs',
        {
          'status': canRetry ? 'retry_wait' : 'failed',
          'next_retry_at': retryAt?.millisecondsSinceEpoch,
          'last_error': error.length <= 360 ? error : error.substring(0, 360),
          'run_token': '',
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [id, 'running', runToken],
      );
      if (changed == 0) return null;
      final updated = await txn.query(
        'generation_jobs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return updated.isEmpty ? null : GenerationJob.fromDb(updated.first);
    });
  }

  Future<DateTime?> deferGenerationJob(
    String id, {
    required Duration delay,
    required String reason,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final retryAt = now.add(delay);
    final changed = await db.update(
      'generation_jobs',
      {
        'status': 'retry_wait',
        'next_retry_at': retryAt.millisecondsSinceEpoch,
        'last_error': '',
        'run_token': '',
        'resume_reason': reason,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: "id = ? AND status IN ('pending','retry_wait','running')",
      whereArgs: [id],
    );
    return changed > 0 ? retryAt : null;
  }

  Future<int> wakeRetryableGenerationJobs() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      'generation_jobs',
      {
        'next_retry_at': now,
        'updated_at': now,
      },
      where: "status = 'retry_wait'",
    );
  }

  Future<bool> suspendGenerationJob(
    String id, {
    required String reason,
    String? runToken,
  }) async {
    final db = await database;
    final where = runToken == null
        ? "id = ? AND status IN ('pending','retry_wait')"
        : 'id = ? AND status = ? AND run_token = ?';
    final whereArgs = runToken == null
        ? <Object?>[id]
        : <Object?>[id, 'running', runToken];
    final changed = await db.update(
      'generation_jobs',
      {
        'status': 'pending',
        'next_retry_at': null,
        'last_error': '',
        'run_token': '',
        'resume_reason': reason,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: where,
      whereArgs: whereArgs,
    );
    return changed > 0;
  }

  /// Atomically commit a proactive assistant message only if this device is
  /// still the writable Active Brain and no user chat turn has started since
  /// the proactive evaluation began. This closes the tiny race between a
  /// pre-commit status check and the actual INSERT.
  ///
  /// Returns null on success, otherwise a compact reason key.
  Future<String?> commitProactiveMessageIfCurrent({
    required ChatMessage message,
    required DateTime evaluationStartedAt,
  }) async {
    final db = await database;
    return db.transaction<String?>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock', 'chat_turn_lease'],
      );
      final settings = <String, String>{};
      for (final row in settingsRows) {
        final settingKey = row['key'];
        if (settingKey is String) {
          settings[settingKey] = (row['value'] as String?) ?? '';
        }
      }
      if (settings['transfer_lock'] == '1') return 'transfer_lock';
      if (settings['active_brain'] == '0') return 'inactive_brain';
      if (_leaseUntil(settings['chat_turn_lease'] ?? '') >
          DateTime.now().millisecondsSinceEpoch) {
        return 'chat_turn';
      }

      final lastUserRows = await txn.query(
        'messages',
        columns: ['created_at'],
        where: 'role = ?',
        whereArgs: const ['user'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (lastUserRows.isNotEmpty) {
        final createdAt = lastUserRows.first['created_at'] as int? ?? 0;
        if (createdAt > evaluationStartedAt.millisecondsSinceEpoch) {
          return 'new_user';
        }
      }

      await txn.insert(
        'messages',
        message.toDb(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return null;
    });
  }

  Future<ChatMessage?> messageById(String id) async {
    final db = await database;
    final rows = await db.query('messages', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : ChatMessage.fromDb(rows.first);
  }

  Future<List<ChatMessage>> recentMessages({int limit = 80}) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromDb).toList();
  }

  /// Metadata-only chat history for Reality Grounding and redacted diagnostics.
  /// Message/reasoning bodies are deliberately not selected.
  Future<List<ChatMessage>> recentMessageHeaders({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: const ['id', 'role', 'created_at', 'is_proactive'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromDb).toList();
  }

  Future<ChatMessage?> messageHeaderById(String id) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: const ['id', 'role', 'created_at', 'is_proactive'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ChatMessage.fromDb(rows.first);
  }

  Future<ChatMessage?> latestProactiveMessage() async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'is_proactive = ?',
      whereArgs: const [1],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChatMessage.fromDb(rows.first);
  }

  Future<List<ChatMessage>> messagesBefore(
    DateTime before, {
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'created_at < ?',
      whereArgs: [before.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromDb).toList();
  }

  Future<List<ChatMessage>> messagesAfter(
    DateTime? after, {
    int limit = 40,
  }) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: after == null ? null : 'created_at > ?',
      whereArgs: after == null ? null : [after.millisecondsSinceEpoch],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromDb).toList();
  }

  Future<DateTime?> lastUserMessageAt() async {
    final db = await database;
    final rows = await db.query(
      'messages',
      columns: ['created_at'],
      where: 'role = ?',
      whereArgs: ['user'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['created_at'] as int);
  }

  Future<void> insertMemory({
    required String kind,
    required String content,
    required double importance,
    double confidence = 0.72,
    List<String> tags = const [],
    String source = 'conversation',
    String subjectKey = '',
    bool pinned = false,
    String semanticType = 'current_fact',
    String evidenceMode = 'auto',
    String? targetMemoryId,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;
    final normalizedSubject = subjectKey.trim().toLowerCase();
    const semanticTypes = {'current_fact', 'inference', 'shared_experience'};
    const evidenceModes = {'auto', 'append', 'reinforce', 'replace'};
    var semantic = semanticTypes.contains(semanticType) ? semanticType : 'current_fact';
    final mode = evidenceModes.contains(evidenceMode) ? evidenceMode : 'auto';
    if (kind == 'shared_experience') semantic = 'shared_experience';
    if (semantic == 'current_fact' && confidence < 0.68 && !pinned) {
      semantic = 'inference';
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    double evidenceSimilarity(String a, String b) {
      final left = _tokens(a);
      final right = _tokens(b);
      if (left.isEmpty || right.isEmpty) {
        return a.trim().toLowerCase() == b.trim().toLowerCase() ? 1.0 : 0.0;
      }
      final shared = left.where(right.contains).length;
      return shared / min(left.length, right.length);
    }

    await db.transaction((txn) async {
      Future<bool> recordEvidence({
        required String memoryId,
        required String evidenceText,
        required String relation,
      }) async {
        final already = await txn.query(
          'memory_evidence',
          columns: ['id'],
          where: 'memory_id = ? AND source = ? AND evidence_text = ?',
          whereArgs: [memoryId, source, evidenceText],
          limit: 1,
        );
        if (already.isNotEmpty) return false;
        await txn.insert('memory_evidence', {
          'id': _uuid.v4(),
          'memory_id': memoryId,
          'source': source,
          'evidence_text': evidenceText,
          'confidence': confidence.clamp(0.0, 1.0),
          'relation': relation,
          'observed_at': now,
        });
        return true;
      }

      Future<void> reinforce(MemoryItem existing, {required String relation}) async {
        if (source.startsWith('conversation_turn:') && existing.source == source) {
          return;
        }
        final isNewEvidence = await recordEvidence(
          memoryId: existing.id,
          evidenceText: normalized,
          relation: relation,
        );
        if (!isNewEvidence) return;
        final mergedTags = <String>{...existing.tags, ...tags}.take(12).join('|');
        await txn.update(
          'memory_items',
          {
            'importance': (existing.importance * 0.82 + importance * 0.26)
                .clamp(0.0, 1.0),
            'confidence': (existing.confidence + (1 - existing.confidence) *
                    (0.12 + confidence.clamp(0.0, 1.0) * 0.16))
                .clamp(0.0, 1.0),
            'tags': mergedTags,
            if (existing.subjectKey.isEmpty && normalizedSubject.isNotEmpty)
              'subject_key': normalizedSubject,
            if (pinned) 'pinned': 1,
            'evidence_count': existing.evidenceCount + 1,
            'last_evidence_at': now,
            'retention_score': (existing.retentionScore + 0.10).clamp(0.0, 1.0),
            'retention_checked_at': now,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      }

      // A reflection slot and a durable post-turn proposal are idempotent.
      // Replaying a frozen worker must not manufacture extra evidence.
      if (source.startsWith('self_reflection_run:')) {
        final alreadyApplied = await txn.query(
          'memory_evidence',
          columns: ['id'],
          where: 'source = ?',
          whereArgs: [source],
          limit: 1,
        );
        if (alreadyApplied.isNotEmpty) return;
        final legacyApplied = await txn.query(
          'memory_items',
          columns: ['id'],
          where: 'source = ?',
          whereArgs: [source],
          limit: 1,
        );
        if (legacyApplied.isNotEmpty) return;
      }

      // Explicit reinforce from the extractor is the main paraphrase-merge
      // path. It preserves the canonical memory text while storing the new
      // wording as durable evidence in memory_evidence.
      if (mode == 'reinforce' && targetMemoryId != null && targetMemoryId.trim().isNotEmpty) {
        final targetRows = await txn.query(
          'memory_items',
          where: 'id = ? AND status = ?',
          whereArgs: [targetMemoryId.trim(), 'active'],
          limit: 1,
        );
        if (targetRows.isNotEmpty) {
          final target = MemoryItem.fromDb(targetRows.first);
          final subjectCompatible = normalizedSubject.isNotEmpty &&
              target.subjectKey.isNotEmpty &&
              normalizedSubject == target.subjectKey;
          final wordingCompatible = evidenceSimilarity(normalized, target.content) >= 0.48;
          if (target.kind == kind && (subjectCompatible || wordingCompatible)) {
            await reinforce(target, relation: 'reinforced');
            return;
          }
        }
      }

      // Exact duplicate remains a deterministic local fallback even when the
      // extraction model did not emit an explicit reinforce target.
      final duplicate = await txn.query(
        'memory_items',
        where: 'kind = ? AND content = ? AND status = ?',
        whereArgs: [kind, normalized, 'active'],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        final existing = MemoryItem.fromDb(duplicate.first);
        if (!(existing.isInference && semantic == 'current_fact')) {
          await reinforce(existing, relation: 'reinforced');
          return;
        }
        // The exact wording may have started life as a tentative inference.
        // Once the same proposition is explicitly confirmed, create a current
        // fact version below and supersede the old inference instead of trapping
        // it forever in the uncertain layer.
      }

      final id = _uuid.v4();
      var factVersion = 1;

      if (semantic == 'current_fact' && normalizedSubject.isNotEmpty) {
        final sameSubject = await txn.query(
          'memory_items',
          where: 'kind = ? AND subject_key = ? AND status = ?',
          whereArgs: [kind, normalizedSubject, 'active'],
        );
        final conflicts = sameSubject
            .where((row) => (row['semantic_type'] as String? ?? 'current_fact') == 'current_fact')
            .toList(growable: false);

        // Any user-pinned interpretation of this subject is authoritative until
        // the user edits/unpins it. Automatic extraction must not fork around it.
        if (sameSubject.any((row) => (row['pinned'] as int? ?? 0) == 1)) return;

        if (mode == 'append' && conflicts.isNotEmpty) {
          // Two simultaneous "current" values for one subject are ambiguous.
          // Preserve the new proposal as an inference instead of corrupting the
          // current-fact invariant.
          semantic = 'inference';
        } else {
          final versionRows = await txn.rawQuery(
            'SELECT MAX(fact_version) AS max_version FROM memory_items WHERE kind = ? AND subject_key = ?',
            [kind, normalizedSubject],
          );
          final maxVersion = (versionRows.first['max_version'] as num?)?.toInt() ?? 0;
          factVersion = maxVersion + 1;

          for (final row in sameSubject) {
            await txn.update(
              'memory_items',
              {
                'status': 'superseded',
                'superseded_by': id,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      }

      // Inference and shared-experience rows intentionally coexist. They can be
      // reinforced later, but never automatically replace a current fact.
      await txn.insert('memory_items', {
        'id': id,
        'kind': kind,
        'content': normalized,
        'importance': importance.clamp(0.0, 1.0),
        'confidence': confidence.clamp(0.0, 1.0),
        'tags': tags.take(12).join('|'),
        'source': source,
        'status': 'active',
        'subject_key': normalizedSubject,
        'pinned': pinned ? 1 : 0,
        'superseded_by': null,
        'created_at': now,
        'updated_at': now,
        'last_recalled_at': null,
        'recall_count': 0,
        'retention_score': 1.0,
        'retention_checked_at': now,
        'semantic_type': semantic,
        'evidence_count': 1,
        'first_observed_at': now,
        'last_evidence_at': now,
        'fact_version': factVersion,
      });
      await recordEvidence(
        memoryId: id,
        evidenceText: normalized,
        relation: mode == 'replace' ? 'replaced' : 'created',
      );
    });
  }

  Future<List<MemoryItem>> memoriesByKind(
    String kind, {
    int limit = 8,
  }) async {
    final db = await database;
    final semantic = kind == 'shared_experience' ? 'shared_experience' : 'current_fact';
    final rows = await db.query(
      'memory_items',
      where: 'kind = ? AND status = ? AND semantic_type = ? AND (retention_score >= ? OR pinned = 1)',
      whereArgs: [kind, 'active', semantic, 0.14],
      orderBy: 'pinned DESC, importance DESC, retention_score DESC, confidence DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromDb).toList();
  }

  Future<List<MemoryItem>> memoryInferencesByKind(
    String kind, {
    int limit = 6,
  }) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: 'kind = ? AND status = ? AND semantic_type = ? AND retention_score >= ?',
      whereArgs: [kind, 'active', 'inference', 0.18],
      orderBy: 'importance DESC, confidence DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromDb).toList();
  }

  Future<List<MemoryItem>> relevantMemories(
    String query, {
    int limit = 12,
  }) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: "status = ? AND semantic_type IN ('current_fact','shared_experience')",
      whereArgs: ['active'],
      orderBy: 'importance DESC, retention_score DESC, updated_at DESC',
      limit: 180,
    );
    final queryTokens = _tokens(query);
    final now = DateTime.now();
    final scored = <({MemoryItem item, double score})>[];
    for (final row in rows) {
      final item = MemoryItem.fromDb(row);
      final textTokens = _tokens('${item.content} ${item.tags.join(' ')}');
      final overlap = queryTokens.isEmpty
          ? 0.0
          : queryTokens.where(textTokens.contains).length / queryTokens.length;
      final ageDays = now.difference(item.updatedAt).inHours / 24.0;
      final recency = 1 / (1 + ageDays / 45.0);
      final kindBoost = switch (item.kind) {
        'shared_experience' => 0.05,
        'preference' => 0.045,
        'user_profile' => 0.035,
        'ai_self' => 0.03,
        _ => 0.0,
      };
      final familiarity = (item.recallCount / 12.0).clamp(0.0, 1.0).toDouble();
      final score = item.importance * 0.34 +
          item.confidence * 0.16 +
          overlap * 0.32 +
          recency * 0.10 +
          familiarity * 0.03 +
          item.retentionScore * 0.15 +
          (item.pinned ? 0.18 : 0.0) +
          kindBoost;
      scored.add((item: item, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final selected = scored.take(limit).map((e) => e.item).toList();
    if (selected.isNotEmpty) {
      final batch = db.batch();
      for (final item in selected) {
        batch.update(
          'memory_items',
          {
            'last_recalled_at': now.millisecondsSinceEpoch,
            'recall_count': item.recallCount + 1,
            'retention_score': (item.retentionScore + 0.025).clamp(0.0, 1.0),
            'retention_checked_at': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
      await batch.commit(noResult: true);
    }
    return selected;
  }

  Future<List<MemoryItem>> memoryCandidatesForExtraction(
    String query, {
    int limit = 14,
  }) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'pinned DESC, importance DESC, confidence DESC, updated_at DESC',
      limit: 220,
    );
    final queryTokens = _tokens(query);
    final scored = <({MemoryItem item, double score})>[];
    for (final row in rows) {
      final item = MemoryItem.fromDb(row);
      final textTokens = _tokens('${item.content} ${item.subjectKey} ${item.tags.join(' ')}');
      final overlap = queryTokens.isEmpty
          ? 0.0
          : queryTokens.where(textTokens.contains).length / queryTokens.length;
      final semanticBoost = switch (item.semanticType) {
        'current_fact' => 0.08,
        'shared_experience' => 0.04,
        _ => 0.0,
      };
      final score = overlap * 0.58 +
          item.importance * 0.17 +
          item.confidence * 0.10 +
          (item.pinned ? 0.22 : 0.0) +
          semanticBoost;
      scored.add((item: item, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.item).toList(growable: false);
  }

  Future<List<MemoryItem>> relevantMemoryInferences(
    String query, {
    int limit = 3,
  }) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: 'status = ? AND semantic_type = ? AND retention_score >= ?',
      whereArgs: ['active', 'inference', 0.18],
      orderBy: 'importance DESC, confidence DESC, updated_at DESC',
      limit: 120,
    );
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return const [];
    final scored = <({MemoryItem item, double score})>[];
    for (final row in rows) {
      final item = MemoryItem.fromDb(row);
      final tokens = _tokens('${item.content} ${item.subjectKey} ${item.tags.join(' ')}');
      final overlap = queryTokens.where(tokens.contains).length / queryTokens.length;
      if (overlap <= 0) continue;
      scored.add((item: item, score: overlap * 0.72 + item.confidence * 0.18 + item.importance * 0.10));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.item).toList(growable: false);
  }

  Future<List<MemoryItem>> relevantHistoricalMemories(
    String query, {
    int limit = 3,
  }) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: 'status = ? AND semantic_type = ? AND subject_key <> ?',
      whereArgs: ['superseded', 'current_fact', ''],
      orderBy: 'updated_at DESC',
      limit: 140,
    );
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return const [];
    final scored = <({MemoryItem item, double score})>[];
    for (final row in rows) {
      final item = MemoryItem.fromDb(row);
      final tokens = _tokens('${item.content} ${item.subjectKey} ${item.tags.join(' ')}');
      final overlap = queryTokens.where(tokens.contains).length / queryTokens.length;
      if (overlap <= 0) continue;
      scored.add((item: item, score: overlap * 0.78 + item.importance * 0.14 + item.confidence * 0.08));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.item).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> memoryEvidenceFor(
    String memoryId, {
    int limit = 40,
  }) async {
    final db = await database;
    return db.query(
      'memory_evidence',
      where: 'memory_id = ?',
      whereArgs: [memoryId],
      orderBy: 'observed_at DESC',
      limit: limit,
    );
  }

  Future<List<MemoryItem>> memoryCandidatesForSelfDrive({int limit = 24}) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: "status = ? AND retention_score >= ? AND semantic_type IN ('current_fact','shared_experience')",
      whereArgs: ['active', 0.18],
      orderBy: 'importance DESC, retention_score DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromDb).toList();
  }

  Future<List<MemoryItem>> listMemories({
    String? kind,
    String status = 'active',
    int limit = 300,
  }) async {
    final db = await database;
    final clauses = <String>['status = ?'];
    final args = <Object?>[status];
    if (kind != null && kind.isNotEmpty && kind != 'all') {
      clauses.add('kind = ?');
      args.add(kind);
    }
    final rows = await db.query(
      'memory_items',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'importance DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromDb).toList();
  }

  Future<void> updateMemoryItem({
    required String id,
    required String content,
    required double importance,
    required double confidence,
    required List<String> tags,
    String? subjectKey,
    bool? pinned,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'memory_items',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final existing = MemoryItem.fromDb(rows.first);
      final normalizedSubject = subjectKey != null
          ? subjectKey.trim().toLowerCase()
          : existing.subjectKey;
      if (existing.status == 'active' &&
          existing.semanticType == 'current_fact' &&
          normalizedSubject.isNotEmpty) {
        final conflicts = await txn.query(
          'memory_items',
          columns: ['id'],
          where: "kind = ? AND subject_key = ? AND status = 'active' AND semantic_type = 'current_fact' AND id <> ?",
          whereArgs: [existing.kind, normalizedSubject, id],
          limit: 1,
        );
        if (conflicts.isNotEmpty) {
          throw StateError('current_fact_subject_conflict');
        }
      }

      final contentChanged = existing.content != normalized;
      if (contentChanged) {
        final priorEvidence = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM memory_evidence WHERE memory_id = ?',
              [id],
            )) ??
            0;
        if (priorEvidence == 0 && existing.content.trim().isNotEmpty) {
          await txn.insert(
            'memory_evidence',
            {
              'id': _uuid.v4(),
              'memory_id': id,
              'source': 'legacy_before_manual_edit:$now',
              'evidence_text': existing.content,
              'confidence': existing.confidence,
              'relation': 'manual_edit_previous',
              'observed_at': existing.lastEvidenceAt.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        final manualSource = 'manual_edit:$now';
        await txn.insert(
          'memory_evidence',
          {
            'id': _uuid.v4(),
            'memory_id': id,
            'source': manualSource,
            'evidence_text': normalized,
            'confidence': confidence.clamp(0.0, 1.0),
            'relation': 'manual_edit',
            'observed_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.update(
        'memory_items',
        {
          'content': normalized,
          'importance': importance.clamp(0.0, 1.0),
          'confidence': confidence.clamp(0.0, 1.0),
          'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).take(12).join('|'),
          if (subjectKey != null) 'subject_key': normalizedSubject,
          if (pinned != null) 'pinned': pinned ? 1 : 0,
          if (contentChanged) 'evidence_count': existing.evidenceCount + 1,
          if (contentChanged) 'last_evidence_at': now,
          'retention_score': 1.0,
          'retention_checked_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> setMemoryStatus(String id, String status) async {
    const allowed = {'active', 'archived', 'superseded'};
    if (!allowed.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported memory status');
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'memory_items',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final existing = MemoryItem.fromDb(rows.first);
      if (status == 'active' &&
          existing.semanticType == 'current_fact' &&
          existing.subjectKey.isNotEmpty) {
        final conflicts = await txn.query(
          'memory_items',
          columns: ['id'],
          where: "kind = ? AND subject_key = ? AND status = 'active' AND semantic_type = 'current_fact' AND id <> ?",
          whereArgs: [existing.kind, existing.subjectKey, id],
          limit: 1,
        );
        if (conflicts.isNotEmpty) {
          throw StateError('current_fact_subject_conflict');
        }
      }
      await txn.update(
        'memory_items',
        {
          'status': status,
          if (status == 'active') 'retention_score': 0.72,
          if (status == 'active') 'retention_checked_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Set<String> _tokens(String text) {
    final lowered = text.toLowerCase();
    final latin = RegExp(r'[a-z0-9_]{2,}').allMatches(lowered).map((m) => m[0]!);
    final chinese = <String>[];
    final chars = lowered.runes.map(String.fromCharCode).toList();
    for (var i = 0; i < chars.length - 1; i++) {
      final pair = '${chars[i]}${chars[i + 1]}';
      if (RegExp(r'[\u4e00-\u9fff]{2}').hasMatch(pair)) chinese.add(pair);
    }
    return {...latin, ...chinese};
  }

  Future<List<CompanionThought>> activeThoughts({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'thoughts',
      where: "lifecycle_state IN ('active','fixation','acted','residual')",
      orderBy: 'strength DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(CompanionThought.fromDb).toList();
  }

  /// Metadata-only Thought read for redacted diagnostics. The SQL substitutes
  /// an empty text value so the private Thought body is never read from disk.
  Future<List<CompanionThought>> activeThoughtMetadata({int limit = 40}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT id, '' AS text, drive_key, kind, strength, born_at, updated_at,
             fed_count, source, last_fed_at, lifecycle_state, action_count,
             last_acted_at, last_satisfied_at, last_resurfaced_at,
             resurfaced_count, residual_strength, last_outbound_message_id,
             topic_key, merged_count, last_merged_at, snoozed_until
      FROM thoughts
      WHERE lifecycle_state IN ('active','fixation','acted','residual')
      ORDER BY strength DESC, updated_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(CompanionThought.fromDb).toList();
  }

  Future<CompanionThought?> latestActiveThought() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'thoughts',
      where: "lifecycle_state IN ('active','fixation') AND "
          '(snoozed_until IS NULL OR snoozed_until <= ?)',
      whereArgs: [now],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CompanionThought.fromDb(rows.first);
  }

  /// Read-only candidates for daily companion-facing relationship surfaces.
  /// Residual/acted/dormant and snoozed Thoughts are excluded in SQL so a
  /// large long-running pool cannot crowd current cares out of a bounded read.
  Future<List<CompanionThought>> currentThoughtsForPresentation({int limit = 30}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'thoughts',
      where: "lifecycle_state IN ('active','fixation') AND "
          '(snoozed_until IS NULL OR snoozed_until <= ?)',
      whereArgs: [now],
      orderBy: 'strength DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(CompanionThought.fromDb).toList();
  }

  Future<void> upsertThought({
    String? id,
    required String text,
    required DriveKey drive,
    required String kind,
    required double strength,
    int fedCount = 0,
    DateTime? bornAt,
    DateTime? lastFedAt,
    String source = 'internal',
    String lifecycleState = 'active',
    int actionCount = 0,
    DateTime? lastActedAt,
    DateTime? lastSatisfiedAt,
    DateTime? lastResurfacedAt,
    int resurfacedCount = 0,
    double residualStrength = 0,
    String? lastOutboundMessageId,
    String topicKey = '',
    int mergedCount = 0,
    DateTime? lastMergedAt,
    DateTime? snoozedUntil,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    final now = DateTime.now();
    await db.insert(
      'thoughts',
      {
        'id': id ?? _uuid.v4(),
        'text': normalized,
        'drive_key': drive.name,
        'kind': kind,
        'strength': strength.clamp(0.0, 1.0),
        'born_at': (bornAt ?? now).millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'fed_count': fedCount,
        'source': source,
        'last_fed_at': (lastFedAt ?? now).millisecondsSinceEpoch,
        'lifecycle_state': lifecycleState,
        'action_count': actionCount,
        'last_acted_at': lastActedAt?.millisecondsSinceEpoch,
        'last_satisfied_at': lastSatisfiedAt?.millisecondsSinceEpoch,
        'last_resurfaced_at': lastResurfacedAt?.millisecondsSinceEpoch,
        'resurfaced_count': resurfacedCount,
        'residual_strength': residualStrength.clamp(0.0, 1.0),
        'last_outbound_message_id': lastOutboundMessageId,
        'topic_key': topicKey.trim().toLowerCase(),
        'merged_count': mergedCount,
        'last_merged_at': lastMergedAt?.millisecondsSinceEpoch,
        'snoozed_until': snoozedUntil?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteThought(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Lifecycle/audit rows are owned by the Thought. Feedback is historical
      // evidence, so keep it but detach the deleted thought reference.
      await txn.delete('thought_lifecycle_events', where: 'thought_id = ?', whereArgs: [id]);
      await txn.update('proactive_feedback', {'thought_id': null}, where: 'thought_id = ?', whereArgs: [id]);
      await txn.delete('thoughts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<CompanionThought?> thoughtById(String id) async {
    final db = await database;
    final rows = await db.query('thoughts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CompanionThought.fromDb(rows.first);
  }

  Future<List<CompanionThought>> lifecycleThoughts({int limit = 80}) async {
    final db = await database;
    final rows = await db.query('thoughts', orderBy: 'updated_at DESC', limit: limit);
    return rows.map(CompanionThought.fromDb).toList();
  }

  Future<CompanionThought?> thoughtBySource(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'thoughts',
      where: 'source = ?',
      whereArgs: [normalized],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CompanionThought.fromDb(rows.first);
  }

  Future<List<CompanionThought>> thoughtsByTopic(
    String topicKey, {
    int limit = 24,
  }) async {
    final key = topicKey.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final db = await database;
    final rows = await db.query(
      'thoughts',
      where: 'topic_key = ?',
      whereArgs: [key],
      orderBy: 'strength DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(CompanionThought.fromDb).toList();
  }

  Future<bool> markThoughtResponseReceivedAtomic({
    required String thoughtId,
    required double responseQuality,
    required String responseMessageId,
  }) async {
    final db = await database;
    return db.transaction<bool>((txn) async {
      final seen = await txn.query(
        'thought_lifecycle_events',
        columns: ['id'],
        where: 'thought_id = ? AND event_type = ? AND message_id = ?',
        whereArgs: [thoughtId, 'response_received', responseMessageId],
        limit: 1,
      );
      if (seen.isNotEmpty) return true;
      final rows = await txn.query('thoughts', where: 'id = ?', whereArgs: [thoughtId], limit: 1);
      if (rows.isEmpty) return false;
      final thought = CompanionThought.fromDb(rows.first);
      final quality = responseQuality.clamp(0.0, 1.0).toDouble();
      final base = max(thought.residualStrength, thought.strength);
      final residual = (base * (0.78 - quality * 0.20)).clamp(0.16, 0.64).toDouble();
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'thoughts',
        {
          'lifecycle_state': 'residual',
          'strength': residual,
          'residual_strength': residual,
          'last_outbound_message_id': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [thoughtId],
      );
      await txn.insert('thought_lifecycle_events', {
        'id': _uuid.v4(),
        'thought_id': thoughtId,
        'event_type': 'response_received',
        'message_id': responseMessageId,
        'detail': '用户已经回应主动消息；先解除等待状态，是否真正解决该念头留给完整对话结果判断。',
        'created_at': now,
      });
      return true;
    });
  }

  Future<bool> applyThoughtResponseOutcomeAtomic({
    required String thoughtId,
    required String outcome,
    required double resolution,
    required String responseMessageId,
  }) async {
    final db = await database;
    final normalizedOutcome = const {
      'resolved', 'engaged', 'deferred', 'dismissed', 'redirected', 'acknowledged'
    }.contains(outcome) ? outcome : 'acknowledged';
    return db.transaction<bool>((txn) async {
      final eventType = 'response_outcome_$normalizedOutcome';
      final seen = await txn.query(
        'thought_lifecycle_events',
        columns: ['id'],
        where: 'thought_id = ? AND event_type = ? AND message_id = ?',
        whereArgs: [thoughtId, eventType, responseMessageId],
        limit: 1,
      );
      if (seen.isNotEmpty) return true;
      final rows = await txn.query('thoughts', where: 'id = ?', whereArgs: [thoughtId], limit: 1);
      if (rows.isEmpty) return false;
      final thought = CompanionThought.fromDb(rows.first);
      final now = DateTime.now();
      final r = resolution.clamp(0.0, 1.0).toDouble();
      final base = max(thought.residualStrength, thought.strength);
      late final String state;
      late final double residual;
      DateTime? snooze;
      switch (normalizedOutcome) {
        case 'resolved':
          residual = (base * (0.30 - r * 0.18)).clamp(0.04, 0.16).toDouble();
          state = residual <= 0.10 ? 'dormant' : 'residual';
          break;
        case 'engaged':
          residual = (base * (0.62 - r * 0.22)).clamp(0.14, 0.46).toDouble();
          state = 'residual';
          break;
        case 'deferred':
          residual = (base * 0.88).clamp(0.28, 0.70).toDouble();
          state = 'residual';
          snooze = now.add(const Duration(hours: 4));
          break;
        case 'dismissed':
          residual = (base * 0.22).clamp(0.03, 0.14).toDouble();
          state = 'dormant';
          snooze = now.add(const Duration(days: 7));
          break;
        case 'redirected':
          residual = (base * 0.48).clamp(0.08, 0.34).toDouble();
          state = residual <= 0.10 ? 'dormant' : 'residual';
          snooze = now.add(const Duration(hours: 12));
          break;
        case 'acknowledged':
        default:
          residual = (base * 0.60).clamp(0.12, 0.40).toDouble();
          state = 'residual';
          break;
      }
      final nowMs = now.millisecondsSinceEpoch;
      await txn.update(
        'thoughts',
        {
          'lifecycle_state': state,
          'strength': residual,
          'residual_strength': residual,
          'last_satisfied_at': nowMs,
          'snoozed_until': snooze?.millisecondsSinceEpoch,
          'last_outbound_message_id': null,
          'updated_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: [thoughtId],
      );
      await txn.insert('thought_lifecycle_events', {
        'id': _uuid.v4(),
        'thought_id': thoughtId,
        'event_type': eventType,
        'message_id': responseMessageId,
        'detail': '主动话题回应结果=$normalizedOutcome，resolution=${r.toStringAsFixed(2)}。',
        'created_at': nowMs,
      });
      return true;
    });
  }

  Future<bool> applyProactiveThreadOutcomeOnce({
    required String threadId,
    required String outcome,
    required String responseMessageId,
    DateTime? followupDueAt,
  }) async {
    final db = await database;
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'unfinished_threads',
        where: 'id = ?',
        whereArgs: [threadId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final row = rows.first;
      if ((row['proactive_outcome_message_id'] as String? ?? '') == responseMessageId) {
        return true;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final values = <String, Object?>{
        'proactive_outcome_message_id': responseMessageId,
        'updated_at': now,
      };
      switch (outcome) {
        case 'resolved':
          values.addAll({
            'status': 'resolved',
            'resolved_at': now,
            'followup_due_at': null,
            'followup_seeded_at': null,
            'followup_run_token': '',
            'followup_claimed_at': null,
          });
          break;
        case 'dismissed':
          values.addAll({
            'status': 'dismissed',
            'resolved_at': now,
            'followup_due_at': null,
            'followup_seeded_at': null,
            'followup_run_token': '',
            'followup_claimed_at': null,
          });
          break;
        case 'deferred':
          values.addAll({
            'followup_due_at': followupDueAt?.millisecondsSinceEpoch,
            'followup_seeded_at': null,
            'followup_run_token': '',
            'followup_claimed_at': null,
          });
          break;
        case 'engaged':
        case 'acknowledged':
        case 'redirected':
        default:
          values.addAll({
            'followup_due_at': null,
            'followup_seeded_at': null,
            'followup_run_token': '',
            'followup_claimed_at': null,
          });
          break;
      }
      final changed = await txn.update(
        'unfinished_threads',
        values,
        where: 'id = ? AND proactive_outcome_message_id IS NOT ?',
        whereArgs: [threadId, responseMessageId],
      );
      return changed == 1;
    });
  }

  Future<bool> updateThoughtLifecycle(
    String id, {
    String? lifecycleState,
    String? kind,
    double? strength,
    double? residualStrength,
    int? actionCount,
    DateTime? lastActedAt,
    DateTime? lastSatisfiedAt,
    DateTime? lastResurfacedAt,
    int? resurfacedCount,
    String? lastOutboundMessageId,
    String? topicKey,
    int? mergedCount,
    DateTime? lastMergedAt,
    DateTime? snoozedUntil,
    bool clearOutboundMessage = false,
    bool clearSnooze = false,
    DateTime? expectedUpdatedAt,
  }) async {
    final values = <String, Object?>{
      if (lifecycleState != null) 'lifecycle_state': lifecycleState,
      if (kind != null) 'kind': kind,
      if (strength != null) 'strength': strength.clamp(0.0, 1.0),
      if (residualStrength != null)
        'residual_strength': residualStrength.clamp(0.0, 1.0),
      if (actionCount != null) 'action_count': actionCount,
      if (lastActedAt != null) 'last_acted_at': lastActedAt.millisecondsSinceEpoch,
      if (lastSatisfiedAt != null)
        'last_satisfied_at': lastSatisfiedAt.millisecondsSinceEpoch,
      if (lastResurfacedAt != null)
        'last_resurfaced_at': lastResurfacedAt.millisecondsSinceEpoch,
      if (resurfacedCount != null) 'resurfaced_count': resurfacedCount,
      if (lastOutboundMessageId != null)
        'last_outbound_message_id': lastOutboundMessageId,
      if (topicKey != null) 'topic_key': topicKey.trim().toLowerCase(),
      if (mergedCount != null) 'merged_count': mergedCount,
      if (lastMergedAt != null) 'last_merged_at': lastMergedAt.millisecondsSinceEpoch,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil.millisecondsSinceEpoch,
      if (clearOutboundMessage) 'last_outbound_message_id': null,
      if (clearSnooze) 'snoozed_until': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    final db = await database;
    final changed = await db.update(
      'thoughts',
      values,
      where: expectedUpdatedAt == null ? 'id = ?' : 'id = ? AND updated_at = ?',
      whereArgs: expectedUpdatedAt == null
          ? <Object?>[id]
          : <Object?>[id, expectedUpdatedAt.millisecondsSinceEpoch],
    );
    return changed == 1;
  }

  Future<bool> hasThoughtLifecycleEvent({
    required String thoughtId,
    required String eventType,
    String? messageId,
    String? detail,
  }) async {
    final db = await database;
    final clauses = <String>['thought_id = ?', 'event_type = ?'];
    final args = <Object?>[thoughtId, eventType];
    if (messageId != null) {
      clauses.add('message_id = ?');
      args.add(messageId);
    }
    if (detail != null) {
      clauses.add('detail = ?');
      args.add(detail);
    }
    final rows = await db.query(
      'thought_lifecycle_events',
      columns: ['id'],
      where: clauses.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Exactly-once Thought reinforcement for one cached post-turn proposal.
  /// The evidence row and the Thought mutation are committed together, so a
  /// retry of the same assistant turn cannot increment fed_count twice.
  Future<bool> applyPostTurnThoughtEvidenceAtomic({
    required String sourceMessageId,
    required String evidenceKey,
    required String text,
    required DriveKey drive,
    required double incomingStrength,
    String topicKey = '',
  }) async {
    final normalizedText = text.trim();
    final normalizedTopic = topicKey.trim().toLowerCase();
    final normalizedEvidence = evidenceKey.trim();
    if (sourceMessageId.isEmpty || normalizedText.isEmpty || normalizedEvidence.isEmpty) {
      return false;
    }
    final db = await database;
    return db.transaction<bool>((txn) async {
      final seen = await txn.query(
        'thought_lifecycle_events',
        columns: ['id'],
        where: 'event_type = ? AND message_id = ? AND detail = ?',
        whereArgs: ['post_turn_evidence', sourceMessageId, normalizedEvidence],
        limit: 1,
      );
      if (seen.isNotEmpty) return true;

      List<Map<String, Object?>> matches;
      if (normalizedTopic.isNotEmpty) {
        matches = await txn.query(
          'thoughts',
          where: 'drive_key = ? AND topic_key = ?',
          whereArgs: [drive.name, normalizedTopic],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
      } else {
        matches = await txn.query(
          'thoughts',
          where: 'drive_key = ? AND text = ?',
          whereArgs: [drive.name, normalizedText],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      String thoughtId;
      if (matches.isEmpty) {
        thoughtId = _uuid.v4();
        final strength = incomingStrength.clamp(0.08, 0.70).toDouble();
        await txn.insert('thoughts', {
          'id': thoughtId,
          'text': normalizedText,
          'drive_key': drive.name,
          'kind': strength >= 0.68 ? 'fixation' : 'flit',
          'strength': strength,
          'born_at': now,
          'updated_at': now,
          'fed_count': 1,
          'source': 'conversation_turn:$sourceMessageId',
          'last_fed_at': now,
          'lifecycle_state': strength >= 0.68 ? 'fixation' : 'active',
          'action_count': 0,
          'last_acted_at': null,
          'last_satisfied_at': null,
          'last_resurfaced_at': null,
          'resurfaced_count': 0,
          'residual_strength': 0.0,
          'last_outbound_message_id': null,
          'topic_key': normalizedTopic,
          'merged_count': 0,
          'last_merged_at': null,
          'snoozed_until': null,
        });
      } else {
        final thought = CompanionThought.fromDb(matches.first);
        thoughtId = thought.id;
        final fed = thought.fedCount + 1;
        final nextStrength =
            (thought.strength * 0.88 + incomingStrength * 0.55 + 0.06)
                .clamp(0.0, 1.0)
                .toDouble();
        final fixation = fed >= 3 || nextStrength >= 0.68;
        await txn.update(
          'thoughts',
          {
            'strength': nextStrength,
            'fed_count': fed,
            'kind': fixation ? 'fixation' : thought.kind,
            'lifecycle_state': fixation ? 'fixation' : 'active',
            'last_fed_at': now,
            'updated_at': now,
            if (thought.topicKey.isEmpty && normalizedTopic.isNotEmpty)
              'topic_key': normalizedTopic,
            // A new real conversation is authoritative enough to reopen a
            // snoozed topic. This mirrors DesireEngine.feedThought behavior.
            'snoozed_until': null,
          },
          where: 'id = ?',
          whereArgs: [thought.id],
        );
      }
      await txn.insert('thought_lifecycle_events', {
        'id': _uuid.v4(),
        'thought_id': thoughtId,
        'event_type': 'post_turn_evidence',
        'detail': normalizedEvidence,
        'message_id': sourceMessageId,
        'created_at': now,
      });
      return true;
    });
  }

  Future<void> addThoughtLifecycleEvent({
    required String thoughtId,
    required String eventType,
    String detail = '',
    String? messageId,
  }) async {
    final db = await database;
    await db.insert('thought_lifecycle_events', {
      'id': _uuid.v4(),
      'thought_id': thoughtId,
      'event_type': eventType,
      'detail': detail,
      'message_id': messageId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ThoughtLifecycleEvent>> recentThoughtLifecycleEvents({int limit = 80}) async {
    final db = await database;
    final rows = await db.query('thought_lifecycle_events', orderBy: 'created_at DESC', limit: limit);
    return rows.map(ThoughtLifecycleEvent.fromDb).toList();
  }

  Future<bool> mergeThoughtRecords({
    required CompanionThought primary,
    required List<CompanionThought> duplicates,
  }) async {
    if (duplicates.isEmpty) return false;
    final db = await database;
    final now = DateTime.now();
    return db.transaction<bool>((txn) async {
      final all = <CompanionThought>[primary, ...duplicates];
      // Thought consolidation works from an in-memory snapshot. If a chat,
      // relationship event or lifecycle worker changed any candidate after the
      // scan, abandon this merge instead of deleting/replacing fresh evidence.
      for (final thought in all) {
        final currentRows = await txn.query(
          'thoughts',
          columns: ['updated_at'],
          where: 'id = ?',
          whereArgs: [thought.id],
          limit: 1,
        );
        if (currentRows.isEmpty ||
            (currentRows.first['updated_at'] as int? ?? 0) !=
                thought.updatedAt.millisecondsSinceEpoch) {
          return false;
        }
      }
      DateTime? latest(DateTime? a, DateTime? b) {
        if (a == null) return b;
        if (b == null) return a;
        return a.isAfter(b) ? a : b;
      }
      // A fresh active/fixation copy means the topic has been reactivated
      // after a previous outbound action. It must not be suppressed merely
      // because an older duplicate is in `acted` state.
      final stateRank = <String, int>{
        'dormant': 0,
        'residual': 1,
        'acted': 2,
        'active': 3,
        'fixation': 4,
      };
      var chosenState = primary.lifecycleState;
      var chosenKind = primary.kind;
      var strength = primary.strength;
      var residual = primary.residualStrength;
      var fed = 0;
      var actions = 0;
      var resurfaced = 0;
      var mergedCount = 0;
      var born = primary.bornAt;
      DateTime? lastFed = primary.lastFedAt;
      DateTime? lastActed = primary.lastActedAt;
      DateTime? lastSatisfied = primary.lastSatisfiedAt;
      DateTime? lastResurfaced = primary.lastResurfacedAt;
      DateTime? snoozedUntil = primary.snoozedUntil;
      String? outbound = primary.lastOutboundMessageId;
      var topicKey = primary.topicKey;
      var bestText = primary.text;
      var bestTextScore = primary.strength + primary.fedCount * 0.02;

      for (final t in all) {
        fed += t.fedCount;
        actions += t.actionCount;
        resurfaced += t.resurfacedCount;
        mergedCount += t.mergedCount;
        if (t.bornAt.isBefore(born)) born = t.bornAt;
        lastFed = latest(lastFed, t.lastFedAt);
        lastActed = latest(lastActed, t.lastActedAt);
        lastSatisfied = latest(lastSatisfied, t.lastSatisfiedAt);
        lastResurfaced = latest(lastResurfaced, t.lastResurfacedAt);
        snoozedUntil = latest(snoozedUntil, t.snoozedUntil);
        if ((stateRank[t.lifecycleState] ?? 0) > (stateRank[chosenState] ?? 0)) {
          chosenState = t.lifecycleState;
          chosenKind = t.kind;
        }
        if (t.lastOutboundMessageId != null &&
            (lastActed == null || t.lastActedAt == lastActed)) {
          outbound = t.lastOutboundMessageId;
        }
        if (t.topicKey.isNotEmpty) topicKey = t.topicKey;
        strength = t.strength > strength ? t.strength : strength;
        residual = t.residualStrength > residual ? t.residualStrength : residual;
        final textScore = t.strength + t.fedCount * 0.02;
        if (textScore > bestTextScore) {
          bestTextScore = textScore;
          bestText = t.text;
        }
      }
      strength = (strength + duplicates.length * 0.025).clamp(0.0, 0.95).toDouble();
      final ids = duplicates.map((e) => e.id).toList(growable: false);
      for (final duplicateId in ids) {
        await txn.update('proactive_feedback', {'thought_id': primary.id}, where: 'thought_id = ?', whereArgs: [duplicateId]);
        await txn.update('thought_lifecycle_events', {'thought_id': primary.id}, where: 'thought_id = ?', whereArgs: [duplicateId]);
      }
      await txn.update('thoughts', {
        'text': bestText,
        'kind': chosenKind,
        'strength': strength,
        'born_at': born.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
        'fed_count': fed,
        'last_fed_at': lastFed?.millisecondsSinceEpoch,
        'lifecycle_state': chosenState,
        'action_count': actions,
        'last_acted_at': lastActed?.millisecondsSinceEpoch,
        'last_satisfied_at': lastSatisfied?.millisecondsSinceEpoch,
        'last_resurfaced_at': lastResurfaced?.millisecondsSinceEpoch,
        'resurfaced_count': resurfaced.clamp(0, 12).toInt(),
        'residual_strength': residual,
        'last_outbound_message_id': outbound,
        'topic_key': topicKey,
        'merged_count': mergedCount + duplicates.length,
        'last_merged_at': now.millisecondsSinceEpoch,
        'snoozed_until': snoozedUntil?.millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [primary.id]);
      for (final duplicateId in ids) {
        await txn.delete('thoughts', where: 'id = ?', whereArgs: [duplicateId]);
      }
      await txn.insert('thought_lifecycle_events', {
        'id': _uuid.v4(),
        'thought_id': primary.id,
        'event_type': 'merged_duplicates',
        'detail': '本地长期去重合并 ${duplicates.length} 条相似念头。',
        'created_at': now.millisecondsSinceEpoch,
      });
      return true;
    });
  }

  Future<DesireSnapshot> loadDesire() async {
    final db = await database;
    final rows = await db.query('desire_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return DesireSnapshot();
    return DesireSnapshot.decode(rows.first['json'] as String);
  }

  Future<void> saveDesire(DesireSnapshot snapshot) async {
    final db = await database;
    await db.insert(
      'desire_state',
      {
        'id': 1,
        'json': snapshot.encode(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically read-modify-write the single Desire snapshot. Multiple Flutter
  /// engines (UI + foreground background engine) can touch inner state, so a
  /// plain load followed by save would otherwise lose concurrent pulses.
  Future<DesireSnapshot> mutateDesire(
    DesireSnapshot Function(DesireSnapshot current) transform,
  ) async {
    final db = await database;
    return db.transaction<DesireSnapshot>((txn) async {
      final rows = await txn.query(
        'desire_state',
        where: 'id = 1',
        limit: 1,
      );
      final current = rows.isEmpty
          ? DesireSnapshot()
          : DesireSnapshot.decode(rows.first['json'] as String);
      final next = transform(current);
      await txn.insert(
        'desire_state',
        {
          'id': 1,
          'json': next.encode(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return next;
    });
  }

  Future<bool> insertConversationSummary({
    required DateTime fromAt,
    required DateTime toAt,
    required String summary,
    List<String> keyPoints = const [],
  }) async {
    final normalized = summary.trim();
    if (normalized.isEmpty) return false;
    final db = await database;
    final id = _uuid.v4();
    final inserted = await db.insert(
      'conversation_summaries',
      {
        'id': id,
        'from_at': fromAt.millisecondsSinceEpoch,
        'to_at': toAt.millisecondsSinceEpoch,
        'summary': normalized,
        'key_points': keyPoints.take(12).join('|'),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // sqflite returns 0 for an ignored insert on the unique range index.
    return inserted != 0;
  }

  Future<List<ConversationSummary>> recentConversationSummaries({
    int limit = 4,
  }) async {
    final db = await database;
    final rows = await db.query(
      'conversation_summaries',
      orderBy: 'to_at DESC',
      limit: limit,
    );
    return rows.map(ConversationSummary.fromDb).toList();
  }

  Future<List<ChatMessage>> pendingMessagesForSummary({int limit = 24}) async {
    final summaries = await recentConversationSummaries(limit: 1);
    final after = summaries.isEmpty ? null : summaries.first.toAt;
    return messagesAfter(after, limit: limit);
  }

  Future<void> upsertUnfinishedThread({
    String? id,
    required String title,
    required String detail,
    required double importance,
    String? sourceMessageId,
    String topicKey = '',
  }) async {
    final normalizedTitle = title.trim();
    final normalizedDetail = detail.trim();
    if (normalizedTitle.isEmpty || normalizedDetail.isEmpty) return;
    final db = await database;
    final normalizedTopic = topicKey.trim().toLowerCase();
    final lookupByTopic = id == null && normalizedTopic.isNotEmpty;
    final existing = await db.query(
      'unfinished_threads',
      where: id != null
          ? 'id = ? AND status = ?'
          : lookupByTopic
              ? 'topic_key = ? AND status = ?'
              : 'title = ? AND status = ?',
      whereArgs: [id ?? (lookupByTopic ? normalizedTopic : normalizedTitle), 'active'],
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing.isNotEmpty) {
      final existingSource = existing.first['source_message_id'] as String?;
      final existingTitle = (existing.first['title'] as String? ?? '').trim();
      final existingDetail = (existing.first['detail'] as String? ?? '').trim();
      final existingTopic = (existing.first['topic_key'] as String? ?? '').trim().toLowerCase();
      if (sourceMessageId != null &&
          sourceMessageId.isNotEmpty &&
          existingSource == sourceMessageId &&
          existingTitle == normalizedTitle &&
          existingDetail == normalizedDetail &&
          (normalizedTopic.isEmpty || existingTopic == normalizedTopic)) {
        return;
      }
      await db.update(
        'unfinished_threads',
        {
          'title': normalizedTitle,
          'detail': normalizedDetail,
          'importance': importance.clamp(0.0, 1.0),
          'source_message_id': sourceMessageId ?? existing.first['source_message_id'],
          if (normalizedTopic.isNotEmpty) 'topic_key': normalizedTopic,
          // A real conversation update means the topic is already active again;
          // cancel any previously scheduled one-shot deferred follow-up.
          'followup_due_at': null,
          'followup_seeded_at': null,
          'followup_run_token': '',
          'followup_claimed_at': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }
    await db.insert('unfinished_threads', {
      'id': id ?? _uuid.v4(),
      'title': normalizedTitle,
      'detail': normalizedDetail,
      'importance': importance.clamp(0.0, 1.0),
      'status': 'active',
      'source_message_id': sourceMessageId,
      'topic_key': normalizedTopic,
      'followup_due_at': null,
      'followup_seeded_at': null,
      'followup_run_token': '',
      'followup_claimed_at': null,
      'followup_count': 0,
      'last_followup_at': null,
      'retired_at': null,
      'retire_reason': '',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> resolveUnfinishedThread(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'status': 'resolved',
        'followup_due_at': null,
        'followup_seeded_at': null,
        'followup_run_token': '',
        'followup_claimed_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'title = ? AND status = ?',
      whereArgs: [normalized, 'active'],
    );
  }

  Future<void> resolveUnfinishedThreadById(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'status': 'resolved',
        'followup_due_at': null,
        'followup_seeded_at': null,
        'followup_run_token': '',
        'followup_claimed_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [normalized, 'active'],
    );
  }

  Future<List<UnfinishedThread>> activeUnfinishedThreads({int limit = 8}) async {
    final db = await database;
    final rows = await db.query(
      'unfinished_threads',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'importance DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(UnfinishedThread.fromDb).toList();
  }

  Future<UnfinishedThread?> unfinishedThreadById(String id) async {
    final db = await database;
    final rows = await db.query('unfinished_threads', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : UnfinishedThread.fromDb(rows.first);
  }

  Future<UnfinishedThread?> activeUnfinishedThreadByTopic(String topicKey) async {
    final key = topicKey.trim().toLowerCase();
    if (key.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'unfinished_threads',
      where: 'status = ? AND topic_key = ?',
      whereArgs: ['active', key],
      orderBy: 'importance DESC, updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : UnfinishedThread.fromDb(rows.first);
  }

  Future<void> touchUnfinishedThread(String id) async {
    final db = await database;
    await db.update(
      'unfinished_threads',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'active'],
    );
  }

  Future<void> scheduleUnfinishedThreadFollowup(
    String id, {
    required DateTime dueAt,
  }) async {
    final maxFollowups =
        int.tryParse(await getSetting('max_deferred_followups') ?? '') ?? 1;
    if (maxFollowups <= 0) return;
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'followup_due_at': dueAt.millisecondsSinceEpoch,
        'followup_seeded_at': null,
        'followup_run_token': '',
        'followup_claimed_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ? AND followup_count < ?',
      whereArgs: [id, 'active', maxFollowups.clamp(1, 3).toInt()],
    );
  }

  Future<void> clearUnfinishedThreadFollowup(String id) async {
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'followup_due_at': null,
        'followup_seeded_at': null,
        'followup_run_token': '',
        'followup_claimed_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> claimUnfinishedThreadFollowupSeed(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleBefore = now - const Duration(minutes: 5).inMilliseconds;
    final token = _uuid.v4();
    final changed = await db.update(
      'unfinished_threads',
      {
        'followup_run_token': token,
        'followup_claimed_at': now,
        'updated_at': now,
      },
      where:
          "id = ? AND status = 'active' AND followup_due_at IS NOT NULL AND followup_due_at <= ? AND followup_seeded_at IS NULL AND (followup_run_token = '' OR followup_claimed_at IS NULL OR followup_claimed_at < ?)",
      whereArgs: [id, now, staleBefore],
    );
    return changed == 1 ? token : null;
  }

  Future<bool> ownsUnfinishedThreadFollowupSeed(String id, String token) async {
    if (token.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      'unfinished_threads',
      columns: ['id'],
      where:
          "id = ? AND status = 'active' AND followup_seeded_at IS NULL AND followup_run_token = ?",
      whereArgs: [id, token],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> applyDeferredFollowupSeedAtomic({
    required String threadId,
    required String claimToken,
    required String topicKey,
    required String thoughtText,
    required DriveKey thoughtDrive,
    required double thoughtStrength,
    required Map<DriveKey, double> pulses,
  }) async {
    if (claimToken.isEmpty || topicKey.trim().isEmpty) return false;
    final db = await database;
    return db.transaction<bool>((txn) async {
      final threads = await txn.query(
        'unfinished_threads',
        where:
            "id = ? AND status = 'active' AND followup_seeded_at IS NULL AND followup_run_token = ?",
        whereArgs: [threadId, claimToken],
        limit: 1,
      );
      if (threads.isEmpty) return false;
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final stateRows = await txn.query('desire_state', where: 'id = 1', limit: 1);
      final snapshot = stateRows.isEmpty
          ? DesireSnapshot()
          : DesireSnapshot.decode(stateRows.first['json'] as String);
      final drives = Map<DriveKey, double>.from(snapshot.drives);
      for (final entry in pulses.entries) {
        final anchor = snapshot.baselines[entry.key] ??
            DesireSnapshot.defaultBaselines()[entry.key] ??
            0.2;
        drives[entry.key] = ((drives[entry.key] ?? anchor) +
                entry.value.clamp(-0.35, 0.35).toDouble())
            .clamp(0.0, 1.0)
            .toDouble();
      }
      await txn.insert(
        'desire_state',
        {
          'id': 1,
          'json': snapshot.copyWith(drives: drives).encode(),
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final normalizedTopic = topicKey.trim().toLowerCase();
      final matches = await txn.query(
        'thoughts',
        where: 'drive_key = ? AND topic_key = ?',
        whereArgs: [thoughtDrive.name, normalizedTopic],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (matches.isEmpty) {
        await txn.insert('thoughts', {
          'id': _uuid.v4(),
          'text': thoughtText.trim(),
          'drive_key': thoughtDrive.name,
          'kind': thoughtStrength >= 0.68 ? 'fixation' : 'flit',
          'strength': thoughtStrength.clamp(0.08, 0.70),
          'born_at': nowMs,
          'updated_at': nowMs,
          'fed_count': 1,
          'source': 'deferred_followup',
          'last_fed_at': nowMs,
          'lifecycle_state': thoughtStrength >= 0.68 ? 'fixation' : 'active',
          'action_count': 0,
          'last_acted_at': null,
          'last_satisfied_at': null,
          'last_resurfaced_at': null,
          'resurfaced_count': 0,
          'residual_strength': 0.0,
          'last_outbound_message_id': null,
          'topic_key': normalizedTopic,
          'merged_count': 0,
          'last_merged_at': null,
          'snoozed_until': null,
        });
      } else {
        final thought = CompanionThought.fromDb(matches.first);
        final fed = thought.fedCount + 1;
        final nextStrength =
            (thought.strength * 0.88 + thoughtStrength * 0.55 + 0.06)
                .clamp(0.0, 1.0)
                .toDouble();
        final fixation = fed >= 3 || nextStrength >= 0.68;
        await txn.update(
          'thoughts',
          {
            'strength': nextStrength,
            'fed_count': fed,
            'kind': fixation ? 'fixation' : thought.kind,
            'lifecycle_state': fixation ? 'fixation' : 'active',
            'last_fed_at': nowMs,
            'updated_at': nowMs,
          },
          where: 'id = ?',
          whereArgs: [thought.id],
        );
      }

      final changed = await txn.update(
        'unfinished_threads',
        {
          'followup_seeded_at': nowMs,
          'followup_run_token': '',
          'followup_claimed_at': null,
          'updated_at': nowMs,
        },
        where:
            "id = ? AND status = 'active' AND followup_seeded_at IS NULL AND followup_run_token = ?",
        whereArgs: [threadId, claimToken],
      );
      if (changed != 1) throw StateError('deferred_followup_claim_lost');
      return true;
    });
  }

  Future<bool> completeUnfinishedThreadFollowupSeed(String id, String token) async {
    if (token.isEmpty) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await db.update(
      'unfinished_threads',
      {
        'followup_seeded_at': now,
        'followup_run_token': '',
        'followup_claimed_at': null,
        'updated_at': now,
      },
      where:
          "id = ? AND status = 'active' AND followup_seeded_at IS NULL AND followup_run_token = ?",
      whereArgs: [id, token],
    );
    return changed == 1;
  }

  Future<void> releaseUnfinishedThreadFollowupSeed(String id, String token) async {
    if (token.isEmpty) return;
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'followup_run_token': '',
        'followup_claimed_at': null,
      },
      where:
          "id = ? AND followup_seeded_at IS NULL AND followup_run_token = ?",
      whereArgs: [id, token],
    );
  }

  Future<void> markUnfinishedThreadFollowupSent(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      '''
      UPDATE unfinished_threads
      SET followup_count = followup_count + 1,
          last_followup_at = ?,
          followup_due_at = NULL,
          followup_seeded_at = NULL,
          followup_run_token = '',
          followup_claimed_at = NULL,
          updated_at = ?
      WHERE id = ? AND status = 'active' AND followup_due_at IS NOT NULL AND followup_due_at <= ?
      ''',
      [now, now, id, now],
    );
  }

  Future<List<UnfinishedThread>> dueUnfinishedThreadFollowups({
    DateTime? now,
    int limit = 4,
  }) async {
    final maxFollowups =
        int.tryParse(await getSetting('max_deferred_followups') ?? '') ?? 1;
    if (maxFollowups <= 0) return const [];
    final db = await database;
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.query(
      'unfinished_threads',
      where: "status = ? AND followup_due_at IS NOT NULL AND followup_due_at <= ? AND followup_seeded_at IS NULL AND followup_count < ? AND (followup_run_token = '' OR followup_claimed_at IS NULL OR followup_claimed_at < ?)",
      whereArgs: [
        'active',
        at,
        maxFollowups.clamp(1, 3).toInt(),
        at - const Duration(minutes: 5).inMilliseconds,
      ],
      orderBy: 'importance DESC, followup_due_at ASC',
      limit: limit,
    );
    return rows.map(UnfinishedThread.fromDb).toList();
  }

  Future<List<UnfinishedThread>> retireStaleUnfinishedThreads({
    DateTime? now,
  }) async {
    final db = await database;
    final at = now ?? DateTime.now();
    final rows = await db.query(
      'unfinished_threads',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'updated_at ASC',
    );
    final retired = <UnfinishedThread>[];
    for (final row in rows) {
      final thread = UnfinishedThread.fromDb(row);
      final age = at.difference(thread.updatedAt);
      String? reason;
      if (thread.importance < 0.55 && age >= const Duration(days: 14)) {
        reason = 'low_importance_stale_14d';
      } else if (thread.importance < 0.75 && age >= const Duration(days: 45)) {
        reason = 'stale_45d';
      } else if (thread.importance < 0.92 && age >= const Duration(days: 120)) {
        reason = 'stale_120d';
      }
      if (reason == null) continue;
      final changed = await db.update(
        'unfinished_threads',
        {
          'status': 'retired',
          'followup_due_at': null,
          'followup_seeded_at': null,
          'followup_run_token': '',
          'followup_claimed_at': null,
          'retired_at': at.millisecondsSinceEpoch,
          'retire_reason': reason,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ? AND updated_at = ?',
        whereArgs: [thread.id, 'active', thread.updatedAt.millisecondsSinceEpoch],
      );
      if (changed == 1) retired.add(thread);
    }
    return retired;
  }

  Future<void> closeUnfinishedThreadById(String id, {String status = 'closed'}) async {
    final normalized = status == 'dismissed' ? 'dismissed' : 'closed';
    final db = await database;
    await db.update(
      'unfinished_threads',
      {
        'status': normalized,
        'followup_due_at': null,
        'followup_seeded_at': null,
        'followup_run_token': '',
        'followup_claimed_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'active'],
    );
  }

  Future<void> addDeviceEvent({
    required String source,
    required String eventType,
    String? appPackage,
    String? summary,
    Map<String, Object?> metadata = const {},
    DateTime? occurredAt,
  }) async {
    final db = await database;
    await db.insert('device_events', {
      'id': _uuid.v4(),
      'device_id': await ensureDeviceId(),
      'source': source,
      'event_type': eventType,
      'app_package': appPackage,
      'summary': summary,
      'occurred_at': (occurredAt ?? DateTime.now()).millisecondsSinceEpoch,
      'metadata_json': jsonEncode(metadata),
    });
  }

  Future<List<Map<String, Object?>>> recentDeviceEvents({
    int minutes = 180,
    int limit = 80,
  }) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    return db.query(
      'device_events',
      where: 'occurred_at >= ?',
      whereArgs: [since],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> deviceEventsAfter(
    DateTime after, {
    int limit = 160,
  }) async {
    final db = await database;
    return db.query(
      'device_events',
      where: 'occurred_at > ?',
      whereArgs: [after.millisecondsSinceEpoch],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> recentDeviceStateEvents({
    int minutes = 720,
    int limit = 40,
  }) async {
    final db = await database;
    final since = DateTime.now()
        .subtract(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    return db.query(
      'device_events',
      where: "source = 'system' AND event_type IN ('screen_on','screen_off','user_present','power_connected','power_disconnected') AND occurred_at >= ?",
      whereArgs: [since],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
  }

  /// Atomically reconciles the current interpreted awareness set.
  ///
  /// The transaction re-checks Active Brain/transfer lock so a phone/tablet
  /// takeover cannot race a perception capture that started just before the
  /// freeze. One row per dedupe_key suppresses noisy duplicate observations.
  Future<List<AwarenessObservation>> syncAwarenessObservations({
    required List<AwarenessObservationDraft> drafts,
    required Set<String> managedKeys,
    DateTime? now,
  }) async {
    final db = await database;
    final instant = now ?? DateTime.now();
    final nowMs = instant.millisecondsSinceEpoch;
    return db.transaction<List<AwarenessObservation>>((txn) async {
      Future<String?> setting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['value'] as String?;
      }

      if (await setting('transfer_lock') == '1' || await setting('active_brain') == '0') {
        return const [];
      }
      var deviceId = await setting('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _uuid.v4();
        await txn.insert(
          'settings',
          {'key': 'device_id', 'value': deviceId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final incomingKeys = drafts.map((e) => e.dedupeKey).toSet();
      final toExpire = managedKeys.difference(incomingKeys);
      for (final key in toExpire) {
        await txn.rawUpdate('''
          UPDATE awareness_observations
          SET expires_at = CASE WHEN expires_at > ? THEN ? ELSE expires_at END,
              updated_at = ?
          WHERE dedupe_key = ? AND expires_at > ?
        ''', [nowMs, nowMs, nowMs, key, nowMs]);
      }

      final result = <AwarenessObservation>[];
      for (final draft in drafts) {
        final existing = await txn.query(
          'awareness_observations',
          where: 'dedupe_key = ?',
          whereArgs: [draft.dedupeKey],
          limit: 1,
        );
        final values = <String, Object?>{
          'device_id': deviceId,
          'kind': draft.kind,
          'summary': draft.summary.trim(),
          'confidence': draft.confidence.clamp(0.0, 1.0).toDouble(),
          'window_start': draft.windowStart.millisecondsSinceEpoch,
          'window_end': draft.windowEnd.millisecondsSinceEpoch,
          'expires_at': draft.expiresAt.millisecondsSinceEpoch,
          'source_fingerprint': draft.sourceFingerprint,
          'metadata_json': jsonEncode(draft.metadata),
          'updated_at': nowMs,
        };
        String id;
        int createdAt;
        if (existing.isEmpty) {
          id = _uuid.v4();
          createdAt = nowMs;
          await txn.insert('awareness_observations', {
            'id': id,
            'dedupe_key': draft.dedupeKey,
            'created_at': createdAt,
            ...values,
          });
        } else {
          id = existing.first['id'] as String;
          createdAt = existing.first['created_at'] as int? ?? nowMs;
          await txn.update(
            'awareness_observations',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        result.add(AwarenessObservation(
          id: id,
          kind: draft.kind,
          summary: draft.summary.trim(),
          confidence: draft.confidence.clamp(0.0, 1.0).toDouble(),
          windowStart: draft.windowStart,
          windowEnd: draft.windowEnd,
          expiresAt: draft.expiresAt,
          dedupeKey: draft.dedupeKey,
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
          updatedAt: instant,
          deviceId: deviceId,
          sourceFingerprint: draft.sourceFingerprint,
          metadata: draft.metadata,
        ));
      }
      return result;
    });
  }

  Future<List<AwarenessObservation>> activeAwarenessObservations({
    int limit = 6,
    double minConfidence = 0.45,
    DateTime? now,
  }) async {
    final db = await database;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT * FROM awareness_observations
      WHERE expires_at > ? AND confidence >= ?
      ORDER BY CASE kind
        WHEN 'screen_state' THEN 0
        WHEN 'current_activity' THEN 1
        WHEN 'availability' THEN 2
        WHEN 'recent_activity' THEN 3
        WHEN 'app_switching' THEN 4
        WHEN 'notification_pressure' THEN 5
        ELSE 9
      END ASC,
      confidence DESC,
      updated_at DESC
      LIMIT ?
    ''', [nowMs, minConfidence, limit.clamp(1, 20).toInt()]);
    return rows.map(AwarenessObservation.fromDb).toList();
  }

  Future<List<AwarenessObservation>> awarenessObservationsBetween(
    DateTime start,
    DateTime end, {
    int limit = 12,
    double minConfidence = 0.62,
  }) async {
    final db = await database;
    final rows = await db.query(
      'awareness_observations',
      where: 'updated_at >= ? AND updated_at < ? AND confidence >= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        minConfidence,
      ],
      orderBy: 'confidence DESC, updated_at DESC',
      limit: limit.clamp(1, 40).toInt(),
    );
    return rows.map(AwarenessObservation.fromDb).toList();
  }

  Future<int> messageCountBetween(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM messages WHERE created_at >= ? AND created_at < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<double?> latestPerceptionBusyScore({
    Duration maxAge = const Duration(minutes: 15),
  }) async {
    final db = await database;
    final since = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    final rows = await db.query(
      'perception_snapshots',
      columns: ['busy_score'],
      where: 'occurred_at >= ?',
      whereArgs: [since],
      orderBy: 'occurred_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.first['busy_score'] as num?)?.toDouble();
  }

  Future<PerceptionSnapshot> insertPerceptionSnapshot({
    required String summary,
    String? currentPackage,
    String? deviceLabel,
    double busyScore = 0,
    int notificationCount = 0,
    Map<String, Object?> metadata = const {},
    DateTime? occurredAt,
  }) async {
    final db = await database;
    final snapshot = PerceptionSnapshot(
      id: _uuid.v4(),
      summary: summary.trim(),
      occurredAt: occurredAt ?? DateTime.now(),
      deviceId: await ensureDeviceId(),
      deviceLabel: deviceLabel,
      currentPackage: currentPackage,
      busyScore: busyScore.clamp(0.0, 1.0).toDouble(),
      notificationCount: notificationCount.clamp(0, 999).toInt(),
      metadata: metadata,
    );
    await db.insert('perception_snapshots', {
      'id': snapshot.id,
      'summary': snapshot.summary,
      'device_id': snapshot.deviceId,
      'device_label': snapshot.deviceLabel,
      'current_package': snapshot.currentPackage,
      'busy_score': snapshot.busyScore,
      'notification_count': snapshot.notificationCount,
      'metadata_json': jsonEncode(snapshot.metadata),
      'occurred_at': snapshot.occurredAt.millisecondsSinceEpoch,
    });
    return snapshot;
  }

  Future<List<PerceptionSnapshot>> recentPerceptionSnapshots({int limit = 8}) async {
    final db = await database;
    final rows = await db.query(
      'perception_snapshots',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(PerceptionSnapshot.fromDb).toList();
  }

  Future<void> addRelationshipEvent({
    required String kind,
    required String summary,
    double intensity = 0.5,
    double valence = 0.0,
    String? sourceMessageId,
    Map<String, Object?> metadata = const {},
  }) async {
    final normalized = summary.trim();
    if (normalized.isEmpty) return;
    const allowed = {
      'closeness', 'trust', 'conflict', 'repair', 'promise', 'milestone',
      'intimacy', 'boundary', 'roleplay', 'support', 'shared_discovery'
    };
    if (!allowed.contains(kind)) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (sourceMessageId != null && sourceMessageId.isNotEmpty) {
      final sameTurn = await db.query(
        'relationship_events',
        columns: ['id'],
        where: 'source_message_id = ? AND kind = ? AND summary = ?',
        whereArgs: [sourceMessageId, kind, normalized],
        limit: 1,
      );
      // Post-turn extraction is retryable. Re-applying the same proposal for
      // the same assistant turn must be idempotent rather than reinforcing it.
      if (sameTurn.isNotEmpty) return;
    }
    final duplicate = await db.query(
      'relationship_events',
      where: 'kind = ? AND summary = ? AND created_at >= ?',
      whereArgs: [kind, normalized, now - const Duration(days: 14).inMilliseconds],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      final oldIntensity = (duplicate.first['intensity'] as num?)?.toDouble() ?? 0.5;
      final oldValence = (duplicate.first['valence'] as num?)?.toDouble() ?? 0.0;
      await db.update(
        'relationship_events',
        {
          'intensity': (oldIntensity * 0.75 + intensity * 0.35).clamp(0.0, 1.0),
          'valence': (oldValence * 0.75 + valence * 0.35).clamp(-1.0, 1.0),
          'source_message_id': sourceMessageId ?? duplicate.first['source_message_id'],
          'metadata_json': jsonEncode(metadata),
          'created_at': now,
          'internalized_at': null,
        },
        where: 'id = ?',
        whereArgs: [duplicate.first['id']],
      );
      return;
    }
    await db.insert('relationship_events', {
      'id': _uuid.v4(),
      'kind': kind,
      'summary': normalized,
      'intensity': intensity.clamp(0.0, 1.0),
      'valence': valence.clamp(-1.0, 1.0),
      'source_message_id': sourceMessageId,
      'metadata_json': jsonEncode(metadata),
      'created_at': now,
      'internalized_at': null,
    });
  }

  Future<List<RelationshipEvent>> recentRelationshipEvents({int limit = 12}) async {
    final db = await database;
    final rows = await db.query(
      'relationship_events',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(RelationshipEvent.fromDb).toList();
  }

  Future<List<RelationshipEvent>> relationshipEventsBetween(
    DateTime start,
    DateTime end, {
    int limit = 24,
  }) async {
    final db = await database;
    final rows = await db.query(
      'relationship_events',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
      limit: limit.clamp(1, 80).toInt(),
    );
    return rows.map(RelationshipEvent.fromDb).toList();
  }

  Future<List<RelationshipEvent>> pendingRelationshipEvents({int limit = 16}) async {
    final db = await database;
    final rows = await db.query(
      'relationship_events',
      where: 'internalized_at IS NULL',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(RelationshipEvent.fromDb).toList();
  }

  Future<void> markRelationshipEventInternalized(String id, {DateTime? at}) async {
    final db = await database;
    await db.update(
      'relationship_events',
      {'internalized_at': (at ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Exactly-once relationship assimilation. Desire changes, the durable
  /// relationship-derived Thought and `internalized_at` are committed in one
  /// SQLite transaction, so a frozen worker cannot replay the same emotional
  /// pulse after another engine takes over.
  Future<bool> assimilateRelationshipEventAtomic({
    required RelationshipEvent event,
    required Map<DriveKey, double> pulses,
    required double baselineLearning,
    required DriveKey thoughtDrive,
    required String thoughtText,
    required double thoughtStrength,
  }) async {
    final db = await database;
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'relationship_events',
        where: 'id = ? AND internalized_at IS NULL',
        whereArgs: [event.id],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final currentEvent = RelationshipEvent.fromDb(rows.first);
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final stateRows = await txn.query('desire_state', where: 'id = 1', limit: 1);
      final snapshot = stateRows.isEmpty
          ? DesireSnapshot()
          : DesireSnapshot.decode(stateRows.first['json'] as String);
      final drives = Map<DriveKey, double>.from(snapshot.drives);
      final baselines = Map<DriveKey, double>.from(snapshot.baselines);
      final anchors = DesireSnapshot.defaultBaselines();
      for (final entry in pulses.entries) {
        final drive = entry.key;
        final delta = entry.value.clamp(-0.35, 0.35).toDouble();
        final anchor = anchors[drive] ?? 0.2;
        drives[drive] = ((drives[drive] ?? anchor) + delta)
            .clamp(0.0, 1.0)
            .toDouble();
        final currentBase = baselines[drive] ?? anchor;
        baselines[drive] = (currentBase + delta * baselineLearning)
            .clamp(max(0.02, anchor - 0.10), min(0.92, anchor + 0.10))
            .toDouble();
      }
      final nextSnapshot = snapshot.copyWith(drives: drives, baselines: baselines);
      await txn.insert(
        'desire_state',
        {'id': 1, 'json': nextSnapshot.encode(), 'updated_at': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final topicKey = (currentEvent.metadata['topic_key'] as String? ?? '')
          .trim()
          .toLowerCase();
      List<Map<String, Object?>> matches;
      if (topicKey.isNotEmpty) {
        matches = await txn.query(
          'thoughts',
          where: 'drive_key = ? AND topic_key = ?',
          whereArgs: [thoughtDrive.name, topicKey],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
      } else {
        matches = await txn.query(
          'thoughts',
          where: 'drive_key = ? AND source = ? AND text = ?',
          whereArgs: [thoughtDrive.name, 'relationship/${currentEvent.kind}', thoughtText],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
      }
      if (matches.isEmpty) {
        await txn.insert('thoughts', {
          'id': _uuid.v4(),
          'text': thoughtText.trim(),
          'drive_key': thoughtDrive.name,
          'kind': thoughtStrength >= 0.68 ? 'fixation' : 'flit',
          'strength': thoughtStrength.clamp(0.08, 0.70),
          'born_at': nowMs,
          'updated_at': nowMs,
          'fed_count': 1,
          'source': 'relationship/${currentEvent.kind}',
          'last_fed_at': nowMs,
          'lifecycle_state': thoughtStrength >= 0.68 ? 'fixation' : 'active',
          'action_count': 0,
          'last_acted_at': null,
          'last_satisfied_at': null,
          'last_resurfaced_at': null,
          'resurfaced_count': 0,
          'residual_strength': 0.0,
          'last_outbound_message_id': null,
          'topic_key': topicKey,
          'merged_count': 0,
          'last_merged_at': null,
          'snoozed_until': null,
        });
      } else {
        final thought = CompanionThought.fromDb(matches.first);
        final fed = thought.fedCount + 1;
        final nextStrength =
            (thought.strength * 0.88 + thoughtStrength * 0.55 + 0.06)
                .clamp(0.0, 1.0)
                .toDouble();
        final fixation = fed >= 3 || nextStrength >= 0.68;
        await txn.update(
          'thoughts',
          {
            'strength': nextStrength,
            'fed_count': fed,
            'kind': fixation ? 'fixation' : thought.kind,
            'lifecycle_state': fixation ? 'fixation' : 'active',
            'last_fed_at': nowMs,
            'updated_at': nowMs,
            if (thought.topicKey.isEmpty && topicKey.isNotEmpty) 'topic_key': topicKey,
          },
          where: 'id = ?',
          whereArgs: [thought.id],
        );
      }

      final changed = await txn.update(
        'relationship_events',
        {'internalized_at': nowMs},
        where: 'id = ? AND internalized_at IS NULL',
        whereArgs: [currentEvent.id],
      );
      if (changed != 1) {
        throw StateError('relationship_assimilation_ownership_lost');
      }
      return true;
    });
  }

  Future<void> updateMemoryRetention({
    required String id,
    required double retentionScore,
    required DateTime checkedAt,
    String? status,
  }) async {
    final db = await database;
    await db.update(
      'memory_items',
      {
        'retention_score': retentionScore.clamp(0.0, 1.0),
        'retention_checked_at': checkedAt.millisecondsSinceEpoch,
        if (status != null) 'status': status,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Optimistic retention update used by long-running memory maintenance.
  /// If another engine already refreshed/recalled this memory, the stale
  /// maintenance pass is discarded instead of overwriting newer retention.
  Future<bool> updateMemoryRetentionIfUnchanged({
    required String id,
    required DateTime expectedCheckedAt,
    required double retentionScore,
    required DateTime checkedAt,
    String? status,
  }) async {
    final db = await database;
    final changed = await db.update(
      'memory_items',
      {
        'retention_score': retentionScore.clamp(0.0, 1.0),
        'retention_checked_at': checkedAt.millisecondsSinceEpoch,
        if (status != null) 'status': status,
      },
      where: 'id = ? AND COALESCE(retention_checked_at, updated_at) = ?',
      whereArgs: [id, expectedCheckedAt.millisecondsSinceEpoch],
    );
    return changed == 1;
  }

  Future<List<MemoryItem>> memoryMaintenanceCandidates({int limit = 500}) async {
    final db = await database;
    final rows = await db.query(
      'memory_items',
      where: 'status = ? AND pinned = 0',
      whereArgs: ['active'],
      orderBy: 'retention_checked_at ASC, updated_at ASC',
      limit: limit,
    );
    return rows.map(MemoryItem.fromDb).toList();
  }

  Future<void> insertReferenceItem({
    required String sourceName,
    required String section,
    required String title,
    required String content,
    List<String> tags = const [],
    double weight = 0.55,
    String? documentId,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    final duplicate = await db.query(
      'reference_items',
      where: 'source_name = ? AND content = ?',
      whereArgs: [sourceName.trim(), normalized],
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (duplicate.isNotEmpty) {
      await db.update(
        'reference_items',
        {
          if (documentId != null) 'document_id': documentId,
          'section': section,
          'title': title.trim(),
          'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).take(12).join('|'),
          'weight': weight.clamp(0.05, 1.0),
          'enabled': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [duplicate.first['id']],
      );
      return;
    }
    await db.insert('reference_items', {
      'id': _uuid.v4(),
      'document_id': documentId,
      'source_name': sourceName.trim().isEmpty ? '未命名资料' : sourceName.trim(),
      'section': section,
      'title': title.trim(),
      'content': normalized,
      'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).take(12).join('|'),
      'weight': weight.clamp(0.05, 1.0),
      'enabled': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<ReferenceItem>> listReferenceItems({int limit = 400}) async {
    final db = await database;
    final rows = await db.query(
      'reference_items',
      orderBy: 'enabled DESC, weight DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(ReferenceItem.fromDb).toList();
  }

  Future<List<ReferenceItem>> relevantReferenceItems(String query, {int limit = 6}) async {
    if ((await getSetting('reference_library_enabled')) == '0') return const [];
    final db = await database;
    final rows = await db.query(
      'reference_items',
      where: 'enabled = 1',
      orderBy: 'weight DESC, updated_at DESC',
      limit: 220,
    );
    final q = _tokens(query);
    final scored = <({ReferenceItem item, double score})>[];
    for (final row in rows) {
      final item = ReferenceItem.fromDb(row);
      final tokens = _tokens('${item.title} ${item.content} ${item.tags.join(' ')}');
      final overlap = q.isEmpty ? 0.0 : q.where(tokens.contains).length / q.length;
      final score = item.weight * 0.52 + overlap * 0.48;
      // Reference material is deliberately on-demand. Even a speaking-style
      // item does not become a permanent per-turn character card.
      if (overlap > 0 || item.weight >= 0.82) {
        scored.add((item: item, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.item).toList(growable: false);
  }

  Future<void> setReferenceEnabled(String id, bool enabled) async {
    final db = await database;
    await db.update(
      'reference_items',
      {'enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReferenceItem(String id) async {
    final db = await database;
    await db.delete('reference_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearReferenceSource(String sourceName) async {
    final db = await database;
    await db.delete('reference_items', where: 'source_name = ?', whereArgs: [sourceName]);
  }

  Future<String> upsertReferenceDocument({
    String? id,
    required String name,
    required String kind,
    required String rawContent,
    List<String> aliases = const [],
    bool enabled = true,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedName = name.trim().isEmpty ? '未命名资料' : name.trim();
    final normalizedAliases = aliases
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(16)
        .join('|');

    if (id != null && id.trim().isNotEmpty) {
      final changed = await db.update(
        'reference_documents',
        {
          'name': normalizedName,
          'kind': kind,
          'aliases': normalizedAliases,
          'raw_content': rawContent.trim(),
          'enabled': enabled ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 1) return id;
    }

    final documentId = id ?? _uuid.v4();
    await db.insert('reference_documents', {
      'id': documentId,
      'name': normalizedName,
      'kind': kind,
      'aliases': normalizedAliases,
      'raw_content': rawContent.trim(),
      'enabled': enabled ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
    return documentId;
  }

  Future<String> saveReferenceDocumentWithChunks({
    String? id,
    required String name,
    required String kind,
    required String rawContent,
    List<String> aliases = const [],
    bool enabled = true,
    required List<Map<String, Object?>> chunks,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedName = name.trim().isEmpty ? '未命名资料' : name.trim();
    final normalizedAliases = aliases
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(16)
        .join('|');
    final documentId = id ?? _uuid.v4();

    return db.transaction((txn) async {
      var updated = 0;
      if (id != null && id.trim().isNotEmpty) {
        updated = await txn.update(
          'reference_documents',
          {
            'name': normalizedName,
            'kind': kind,
            'aliases': normalizedAliases,
            'raw_content': rawContent.trim(),
            'enabled': enabled ? 1 : 0,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      if (updated != 1) {
        await txn.insert('reference_documents', {
          'id': documentId,
          'name': normalizedName,
          'kind': kind,
          'aliases': normalizedAliases,
          'raw_content': rawContent.trim(),
          'enabled': enabled ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      }

      await txn.delete(
        'reference_items',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      for (final chunk in chunks) {
        final content = (chunk['content'] as String? ?? '').trim();
        if (content.isEmpty) continue;
        await txn.insert('reference_items', {
          'id': _uuid.v4(),
          'document_id': documentId,
          'source_name': normalizedName,
          'section': chunk['section'] as String? ?? kind,
          'title': chunk['title'] as String? ?? '',
          'content': content,
          'tags': chunk['tags'] as String? ?? '',
          'weight': (chunk['weight'] as num?)?.toDouble() ?? 0.58,
          'enabled': enabled ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      }
      return documentId;
    });
  }

  Future<ReferenceDocument?> referenceDocumentById(String id) async {
    final db = await database;
    final rows = await db.query(
      'reference_documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ReferenceDocument.fromDb(rows.first);
  }

  Future<List<ReferenceDocument>> listReferenceDocuments({int limit = 100}) async {
    final db = await database;
    final rows = await db.query('reference_documents', orderBy: 'enabled DESC, updated_at DESC', limit: limit);
    return rows.map(ReferenceDocument.fromDb).toList();
  }

  Future<List<ReferenceItem>> referenceItemsForDocument(String documentId) async {
    final db = await database;
    final rows = await db.query(
      'reference_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ReferenceItem.fromDb).toList();
  }

  Future<void> replaceDocumentChunks(
    String documentId, {
    required String sourceName,
    required List<Map<String, Object?>> chunks,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final documentRows = await txn.query(
        'reference_documents',
        columns: const ['enabled'],
        where: 'id = ?',
        whereArgs: [documentId],
        limit: 1,
      );
      if (documentRows.isEmpty) {
        throw StateError('Reference document does not exist: $documentId');
      }
      final documentEnabled = (documentRows.first['enabled'] as int? ?? 1) == 1;
      await txn.delete('reference_items', where: 'document_id = ?', whereArgs: [documentId]);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final chunk in chunks) {
        final content = (chunk['content'] as String? ?? '').trim();
        if (content.isEmpty) continue;
        await txn.insert('reference_items', {
          'id': _uuid.v4(),
          'document_id': documentId,
          'source_name': sourceName,
          'section': chunk['section'] as String? ?? 'character',
          'title': chunk['title'] as String? ?? '',
          'content': content,
          'tags': chunk['tags'] as String? ?? '',
          'weight': (chunk['weight'] as num?)?.toDouble() ?? 0.58,
          'enabled': documentEnabled ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> setReferenceDocumentEnabled(String id, bool enabled) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'reference_documents',
        {'enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'reference_items',
        {'enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'document_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteReferenceDocument(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reference_items', where: 'document_id = ?', whereArgs: [id]);
      await txn.delete('reference_documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<RuleLayer>> listRuleLayers() async {
    final db = await database;
    await _seedRuleLayers(db);
    final rows = await db.query('rule_layers', orderBy: 'key ASC');
    return rows.map(RuleLayer.fromDb).toList();
  }

  Future<void> updateRuleLayer(String key, {String? content, bool? enabled}) async {
    final db = await database;
    if (enabled == false) {
      final rows = await db.query(
        'rule_layers',
        columns: const ['locked'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty && (rows.first['locked'] as int? ?? 0) == 1) {
        return;
      }
    }
    await db.update('rule_layers', {
      if (content != null) 'content': content,
      if (enabled != null) 'enabled': enabled ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'key = ?', whereArgs: [key]);
  }

  Future<void> resetRuleLayer(String key) async {
    final match = defaultRuleLayers.where((e) => e.key == key);
    if (match.isEmpty) return;
    final layer = match.first;
    final db = await database;
    await db.insert('rule_layers', {
      'key': layer.key,
      'title': layer.title,
      'content': layer.content,
      'load_policy': layer.loadPolicy,
      'enabled': 1,
      'locked': layer.locked ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> createProactiveFeedback({
    required String proactiveMessageId,
    String? thoughtId,
    String topicKey = '',
    String? threadId,
    String intentKind = '',
    String deliveryStyle = '',
    required DateTime sentAt,
    String contextHourBucket = '',
    String contextActivity = 'unknown',
    double contextBusy = 0,
  }) async {
    final db = await database;
    await db.insert('proactive_feedback', {
      'id': _uuid.v4(),
      'proactive_message_id': proactiveMessageId,
      'thought_id': thoughtId,
      'topic_key': topicKey.trim().toLowerCase(),
      'thread_id': threadId,
      'intent_kind': intentKind.trim(),
      'delivery_style': deliveryStyle.trim(),
      'sent_at': sentAt.millisecondsSinceEpoch,
      'context_hour_bucket': contextHourBucket.trim(),
      'context_activity': contextActivity.trim().isEmpty ? 'unknown' : contextActivity.trim(),
      'context_busy': contextBusy.clamp(0.0, 1.0).toDouble(),
      'response_bucket': 'pending',
      'user_text_length': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<ProactiveFeedback>> recentProactiveFeedback({int limit = 60}) async {
    final db = await database;
    final rows = await db.query('proactive_feedback', orderBy: 'sent_at DESC', limit: limit);
    return rows.map(ProactiveFeedback.fromDb).toList();
  }

  Future<ProactiveFeedback?> latestPendingProactiveFeedback() async {
    final db = await database;
    final rows = await db.query(
      'proactive_feedback',
      where: 'response_bucket = ?',
      whereArgs: ['pending'],
      orderBy: 'sent_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ProactiveFeedback.fromDb(rows.first);
  }

  Future<void> resolveProactiveFeedback({
    required String id,
    required String userResponseMessageId,
    required int latencySeconds,
    required String responseBucket,
    required int userTextLength,
    required double responseQuality,
  }) async {
    final db = await database;
    await db.update('proactive_feedback', {
      'user_response_message_id': userResponseMessageId,
      'response_latency_seconds': latencySeconds,
      'response_bucket': responseBucket,
      'user_text_length': userTextLength,
      'response_quality': responseQuality.clamp(0.0, 1.0),
      'outcome': 'response_received',
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<ProactiveFeedback?> proactiveFeedbackForUserResponse(String messageId) async {
    final db = await database;
    final rows = await db.query(
      'proactive_feedback',
      where: 'user_response_message_id = ?',
      whereArgs: [messageId],
      orderBy: 'sent_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ProactiveFeedback.fromDb(rows.first);
  }

  Future<List<ProactiveFeedback>> recentProactiveFeedbackByTopic(
    String topicKey, {
    int limit = 20,
  }) async {
    final key = topicKey.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final db = await database;
    final rows = await db.query(
      'proactive_feedback',
      where: 'topic_key = ?',
      whereArgs: [key],
      orderBy: 'sent_at DESC',
      limit: limit,
    );
    return rows.map(ProactiveFeedback.fromDb).toList();
  }


  Future<List<ProactiveFeedback>> recentProactiveFeedbackByIntent(
    String intentKind, {
    int limit = 20,
  }) async {
    final key = intentKind.trim();
    if (key.isEmpty) return const [];
    final db = await database;
    final rows = await db.query(
      'proactive_feedback',
      where: 'intent_kind = ?',
      whereArgs: [key],
      orderBy: 'sent_at DESC',
      limit: limit,
    );
    return rows.map(ProactiveFeedback.fromDb).toList();
  }

  Future<void> finalizeProactiveOutcome({
    required String id,
    required String outcome,
    required double outcomeScore,
    required double timingFit,
    required double topicFit,
  }) async {
    const allowed = {'engaged', 'acknowledged', 'deferred', 'resolved', 'dismissed', 'redirected', 'no_response'};
    final normalized = allowed.contains(outcome) ? outcome : 'acknowledged';
    final db = await database;
    await db.update(
      'proactive_feedback',
      {
        'outcome': normalized,
        'outcome_score': outcomeScore.clamp(0.0, 1.0),
        'timing_fit': timingFit.clamp(-1.0, 1.0).toDouble(),
        'topic_fit': topicFit.clamp(-1.0, 1.0).toDouble(),
        'processed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> expireProactiveFeedback({required DateTime before}) async {
    final db = await database;
    await db.update(
      'proactive_feedback',
      {
        'response_bucket': 'no_response',
        'outcome': 'no_response',
        'outcome_score': 0.0,
        // Silence is weak evidence about timing and no evidence that the topic
        // itself was unwelcome. profile() also down-weights no-response rows.
        'timing_fit': -0.18,
        'topic_fit': 0.0,
        'processed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'response_bucket = ? AND sent_at < ?',
      whereArgs: ['pending', before.millisecondsSinceEpoch],
    );
  }

  Future<void> enqueuePostTurnJob({
    required String userMessageId,
    required String assistantMessageId,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'post_turn_jobs',
      {
        'id': _uuid.v4(),
        'user_message_id': userMessageId,
        'assistant_message_id': assistantMessageId,
        'status': 'pending',
        'attempts': 0,
        'last_error': '',
        'run_token': '',
        'result_json': '',
        'started_at': null,
        'heartbeat_at': null,
        'next_retry_at': null,
        'model_completed_at': null,
        'desire_applied_at': null,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> recoverStalePostTurnJobs({
    Duration staleAfter = const Duration(minutes: 15),
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - staleAfter.inMilliseconds;
    await db.update(
      'post_turn_jobs',
      {
        'status': 'retry_wait',
        'run_token': '',
        'next_retry_at': now,
        'last_error': 'stale_running_recovered',
        'updated_at': now,
      },
      where:
          "status = 'running' AND COALESCE(heartbeat_at, updated_at) < ?",
      whereArgs: [cutoff],
    );
  }

  /// Atomically selects and owns one due post-turn job. The returned run token
  /// is the only authority allowed to checkpoint or complete that attempt.
  Future<PostTurnJob?> claimNextPostTurnJob() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final token = _uuid.v4();
    return db.transaction<PostTurnJob?>((txn) async {
      final rows = await txn.query(
        'post_turn_jobs',
        where:
            "status = 'pending' OR (status = 'retry_wait' AND (next_retry_at IS NULL OR next_retry_at <= ?))",
        whereArgs: [now],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final current = PostTurnJob.fromDb(rows.first);
      final changed = await txn.update(
        'post_turn_jobs',
        {
          'status': 'running',
          'attempts': current.attempts + 1,
          'run_token': token,
          'started_at': now,
          'heartbeat_at': now,
          'next_retry_at': null,
          'last_error': '',
          'updated_at': now,
        },
        where:
            "id = ? AND (status = 'pending' OR (status = 'retry_wait' AND (next_retry_at IS NULL OR next_retry_at <= ?)))",
        whereArgs: [current.id, now],
      );
      if (changed != 1) return null;
      final claimed = await txn.query(
        'post_turn_jobs',
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [current.id, 'running', token],
        limit: 1,
      );
      return claimed.isEmpty ? null : PostTurnJob.fromDb(claimed.first);
    });
  }

  Future<bool> ownsPostTurnJobRun(String id, String runToken) async {
    if (runToken.isEmpty) return false;
    final db = await database;
    final rows = await db.query(
      'post_turn_jobs',
      columns: ['id'],
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> heartbeatPostTurnJob(String id, String runToken) async {
    if (runToken.isEmpty) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await db.update(
      'post_turn_jobs',
      {'heartbeat_at': now, 'updated_at': now},
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
    );
    return changed == 1;
  }

  Future<bool> checkpointPostTurnProposal({
    required String id,
    required String runToken,
    required String resultJson,
  }) async {
    if (runToken.isEmpty || resultJson.trim().isEmpty) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await db.update(
      'post_turn_jobs',
      {
        'result_json': resultJson,
        'model_completed_at': now,
        'heartbeat_at': now,
        'updated_at': now,
      },
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
    );
    return changed == 1;
  }

  Future<bool> markPostTurnJobDone(String id, String runToken) async {
    if (runToken.isEmpty) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = await db.update(
      'post_turn_jobs',
      {
        'status': 'done',
        'run_token': '',
        'next_retry_at': null,
        'last_error': '',
        'heartbeat_at': now,
        'updated_at': now,
      },
      where: 'id = ? AND status = ? AND run_token = ?',
      whereArgs: [id, 'running', runToken],
    );
    return changed == 1;
  }

  Future<PostTurnJob?> failPostTurnJob(
    String id, {
    required String runToken,
    required String error,
    required bool recoverable,
  }) async {
    if (runToken.isEmpty) return null;
    final db = await database;
    final maxAttempts =
        int.tryParse(await getSetting('post_turn_max_attempts') ?? '') ?? 0;
    return db.transaction<PostTurnJob?>((txn) async {
      final rows = await txn.query(
        'post_turn_jobs',
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [id, 'running', runToken],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final job = PostTurnJob.fromDb(rows.first);
      final configuredLimit = maxAttempts <= 0 ? null : maxAttempts.clamp(1, 100);
      final canRetry = recoverable &&
          (configuredLimit == null || job.attempts < configuredLimit);
      final now = DateTime.now();
      DateTime? retryAt;
      if (canRetry) {
        final seconds = job.attempts <= 1
            ? 30
            : job.attempts == 2
                ? 120
                : job.attempts == 3
                    ? 600
                    : job.attempts == 4
                        ? 1800
                        : 3600;
        retryAt = now.add(Duration(seconds: seconds));
      }
      final compact = error.length <= 360 ? error : error.substring(0, 360);
      final changed = await txn.update(
        'post_turn_jobs',
        {
          'status': canRetry ? 'retry_wait' : 'failed',
          'run_token': '',
          'next_retry_at': retryAt?.millisecondsSinceEpoch,
          'last_error': compact,
          'heartbeat_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [id, 'running', runToken],
      );
      if (changed != 1) return null;
      final updated = await txn.query(
        'post_turn_jobs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return updated.isEmpty ? null : PostTurnJob.fromDb(updated.first);
    });
  }

  Future<int> wakeRetryablePostTurnJobs() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.update(
      'post_turn_jobs',
      {'next_retry_at': now, 'updated_at': now},
      where: "status = 'retry_wait'",
    );
  }

  Future<bool> applyPostTurnDesirePulsesOnce({
    required String jobId,
    required String runToken,
    required Map<DriveKey, double> pulses,
    double baselineLearning = 0.018,
  }) async {
    if (runToken.isEmpty || pulses.isEmpty) return true;
    final db = await database;
    return db.transaction<bool>((txn) async {
      final jobs = await txn.query(
        'post_turn_jobs',
        where: 'id = ? AND status = ? AND run_token = ?',
        whereArgs: [jobId, 'running', runToken],
        limit: 1,
      );
      if (jobs.isEmpty) return false;
      if (jobs.first['desire_applied_at'] != null) return true;

      final rows = await txn.query('desire_state', where: 'id = 1', limit: 1);
      final snapshot = rows.isEmpty
          ? DesireSnapshot()
          : DesireSnapshot.decode(rows.first['json'] as String);
      final drives = Map<DriveKey, double>.from(snapshot.drives);
      final baselines = Map<DriveKey, double>.from(snapshot.baselines);
      final anchors = DesireSnapshot.defaultBaselines();
      for (final entry in pulses.entries) {
        final drive = entry.key;
        final delta = entry.value.clamp(-0.35, 0.35).toDouble();
        final anchor = anchors[drive] ?? 0.2;
        drives[drive] = ((drives[drive] ?? anchor) + delta)
            .clamp(0.0, 1.0)
            .toDouble();
        final currentBase = baselines[drive] ?? anchor;
        baselines[drive] = (currentBase + delta * baselineLearning)
            .clamp(max(0.02, anchor - 0.10), min(0.92, anchor + 0.10))
            .toDouble();
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert(
        'desire_state',
        {
          'id': 1,
          'json': snapshot.copyWith(drives: drives, baselines: baselines).encode(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final changed = await txn.update(
        'post_turn_jobs',
        {
          'desire_applied_at': now,
          'heartbeat_at': now,
          'updated_at': now,
        },
        where:
            'id = ? AND status = ? AND run_token = ? AND desire_applied_at IS NULL',
        whereArgs: [jobId, 'running', runToken],
      );
      if (changed != 1) {
        throw StateError('post_turn_desire_ownership_lost');
      }
      return true;
    });
  }

  Future<Duration?> nextPostTurnRecoveryDelay({
    Duration runningStaleAfter = const Duration(minutes: 15),
  }) async {
    final db = await database;
    final rows = await db.query(
      'post_turn_jobs',
      columns: ['status', 'next_retry_at', 'heartbeat_at', 'updated_at'],
      where: "status IN ('pending','running','retry_wait')",
    );
    if (rows.isEmpty) return null;
    final now = DateTime.now();
    Duration? shortest;
    for (final row in rows) {
      final status = row['status'] as String? ?? 'pending';
      late Duration wait;
      if (status == 'pending') {
        wait = Duration.zero;
      } else if (status == 'retry_wait') {
        final ms = row['next_retry_at'] as int?;
        if (ms == null) {
          wait = Duration.zero;
        } else {
          final due = DateTime.fromMillisecondsSinceEpoch(ms);
          wait = due.isAfter(now) ? due.difference(now) : Duration.zero;
        }
      } else {
        final heartbeatMs = row['heartbeat_at'] as int? ??
            row['updated_at'] as int? ??
            now.millisecondsSinceEpoch;
        final staleAt = DateTime.fromMillisecondsSinceEpoch(heartbeatMs)
            .add(runningStaleAfter);
        wait = staleAt.isAfter(now) ? staleAt.difference(now) : Duration.zero;
      }
      if (shortest == null || wait < shortest) shortest = wait;
      if (shortest == Duration.zero) return Duration.zero;
    }
    return shortest;
  }

  Future<int> retryFailedPostTurnJobsManually() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<int>((txn) async {
      final settingsRows = await txn.query(
        'settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['active_brain', 'transfer_lock'],
      );
      final settings = <String, String>{
        for (final row in settingsRows)
          if (row['key'] is String)
            row['key'] as String: row['value'] as String? ?? '',
      };
      if (settings['transfer_lock'] == '1' || settings['active_brain'] == '0') {
        return 0;
      }
      return txn.update(
        'post_turn_jobs',
        {
          'status': 'retry_wait',
          'run_token': '',
          'next_retry_at': now,
          'last_error': '',
          'updated_at': now,
        },
        where: "status = 'failed'",
      );
    });
  }

  Future<Map<String, int>> postTurnJobStats() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM post_turn_jobs GROUP BY status',
    );
    return {
      for (final row in rows)
        row['status'] as String: (row['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> markThoughtsDormantForTopic(
    String topicKey, {
    String detail = '长期未再发生的未完成话题已退休。',
  }) async {
    final key = topicKey.trim().toLowerCase();
    if (key.isEmpty) return;
    final db = await database;
    final rows = await db.query(
      'thoughts',
      columns: ['id', 'strength', 'residual_strength'],
      where: "topic_key = ? AND lifecycle_state IN ('active','fixation','acted','residual')",
      whereArgs: [key],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final row in rows) {
        final strength = (row['strength'] as num?)?.toDouble() ?? 0.0;
        final residual = (row['residual_strength'] as num?)?.toDouble() ?? strength;
        await txn.update(
          'thoughts',
          {
            'lifecycle_state': 'dormant',
            'kind': 'flit',
            'strength': min(0.10, strength),
            'residual_strength': min(0.12, residual),
            'last_outbound_message_id': null,
            'snoozed_until': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        await txn.insert('thought_lifecycle_events', {
          'id': _uuid.v4(),
          'thought_id': row['id'],
          'event_type': 'topic_retired',
          'detail': detail,
          'message_id': null,
          'created_at': now,
        });
      }
    });
  }

  Future<int> pruneThoughtLifecycleEvents({
    int keepPerThought = 64,
    Duration maxAge = const Duration(days: 180),
  }) async {
    final db = await database;
    var removed = 0;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    final thoughtIds = await db.rawQuery(
      'SELECT DISTINCT thought_id FROM thought_lifecycle_events',
    );
    for (final item in thoughtIds) {
      final thoughtId = item['thought_id'] as String;
      final rows = await db.query(
        'thought_lifecycle_events',
        columns: ['id', 'created_at'],
        where: 'thought_id = ?',
        whereArgs: [thoughtId],
        orderBy: 'created_at DESC',
      );
      final deleteIds = <String>[];
      for (var i = 0; i < rows.length; i++) {
        final createdAt = rows[i]['created_at'] as int;
        if (i >= keepPerThought || createdAt < cutoff) {
          deleteIds.add(rows[i]['id'] as String);
        }
      }
      for (final id in deleteIds) {
        removed += await db.delete(
          'thought_lifecycle_events',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    removed += await db.rawDelete(
      'DELETE FROM thought_lifecycle_events WHERE thought_id NOT IN (SELECT id FROM thoughts)',
    );
    return removed;
  }

  Future<int> pruneTableByAgeAndCap({
    required String table,
    required String timeColumn,
    required Duration maxAge,
    required int maxRows,
  }) async {
    const allowedTables = {
      'proactive_feedback',
      'proactive_history',
      'perception_snapshots',
      'awareness_observations',
      'device_events',
      'daily_continuity',
      'post_turn_jobs',
      'maintenance_runs',
    };
    const allowedColumns = {
      'sent_at',
      'created_at',
      'occurred_at',
      'updated_at',
      'window_start',
      'completed_at',
    };
    if (!allowedTables.contains(table) || !allowedColumns.contains(timeColumn)) {
      throw ArgumentError('Unsupported maintenance table/column');
    }
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    var removed = await db.delete(
      table,
      where: '$timeColumn < ?',
      whereArgs: [cutoff],
    );
    final overflow = await db.rawQuery(
      'SELECT id FROM $table ORDER BY $timeColumn DESC LIMIT -1 OFFSET ?',
      [maxRows],
    );
    for (final row in overflow) {
      removed += await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
    }
    return removed;
  }

  Future<int> pruneCompletedPostTurnJobs() async {
    final db = await database;
    final doneCutoff = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final failedCutoff = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    var removed = await db.delete(
      'post_turn_jobs',
      where: 'status = ? AND updated_at < ?',
      whereArgs: ['done', doneCutoff],
    );
    removed += await db.delete(
      'post_turn_jobs',
      where: 'status = ? AND updated_at < ?',
      whereArgs: ['failed', failedCutoff],
    );
    return removed;
  }

  Future<int> pruneTerminalGenerationJobs() async {
    final db = await database;
    final completedCutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final failedCutoff = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    var removed = await db.delete(
      'generation_jobs',
      where: 'status = ? AND updated_at < ?',
      whereArgs: ['completed', completedCutoff],
    );
    removed += await db.delete(
      'generation_jobs',
      where: "status IN ('failed','cancelled','cancelled_by_user') AND updated_at < ?",
      whereArgs: [failedCutoff],
    );
    return removed;
  }

  Future<void> addMaintenanceRun({
    required DateTime startedAt,
    required int retiredThreads,
    required int prunedLifecycle,
    required int prunedFeedback,
    required int prunedHistory,
    required int prunedPerceptions,
    required int prunedDeviceEvents,
    required int prunedJobs,
    String notes = '',
  }) async {
    final db = await database;
    await db.insert('maintenance_runs', {
      'id': _uuid.v4(),
      'started_at': startedAt.millisecondsSinceEpoch,
      'completed_at': DateTime.now().millisecondsSinceEpoch,
      'retired_threads': retiredThreads,
      'pruned_lifecycle': prunedLifecycle,
      'pruned_feedback': prunedFeedback,
      'pruned_history': prunedHistory,
      'pruned_perceptions': prunedPerceptions,
      'pruned_device_events': prunedDeviceEvents,
      'pruned_jobs': prunedJobs,
      'notes': notes.length <= 500 ? notes : notes.substring(0, 500),
    });
  }

  Future<MaintenanceRun?> latestMaintenanceRun() async {
    final db = await database;
    final rows = await db.query(
      'maintenance_runs',
      orderBy: 'completed_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : MaintenanceRun.fromDb(rows.first);
  }

  Future<InteractionSession?> activeInteractionSession() async {
    final db = await database;
    final rows = await db.query(
      'interaction_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : InteractionSession.fromDb(rows.first);
  }

  Future<List<InteractionSession>> recentInteractionSessions({int limit = 12}) async {
    final db = await database;
    final rows = await db.query(
      'interaction_sessions',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(InteractionSession.fromDb).toList();
  }

  Future<void> applyInteractionSessionUpdate({
    required String action,
    String kind = 'roleplay',
    String title = '',
    String premise = '',
    List<String> boundaries = const [],
    String continuityNote = '',
    String? sourceMessageId,
  }) async {
    if ((await getSetting('session_tracking_enabled')) == '0' && action != 'end') return;
    const kinds = {'roleplay', 'intimacy', 'roleplay_intimacy'};
    if (!kinds.contains(kind)) kind = 'roleplay';
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final active = await txn.query(
        'interaction_sessions',
        where: 'status = ?',
        whereArgs: ['active'],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (action == 'end') {
        if (active.isNotEmpty) {
          await txn.update(
            'interaction_sessions',
            {'status': 'ended', 'updated_at': now, 'ended_at': now},
            where: 'id = ?',
            whereArgs: [active.first['id']],
          );
        }
        return;
      }
      if (action != 'open' && action != 'update') return;

      if (action == 'open') {
        if (active.isNotEmpty &&
            sourceMessageId != null &&
            sourceMessageId.isNotEmpty &&
            active.first['source_message_id'] == sourceMessageId) {
          final current = InteractionSession.fromDb(active.first);
          await txn.update(
            'interaction_sessions',
            {
              'kind': kind,
              'title': title.trim().isEmpty ? current.title : title.trim(),
              'premise': premise.trim().isEmpty ? current.premise : premise.trim(),
              'boundaries_json': boundaries.isEmpty
                  ? jsonEncode(current.boundaries)
                  : jsonEncode(boundaries.map((e) => e.trim()).where((e) => e.isNotEmpty).take(16).toList()),
              'continuity_note': continuityNote.trim().isEmpty
                  ? current.continuityNote
                  : continuityNote.trim(),
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [current.id],
          );
          return;
        }
        if (active.isNotEmpty) {
          await txn.update(
            'interaction_sessions',
            {'status': 'ended', 'updated_at': now, 'ended_at': now},
            where: 'id = ?',
            whereArgs: [active.first['id']],
          );
        }
        final normalizedTitle = title.trim().isEmpty
            ? (kind == 'roleplay' ? '临时角色扮演' : '亲密互动')
            : title.trim();
        await txn.insert('interaction_sessions', {
          'id': _uuid.v4(),
          'kind': kind,
          'title': normalizedTitle,
          'status': 'active',
          'premise': premise.trim(),
          'boundaries_json': jsonEncode(boundaries.map((e) => e.trim()).where((e) => e.isNotEmpty).take(16).toList()),
          'continuity_note': continuityNote.trim(),
          'source_message_id': sourceMessageId,
          'started_at': now,
          'updated_at': now,
          'ended_at': null,
        });
        return;
      }

      if (active.isEmpty) return;
      final current = InteractionSession.fromDb(active.first);
      await txn.update(
        'interaction_sessions',
        {
          'kind': kind,
          'title': title.trim().isEmpty ? current.title : title.trim(),
          'premise': premise.trim().isEmpty ? current.premise : premise.trim(),
          'boundaries_json': boundaries.isEmpty
              ? jsonEncode(current.boundaries)
              : jsonEncode(boundaries.map((e) => e.trim()).where((e) => e.isNotEmpty).take(16).toList()),
          'continuity_note': continuityNote.trim().isEmpty
              ? current.continuityNote
              : continuityNote.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [current.id],
      );
    });
  }

  Future<int> totalMessageCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM messages');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> addProactiveHistory({
    required String triggerReason,
    required String decision,
    String? messageId,
  }) async {
    final db = await database;
    await db.insert('proactive_history', {
      'id': _uuid.v4(),
      'trigger_reason': triggerReason,
      'decision': decision,
      'message_id': messageId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> proactiveCountSince(Duration duration) async {
    final db = await database;
    final since = DateTime.now().subtract(duration).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM proactive_history WHERE decision = ? AND created_at >= ?',
      ['sent', since],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> tryAcquireLocalLease(
    String key, {
    Duration holdFor = const Duration(seconds: 120),
  }) async {
    // Do not let this isolate re-acquire a lease it still logically owns, even
    // after the database TTL expires. Without this guard, an overlapping task
    // in the same isolate could overwrite the in-memory token; the older task's
    // finally block would then accidentally release the newer task's lease.
    if (_ownedLeaseTokens.containsKey(key)) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final token = _uuid.v4();
    final acquired = await db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      final raw = rows.isEmpty ? '' : rows.first['value'] as String? ?? '';
      final until = _leaseUntil(raw);
      if (until > now) return false;
      await txn.insert(
        'settings',
        {
          'key': key,
          'value': '$token|${now + holdFor.inMilliseconds}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    });
    if (acquired) {
      _ownedLeaseTokens[key] = token;
    }
    return acquired;
  }

  Future<bool> renewLocalLease(
    String key, {
    Duration holdFor = const Duration(seconds: 120),
  }) async {
    final token = _ownedLeaseTokens[key];
    if (token == null || token.isEmpty) return false;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final raw = rows.first['value'] as String? ?? '';
      if (!raw.startsWith('$token|')) return false;
      await txn.insert(
        'settings',
        {'key': key, 'value': '$token|${now + holdFor.inMilliseconds}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    });
  }

  Future<void> releaseLocalLease(String key) async {
    final token = _ownedLeaseTokens.remove(key);
    if (token == null || token.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final raw = rows.first['value'] as String? ?? '';
      if (!raw.startsWith('$token|')) return;
      await txn.insert(
        'settings',
        {'key': key, 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  int _leaseUntil(String raw) {
    if (raw.isEmpty) return 0;
    final separator = raw.lastIndexOf('|');
    final value = separator < 0 ? raw : raw.substring(separator + 1);
    return int.tryParse(value) ?? 0;
  }

  Future<bool> isLocalLeaseHeld(String key) async {
    final raw = await getSetting(key) ?? '';
    return _leaseUntil(raw) > DateTime.now().millisecondsSinceEpoch;
  }

  /// Whether an autonomous/background subsystem may mutate the companion's
  /// durable inner state on this device. Standby devices remain view-only, and
  /// an in-progress transfer freezes new brain work until the snapshot handoff
  /// finishes. User-facing settings can still be changed separately.
  Future<bool> brainWorkAllowed() async {
    if ((await getSetting('transfer_lock')) == '1') return false;
    return (await getSetting('active_brain')) != '0';
  }

  Future<bool> tryAcquireProactiveLease({
    Duration holdFor = const Duration(seconds: 90),
  }) =>
      tryAcquireLocalLease(
        'proactive_lease_until',
        holdFor: holdFor,
      );

  Future<void> releaseProactiveLease() =>
      releaseLocalLease('proactive_lease_until');

  Future<DailyContinuityRecord?> dailyContinuityForDay(String localDay) async {
    final db = await database;
    final rows = await db.query(
      'daily_continuity',
      where: 'local_day = ?',
      whereArgs: [localDay],
      limit: 1,
    );
    return rows.isEmpty ? null : DailyContinuityRecord.fromDb(rows.first);
  }

  Future<List<DailyContinuityRecord>> latestDailyContinuity({int limit = 3}) async {
    final db = await database;
    final rows = await db.query(
      'daily_continuity',
      orderBy: 'window_start DESC',
      limit: limit.clamp(1, 14).toInt(),
    );
    return rows.map(DailyContinuityRecord.fromDb).toList();
  }

  Future<List<DailyContinuityRecord>> dailyContinuityBefore(
    DateTime before, {
    int limit = 2,
  }) async {
    final db = await database;
    final rows = await db.query(
      'daily_continuity',
      where: 'window_start < ?',
      whereArgs: [before.millisecondsSinceEpoch],
      orderBy: 'window_start DESC',
      limit: limit.clamp(1, 14).toInt(),
    );
    return rows.map(DailyContinuityRecord.fromDb).toList();
  }

  Future<DailyContinuitySaveResult> upsertDailyContinuityIfBrainOwned({
    required String localDay,
    required DateTime windowStart,
    required DateTime windowEnd,
    required String sharedMomentsJson,
    required String carriedThreadsJson,
    required String caresJson,
    required String awarenessJson,
    required int messageCount,
    required int relationshipEventCount,
    required bool quietDay,
    required String sourceFingerprint,
    DateTime? finalizedAt,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      Future<String?> setting(String key) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['value'] as String?;
      }

      if (await setting('transfer_lock') == '1' ||
          await setting('active_brain') == '0') {
        return const DailyContinuitySaveResult(
          changed: false,
          finalizedNow: false,
        );
      }

      final existingRows = await txn.query(
        'daily_continuity',
        where: 'local_day = ?',
        whereArgs: [localDay],
        limit: 1,
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final finalMs = finalizedAt?.millisecondsSinceEpoch;
      if (existingRows.isEmpty) {
        await txn.insert('daily_continuity', {
          'id': _uuid.v4(),
          'local_day': localDay,
          'window_start': windowStart.millisecondsSinceEpoch,
          'window_end': windowEnd.millisecondsSinceEpoch,
          'shared_moments_json': sharedMomentsJson,
          'carried_threads_json': carriedThreadsJson,
          'cares_json': caresJson,
          'awareness_json': awarenessJson,
          'message_count': messageCount,
          'relationship_event_count': relationshipEventCount,
          'quiet_day': quietDay ? 1 : 0,
          'source_fingerprint': sourceFingerprint,
          'finalized_at': finalMs,
          'created_at': nowMs,
          'updated_at': nowMs,
        });
        return DailyContinuitySaveResult(
          changed: true,
          finalizedNow: finalMs != null,
        );
      }

      final existing = existingRows.first;
      if (existing['finalized_at'] != null) {
        return const DailyContinuitySaveResult(
          changed: false,
          finalizedNow: false,
        );
      }
      final fingerprintChanged =
          (existing['source_fingerprint'] as String? ?? '') != sourceFingerprint;
      final finalizedNow = finalMs != null;
      if (!fingerprintChanged && !finalizedNow) {
        return const DailyContinuitySaveResult(
          changed: false,
          finalizedNow: false,
        );
      }
      await txn.update(
        'daily_continuity',
        {
          'window_start': windowStart.millisecondsSinceEpoch,
          'window_end': windowEnd.millisecondsSinceEpoch,
          'shared_moments_json': sharedMomentsJson,
          'carried_threads_json': carriedThreadsJson,
          'cares_json': caresJson,
          'awareness_json': awarenessJson,
          'message_count': messageCount,
          'relationship_event_count': relationshipEventCount,
          'quiet_day': quietDay ? 1 : 0,
          'source_fingerprint': sourceFingerprint,
          if (finalMs != null) 'finalized_at': finalMs,
          'updated_at': nowMs,
        },
        where: 'local_day = ?',
        whereArgs: [localDay],
      );
      return DailyContinuitySaveResult(
        changed: fingerprintChanged || finalizedNow,
        finalizedNow: finalizedNow,
      );
    });
  }

  Future<Map<String, int>> memoryStats() async {
    final db = await database;
    Future<int> count(String table, [String? where, List<Object?>? args]) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
        args,
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    }

    return {
      'memories': await count('memory_items', 'status = ?', ['active']),
      'memory_evidence': await count('memory_evidence'),
      'summaries': await count('conversation_summaries'),
      'threads': await count('unfinished_threads', 'status = ?', ['active']),
      'thoughts': await count('thoughts'),
      'perceptions': await count('perception_snapshots'),
      'awareness_observations': await count('awareness_observations'),
      'daily_continuity': await count('daily_continuity'),
      'relationship_events': await count('relationship_events'),
      'active_sessions': await count('interaction_sessions', 'status = ?', ['active']),
      'references': await count('reference_items', 'enabled = 1'),
      'reference_documents': await count('reference_documents', 'enabled = 1'),
      'thought_lifecycle_events': await count('thought_lifecycle_events'),
      'proactive_feedback': await count('proactive_feedback'),
      'retired_threads': await count('unfinished_threads', 'status = ?', ['retired']),
      'pending_post_turn_jobs': await count('post_turn_jobs', "status IN ('pending','running','retry_wait','failed')"),
      'active_generation_jobs': await count('generation_jobs', "status IN ('pending','running','retry_wait')"),
      'failed_generation_jobs': await count('generation_jobs', 'status = ?', ['failed']),
      'somatic_events': await count('somatic_events'),
      'active_somatic_channels': await count(
        'somatic_aggregates',
        'expires_at > ?',
        [DateTime.now().millisecondsSinceEpoch],
      ),
    };
  }

  Future<Map<String, Object?>> exportAll() async {
    final identity = await transferStateIdentity();
    final db = await database;
    const tables = [
      'messages',
      'memory_items',
      'memory_evidence',
      'conversation_summaries',
      'unfinished_threads',
      'thoughts',
      'desire_state',
      'device_events',
      'perception_snapshots',
      'awareness_observations',
      'daily_continuity',
      'proactive_history',
      'relationship_events',
      'interaction_sessions',
      'reference_documents',
      'reference_items',
      'rule_layers',
      'thought_lifecycle_events',
      'proactive_feedback',
      'post_turn_jobs',
      'generation_jobs',
      'somatic_events',
      'somatic_aggregates',
      'settings',
    ];
    // Read the whole state inside one SQLite transaction so background
    // memory/perception writers cannot produce a cross-table torn snapshot.
    final data = await db.transaction<Map<String, Object?>>((txn) async {
      final result = <String, Object?>{};
      for (final table in tables) {
        if (table == 'post_turn_jobs') {
          // Completed maintenance jobs are device-local bookkeeping; only carry
          // unfinished work across a phone/tablet Active Brain transfer.
          result[table] = await txn.query(
            table,
            where: "status != ?",
            whereArgs: ['done'],
          );
        } else {
          result[table] = await txn.query(table);
        }
      }
      return result;
    });
    return {
      'format': 'ai-companion-localfirst',
      'schema_version': schemaVersion,
      'state_lineage_id': identity.lineageId,
      'state_generation': identity.generation,
      'source_device_id': identity.deviceId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': data,
    };
  }

  Future<void> importAll(
    Map<String, dynamic> backup, {
    Map<String, String> runtimeSettingOverrides = const <String, String>{},
    TransferReceipt? localTransferReceipt,
  }) async {
    if (backup['format'] != 'ai-companion-localfirst') {
      throw const FormatException('不是 AI Companion 状态包');
    }
    final version = (backup['schema_version'] as num?)?.toInt();
    if (version == null || version < 1 || version > schemaVersion) {
      throw FormatException('不支持的状态包版本 $version');
    }
    final rawTables = (backup['tables'] as Map).cast<String, dynamic>();
    final db = await database;
    await db.transaction((txn) async {
      const ordered = [
        'messages',
        'memory_items',
        'memory_evidence',
        'conversation_summaries',
        'unfinished_threads',
        'thoughts',
        'device_events',
        'perception_snapshots',
        'awareness_observations',
        'daily_continuity',
        'proactive_history',
        'relationship_events',
        'interaction_sessions',
        'reference_documents',
        'reference_items',
        'rule_layers',
        'thought_lifecycle_events',
        'proactive_feedback',
        'post_turn_jobs',
        'generation_jobs',
        'somatic_events',
        'somatic_aggregates',
        'desire_state',
        'settings',
      ];
      for (final table in ordered) {
        await txn.delete(table);
        final rows = (rawTables[table] as List?) ?? const [];
        for (final raw in rows) {
          final row = Map<String, Object?>.from(raw as Map);
          if (table == 'memory_items' && version < 2) {
            final created = row['created_at'] as int;
            row.addAll({
              'confidence': 0.7,
              'source': 'conversation',
              'status': 'active',
              'updated_at': created,
            });
          }
          if (table == 'thoughts' && version < 2) {
            row.addAll({
              'source': 'internal',
              'last_fed_at': row['updated_at'],
            });
          }
          if (table == 'memory_items' && version < 4) {
            row.addAll({
              'subject_key': '',
              'pinned': 0,
              'superseded_by': null,
            });
          }
          if (table == 'memory_items' && version < 6) {
            row.addAll({
              'retention_score': 1.0,
              'retention_checked_at': row['updated_at'] ?? row['created_at'],
            });
          }
          if (table == 'memory_items' && version < 15) {
            row.addAll({
              'semantic_type': row['kind'] == 'shared_experience'
                  ? 'shared_experience'
                  : 'current_fact',
              'evidence_count': 1,
              'first_observed_at': row['created_at'],
              'last_evidence_at': row['updated_at'] ?? row['created_at'],
              'fact_version': 1,
            });
          }
          if (table == 'relationship_events' && version < 6) {
            row['internalized_at'] = row['created_at'];
          }
          if (table == 'reference_items' && version < 7) {
            row['document_id'] = null;
          }
          if (table == 'thoughts' && version < 8) {
            row.addAll({
              'lifecycle_state': (row['kind'] == 'fixation') ? 'fixation' : 'active',
              'action_count': 0,
              'last_acted_at': null,
              'last_satisfied_at': null,
              'last_resurfaced_at': null,
              'resurfaced_count': 0,
              'residual_strength': 0.0,
              'last_outbound_message_id': null,
            });
          }
          if (table == 'thoughts' && version < 9) {
            row.addAll({
              'topic_key': '',
              'merged_count': 0,
              'last_merged_at': null,
              'snoozed_until': null,
            });
          }
          if (table == 'unfinished_threads' && version < 9) {
            row['topic_key'] = '';
          }
          if (table == 'proactive_feedback' && version < 9) {
            row.addAll({
              'topic_key': '',
              'thread_id': null,
              'response_quality': null,
              'outcome': row['response_bucket'] == 'no_response'
                  ? 'no_response'
                  : row['user_response_message_id'] != null
                      ? 'response_received'
                      : 'pending',
              'outcome_score': null,
              'processed_at': row['response_bucket'] == 'no_response' ? row['sent_at'] : null,
            });
          }
          if (table == 'unfinished_threads' && version < 10) {
            row.addAll({
              'followup_due_at': null,
              'followup_seeded_at': null,
              'followup_count': 0,
              'last_followup_at': null,
              'retired_at': null,
              'retire_reason': '',
            });
          }
          if (table == 'unfinished_threads' && version < 12) {
            row['followup_run_token'] = '';
            row['followup_claimed_at'] = null;
            row['proactive_outcome_message_id'] = null;
          }
          if (table == 'post_turn_jobs' && version < 12) {
            row.addAll({
              'run_token': '',
              'result_json': '',
              'started_at': null,
              'heartbeat_at': null,
              'next_retry_at': null,
              'model_completed_at': null,
              'desire_applied_at': null,
            });
          }
          if (table == 'messages' && version < 13) {
            row['proactive_intent'] = '';
            row['proactive_delivery'] = '';
          }
          if (table == 'messages') {
            row.remove('provider_reasoning');
            row.remove('companion_voice');
          }
          if (table == 'settings' &&
              (row['key'] as String? ?? '').startsWith('companion_voice')) {
            continue;
          }
          if (table == 'proactive_feedback' && version < 13) {
            row['intent_kind'] = '';
            row['delivery_style'] = '';
          }
          if (table == 'proactive_feedback' && version < 16) {
            row['context_hour_bucket'] = '';
            row['context_activity'] = 'unknown';
            row['context_busy'] = 0.0;
            row['timing_fit'] = row['outcome'] == 'no_response' ? -0.18 : null;
            row['topic_fit'] = row['outcome'] == 'no_response' ? 0.0 : null;
          }
          if (table == 'post_turn_jobs' && row['status'] == 'running') {
            row['status'] = 'retry_wait';
            row['run_token'] = '';
            row['next_retry_at'] = null;
            row['last_error'] = 'resumed_after_transfer';
          }
          if (table == 'generation_jobs' && row['status'] == 'running') {
            row['status'] = 'pending';
            row['next_retry_at'] = null;
            row['run_token'] = '';
            row['resume_reason'] = 'resumed_after_transfer';
            row['last_error'] = 'source_generation_interrupted_by_transfer';
          }
          await txn.insert(
            table,
            row,
            conflictAlgorithm: table == 'conversation_summaries'
                ? ConflictAlgorithm.ignore
                : ConflictAlgorithm.abort,
          );
        }
      }
      if (version < 13) {
        // Old state packages predate proactive presentation metadata. Rebuild
        // the same conservative categories used by the v13 database upgrade
        // after all related rows (thoughts/messages/feedback) have arrived.
        await txn.execute("""
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
        """);
        await txn.execute("""
          UPDATE messages
          SET proactive_intent = COALESCE(
                (SELECT intent_kind FROM proactive_feedback
                 WHERE proactive_feedback.proactive_message_id = messages.id),
                'gentle_ping'
              ),
              proactive_delivery = COALESCE(
                (SELECT delivery_style FROM proactive_feedback
                 WHERE proactive_feedback.proactive_message_id = messages.id),
                'normal'
              )
          WHERE is_proactive = 1 AND proactive_intent = ''
        """);
      }
      await txn.insert(
        'settings',
        {'key': 'memory_consolidation_enabled', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.insert(
        'settings',
        {'key': 'self_drive_enabled', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final entry in const <String, String>{
        'active_brain': '1',
        'model': 'deepseek-v4-flash',
        'reasoning_effort': 'high',
        'auto_memory': '1',
        'transfer_lock': '0',
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
        'long_running_maintenance_enabled': '1',
        'last_long_running_maintenance_at': '0',
        'deferred_followup_enabled': '1',
        'max_deferred_followups': '1',
        'post_turn_queue_enabled': '1',
        'background_error_count': '0',
        'last_background_error': '',
        'durable_generation_enabled': '1',
        'generation_max_attempts': '0',
        'last_generation_recovery_error': '',
        'post_turn_max_attempts': '0',
        'last_async_worker_error': '',
        'daily_continuity_enabled': '1',
        'last_daily_continuity_refresh_at': '0',
        'last_daily_continuity_error': '',
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
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final entry in runtimeSettingOverrides.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Current-state awareness from the source device is useful briefly after
      // takeover, but must not masquerade as the target device's live state.
      // Give imported observations a short grace window; the new Active Brain
      // will then refresh/supersede them from its own local sensors.
      final targetDeviceId = runtimeSettingOverrides['device_id'];
      if (version >= 14 && targetDeviceId != null && targetDeviceId.isNotEmpty) {
        final graceUntil = DateTime.now()
            .add(const Duration(minutes: 12))
            .millisecondsSinceEpoch;
        await txn.rawUpdate('''
          UPDATE awareness_observations
          SET expires_at = CASE WHEN expires_at > ? THEN ? ELSE expires_at END
          WHERE device_id IS NOT NULL AND device_id <> ?
        ''', [graceUntil, graceUntil, targetDeviceId]);
      }

      final desireRows = await txn.query('desire_state', where: 'id = 1', limit: 1);
      if (desireRows.isEmpty) {
        await txn.insert('desire_state', {
          'id': 1,
          'json': DesireSnapshot().encode(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      if (localTransferReceipt != null) {
        await txn.insert(
          'transfer_receipts',
          localTransferReceipt.toDb(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
    await _seedRuleLayers(await database);
    await ensureDeviceId();
    await ensureStateLineageId();
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // Opening failed; there is no database handle to close.
      }
    }
    await _db?.close();
    _db = null;
    _opening = null;
  }
}
