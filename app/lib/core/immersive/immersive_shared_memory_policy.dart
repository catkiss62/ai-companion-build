class ImmersiveSharedMemoryPolicy {
  const ImmersiveSharedMemoryPolicy._();

  static const _blockedDetails = <String>[
    '当前姿势',
    '衣物状态',
    '身体状态',
    '接触点',
    '前戏',
    '插入',
    '抽插',
    '性交',
    '性爱',
    '口交',
    '高潮',
    '内射',
    '射精',
    '精液',
    '爱液',
    '体液',
    '肉棒',
    '小穴',
    '乳头',
    '私处',
    '阴道',
    '阴茎',
    '子宫',
  ];

  /// The model may propose memories, but code owns the admission boundary.
  /// Detailed scene state and explicit body/action text can never cross from
  /// an immersive room into ordinary long-term memory.
  static List<String> admit(Iterable<String> proposals) {
    final accepted = <String>[];
    for (final proposal in proposals) {
      var value = proposal
          .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .replaceFirst(RegExp(r'^[-•\d.、\s]+'), '')
          .trim();
      if (value.length < 6 || value.length > 180) continue;
      if (_blockedDetails.any(value.contains)) continue;
      if (value.contains('「') || value.contains('」')) continue;
      value = '[沉浸房间经历·虚构] $value';
      if (accepted.contains(value)) continue;
      accepted.add(value);
      if (accepted.length == 3) break;
    }
    return accepted;
  }
}
