import 'companion_wish.dart';

/// Retrieval only: these hints never decide a wish's state. Keep actual nearby
/// dialogue so a reference like "that wish" has a subject. Model + evidence
/// validation still decide whether this is a considered change of intention.
class WishEvidenceWindow {
  static List<WishEvidence> select(List<WishEvidence> all, List<CompanionWish> wishes) {
    final chat = all.where((e) => e.kind == 'user_text' || e.kind == 'assistant_text').toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final selected = <String, WishEvidence>{};
    for (final kind in ['user_text', 'assistant_text']) {
      for (final e in chat.reversed.where((e) => e.kind == kind).take(16)) {
        selected[e.id] = e;
      }
    }
    final pending = wishes.where((w) => !w.legacy && !w.manualHold &&
        (w.active || w.state == 'paused')).toList();
    final ranked = <({int index, int score})>[];
    for (var i = 0; i < chat.length; i++) {
      final e = chat[i];
      if (e.kind != 'assistant_text' || !pending.any((w) => e.at.isAfter(w.updatedAt))) continue;
      var overlap = 0;
      for (final w in pending.where((w) => e.at.isAfter(w.updatedAt))) {
        final target = '${w.goal} ${w.criterion}';
        for (var j = 0; j + 3 <= target.length; j++) {
          final part = target.substring(j, j + 3);
          if (!RegExp(r'\s').hasMatch(part) && e.text.contains(part)) overlap++;
        }
      }
      final mentionsWish = e.text.contains('愿望');
      final disposition = RegExp(r'放下|不再|暂时|不想|想通|满足|结案|不执着|不执著').hasMatch(e.text);
      // A nearby user message can identify a wish referred to elliptically.
      final previous = i > 0 ? chat[i - 1].text : '';
      final contextual = pending.any((w) {
        for (var j = 0; j + 3 <= w.goal.length; j++) {
          if (previous.contains(w.goal.substring(j, j + 3))) return true;
        }
        return false;
      });
      if (overlap > 0 || mentionsWish || (contextual && disposition)) {
        ranked.add((index: i, score: (disposition ? 100 : 0) + (mentionsWish ? 20 : 0) + overlap.clamp(0, 10).toInt()));
      }
    }
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : b.index.compareTo(a.index);
    });
    for (final entry in ranked.take(4)) {
      for (final i in [entry.index - 1, entry.index, entry.index + 1]) {
        if (i >= 0 && i < chat.length) selected[chat[i].id] = chat[i];
      }
    }
    return selected.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }
}
