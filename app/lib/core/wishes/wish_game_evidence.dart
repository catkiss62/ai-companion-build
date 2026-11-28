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

  static bool eligible(CompanionWish wish, {required bool includePaused}) =>
      wish.route == 'game' && !wish.manualHold && !wish.legacy &&
      (wish.active || includePaused && wish.state == 'paused' && wish.autoPausedAt != null);

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
        'at': at.millisecondsSinceEpoch, 'returned_outcome': output,
        'text': 'action=$action\nsubmitted_input=$input\nreturned_outcome=$output'});
    }
    final kept = <Map<String, dynamic>>[];
    for (final w in wishes.where((w) => eligible(w, includePaused: true))) {
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

  static List<WishEvidence> collect(String raw, List<CompanionWish> wishes, DateTime now, {bool includePaused = false}) {
    final owners = {for (final w in wishes.where((w) => eligible(w, includePaused: includePaused))) w.id: w};
    final result = <String, WishEvidence>{};
    for (final row in decode(raw)) {
      final at = DateTime.fromMillisecondsSinceEpoch((row['at'] as num? ?? 0).toInt());
      final owner = owners[row['wish_id']];
      if (owner == null || at.isAfter(now) || !at.isAfter(owner.createdAt) ||
          owner.autoPausedAt != null && at.isAfter(owner.autoPausedAt!)) continue;
      final context = row['text'] as String;
      const marker = '\nreturned_outcome=';
      final split = context.indexOf(marker);
      final outcome = row['returned_outcome'] as String? ??
          (split < 0 ? '' : context.substring(split + marker.length));
      final id = row['id'] as String;
      result[id] = WishEvidence(id: id, kind: 'game_result',
        gameId: row['game_id'] as String, text: context, gameOutcome: outcome, at: at);
    }
    return result.values.toList();
  }
}
