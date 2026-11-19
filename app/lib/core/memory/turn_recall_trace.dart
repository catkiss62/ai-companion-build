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
      'source_turn': [
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

  static Map<String, Object?> _excerpt(String text, int max) {
    final chars = text.runes.take(max + 1).toList();
    return {
      'text': String.fromCharCodes(chars.take(max)),
      'excerpt_truncated': chars.length > max,
    };
  }

  Map<String, Object?> snapshot(
    List<Map<String, Object?>> messages,
    String channel,
  ) {
    final system = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'])
        .whereType<String>()
        .toList();
    return {
      'channel': channel,
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
