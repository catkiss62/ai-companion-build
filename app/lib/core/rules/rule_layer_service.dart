import '../database/app_database.dart';
import '../models/interaction_session.dart';
import '../models/reference_item.dart';
import '../models/rule_layer.dart';
import '../personality/personality_catalog.dart';
import 'rule_layer_grouping.dart';
import 'intimacy_prompt_sections.dart';

class RuleLayerBundle {
  const RuleLayerBundle({
    required this.layers,
    required this.intimacyActive,
    required this.referenceTriggered,
    this.specialStylePrompt = '',
    this.personalityBaseKey = PersonalityCatalog.noneKey,
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

  String get intimacyPreflight {
    for (final layer in layers) {
      if (layer.key != '04_intimacy_core') continue;
      return IntimacyPromptSections.parse(layer.content).latePrompt();
    }
    return '';
  }

  String formatForPrompt() {
    if (layers.isEmpty) return '';
    final buffer = StringBuffer('【当前行为规则层】\n');
    for (final group in groupRuleLayers(layers)) {
      buffer.writeln('\n## ${group.title}');
      for (final layer in group.layers) {
        final content = layer.key == '04_intimacy_core'
            ? IntimacyPromptSections.parse(layer.content).body
            : layer.content.trim();
        buffer
          ..writeln('\n### ${ruleLayerSectionTitle(layer)}')
          ..writeln(content);
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
    final specialTrial = specialStyleKeyOverride == null
        ? await db.activeSpecialStyleTrial()
        : null;
    final specialStyleKey =
        specialStyleKeyOverride ?? specialTrial?.styleKey ?? '';
    final selected = <RuleLayer>[];
    for (final layer in all) {
      if (!layer.enabled && !layer.locked) continue;
      final include = switch (layer.loadPolicy) {
        'always' => true,
        'daily' => true,
        'intimacy' => intimacy,
        // The bundled 05+06 rules are one complete NSFW pipeline. The
        // secondary reference switch still controls imported retrieval data,
        // but must never strand the built-in rendering reference.
        'reference_intimacy' => intimacy &&
            (layer.key == '06_intimacy_reference' || referenceTriggered),
        _ => false,
      };
      if (include && layer.content.trim().isNotEmpty) {
        selected.add(layer);
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
      personalityBaseKey: PersonalityCatalog.noneKey,
      personalityTrialActive: false,
      personalityTemplatePresent: true,
      personalityExecutionAnchor: '',
      templates: templates,
    );
  }

}
