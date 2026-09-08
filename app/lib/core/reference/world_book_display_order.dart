import '../models/reference_document.dart';

/// UI-only ordering for the world-book library.
///
/// Database priority continues to control prompt precedence. The display list
/// merely keeps the special-style presets immediately after the personality
/// and relationship-posture presets, without reordering unrelated user items.
class WorldBookDisplayOrder {
  const WorldBookDisplayOrder._();

  static List<ReferenceDocument> arrange(
    Iterable<ReferenceDocument> documents,
  ) {
    final source = documents.toList(growable: false);
    final special = source.where(_isSpecial).toList(growable: false);
    if (special.isEmpty) return source;

    final result = source.where((item) => !_isSpecial(item)).toList();
    var lastPersonalityOrPosture = -1;
    for (var index = 0; index < result.length; index++) {
      if (_isPersonalityOrPosture(result[index])) {
        lastPersonalityOrPosture = index;
      }
    }
    if (lastPersonalityOrPosture < 0) return source;
    result.insertAll(lastPersonalityOrPosture + 1, special);
    return List<ReferenceDocument>.unmodifiable(result);
  }

  static bool _isPersonalityOrPosture(ReferenceDocument document) =>
      document.id.startsWith('builtin.worldbook.personality.') ||
      document.id.startsWith('builtin.worldbook.posture.');

  static bool _isSpecial(ReferenceDocument document) =>
      document.id.startsWith('builtin.worldbook.special.');
}
