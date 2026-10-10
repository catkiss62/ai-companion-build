import 'dart:convert';
import 'companion_wish.dart';

/// Durable local receipts, distinct from wishes and assistant narration.
/// Keep a bounded early and recent window per active wish across game log rotation.
class WishGameEvidence {
  static const key = 'companion_wish_game_receipts_v1';
  static List<Map<String, dynamic>> decode(String raw) {
    try { return (jsonDecode(raw) as List).whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList(); }
    catch (_) { return []; }
  }

  static String append({required String raw, required List<CompanionWish> wishes,
    required String gameId, required String eventId, required String action,
    required String input, required String output, required DateTime at}) {
    final pending = wishes.where((w) => w.active && !w.legacy && !w.manualHold &&
        w.route == 'game').take(4).toList();
    final rows = decode(raw);
    for (final w in pending.where((w) => w.gameId == gameId && !at.isBefore(w.createdAt))) {
      final id = 'game:$gameId:$eventId';
      if (rows.any((e) => e['wish_id'] == w.id && e['id'] == id)) continue;
      rows.add({'wish_id': w.id, 'id': id, 'game_id': gameId,
        'at': at.millisecondsSinceEpoch,
        'text': 'action=$action\nsubmitted_input=$input\nreturned_outcome=$output'});
    }
    final kept = <Map<String, dynamic>>[];
    for (final w in pending) {
      final items = rows.where((e) => e['wish_id'] == w.id &&
          (e['at'] as num? ?? 0) >= w.createdAt.millisecondsSinceEpoch).toList();
      final selected = <String, Map<String, dynamic>>{};
      for (final e in [...items.take(8), ...items.reversed.take(16).toList().reversed]) {
        selected[e['id'] as String] = e;
      }
      kept.addAll(selected.values);
    }
    return jsonEncode(kept);
  }

  static List<WishEvidence> collect(String raw, List<CompanionWish> wishes, DateTime now) {
    final ids = wishes.where((w) => w.active && !w.manualHold).map((w) => w.id).toSet();
    final result = <String, WishEvidence>{};
    for (final row in decode(raw)) {
      final at = DateTime.fromMillisecondsSinceEpoch((row['at'] as num? ?? 0).toInt());
      if (!ids.contains(row['wish_id']) || at.isAfter(now)) continue;
      final id = row['id'] as String;
      result[id] = WishEvidence(id: id, kind: 'game_result',
        gameId: row['game_id'] as String, text: row['text'] as String, at: at);
    }
    return result.values.toList();
  }
}
