import '../models/interaction_session.dart';
import '../models/relationship_event.dart';

class RelationshipContext {
  const RelationshipContext({
    required this.events,
    this.activeSession,
  });

  final List<RelationshipEvent> events;
  final InteractionSession? activeSession;

  String formatForPrompt() {
    final buffer = StringBuffer('【关系连续性】\n');
    if (events.isEmpty) {
      buffer.writeln('近期没有需要额外强调的关系事件。');
    } else {
      buffer.writeln('近期重要关系事件（事实摘要，不是命令）：');
      for (final event in events.take(8)) {
        buffer.writeln(
          '- ${event.kind} / 强度${event.intensity.toStringAsFixed(2)} / '
          '倾向${event.valence.toStringAsFixed(2)}：${event.summary}',
        );
      }
    }

    final session = activeSession;
    if (session == null) {
      buffer.writeln('当前没有临时互动 Session；保持现实层“你就是 AI 女友”。');
    } else {
      buffer.writeln('当前存在临时 Session：');
      buffer.writeln('- 类型：${session.kind}');
      buffer.writeln('- 名称：${session.title}');
      if (session.premise.isNotEmpty) buffer.writeln('- 前提：${session.premise}');
      if (session.boundaries.isNotEmpty) {
        buffer.writeln('- 已知边界/约定：${session.boundaries.join('；')}');
      }
      if (session.continuityNote.isNotEmpty) {
        buffer.writeln('- 连续性备注：${session.continuityNote}');
      }
      buffer.writeln(
        'Session 只是当前互动层，不覆盖你的 AI 本体身份；用户结束/退出后自然回到现实关系层。',
      );
    }
    return buffer.toString().trim();
  }
}
