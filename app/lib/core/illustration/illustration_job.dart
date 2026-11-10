import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'illustration_prompt.dart';

enum IllustrationSource { chat, proactive, diary }

/// Durable admission keyed by the exact committed message or diary.
class IllustrationJob {
  const IllustrationJob({
    required this.source,
    required this.ownerId,
    required this.intent,
    this.context = '',
    this.plan,
    this.requiresAutonomy = false,
  });

  final IllustrationSource source;
  final String ownerId;
  final String intent;
  final String context;
  final IllustrationPlan? plan;
  final bool requiresAutonomy;

  static const keyPrefix = 'illustration_job:';
  static const diaryMediaPrefix = 'illustration_diary_media:';
  static const configRevisionKey = 'illustration_config_revision';
  static const diaryEntriesKey = 'simulated_phone_diary_json';

  static String keyFor(IllustrationSource source, String ownerId) =>
      '$keyPrefix${source.name}:$ownerId';

  String get key => keyFor(source, ownerId);

  Map<String, dynamic> initial() => {
    'state': 'queued',
    'source': source.name,
    'owner_id': ownerId,
    'at': DateTime.now().millisecondsSinceEpoch,
    'attempts': 0,
    if (requiresAutonomy) 'autonomous': true,
    'intent': _bounded(intent, 800),
    if (context.isNotEmpty) 'context': _bounded(context, 1600),
    if (plan != null) 'plan': plan!.toJson(),
  };

  Future<void> admit(DatabaseExecutor db) async {
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode(initial()),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static String _bounded(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  static Map<String, Object?> forPortableSnapshot(Map<String, Object?> row) {
    final key = row['key']?.toString() ?? '';
    if (!key.startsWith(keyPrefix)) return row;
    final job = decode(row['value']?.toString());
    if (job == null || job['state'] != 'queued') return row;
    return {
      ...row,
      'value': jsonEncode({
        'state': 'failed',
        'error': 'restore',
        'source': job['source'],
        'owner_id': job['owner_id'],
        'at': job['at'],
        'attempts': job['attempts'],
      }),
    };
  }

  static bool diaryContains(String? raw, String ownerId) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final entries = jsonDecode(raw);
      return entries is List &&
          entries.any((entry) => entry is Map && entry['id'] == ownerId);
    } on FormatException {
      return false;
    }
  }

  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
