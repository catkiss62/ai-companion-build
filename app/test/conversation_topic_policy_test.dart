import 'package:ai_companion_localfirst/core/desire/conversation_topic_policy.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';

void main() {
  final now = DateTime(2026, 10, 5, 21);
  const oldText = '我想在钓鱼游戏里试一试不同的鱼饵看看效果';
  const newText = '今天这条鱼终于上钩了，换到浅水区之后成功了';
  CompanionThought thought(String id, String text) => CompanionThought(
    id: id, text: text, driveKey: 'social', kind: 'flit', strength: .8,
    bornAt: now, updatedAt: now, topicKey: 'game.fishing', source: 'internal');
  DesireCoreCandidate candidate(String id, double score) => DesireCoreCandidate(
    drive: DriveKey.social, score: score, action: 'share_thought',
    reason: '', reasonSource: 'internal', thoughtId: id);
  ChatMessage message(String role, DateTime at) => ChatMessage(
    id: 'history', role: role, content: oldText, createdAt: at);
  final candidates = [candidate('old', .8), candidate('new', .72)];
  final thoughts = [thought('old', oldText), thought('new', newText)];
  DesireCoreCandidate choose(List<ChatMessage> history) =>
    ConversationTopicPolicy.preferNovel(candidates: candidates,
      thoughts: thoughts, recent: history, now: now);

  test('repeated body loses to a fresh thought despite identical topic key', () {
    expect(choose([message('assistant', now)]).thoughtId, 'new');
    expect(candidates.first.score, .8); // Never mutate Desire competition.
  });
  test('user wording is not evidence that AI already shared the content', () {
    expect(choose([message('user', now)]).thoughtId, 'old');
  });
  test('old and future history cannot suppress current expression', () {
    expect(choose([message('assistant', now.subtract(const Duration(days: 2)))]).thoughtId, 'old');
    expect(choose([message('assistant', now.add(const Duration(minutes: 1)))]).thoughtId, 'old');
  });
  test('roleplay history cannot suppress ordinary topics', () {
    expect(choose([ChatMessage(id: 'rp', role: 'assistant', content: oldText,
      createdAt: now, worldBookContextJson:
        const WorldBookTurnContext(roleplaySessionId: 'rp').encode())]).thoughtId, 'old');
  });
  test('no alternative still permits the original topic', () {
    expect(ConversationTopicPolicy.preferNovel(candidates: [candidates.first],
      thoughts: thoughts, recent: [message('assistant', now)], now: now).thoughtId, 'old');
  });
  test('only last eight assistant expressions affect novelty', () {
    final history = [message('assistant', now.subtract(const Duration(minutes: 9))),
      for (var i = 0; i < 8; i++) ChatMessage(id: '$i', role: 'assistant',
        content: '与旧念头无关的内容', createdAt: now.subtract(Duration(minutes: i)))];
    expect(choose(history).thoughtId, 'old');
  });
  final snapshot = DesireSnapshot(drives: {
    for (final d in DriveKey.values) d: d == DriveKey.social ? .95 : .1,
  });
  ConversationInitiativePlan plan(String text) => ConversationInitiativePolicy.select(
    snapshot: snapshot, thoughts: thoughts, latestUserText: text,
    recent: [message('assistant', now)], now: now);
  test('answer, explicit redirect and closing keep their original actions', () {
    expect(plan('这个怎么做？').primary, ConversationInitiativeMode.answerUser);
    expect(plan('对了，我想聊音乐').primary, ConversationInitiativeMode.followUserJump);
    expect(plan('晚安，我去睡了').primary, ConversationInitiativeMode.releaseTopic);
  });
  test('short acknowledgement alone is never a closing classification', () {
    expect(plan('嗯').primary, isNot(ConversationInitiativeMode.releaseTopic));
    expect(plan('哈哈').primary, isNot(ConversationInitiativeMode.releaseTopic));
  });
  test('fresh proactive contract preserves isolation and WAIT', () {
    final prompt = ConversationTopicPolicy.prompt(proactive: true, freshSourceOnly: true);
    expect(prompt, contains('不要从旧聊天、旧线程或记忆补题'));
    expect(prompt, contains('WAIT'));
    expect(prompt, isNot(contains('若上下文已有相关未完成线程')));
  });
}
