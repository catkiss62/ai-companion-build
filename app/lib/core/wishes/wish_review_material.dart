import 'companion_wish.dart';

/// A lossless-for-dedup projection, never a rewrite of the saved wish ledger.
/// Live/paused/expired criteria remain complete for evidence validation.
class WishReviewMaterial {
  static bool reviewable(CompanionWish wish) => !wish.legacy && !wish.manualHold &&
      (wish.active || wish.state == 'paused' || wish.state == 'expired');

  static Map<String, Object?> wishes(List<CompanionWish> items) => {
    'wishes': items.where(reviewable).map((w) => w.toJson()).toList(),
    'wish_history': items.where((w) => !reviewable(w)).take(116).map((w) => {
      'id': w.id, 'goal': w.goal, 'route': w.route, 'game_id': w.gameId,
      'state': w.state, 'legacy': w.legacy,
      'created_at': w.createdAt.millisecondsSinceEpoch,
      'updated_at': w.updatedAt.millisecondsSinceEpoch,
    }).toList(),
  };
}
