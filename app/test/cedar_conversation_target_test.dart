import 'package:ai_companion_localfirst/core/mcp/cedar_conversation_target.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = '小游戏: fishing·钓鱼模拟，抛竿卖鱼·作者 | '
      'white_room·白房间自由输入互动叙事·作者';
  final now = DateTime(2026, 9, 29, 22, 50);
  ChatMessage message(String id, String role, String content, int minutesAgo) =>
      ChatMessage(id: id, role: role, content: content,
          createdAt: now.subtract(Duration(minutes: minutesAgo)));

  test('explicit white room request survives 39-minute gap and old fishing', () {
    final previous = [
      message('fishing', 'user', '陪你去钓鱼', 50),
      message('room', 'user', '这个白房间，给我讲讲玩法', 40),
      message('assistant', 'assistant', '下次一起去白房间吧', 39),
    ];
    expect(CedarConversationTarget.recentGameId(
      latestUserText: '好啊，走，去玩白房间游戏', now: now,
      previous: previous, catalog: catalog,
    ), 'white_room');
    expect(CedarConversationTarget.conflictsWithPlan(
      targetGameId: 'white_room',
      calls: [(toolId: 'cedar_toy.play', gameId: 'fishing')],
    ), isTrue);
    expect(CedarConversationTarget.conflictsWithPlan(
      targetGameId: 'white_room',
      calls: [(toolId: 'cedar_toy.get_guide', gameId: 'white_room')],
    ), isFalse);
    expect(CedarConversationTarget.conflictsWithPlan(
      targetGameId: 'white_room',
      calls: [(toolId: 'cedar_toy.play', gameId: '')],
    ), isTrue);
  });

  test('short acceptance inherits the latest user game reference', () {
    expect(CedarConversationTarget.recentGameId(
      latestUserText: '我陪你去呗', now: now,
      previous: [
        message('old', 'user', '陪你去钓鱼', 48),
        message('new', 'user', '这个白房间怎么探索', 5),
        message('reply', 'assistant', '你陪我一起试吧', 1),
      ], catalog: catalog,
    ), 'white_room');
  });

  test('later direct choice replaces prior game target', () {
    expect(CedarConversationTarget.recentGameId(
      latestUserText: '继续钓鱼', now: now,
      previous: [message('new', 'user', '白房间怎么探索', 1)],
      catalog: catalog,
    ), 'fishing');
  });
}
