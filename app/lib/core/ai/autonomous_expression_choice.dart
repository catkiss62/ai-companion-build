import '../models/chat_message.dart';
import '../models/chat_segment.dart';
import '../models/world_book_turn_context.dart';

/// Optional turn-local guidance. The existing body model chooses expression in
/// the same request; no random persona, new planner, quota or durable trait.
class AutonomousExpressionChoice {
  static const settingKey = 'autonomous_expression_choice_v1';
  static const diagnosticKey = 'autonomous_expression_snapshot_v1';

  static Map<String, int> structure(Iterable<ChatMessage> recent) {
    final rows = recent.where((m) => m.isAssistant && m.content.trim().isNotEmpty &&
        m.proactiveIntent != 'calendar_reminder' &&
        !WorldBookTurnContext.decode(m.worldBookContextJson).hasRoleplay).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final sample = rows.reversed.take(6).toList();
    var actions = 0, questions = 0, brief = 0;
    for (final m in sample) {
      final segments = m.segments.isEmpty ? ChatSegmentCodec.parseAssistantText(m.content) : m.segments;
      if (segments.any((s) => s.kind == ChatSegmentKind.action)) actions++;
      final dialogue = segments.where((s) => s.kind == ChatSegmentKind.dialogue).toList();
      final ending = dialogue.isEmpty ? m.content : dialogue.last.text;
      if (RegExp(r'[?？][」”"\s]*$').hasMatch(ending)) questions++;
      if (m.content.runes.length <= 80) brief++;
    }
    return {'sample': sample.length, 'with_action': actions, 'question_end': questions, 'brief': brief};
  }

  static String render({required bool enabled, required bool roleplay,
      required bool freshSourceOnly, required Iterable<ChatMessage> recent}) {
    if (!enabled || roleplay) return '';
    final stats = structure(recent);
    final history = !freshSourceOnly && stats['sample']! > 0
        ? '\n近期${stats['sample']}条普通回复的形式观察：${stats['with_action']}条带动作、${stats['question_end']}条以问句结束、${stats['brief']}条较短。这只是形式统计，不是重复判决或必须换写法的指令。'
        : '';
    return '''【自主表达选择】
组织本轮正文时，结合你此刻在意的内容、自己的判断、心情和已有自我理解，选择想怎样说。可简短接住，也可把在意的内容展开；可以直接表达，也可以含蓄试探；可以先说自己的想法、承接、真正有疑问时追问，或自然收尾。玩笑和动作有表达作用时再用，允许纯对白，不需要凑齐“动作—调侃—提问”。
沿着当前交流的语气继续通常就很好；允许不调整，不强制轮换，不按次数禁用同一种表达。用户短回复不等于拒绝话题，不自动迎合或改写成只关心用户；当前明确问题、具体格式和原有角色要求优先。只影响这次怎样表达，不改长期人格、主动联系额度或行动权限。直接写自然正文，不报告选择、打分或分析过程。$history''';
  }
}
