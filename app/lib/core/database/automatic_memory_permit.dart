import 'package:sqflite/sqflite.dart';
import 'brain_work_fence.dart';

/// Captured before async work and persisted with its proposal. Old results
/// cannot acquire new authority after a toggle or snapshot replacement.
class AutomaticMemoryPermit {
  const AutomaticMemoryPermit(this.feature, this.enabled, this.version, this.identity);
  final String feature, version;
  final bool enabled;
  final Map<String, String> identity;
  static const features = {'auto_memory', 'memory_consolidation_enabled'};
  static String versionKey(String feature) => '${feature}_permit_version_v1';
  static const identityKeys = ['state_lineage_id', 'state_generation', 'runtime_state_epoch_v1'];

  static Future<AutomaticMemoryPermit> capture(DatabaseExecutor txn, String feature) async {
    if (!features.contains(feature)) throw ArgumentError.value(feature);
    return AutomaticMemoryPermit(feature, await BrainWorkFence.value(txn, feature) != '0',
      await BrainWorkFence.value(txn, versionKey(feature)), {
        for (final key in identityKeys) key: await BrainWorkFence.value(txn, key),
      });
  }
  Future<bool> matches(DatabaseExecutor txn) async => enabled &&
      await BrainWorkFence.value(txn, feature) != '0' &&
      await BrainWorkFence.value(txn, versionKey(feature)) == version &&
      await BrainWorkFence(identity: identity).matches(txn);
  Map<String, Object?> toJson() => {'schema': 1, 'feature': feature,
    'enabled': enabled, 'version': version, 'identity': identity};
  static AutomaticMemoryPermit? decode(Object? value) {
    if (value is! Map || value['schema'] != 1 || !features.contains(value['feature']) ||
        value['enabled'] is! bool || value['version'] is! String || value['identity'] is! Map) return null;
    final identity = value['identity'] as Map;
    if (identity.length != identityKeys.length || identityKeys.any((key) => identity[key] is! String)) return null;
    return AutomaticMemoryPermit(value['feature'] as String, value['enabled'] as bool,
      value['version'] as String, {for (final key in identityKeys) key: identity[key] as String});
  }
}
