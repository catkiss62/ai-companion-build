import 'package:ai_companion_localfirst/core/mcp/cedar_toy_arcade_skill.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 8);
  ChatMessage turn(String role, String content, int minutesAgo) => ChatMessage(
        id: '$role-$minutesAgo', role: role, content: content,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
      );
  ChatMessage? invite(List<ChatMessage> turns, String latest) =>
      CedarToyArcadeSkill.pendingUserInvitation(
        previous: turns, latestUserText: latest, now: now,
      );

  test('user invitation enters on demand; short consent can refer back twice', () {
    expect(CedarToyArcadeSkill.isRelevant('陪你钓鱼？看你今天都没钓鱼'), isTrue);
    final first = turn('user', '陪你钓鱼？看你今天都没钓鱼', 3);
    final second = turn('assistant', '走啊，我也想试试。', 2);
    expect(invite([first, second], '走着'), first);
    expect(invite([first, second, turn('user', '走着', 1),
      turn('assistant', '马上开始。', 0)], '开始吧'), first);
  });

  test('unrelated, declined and stale turns never reopen planning', () {
    final first = turn('user', '陪你钓鱼？', 14);
    final answer = turn('assistant', '可以呀。', 13);
    expect(invite([first, answer], '抱抱我'), isNull);
    expect(invite([first, answer, turn('user', '改天吧', 2),
      turn('assistant', '好。', 1)], '开始吧'), isNull);
    expect(invite([turn('user', '陪你钓鱼？', 16), answer], '走着'), isNull);
    expect(invite([turn('user', '今天游戏还不错', 2), answer], '走着'), isNull);
    expect(invite([first], '走着'), isNull);
  });
}
