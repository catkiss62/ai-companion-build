import 'package:ai_companion_localfirst/core/autonomy/public_web_share_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_presentation.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/proactive_intent.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought candidateThought({
  String id = 'candidate-abc',
  String source = 'public_web_candidate:candidate-abc',
  String topicKey = 'public_web_candidate:candidate-abc',
}) =>
    CompanionThought(
      id: 'thought-1',
      text: PublicWebSharePolicy.thoughtText,
      driveKey: DriveKey.curiosity.name,
      kind: 'flit',
      strength: 0.62,
      bornAt: DateTime.utc(2026, 8, 25),
      updatedAt: DateTime.utc(2026, 8, 25),
      source: source,
      topicKey: topicKey,
    );

void main() {
  group('PublicWebSharePolicy', () {
    test('binds only a normalized local id into Thought provenance', () {
      expect(
        PublicWebSharePolicy.topicKey(' Candidate-ABC '),
        'public_web_candidate:candidate-abc',
      );
      expect(
        PublicWebSharePolicy.candidateIdFromTopic(
          ' PUBLIC_WEB_CANDIDATE:Candidate-ABC ',
        ),
        'candidate-abc',
      );
      expect(
        PublicWebSharePolicy.candidateIdFromTopic('ordinary-topic'),
        isNull,
      );
      expect(
        candidateThought().provenance,
        ThoughtProvenance.publicWebCandidate,
      );
      expect(PublicWebSharePolicy.isCandidateThought(candidateThought()), isTrue);
    });

    test('Thought text remains content free', () {
      final text = PublicWebSharePolicy.thoughtText.toLowerCase();
      expect(text, isNot(contains('http')));
      expect(text, isNot(contains('www.')));
      expect(text, isNot(contains('title:')));
      expect(text, isNot(contains('summary:')));
      expect(text, isNot(contains('url:')));
      expect(text, isNot(contains('座头鲸')));
    });

    test('candidate provenance selects social share presentation', () {
      final thought = candidateThought();
      final intent = DesireIntent(
        drive: DriveKey.curiosity,
        score: 0.72,
        reason: thought.text,
        wantAction: 'share_thought',
        thoughtId: thought.id,
        reasonSource: thought.source,
      );
      expect(
        ProactivePresentationPolicy.classify(intent: intent),
        ProactiveIntentKind.socialShare,
      );
    });

    test('terminal lifecycle names remain disjoint from pending states', () {
      expect(
        {
          PublicWebSharePolicy.stagingLifecycle,
          PublicWebSharePolicy.readyLifecycle,
          PublicWebSharePolicy.sharedLifecycle,
          PublicWebSharePolicy.declinedLifecycle,
        }.length,
        4,
      );
    });
  });
}
