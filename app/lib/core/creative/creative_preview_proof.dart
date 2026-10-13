/// Admission of facts measured by the native WebView preview. These fields
/// carry counts and hashes only, never a page's saved values or private choices.
class CreativePreviewProof {
  static const fields = ['proof_version', 'source_hash', 'restore_required',
    'restore_verified', 'baseline_verified', 'checkpoint_verified', 'save_seq',
    'reload_generation', 'assertion_count', 'changed_count', 'restored_count', 'proof_phase'];

  static List<Map<String, String>> assertions(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 4) throw const FormatException('恢复断言最多4项');
    final result = <Map<String, String>>[];
    for (final item in value) {
      if (item is! Map || item['selector'] is! String || item['state_path'] is! String ||
          !{'text', 'value', 'checked'}.contains(item['property'])) {
        throw const FormatException('恢复断言需要 selector、property 和公开 state_path');
      }
      final selector = (item['selector'] as String).trim();
      final path = (item['state_path'] as String).trim();
      final normalized = path.startsWith(r'$.') ? path.substring(2) : path;
      final tokens = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|\[(?:0|[1-9][0-9]{0,3})\]').allMatches(normalized).toList();
      if (selector.isEmpty || selector.length > 240 || path.length > 160 ||
          !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[(?:0|[1-9][0-9]{0,3})\])*$').hasMatch(normalized) ||
          tokens.length > 8 || tokens.any((t) => {'__proto__', 'prototype', 'constructor'}.contains(t.group(0)))) {
        throw const FormatException('恢复断言选择器或状态路径无效');
      }
      result.add({'selector': selector, 'property': item['property'] as String, 'state_path': path});
    }
    return result;
  }

  static Map<String, Object?> project(Map? result) => {
    for (final field in fields) if (result?.containsKey(field) == true) field: result![field],
  };

  static List<String> errors(Map? result, {required String sourceHash,
      required bool companion, required int assertionCount}) {
    if (result == null || result['proof_version'] != 2 || result['source_hash'] != sourceHash) {
      return ['当前源码缺少版本2原生试玩证明，请重新运行 work_preview'];
    }
    final saves = result['save_count'];
    if (saves is! int || saves < 0) return ['试玩保存计数无效'];
    final requiredRestore = companion || saves > 0;
    if (result['restore_required'] != requiredRestore) return ['试玩恢复要求与实际保存行为不一致'];
    if (!requiredRestore) {
      return result['proof_phase'] == 'stateless' ? [] : ['无状态试玩阶段不完整'];
    }
    final count = result['assertion_count'];
    final changed = result['changed_count'];
    final restored = result['restored_count'];
    final seq = result['save_seq'];
    final generation = result['reload_generation'];
    final reloads = result['reload_count'];
    if (saves < 1 || result['baseline_verified'] != true ||
        result['checkpoint_verified'] != true || result['restore_verified'] != true ||
        result['proof_phase'] != 'restored' || count is! int || count != assertionCount || count < 1 || count > 4 ||
        changed is! int || changed < 1 || changed > count || restored != count ||
        seq is! int || seq < 1 || seq > saves || generation is! int || generation < 2 ||
        reloads is! int || reloads < 1) {
      return ['尚未证明本次保存的进度在独立重开后恢复；需要有实际变化的公开状态和DOM恢复断言'];
    }
    return [];
  }
}
