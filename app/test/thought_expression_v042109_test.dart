import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_self_judge.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_outcome_verifier.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const candidate = <String, Object?>{'kind': 'public_web',
  'title': 'Whale song changes across years',
  'summary': 'Repeated phrases change within a population.',
  'key_points': ['Recordings show changing themes, not a fixed language.']};
const plan = ConversationInitiativePlan(primary: ConversationInitiativeMode.shareOwnView,
  topicMove: ConversationTopicMove.stay, speechAct: ConversationSpeechAct.selfShare,
  drive: DriveKey.curiosity, action: 'share_thought', scoreBand: 'high',
  hasThought: true, sourceProvenance: 'public_web_candidate', askAuthorized: false,
  curiosityGateReason: 'no_specific_gap', questionPressureBand: 'none', alternatives: [],
  sourceThoughtId: 'selected');

void main() {
  CompanionThought thought(String text) => CompanionThought(id: 'selected', text: text,
    driveKey: 'curiosity', kind: 'flit', strength: .7,
    bornAt: DateTime(2026), updatedAt: DateTime(2026), source: 'memory:fixture', topicKey: 'whale.song');

  test('common Chinese fragments and even exact wording alone cannot settle a thought', () {
    for (final reply in ['我等到了夸奖，就是开心。', '我查到了鲸歌变化，就是想和你分享。']) {
      final result = ConversationOutcomeVerifier.verify(finalText: reply, plan: plan,
        sourceThought: thought('我查到了鲸歌变化，就是想和你分享。'));
      expect(result.shouldMarkThoughtActed, isFalse);
    }
  });

  test('confirmed natural paraphrase can settle a selected thought without character overlap', () {
    final result = ConversationOutcomeVerifier.verify(finalText: 'The tunes evolve over the years.',
      plan: plan, sourceThought: thought('同一群体的鲸歌主题会随时间变化。'), sourceExpressionConfirmed: true);
    expect(result.shouldMarkThoughtActed, isTrue);
    expect(result.reason, 'expressed_match');
  });

  for (final answer in ['yes', 'no', 'missing', 'invalid']) {
    test('$answer expression answer shares one JEV request and preserves the heat decision', () async {
      Map<String, dynamic>? requestBody;
      var requests = 0, fallbackCalls = 0;
      bool? confirmed;
      final judge = PlayfulSelfJudge(client: DeepSeekClient(),
        jevGateway: JevDecisionGateway(enabledReader: () async => true,
          keyReader: () async => 'test', clientFactory: () => MockClient((request) async {
            requests++;
            requestBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({'answers': {
              'route': {'type': 'choice', 'choice': 'playful', 'confidence': .1,
                'probabilities': {'playful': 1.0}},
              if (answer != 'missing') 'thought_expressed': {
                'type': 'choice', 'choice': answer == 'invalid' ? 'unknown' : answer,
                'confidence': .1, 'probabilities': {answer == 'invalid' ? 'unknown' : answer: 1.0}},
            }}), 200);
          })), fallbackClassifier: (_, __) async { fallbackCalls++; return PlayfulSelfActivity.strong; });
      final reply = '${List.filled(1700, 'a').join()} The tunes evolve over the years.';
      final activity = await judge.classify(apiKey: 'test', endpoint: 'https://unused.invalid',
        userText: 'How interesting.', assistantText: reply, thoughtCandidate: candidate,
        onThoughtExpressionVerified: (value) => confirmed = value);
      // Assert outside the transport: gateway error handling must not hide a failed assertion.
      expect(requests, 1);
      expect(fallbackCalls, 0);
      expect(activity, PlayfulSelfActivity.playful);
      expect(confirmed, answer == 'yes');
      expect(requestBody!['state']['thought_candidate'], candidate);
      expect(requestBody!['state']['thought_reply_full'], reply);
      expect((requestBody!['state']['assistant_reply'] as String).length, 1500);
      final instructions = requestBody!['questions']['thought_expressed']['instructions'] as String;
      expect(instructions, contains('natural paraphrases'));
      expect(instructions, contains('Common words'));
      final settled = ConversationOutcomeVerifier.verify(finalText: reply, plan: plan,
        sourceThought: thought('鲸歌的主题随年份改变。'), sourceExpressionConfirmed: confirmed!);
      expect(settled.shouldMarkThoughtActed, answer == 'yes');
    });
  }

  test('no selected source adds no expression question and cannot acquire a stale confirmation', () async {
    Map<String, dynamic>? sent;
    var confirmed = true;
    final judge = PlayfulSelfJudge(client: DeepSeekClient(),
      jevGateway: JevDecisionGateway(enabledReader: () async => true, keyReader: () async => 'test',
        clientFactory: () => MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'answers': {'route': {
            'type': 'choice', 'choice': 'none', 'confidence': .8, 'probabilities': {'none': 1.0}}}}), 200);
        })));
    expect(await judge.classify(apiKey: 'test', endpoint: 'https://unused.invalid', userText: 'Hi',
      assistantText: 'Hi there.', onThoughtExpressionVerified: (value) => confirmed = value), PlayfulSelfActivity.none);
    expect(confirmed, isFalse);
    expect(sent!['questions'], isNot(contains('thought_expressed')));
    expect(sent!['state'], isNot(contains('thought_candidate')));
  });

  test('unavailable JEV and legacy fallback cannot invent an expression confirmation', () async {
    var confirmed = true, fallbackCalls = 0;
    final judge = PlayfulSelfJudge(client: DeepSeekClient(),
      jevGateway: JevDecisionGateway(enabledReader: () async => false),
      fallbackClassifier: (_, __) async { fallbackCalls++; return PlayfulSelfActivity.none; });
    await judge.classify(apiKey: 'test', endpoint: 'https://unused.invalid', userText: 'Hi', assistantText: 'Hi.',
      thoughtCandidate: candidate, onThoughtExpressionVerified: (value) => confirmed = value);
    expect(fallbackCalls, 1);
    expect(confirmed, isFalse);
  });
}
