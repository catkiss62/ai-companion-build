import 'package:sqflite/sqflite.dart';
import 'companion_wish.dart';

/// Retrieval only: these hints never decide a wish's state. Keep actual nearby
/// dialogue so a reference like "that wish" has a subject. Model + evidence
/// validation still decide whether this is a considered change of intention.
class WishEvidenceWindow {
  /// Fetch candidate message IDs. The caller rehydrates their provenance and
  /// rechecks revisions before committing a decision.
  static Future<Set<String>> photoWishMessages(DatabaseExecutor txn,
      List<CompanionWish> wishes, DateTime now) async {
    final ids = <String>{};
    final pending = wishes.where((w) => w.route == 'user' &&
        w.completionKind == 'user_photo' && !w.manualHold && !w.legacy &&
        (w.active || w.state == 'expired' || w.state == 'paused')).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    for (final w in pending.take(8)) {
      final end = w.deadline != null && w.deadline!.isBefore(now) ? w.deadline! : now;
      if (!end.isAfter(w.createdAt)) continue;
      for (final id in w.sourceIds) {
        if (id.startsWith('chat:')) ids.add(id.substring(5));
        if (id.startsWith('photo:') && id.lastIndexOf(':') > 5) {
          ids.add(id.substring(6, id.lastIndexOf(':')));
        }
      }
      final words = <String>{};
      for (final match in RegExp(r'[\u3400-\u9fff]+|[a-zA-Z0-9]{2,}').allMatches('${w.goal} ${w.criterion}')) {
        final word = match[0]!;
        if (word.length < 2) continue;
        if (RegExp(r'^[a-zA-Z0-9]').hasMatch(word)) { words.add(word); continue; }
        for (var i = 0; i + 2 <= word.length; i++) {
          words.add(word.substring(i, i + 2));
        }
      }
      final terms = words.take(48).toList();
      String score(String column) => ['0', for (final _ in terms) '(instr($column, ?) > 0)'].join(' + ');
      final photoRows = await txn.rawQuery('''
        SELECT m.id, MAX(${score("coalesce(a.vision_summary,'') || ' ' || m.content")}) AS relevance
        FROM message_attachments a JOIN messages m ON m.id = a.message_id
        WHERE m.role = 'user' AND m.created_at <= ? AND a.kind = 'image'
        AND a.vision_status = 'completed' AND a.source NOT GLOB 'user_sticker:*'
        AND a.source NOT GLOB 'assistant_*' AND a.source NOT GLOB 'mcp/*'
        GROUP BY m.id ORDER BY relevance DESC, abs(m.created_at - ?) ASC, m.id LIMIT 6
      ''', [...terms, end.millisecondsSinceEpoch, w.createdAt.millisecondsSinceEpoch]);
      final textRows = await txn.rawQuery('''
        SELECT id, (${score('content')}) +
          (instr(content,'愿望') > 0) * 3 +
          ((instr(content,'那张') > 0 OR instr(content,'之前') > 0 OR instr(content,'上次') > 0)
           AND (instr(content,'就是') > 0 OR instr(content,'已经') > 0 OR instr(content,'完整') > 0)) * 4 AS relevance
        FROM messages WHERE role = 'user' AND created_at > ? AND created_at <= ?
        AND length(trim(content)) > 0 ORDER BY relevance DESC, created_at DESC, id LIMIT 6
      ''', [...terms, w.createdAt.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
      ids.addAll([...photoRows, ...textRows].map((r) => r['id'] as String));
    }
    return ids;
  }

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
      if (!pending.any((w) => w.acceptsIntentionAt(e.at))) continue;
      var overlap = 0;
      for (final w in pending.where((w) => w.acceptsIntentionAt(e.at))) {
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
