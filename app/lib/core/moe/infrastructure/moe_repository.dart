import '../domain/moe_models.dart';

abstract interface class MoeRepository {
  Future<MoeStateSnapshot> loadState();

  Future<void> saveState(MoeStateSnapshot state);

  Future<bool> recordEventIfNew(MoeObservedEvent event);

  /// Inserts the event and advances state in one SQLite transaction. Duplicate
  /// event keys return the existing state without invoking [advance].
  Future<MoeStateSnapshot> advanceEventIfNew(
    MoeObservedEvent event, {
    required MoeStateSnapshot Function(MoeStateSnapshot previous) advance,
  });

  Future<MoeExpressionMode> loadExpressionMode();

  Future<void> setExpressionMode(MoeExpressionMode mode);
}
