import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../emotion/emotion_contract.dart';
import '../diagnostics/provider_health.dart';
import '../diagnostics/proactive_policy_telemetry.dart';
import '../desire/desire_core_policy.dart';
import '../desire/interaction_reciprocity_policy.dart';
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
import '../integration/moe_expression_default_policy.dart';
import '../phone/album_perceptual_hash.dart';
import '../reference/world_book_presets.dart';
import '../models/perception_snapshot.dart';
import '../models/personality_trial.dart';
import '../models/personality_learning.dart';
import '../models/self_experience.dart';
import '../models/post_turn_job.dart';
import '../models/generation_job.dart';
import '../models/maintenance_run.dart';
import '../models/maintenance_prune_policy.dart';
import '../models/reference_item.dart';
import '../models/reference_document.dart';
import '../models/rule_layer.dart';
import '../models/proactive_feedback.dart';
import '../models/proactive_frequency.dart';
import '../models/thought_lifecycle_event.dart';
import '../rules/rule_layer_content_immersive.dart';
import '../rules/rule_layer_content_v0353.dart';
import '../rules/rule_layer_content_v0417.dart';
import '../rules/rule_layer_content_v0418.dart';
import '../rules/rule_layer_content_v04125.dart';
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

class ConversationContextResetResult {
  const ConversationContextResetResult({
    required this.applied,
    required this.reason,
    this.resetAt,
  });

  final bool applied;
  final String reason;
  final DateTime? resetAt;
}

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
  // Historical validator compatibility token: static const int schemaVersion = 34;
  // Historical validator compatibility token: static const int schemaVersion = 35;
  // Historical validator compatibility token: static const int schemaVersion = 36;
  // Historical validator compatibility token: static const int schemaVersion = 37;
  // Historical validator compatibility token: static const int schemaVersion = 38;
  // Historical validator compatibility token: static const int schemaVersion = 39;
  // Historical validator compatibility token: static const int schemaVersion = 40;
  // Historical validator compatibility token: static const int schemaVersion = 41;
  // Historical validator compatibility token: static const int schemaVersion = 42;
  // Historical validator compatibility token: static const int schemaVersion = 44;
  static const int schemaVersion = 45;

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
        ProactiveFrequencyPolicy.settingKey:
            ProactiveFrequencyPolicy.defaultKey,
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
          await db.execute('ALTER TA