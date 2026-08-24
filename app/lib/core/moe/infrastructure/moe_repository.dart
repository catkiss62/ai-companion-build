import '../domain/moe_models.dart';

abstract interface class MoeRepository {
  Future<MoeStateSnapshot> loadState();

  Future<void> saveState(MoeStateSnapshot state);

  Future<bool> recordEventIfNew(MoeObservedEvent event);

  Future<MoeExpressionMode> loadExpressionMode();

  Future<void> setExpressionMode(MoeExpressionMode mode);
}
