import '../ai/prompt_builder.dart';
import '../database/app_database.dart';
import '../memory/memory_brain.dart';
import '../models/immersive_room.dart';
import '../personality/personality_catalog.dart';
import '../relationship/relationship_brain.dart';

class ImmersivePromptBuilder {
  ImmersivePromptBuilder(this.db)
      : memoryBrain = MemoryBrain(db),
        relationshipBrain = RelationshipBrain(db);

  final AppDatabase db;
  final MemoryBrain memoryBrain;
  final RelationshipBrain relationshipBrain;

  Future<List<Map<String, Object?>>> build({
    required ImmersiveRoom room,
    required List<ImmersiveMessage> history,
    required String latestUserText,
    required bool nsfwActive,
  }) async {
    final all = await db.listRuleLayers();
    final byKey = {for (final layer in all) layer.key: layer};
    final templates = <String, String>{
      for (final layer in all.where((item) => item.loadPolicy == 'template'))
        layer.key: layer.content,
    };
    final identity = templates['08_runtime_identity'] ?? PromptBuilder.identityPrompt;
    final selected = <String>[];
    final selectedKeys = <String>[
      '01_core',
      '01_relationship',
      '03_personality_seed',
      '03_appearance_identity',
      '04_memory_rules',
      'immersive_07_global',
      if (nsfwActive) '04_intimacy_core',
      if (nsfwActive) 'immersive_07_nsfw_source',
    ];
    for (final key in selectedKeys) {
      final layer = byKey[key];
      if (layer == null || (!layer.enabled && !layer.locked)) continue;
      selected.add('【${layer.title}】\n${layer.content.trim()}');
    }

    final profileTrial = await db.activePersonalityTrial();
    final specialTrial = await db.activeSpecialStyleTrial();
    final baseKey = profileTrial?.baseKey ??
        (await db.getSetting('personality_base_key') ?? 'neutral');
    final postureKey = profileTrial?.postureKey ??
        (await db.getSetting('personality_posture_key') ?? 'equal');
    final personality = PersonalityCatalog.compileProfile(
      baseKey,
      postureKey,
      trial: profileTrial != null,
      templates: templates,
    );
    final special = specialTrial == null
        ? ''
        : PersonalityCatalog.compileSpecial(
            specialTrial.styleKey,
            intimacyActive: nsfwActive,
            templates: templates,
          );

    final memory = await memoryBrain.buildContext(
      latestUserText,
      relevantLimit: 10,
      retrievalMode: 'immersive_room',
    );
    final relationship = await relationshipBrain.buildContext();
    final context = StringBuffer()
      ..writeln('【共享关系与长期记忆】')
      ..writeln(memoryBrain.formatForPrompt(memory))
      ..writeln(relationship.formatForPrompt())
      ..writeln()
      ..writeln('【当前正式性格】')
      ..writeln(personality);
    if (special.trim().isNotEmpty) {
      context
        ..writeln()
        ..writeln('【当前特殊风格试穿】')
        ..writeln(special.trim());
    }
    if (room.entryContext.trim().isNotEmpty) {
      context
        ..writeln()
        ..writeln('【本房间入场背景】')
        ..writeln(room.entryContext.trim());
    }
    if (room.rollingSummary.trim().isNotEmpty) {
      context
        ..writeln()
        ..writeln('【本房间较早剧情摘要】')
        ..writeln(room.rollingSummary.trim());
    }
    if (room.sceneLedger.trim().isNotEmpty) {
      context
        ..writeln()
        ..writeln('【本房间当前现场账】')
        ..writeln(room.sceneLedger.trim());
    }

    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': identity.trim()},
      {
        'role': 'system',
        'content': '【沉浸房间专用规则层】\n${selected.join('\n\n')}',
      },
      {'role': 'system', 'content': context.toString().trim()},
      {
        'role': 'system',
        'content': '【当前房间的小说规则】\n${room.novelRules.trim()}',
      },
      ..._boundedHistory(
        history.skip(room.summarizedMessageCount).toList(growable: false),
      ),
      {
        'role': 'system',
        'content': '''【本轮最终锁】
直接续写小说正文，不输出标题、规则、总结、状态栏、[TEXT]、[MIND]、JSON 或 <emotion> 标签。段落之间只空一行。
可见 reasoning_content 与正文中的完整句子必须使用自然简体中文；专业名词可保留英文。
普通轮以1200至1600个可见中文字符为目标且不得少于1000；只有当前用户明确输入[动作加速]或[场景快进]时才写400至700字。
只推进当前一个叙事节拍，不替玩家新增台词、关键决定或重大动作，在需要他继续输入的位置自然停下。''',
      },
      {'role': 'user', 'content': latestUserText},
    ];
    return messages;
  }

  List<Map<String, Object?>> _boundedHistory(
    List<ImmersiveMessage> history,
  ) {
    const characterBudget = 22000;
    var used = 0;
    final selected = <ImmersiveMessage>[];
    for (final message in history.reversed) {
      if (used + message.content.length > characterBudget && selected.isNotEmpty) {
        break;
      }
      selected.add(message);
      used += message.content.length;
    }
    return selected.reversed
        .map(
          (message) => <String, Object?>{
            'role': message.role,
            'content': message.content,
          },
        )
        .toList(growable: false);
  }

  static List<Map<String, Object?>> continuationMessages(
    List<Map<String, Object?>> initial,
    String partial,
  ) => [
        ...initial,
        {'role': 'assistant', 'content': partial},
        {
          'role': 'system',
          'content': '''【同一条正文的无缝续写】
上一段尚未达到本轮硬下限。只从最后一句之后无缝继续，不复述、不重写、不加标题或说明；保持同一视角、现场、阶段和语义，直到本轮总正文达到至少1000个可见中文字符，再在自然互动节点停下。''',
        },
      ];
}
