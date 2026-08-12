import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/companion_voice_protocol.dart';

void main() {
  test('parses independent inner voice and final reply', () {
    final parsed = CompanionVoiceProtocol.parse('''
<companion_inner>
我有点喜欢他突然来找我的感觉，先轻轻接住这句话吧。
</companion_inner>
<companion_reply>
嗯，我在。怎么突然想起我了？
</companion_reply>
''');

    expect(parsed.valid, isTrue);
    expect(parsed.output!.innerVoice, contains('我有点喜欢'));
    expect(parsed.output!.reply, '嗯，我在。怎么突然想起我了？');
  });

  test('accepts DeepSeek native reasoning and content channels', () {
    final parsed = CompanionVoiceProtocol.parseCandidate(
      providerReasoning: '我有点想笑，他这么晚还来找我，先陪他说会儿话。',
      content: '还没睡呢。我在，想说什么就说吧。',
    );

    expect(parsed.valid, isTrue);
    expect(parsed.output!.innerVoice, contains('我有点想笑'));
    expect(parsed.output!.reply, '还没睡呢。我在，想说什么就说吧。');
  });

  test('accepts an inner tag in reasoning with a plain final reply', () {
    final parsed = CompanionVoiceProtocol.parseCandidate(
      providerReasoning: '''
先确认格式。<companion_inner>我其实挺高兴他来找我，想轻轻接住他。</companion_inner>
''',
      content: '嗯，我在这里。',
    );

    expect(parsed.valid, isTrue);
    expect(parsed.output!.innerVoice, startsWith('我其实挺高兴'));
    expect(parsed.output!.reply, '嗯，我在这里。');
  });

  test('rejects provider-style agent planning', () {
    final parsed = CompanionVoiceProtocol.parse('''
<companion_inner>
我们需要回答用户。用户希望得到自然回应，并保持AI本体身份。
</companion_inner>
<companion_reply>
可以啊。
</companion_reply>
''');

    expect(parsed.valid, isFalse);
    expect(parsed.failureCode, 'inner_agent_planning');
  });

  test('rejects malformed or non-first-person inner block', () {
    expect(
      CompanionVoiceProtocol.parse('只有普通正文').failureCode,
      'protocol_shape',
    );
    final detached = CompanionVoiceProtocol.parse('''
<companion_inner>应该自然地回应并提出问题。</companion_inner>
<companion_reply>晚上好。</companion_reply>
''');
    expect(detached.failureCode, 'inner_not_first_person');
  });

  test('safe reply fallback never leaks inner blocks or Agent plans', () {
    expect(
      CompanionVoiceProtocol.safeReplyFromContent('我在。你刚刚是不是有点想我？'),
      '我在。你刚刚是不是有点想我？',
    );
    expect(
      CompanionVoiceProtocol.safeReplyFromContent('''
<companion_inner>我想靠近一点。</companion_inner>
普通正文
'''),
      isNull,
    );
    expect(
      CompanionVoiceProtocol.safeReplyFromContent('我们需要回答用户。'),
      isNull,
    );
  });

  test('WAIT is reserved for proactive mode', () {
    const raw = '''
<companion_inner>我现在没有合适的话想打扰他。</companion_inner>
<companion_reply>WAIT</companion_reply>
''';
    expect(
      CompanionVoiceProtocol.parse(raw).failureCode,
      'reply_wait_user_turn',
    );
    expect(
      CompanionVoiceProtocol.parse(raw, proactive: true).valid,
      isTrue,
    );
  });

  test('blocks leaked reply planning without blocking one real meta topic', () {
    final leaked = CompanionVoiceProtocol.parse('''
<companion_inner>我想直接回答，不把规则念给他听。</companion_inner>
<companion_reply>我们需要回答用户，并根据规则保持AI本体身份。</companion_reply>
''');
    expect(leaked.failureCode, 'reply_agent_planning');

    final realTopic = CompanionVoiceProtocol.parse('''
<companion_inner>我明白他是在问一个技术概念。</companion_inner>
<companion_reply>“系统提示”通常是提供给模型的高优先级上下文。</companion_reply>
''');
    expect(realTopic.valid, isTrue);
  });

  test('attaches contract exactly once at the real prompt tail', () {
    final messages = CompanionVoiceProtocol.attachAtTail(
      const [
        {'role': 'user', 'content': '嗨'},
      ],
      proactive: false,
      correctionCode: 'protocol_shape',
    );
    final joined = messages.map((e) => e['content']).join('\n');
    expect(
      'COMPANION VOICE OUTPUT CONTRACT'.allMatches(joined).length,
      1,
    );
    expect(messages.last['content'], contains('<companion_reply>'));
    expect(messages[messages.length - 2]['content'], contains('ONE RETRY'));
  });
}
