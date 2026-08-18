import '../database/app_database.dart';
import '../models/interaction_session.dart';
import '../models/reference_item.dart';
import '../models/rule_layer.dart';
import '../personality/personality_catalog.dart';
import 'rule_layer_grouping.dart';

class RuleLayerBundle {
  const RuleLayerBundle({
    required this.layers,
    required this.intimacyActive,
    required this.referenceTriggered,
    this.specialStylePrompt = '',
  });

  final List<RuleLayer> layers;
  final bool intimacyActive;
  final bool referenceTriggered;
  final String specialStylePrompt;

  String formatForPrompt() {
    if (layers.isEmpty) return '';
    final buffer = StringBuffer('【当前行为规则层】\n');
    for (final group in groupRuleLayers(layers)) {
      buffer.writeln('\n## ${group.title}');
      for (final layer in group.layers) {
        buffer
          ..writeln('\n### ${ruleLayerSectionTitle(layer)}')
          ..writeln(layer.content.trim());
      }
    }
    if (specialStylePrompt.trim().isNotEmpty) {
      buffer
        ..writeln('\n## 当前特殊表达与现实边界')
        ..writeln(specialStylePrompt.trim());
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
    final intimacy =
        _sessionIsIntimacy(session) || _bootstrapIntimacy(latestUserText);
    final referenceTriggered = intimacy && references.isNotEmpty;
    final profileTrial = await db.activePersonalityTrial();
    final specialTrial = await db.activeSpecialStyleTrial();
    final selected = <RuleLayer>[];
    for (final layer in all) {
      if (!layer.enabled && !layer.locked) continue;
      final include = switch (layer.loadPolicy) {
        'always' => true,
        'daily' => !intimacy,
        'intimacy' => intimacy,
        'reference_intimacy' => referenceTriggered,
        _ => false,
      };
      if (include) {
        if (layer.key == '03_personality_seed' && profileTrial != null) {
          selected.add(RuleLayer(
            key: layer.key,
            title: 'Current Personality Structure',
            // Recompile from stable keys so an app update can improve the
            // reaction/expression contract even when a trial was already
            // active before the update. The stored snapshot remains useful
            // for audit/backup but is not an immutable prompt cache.
            content: PersonalityCatalog.compileProfile(
              profileTrial.baseKey,
              profileTrial.postureKey,
              trial: true,
            ),
            loadPolicy: layer.loadPolicy,
            enabled: true,
            locked: false,
            updatedAt: profileTrial.startedAt,
          ));
        } else {
          selected.add(layer);
        }
      }
    }
    return RuleLayerBundle(
      layers: selected,
      intimacyActive: intimacy,
      referenceTriggered: referenceTriggered,
      specialStylePrompt: specialTrial == null
          ? ''
          : PersonalityCatalog.compileSpecial(
              specialTrial.styleKey,
              intimacyActive: intimacy,
            ),
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
