import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/grounding/information_seeking_question_guard.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

DesireSnapshot _snapshot(DriveKey primary, double value) => DesireSnapshot(
      drives: {
        for (final drive in DriveKey.values)
          drive: drive == DriveKey.fatigue ? 0.12 : 0.18,
        primary: value,
      },
    );

CompanionThought _thought({
  String id = 'thought-1',
  String text = '我很好奇他为什么突然换了决定。',
  String drive = 'curiosity',
  String source = 'conversation_turn:user-1',
  double strength = 0.82,
}) {
  final now = DateTime(2026, 9, 2, 21);
  return CompanionThought(
    id: id,
    text: text,
    driveKey: drive,
    kind: 'flit',
    strength: strength,
    bornAt: now,
    updatedAt: now,
    source: source,
  );
}

ChatMessage _message(String id, String role, String content, int minute) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026, 9, 2, 20, minute),
    );

void main() {
  test('the same user emotion does not force one support-agent reaction', () {
    final attachment = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.attachment, 0.91),
      thoughts: const [],
      latestUserText: '好烦。',
    );
    final fatigue = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.fatigue, 0.91),
      thoughts: const [],
      latestUserText: '好烦。',
    );
    final reflection = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.reflection, 0.91),
      thoughts: const [],
      latestUserText: '好烦。',
    );

    expect(attachment.primary, ConversationInitiativeMode.seekAttention);
    expect(fatigue.primary, ConversationInitiativeMode.showOwnNeed);
    expect(reflection.primary, ConversationInitiativeMode.shareOwnView);
    expect({
      attachment.primary,
      fatigue.primary,
      reflection.primary,
    }, hasLength(3));
  });

  test('a real user question is answered instead of escaped through probing', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.attachment, 0.91),
      thoughts: const [],
      latestUserText: '这个功能为什么会失效？',
    );

    expect(plan.primary, ConversationInitiativeMode.answerUser);
    expect(plan.speechAct, ConversationSpeechAct.answer);
    expect(plan.askAuthorized, isFalse);
  });

  test('explicit user jump follows the new direction without reviving old thought', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.curiosity, 0.92),
      thoughts: [_thought()],
      latestUserText: '换个话题，我刚才看到一只橘猫。',
    );

    expect(plan.primary, ConversationInitiativeMode.followUserJump);
    expect(plan.topicMove, ConversationTopicMove.followUserJump);
    expect(plan.askAuthorized, isFalse);
    expect(plan.curiosityGateReason, 'user_redirected');
  });

  test('handing over topic choice opens a new own topic, not old user history', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.reflection, 0.92),
      thoughts: [_thought(drive: 'reflection')],
      latestUserText: '找个话题聊聊呗，你有什么想说的吗？',
    );

    expect(plan.primary, ConversationInitiativeMode.openOwnTopic);
    expect(plan.topicMove, ConversationTopicMove.openOwnTopic);
    expect(plan.speechAct, ConversationSpeechAct.selfShare);
    expect(plan.sourceThoughtId, isNull);
  });

  test('recent interview rhythm softly blocks a non-urgent curiosity probe', () {
    final recent = [
      _message('a1', 'assistant', '「发生什么事了？」', 1),
      _message('u1', 'user', '工作有点烦。', 2),
      _message('a2', 'assistant', '「为什么会这样？」', 3),
      _message('u2', 'user', '临时加班。', 4),
    ];
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.curiosity, 0.42),
      thoughts: [_thought(strength: 0.25)],
      recent: recent,
      latestUserText: '反正就是这样。',
      now: DateTime(2026, 9, 2, 21),
    );

    expect(plan.questionPressureBand, 'high');
    expect(plan.askAuthorized, isFalse);
    expect(plan.curiosityGateReason, 'question_pressure');
    expect(plan.primary, ConversationInitiativeMode.branchFromDetail);
  });

  test('a strong specific curiosity can cross the soft question-pressure gate', () {
    final recent = [
      _message('a1', 'assistant', '「发生什么事了？」', 1),
      _message('u1', 'user', '工作有点烦。', 2),
      _message('a2', 'assistant', '「为什么会这样？」', 3),
      _message('u2', 'user', '临时加班。', 4),
    ];
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.curiosity, 0.98),
      thoughts: [_thought(strength: 0.98)],
      recent: recent,
      latestUserText: '反正就是这样。',
      now: DateTime(2026, 9, 2, 21),
    );

    expect(plan.questionPressureBand, 'high');
    expect(plan.askAuthorized, isTrue);
    expect(plan.primary, ConversationInitiativeMode.probeUserTopic);
  });

  test('release language closes instead of manufacturing a new question', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.curiosity, 0.95),
      thoughts: [_thought()],
      latestUserText: '算了不说了。',
    );

    expect(plan.primary, ConversationInitiativeMode.releaseTopic);
    expect(plan.speechAct, ConversationSpeechAct.pauseOrClose);
    expect(plan.askAuthorized, isFalse);
  });

  test('unauthorized guard catches support-agent information requests', () {
    final result = InformationSeekingQuestionGuard.evaluate(
      text: '「发生什么事了？能和我说说吗？」',
      askAuthorized: false,
    );

    expect(result.allowed, isFalse);
    expect(result.reason, 'unauthorized_information_request');
  });

  test('guard preserves teasing rhetorical questions and authorized asks', () {
    final teasing = InformationSeekingQuestionGuard.evaluate(
      text: '「咋了，终于发现自己是猪了？」',
      askAuthorized: false,
    );
    final authorized = InformationSeekingQuestionGuard.evaluate(
      text: '「谁惹你了？」',
      askAuthorized: true,
    );

    expect(teasing.allowed, isTrue);
    expect(authorized.allowed, isTrue);
  });

  test('prompt keeps reasoning visible while making question authority explicit', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: _snapshot(DriveKey.reflection, 0.90),
      thoughts: [_thought(drive: 'reflection', text: '我想到另一个相似的细节。')],
    );
    final prompt = plan.promptSection();

    expect(prompt, contains('按本轮主动作实际行动'));
    expect(prompt, contains('追问授权=无'));
    expect(prompt, contains('用户换题时直接跟随'));
    expect(prompt, isNot(contains('隐藏思考链')));
  });
}
