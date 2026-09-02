import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_prompt_policy.dart';
import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_outcome_verifier.dart';
import 'package:ai_companion_localfirst/core/grounding/information_seeking_question_guard.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

ConversationInitiativePlan _plan(
  ConversationSpeechAct speechAct, {
  bool askAuthorized = false,
  bool hasThought = true,
  String? thoughtId = 'thought-1',
}) =>
    ConversationInitiativePlan(
      primary: switch (speechAct) {
        ConversationSpeechAct.ask => ConversationInitiativeMode.probeUserTopic,
        ConversationSpeechAct.selfShare =>
          ConversationInitiativeMode.shareOwnView,
        ConversationSpeechAct.tease => ConversationInitiativeMode.flirtOrInsist,
        ConversationSpeechAct.seekAttention =>
          ConversationInitiativeMode.seekAttention,
        ConversationSpeechAct.invite =>
          ConversationInitiativeMode.inviteSharedActivity,
        ConversationSpeechAct.showNeed => ConversationInitiativeMode.showOwnNeed,
        ConversationSpeechAct.pauseOrClose =>
          ConversationInitiativeMode.releaseTopic,
        ConversationSpeechAct.answer => ConversationInitiativeMode.answerUser,
        ConversationSpeechAct.react =>
          ConversationInitiativeMode.stayWithUserTopic,
      },
      topicMove: ConversationTopicMove.stay,
      speechAct: speechAct,
      drive: speechAct == ConversationSpeechAct.ask
          ? DriveKey.curiosity
          : DriveKey.social,
      action: speechAct == ConversationSpeechAct.ask
          ? 'discover_interest'
          : 'share_thought',
      scoreBand: 'high',
      hasThought: hasThought,
      sourceProvenance: hasThought ? 'memory' : 'drive_state',
      askAuthorized: askAuthorized,
      curiosityGateReason: askAuthorized ? 'authorized' : 'no_specific_gap',
      questionPressureBand: 'none',
      alternatives: const [],
      sourceThoughtId: thoughtId,
    );

CompanionThought _thought({
  String text = '我想知道项目构建为什么失败，具体卡在了哪个步骤。',
  String source = 'memory:test',
  String topicKey = 'project.build.failure',
}) {
  final now = DateTime(2026, 9, 2, 21);
  return CompanionThought(
    id: 'thought-1',
    text: text,
    driveKey: 'curiosity',
    kind: 'flit',
    strength: 0.8,
    bornAt: now,
    updatedAt: now,
    source: source,
    topicKey: topicKey,
  );
}

void main() {
  group('final output owns action truth', () {
    test('authorized ask without a real question remains unacted', () {
      final verification = ConversationOutcomeVerifier.verify(
        finalText: '「行，那我先盯着构建日志。」',
        plan: _plan(ConversationSpeechAct.ask, askAuthorized: true),
        sourceThought: _thought(),
      );

      expect(verification.allowed, isTrue);
      expect(verification.hadAiBid, isFalse);
      expect(verification.shouldMarkThoughtActed, isFalse);
      expect(verification.reason, 'planned_bid_not_expressed');
    });

    test('authorized ask must match the selected Thought', () {
      final verification = ConversationOutcomeVerifier.verify(
        finalText: '「你今天想吃什么？」',
        plan: _plan(ConversationSpeechAct.ask, askAuthorized: true),
        sourceThought: _thought(),
      );

      expect(verification.informationRequestExpressed, isTrue);
      expect(verification.allowed, isFalse);
      expect(verification.reason, 'ask_source_mismatch');
      expect(verification.shouldMarkThoughtActed, isFalse);
    });

    test('matching information request can become an acted Thought', () {
      final verification = ConversationOutcomeVerifier.verify(
        finalText: '「项目构建具体卡在哪个步骤？」',
        plan: _plan(ConversationSpeechAct.ask, askAuthorized: true),
        sourceThought: _thought(),
      );

      expect(verification.allowed, isTrue);
      expect(verification.hadAiBid, isTrue);
      expect(verification.sourceThoughtExpressed, isTrue);
      expect(verification.shouldMarkThoughtActed, isTrue);
      expect(verification.reason, 'expressed_match');
    });

    test('rhetorical teasing is not converted into information seeking', () {
      final guard = InformationSeekingQuestionGuard.evaluate(
        text: '「难道你还想赖账？」',
        askAuthorized: false,
      );
      final colloquialGuard = InformationSeekingQuestionGuard.evaluate(
        text: '「凭什么？关我什么事？」',
        askAuthorized: false,
      );
      final verification = ConversationOutcomeVerifier.verify(
        finalText: '「难道你还想赖账？」',
        plan: _plan(
          ConversationSpeechAct.tease,
          hasThought: false,
          thoughtId: null,
        ),
      );

      expect(guard.hasInformationRequest, isFalse);
      expect(guard.hasRhetoricalQuestion, isTrue);
      expect(colloquialGuard.hasInformationRequest, isFalse);
      expect(colloquialGuard.hasRhetoricalQuestion, isTrue);
      expect(verification.expressedSpeechAct, 'tease');
      expect(verification.hadAiBid, isTrue);
    });
  });

  group('public web prompt ablation', () {
    test('unselected autonomous results are not ambient prompt context', () {
      expect(
        PublicWebPromptPolicy.candidateIds(agentToolResults: const []),
        isEmpty,
      );
    });

    test('only the candidate bound to the selected web Thought is admitted', () {
      final thought = _thought(
        text: PublicWebSharePolicy.thoughtText,
        source: PublicWebSharePolicy.source('candidate-7'),
        topicKey: PublicWebSharePolicy.topicKey('candidate-7'),
      );

      expect(
        PublicWebPromptPolicy.candidateIds(
          agentToolResults: const [],
          selectedThought: thought,
        ),
        ['candidate-7'],
      );
    });

    test('current user web tool results exclude autonomous cards', () {
      const toolResult = AgentToolResult(
        toolId: 'public_web.search',
        status: AgentToolStatus.succeeded,
        displayText: 'done',
        promptData: 'bounded result',
        resultCount: 2,
      );

      expect(
        PublicWebPromptPolicy.candidateIds(
          agentToolResults: const [toolResult],
          selectedCandidateId: 'candidate-7',
        ),
        isEmpty,
      );
    });
  });
}
