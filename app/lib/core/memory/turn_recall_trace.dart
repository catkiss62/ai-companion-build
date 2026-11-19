import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/memory_item.dart';
import 'memory_revision.dart';

/// Transient, per-request evidence. Only the generation that commits may
/// publish this snapshot. The redacted diagnostics do not read its setting.
class TurnRecallTrace {
  static const key = 'private_chat_recall_last_five_v1';
  final _candidates = <Map<String, Object?>>[];
  final _sections = <({String kind, String text, Map<String, Object?> meta})>[];
  int? rankedCount;

  static Map<String, Object?> provenance(MemoryItem item) {
    final source = MemorySourceContext.decode(item.sourceContextJson);
    return {
      'id': item.id,
      'actor': item.actorKey,
      'source_turn': <Map<String, Object?>>[
        for (final role in ['user', 'assistant'])
          if (source[role] case final Map row)
            {
              'speaker': role,
              'message_id': row['message_id'],
              'said_at_ms': row['created_at'],
            }
          else if ((role == 'user'
                  ? item.sourceUserMessageId
                  : item.sourceAssistantMessageId)
              .isNotEmpty)
            {
              'speaker': role,
              'message_id': role == 'user'
                  ? item.sourceUserMessageId
                  : item.sourceAssistantMessageId,
              'said_at_ms': null,
            },
      ],
      'last_evidence_at_ms': item.evidenceTimeKnown
          ? item.lastEvidenceAt.millisecondsSinceEpoch
          : null,
      // The ordinary extraction clock dates the evidence, not the event.
      if (source['scene'] == 'model_dialogue' &&
          source['first_message_at'] is int &&
          source['last_message_at'] is int)
        'event_range_ms': [
          source['first_message_at'],
          source['last_message_at'],
        ],
    };
  }

  void ranked(List<MemoryItem> items) {
    rankedCount = items.length;
    for (final item in items.take(40)) {
      _candidates.add({...provenance(item), ..._excerpt(item.content, 220)});
    }
  }

  void section(
    String kind,
    String text, [
    Map<String, Object?> meta = const {},
  ]) {
    if (text.isNotEmpty) _sections.add((kind: kind, text: text, meta: meta));
  }

  Future<void> resolveSourceTimes(DatabaseExecutor db) async {
    final unresolved = <Map<String, Object?>>[];
    for (final entry in [..._candidates, ..._sections.map((s) => s.meta)]) {
      if (entry['source_turn'] case final List sources) {
        unresolved.addAll(
          sources.whereType<Map<String, Object?>>().where(
            (source) =>
                source['said_at_ms'] == null && source['message_id'] is String,
          ),
        );
      }
    }
    final ids = unresolved
        .map((row) => row['message_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final rows = await db.query(
      'messages',
      columns: ['id', 'role', 'created_at'],
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byId = {for (final row in rows) row['id']: row};
    for (final source in unresolved) {
      final row = byId[source['message_id']];
      if (row != null && row['role'] == source['speaker'])
        source['said_at_ms'] = row['created_at'];
    }
  }

  static Map<String, Object?> _excerpt(String text, int max) {
    final chars = text.runes.take(max + 1).toList();
    return {
      'text': String.fromCharCodes(chars.take(max)),
      'excerpt_truncated': chars.length > max,
    };
  }

  Map<String, Object?> snapshot(
    List<Map<String, Object?>> messages,
    String channel, {
    Map<String, String> historyTools = const {},
  }) {
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'])
        .whereType<String>()
        .toList();
    final toolMaterials = [
      ...system,
      ...messages
          .where((m) => m['role'] == 'tool')
          .map((m) => m['content'])
          .whereType<String>(),
    ];
    return {
      'channel': channel,
      'history_tool_sections': [
        for (final entry in historyTools.entries)
          if (toolMaterials.any((content) => content.contains(entry.key)))
            {'tool': entry.value, ..._excerpt(entry.key, 1400)}
          else
            {'tool': entry.value, 'status': 'absent_from_final_request'},
      ],
      'ranked_status': rankedCount == null
          ? 'not_triggered'
          : rankedCount == 0
          ? 'no_hit'
          : 'ranked',
      'ranked_candidate_count': rankedCount,
      'candidate_list_truncated': (rankedCount ?? 0) > _candidates.length,
      'ranked_candidates': _candidates,
      'request_sections': [
        for (final entry in _sections)
          if (system.any((text) => text.contains(entry.text)))
            {'kind': entry.kind, ...entry.meta, ..._excerpt(entry.text, 1400)}
          else
            {
              'kind': entry.kind,
              ...entry.meta,
              'status': 'absent_from_final_request',
            },
      ],
    };
  }

  static Future<List<dynamic>> read(DatabaseExecutor db) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key=?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return [];
    try {
      final data = jsonDecode(rows.first['value'] as String);
      return data is List ? data.whereType<Map>().take(5).toList() : [];
    } on FormatException {
      return [];
    }
  }

  static Future<List<dynamic>> forExport(DatabaseExecutor db) async {
    final rows = await read(db);
    if (rows.isEmpty) return [];
    final current = await db.query(
      'messages',
      columns: ['id', 'source_revision'],
      where: 'id IN (${List.filled(rows.length, '?').join(',')})',
      whereArgs: [for (final row in rows) row['reply']],
    );
    final revisions = {
      for (final row in current) row['id']: row['source_revision'],
    };
    return rows
        .where(
          (row) =>
              row['revision'] is int &&
              revisions[row['reply']] == row['revision'],
        )
        .toList();
  }

  static Future<void> record(
    DatabaseExecutor db,
    Map<String, Object?> snapshot, {
    required String turn,
    required String reply,
    required int revision,
    required int at,
    required String? model,
  }) async {
    final old = await read(db);
    final rows = [
      {
        'turn': turn,
        'reply': reply,
        'revision': revision,
        'committed_at_ms': at,
        'model': model,
        ...snapshot,
      },
      ...old.where((row) => row['turn'] != turn).take(4),
    ];
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode(rows),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
