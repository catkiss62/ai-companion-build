import '../database/app_database.dart';
import '../models/interaction_session.dart';
import '../models/reference_item.dart';
import '../models/rule_layer.dart';

class RuleLayerBundle {
  const RuleLayerBundle({
    required this.layers,
    required this.intimacyActive,
    required this.referenceTriggered,
  });

  final List<RuleLayer> layers;
  final bool intimacyActive;
  final bool referenceTriggered;

  String formatForPrompt() {
    if (layers.isEmpty) return '';
    final buffer = StringBuffer('【当前行为规则层】\n');
    for (final layer in layers) {
      buffer
        ..writeln('\n### ${layer.title}')
        ..writeln(layer.content.trim());
    }
    return buffer.toString().trim();
  }
}

class RuleLayerService {
  RuleLayerService(this.db);

  final AppDatabase db;

  Future<RuleLayerBundle> resolve({
    required String latestUserText,
    required InteractionSession? session,
    required List<ReferenceItem> references,
  }) async {
    if ((await db.getSetting('rule_layers_enabled')) == '0') {
      return const RuleLayerBundle(
        layers: [],
        intimacyActive: false,
        referenceTriggered: false,
      );
    }
    final all = await db.listRuleLayers();
    final intimacy = _sessionIsIntimacy(session) || _bootstrapIntimacy(latestUserText);
    final referenceTriggered = intimacy && references.isNotEmpty;
    final selected = <RuleLayer>[];
    for (final layer in all) {
      if (!layer.enabled && layer.key != '01_core') continue;
      final include = switch (layer.loadPolicy) {
        'always' => true,
        'daily' => !intimacy,
        'intimacy' => intimacy,
        'reference_intimacy' => referenceTriggered,
        _ => false,
      };
      if (include) selected.add(layer);
    }
    return RuleLayerBundle(
      layers: selected,
      intimacyActive: intimacy,
      referenceTriggered: referenceTriggered,
    );
  }

  bool _sessionIsIntimacy(InteractionSession? session) {
    if (session == null) return false;
    return session.kind == 'intimacy' || session.kind == 'roleplay_intimacy';
  }

  /// Conservative first-turn bootstrap only. This is deliberately narrower
  /// than a general NSFW classifier so ordinary flirting does not abruptly
  /// switch the entire writing layer.
  bool _bootstrapIntimacy(String text) {
    final lowered = text.toLowerCase();
    const explicit = <String>[
      '进入亲密模式',
      '进入成人模式',
      '成人互动',
      '亲密session',
      'intimacy session',
      'nsfw模式',
      '开始性爱',
      '开始做爱',
    ];
    return explicit.any(lowered.contains);
  }
}
