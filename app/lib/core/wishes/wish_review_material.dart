import 'companion_wish.dart';

/// A lossless-for-dedup projection, never a rewrite of the saved wish ledger.
/// Live/paused/expired criteria remain complete for evidence validation.
class WishReviewMaterial {
  static const historyLimit = 116;
  static bool reviewable(CompanionWish wish) => !wish.legacy && !wish.manualHold &&
      (wish.active || wish.state == 'paused' || wish.state == 'expired');

  /// Evidence is grouped for active wishes and targeted natural pauses during upgrades. Other
  /// reviewable records retain access to the shared source catalogue.
  static Map<String, List<WishEvidence>> candidates(
    List<CompanionWish> wishes, List<WishEvidence> evidence,
    Map<String, List<String>> targetIds, {bool includePaused = false}
  ) {
    final result = <String,List<WishEvidence>>{};
    for (final wish in wishes.where((w) => reviewable(w) && (w.active || includePaused && w.autoPausedAt != null))) {
      final target = '${wish.goal} ${wish.criterion}';
      final terms = <String>{
        for (var i = 0; i + 2 <= target.length; i++)
          if (!target.substring(i,i+2).contains(RegExp(r'\s'))) target.substring(i,i+2),
      };
      final ranked = <({WishEvidence item, int score})>[];
      for (final e in evidence) {
        if (wish.deadline != null && e.at.isAfter(wish.deadline!)) continue;
        if (e.kind == 'user_photo' && wish.completionKind != 'user_photo') continue;
        if (e.kind != 'user_photo' && !e.at.isAfter(wish.createdAt)) continue;
        if (!const {'user_text','user_photo','assistant_text','game_result'}.contains(e.kind)) continue;
        final matchingGame = e.kind == 'game_result' && e.gameId == wish.gameId && wish.route == 'game';
        if (e.kind == 'game_result' && !matchingGame) continue;
        final index = targetIds[wish.id]?.indexOf(e.id) ?? -1;
        final overlap = terms.where(e.text.contains).length;
        if (!wish.active && (e.at.isAfter(wish.autoPausedAt!) ||
            overlap == 0 && !matchingGame && !wish.sourceIds.contains(e.id) &&
            !(index >= 0 && e.kind == 'user_text' && RegExp(r'那张|之前|上次|愿望').hasMatch(e.text)))) continue;
        final score = overlap + (matchingGame ? 30 : 0) +
            (index >= 0 ? 36 - index.clamp(0,30).toInt() : 0) +
            (wish.sourceIds.contains(e.id) ? 20 : 0);
        if (score > 0) ranked.add((item:e,score:score));
      }
      ranked.sort((a,b) {
        final score = b.score.compareTo(a.score);
        return score == 0 ? b.item.at.compareTo(a.item.at) : score;
      });
      result[wish.id] = [
        for (final kind in ['user_text','user_photo','game_result','assistant_text'])
          ...ranked.where((r) => r.item.kind == kind).take(kind == 'assistant_text' ? 2 : 6).map((r)=>r.item),
      ];
    }
    return result;
  }

  static Map<String,Object?> forReviewer(List<CompanionWish> items,
      Map<String,List<WishEvidence>> groups, {Set<String> requiredIds = const {}}) {
    final view = wishes(items, requiredIds: requiredIds);
    for (final w in (view['wishes'] as List).whereType<Map>()) {
      final group = groups[w['id']];
      if (group != null) w['candidate_evidence'] = group.map((e)=>e.toJson()).toList();
    }
    return view;
  }

  /// Updates on paused/expired wishes are optional. Every active item needs
  /// exactly one disposition; a malformed batch must not consume the upgrade.
  static String? responseError(List<CompanionWish> items, Map payload, Set<String> sourceIds,
      {Set<String> archived = const {}, Set<String> requiredIds = const {}}) {
    final rows = payload['updates'];
    if (rows is! List) return 'missing_updates';
    final allowed = items.where(reviewable).map((w) => w.id).toSet();
    final active = items.where((w) => w.active && reviewable(w)).map((w) => w.id).toSet();
    final seen = <String>{};
    for (final row in rows) {
      if (row is! Map || row['id'] is! String) return 'malformed_update';
      final id = row['id'] as String;
      if (!allowed.contains(id)) return 'unknown_wish_id';
      if (!seen.add(id)) return 'duplicate_wish_id';
      if (row['state'] == 'unchanged') {
        if (!const {'insufficient_evidence','criterion_unmet','no_new_evidence','missing_original_photo',
            'missing_user_confirmation','target_ambiguous','new_result_required'}.contains(row['reason_code'])) return 'invalid_review_reason';
        final refs = row['evidence_ids'];
        if (refs is! List || refs.length > 12 || refs.any((s) => !sourceIds.contains(s))) return 'invalid_review_sources';
      } else if (!const {'active','completed','satisfied','paused','abandoned'}.contains(row['state'])) {
        return 'invalid_state';
      } else if (row['quote'] is! String || (row['quote'] as String).trim().length < 3 ||
          row['confidence'] is! num || row['same_target'] is! bool ||
          row['state'] == 'completed' && row['observed'] is! bool) {
        return 'malformed_update';
      } else if (!sourceIds.contains(row['evidence_id'])) {
        return 'missing_source';
      }
    }
    seen.addAll(archived);
    return seen.containsAll(active) && seen.containsAll(requiredIds) ? null : 'missing_wish_review';
  }
  static Map<String, Object?> wishes(List<CompanionWish> items, {Set<String> requiredIds = const {}}) => {
    'wishes': [
      ...items.where((w) => w.active && reviewable(w)),
      ...items.where((w) => !w.active && reviewable(w) && requiredIds.contains(w.id)),
      ...items.where((w) => !w.active && reviewable(w) && !requiredIds.contains(w.id)).take(historyLimit),
    ].map((w) => w.toJson()).toList(),
    'wish_history': items.where((w) => !reviewable(w)).take(historyLimit).map((w) => {
      'id': w.id, 'goal': w.goal, 'route': w.route, 'game_id': w.gameId,
      'state': w.state, 'legacy': w.legacy,
      'created_at': w.createdAt.millisecondsSinceEpoch,
      'updated_at': w.updatedAt.millisecondsSinceEpoch,
    }).toList(),
  };
}
