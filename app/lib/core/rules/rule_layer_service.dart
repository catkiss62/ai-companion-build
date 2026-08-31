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
    this.personalityBaseKey = 'neutral',
    this.personalityTrialActive = false,
    this.personalityTemplatePresent = false,
    this.personalityExecutionAnchor = '',
    this.templates = const {},
  });

  final List<RuleLayer> layers;
  final bool intimacyActive;
  final bool referenceTriggered;
  final String specialStylePrompt;
  final String personalityBaseKey;
  final bool personalityTrialActive;
  final bool personalityTemplatePresent;
  final String personalityExecutionAnchor;
  final Map<String, String> templates;

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
        ..writeln('\n## 当前特殊表达')
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
    bool? nsfwActive,
    bool? nsfwReferenceActive,
    String? specialStyleKeyOverride,
  }) async {
    final all = await db.listRuleLayers();
    final templates = <String, String>{
      for (final layer in all.where((item) => item.loadPolicy == 'template'))
        layer.key: layer.content,
    };
    if ((await db.getSetting('rule_layers_enabled')) == '0') {
      return RuleLayerBundle(
        layers: [],
        intimacyActive: false,
        referenceTriggered: false,
        templates: templates,
      );
    }
    // The router selects adult rendering/reference depth. Daily relationship
    // rules stay loaded in every mode. A Session stores scene continuity and
    // is never a permission gate.
    final intimacy = nsfwActive ??
        ((await db.getSetting('nsfw_active')) == '1');
    final referenceTriggered = intimacy &&
        (nsfwReferenceActive ??
            ((await db.getSetting('nsfw_reference_active')) == '1'));
    final profileTrial = await db.activePersonalityTrial();
    final specialTrial = specialStyleKeyOverride == null
        ? await db.activeSpecialStyleTrial()
        : null;
    final specialStyleKey =
        specialStyleKeyOverride ?? specialTrial?.styleKey ?? '';
    final longTermBase =
        await db.getSetting('personality_base_key') ?? 'neutral';
    final longTermPosture =
        await db.getSetting('personality_posture_key') ?? 'equal';
    final effectiveBaseKey = profileTrial?.baseKey ?? longTermBase;
    final effectiveBase = PersonalityCatalog.base(effectiveBaseKey).key;
    final personalityTemplateKey =
        PersonalityCatalog.basePromptKey(effectiveBase);
    final selected = <RuleLayer>[];
    for (final layer in all) {
      if (!layer.enabled && !layer.locked) continue;
      final include = switch (layer.loadPolicy) {
        'always' => true,
        'daily' => true,
        'intimacy' => intimacy,
        'reference_intimacy' => referenceTriggered,
        _ => false,
      };
      if (include) {
        selected.add(layer);
        if (layer.key == '03_personality_seed') {
          final baseKey = effectiveBase;
          final postureKey = profileTrial?.postureKey ?? longTermPosture;
          selected.add(RuleLayer(
            key: '03_personality_expression',
            title: profileTrial == null
                ? 'Current Personality Expression'
                : 'Current Personality Trial',
            content: PersonalityCatalog.compileProfile(
              baseKey,
              postureKey,
              trial: profileTrial != null,
              templates: templates,
            ),
            loadPolicy: 'always',
            enabled: true,
            locked: true,
            updatedAt: profileTrial?.startedAt ?? DateTime.now(),
          ));
        }
      }
    }
    return RuleLayerBundle(
      layers: selected,
      intimacyActive: intimacy,
      referenceTriggered: referenceTriggered,
      specialStylePrompt: specialStyleKey.isEmpty ||
              !PersonalityCatalog.isKnownSpecial(specialStyleKey)
          ? ''
          : PersonalityCatalog.compileSpecial(
              specialStyleKey,
              intimacyActive: intimacy,
              templates: templates,
            ),
      personalityBaseKey: effectiveBase,
      personalityTrialActive: profileTrial != null,
      personalityTemplatePresent: effectiveBase == 'neutral' ||
          (templates[personalityTemplateKey]?.trim().isNotEmpty ?? false),
      personalityExecutionAnchor:
          PersonalityCatalog.executionAnchor(effectiveBase),
      templates: templates,
    );
  }

}
