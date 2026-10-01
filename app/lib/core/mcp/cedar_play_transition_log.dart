import 'dart:convert';

import '../database/app_database.dart';

/// Bounded control evidence only: no guide, dialogue, params, or epoch token.
class CedarPlayTransitionLog {
  CedarPlayTransitionLog(this.db);
  final AppDatabase db;
  static const key = 'cedar_timed_play_transitions_v1';

  Future<void> record({required String source, required String reason,
      String before = '', String after = '', DateTime? at}) async {
    try {
      for (var retry = 0; retry < 3; retry++) {
        final raw = await db.getSetting(key) ?? '';
        List<dynamic> entries;
        try {
          final decoded = jsonDecode(raw);
          entries = decoded is List ? List<dynamic>.from(decoded) : [];
        } catch (_) { entries = []; }
        entries.add({'at': (at ?? DateTime.now()).millisecondsSinceEpoch,
          'source': source, 'reason': reason, 'before': before, 'after': after,
          'contentIncluded': false});
        if (entries.length > 32) entries = entries.sublist(entries.length - 32);
        if (await db.setSettingsAtomically({key: jsonEncode(entries)},
            expectedSettings: {key: raw})) return;
      }
    } catch (_) { /* Observability cannot stop a game. */ }
  }
}
