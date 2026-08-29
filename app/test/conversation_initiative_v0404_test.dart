import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/desire/ordinary_desire_response.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';

DesireSnapshot snapshotWith(DriveKey drive, double value) => DesireSnapshot(
      drives: {
        for (final item in DriveKey.values)
          item: item == DriveKey.fatigue ? 0.12 : 0.18,
        drive: value,
      },
    );

void main() {
  test('attachment becomes an attention bid without removing topic options', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.attachment, 0.94),
      thoughts: const [],
      now: DateTime(2026, 8, 29, 20),
    );

    expect(plan.primary, ConversationInitiativeMode.seekAttention);
    expect(
      plan.alternatives,
      contains(ConversationInitiativeMode.stayWithUserTopic),
    );
    expect(
      plan.alternatives,
      contains(ConversationInitiativeMode.probeUserTopic),
    );
  });

  test('curiosity can keep probing while social can open her own topic', () {
    final curious = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.curiosity, 0.94),
      thoughts: const [],
    );
    final social = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.social, 0.94),
      thoughts: const [],
    );

    expect(curious.primary, ConversationInitiativeMode.probeUserTopic);
    expect(social.primary, ConversationInitiativeMode.openOwnTopic);
  });

  test('fatigue exposes her own need instead of manufacturing caretaking', () {
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.fatigue: 0.88,
      },
    );
    final plan = ConversationInitiativePolicy.select(
      snapshot: snapshot,
      thoughts: const [],
    );

    expect(plan.primary, ConversationInitiativeMode.showOwnNeed);
    expect(plan.action, 'rest');
  });

  test('initiative prompt explicitly rejects length-based disengagement', () {
    final plan = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.reflection, 0.90),
      thoughts: const [],
    );
    final prompt = plan.promptSection();

    expect(prompt, contains('绝不根据用户消息的字数'));
    expect(prompt, contains('继续用户话题不等于被动'));
    expect(prompt, contains('不自动占据成熟姐姐'));
  });

  test('engaged response settles the expressed drive by semantic resolution', () {
    final outcome = OrdinaryDesireResponseOutcome.parse(
      hasPreviousOrdinaryAssistant: true,
      raw: const {
        'had_ai_bid': true,
        'drive': 'attachment',
        'action': 'reach_out',
        'outcome': 'engaged',
        'resolution': 0.8,
      },
    )!;

    expect(outcome.satisfiedDrive, DriveKey.attachment);
    expect(outcome.satisfactionIntensity, closeTo(0.79, 0.0001));
  });

  test('acknowledgement is partial while redirect and refusal do not settle', () {
    OrdinaryDesireResponseOutcome parse(String outcome) =>
        OrdinaryDesireResponseOutcome.parse(
          hasPreviousOrdinaryAssistant: true,
          raw: {
            'had_ai_bid': true,
            'drive': 'curiosity',
            'action': 'discover_interest',
            'outcome': outcome,
            'resolution': 0.6,
          },
        )!;

    expect(parse('acknowledged').satisfactionIntensity, closeTo(0.372, 0.0001));
    expect(parse('redirected').satisfiedDrive, isNull);
    expect(parse('refused').satisfiedDrive, isNull);
  });

  test('missing previous assistant or invalid bid cannot fabricate settling', () {
    expect(
      OrdinaryDesireResponseOutcome.parse(
        hasPreviousOrdinaryAssistant: false,
        raw: const {'had_ai_bid': true, 'outcome': 'engaged'},
      ),
      isNull,
    );
    final invalid = OrdinaryDesireResponseOutcome.parse(
      hasPreviousOrdinaryAssistant: true,
      raw: const {
        'had_ai_bid': true,
        'drive': 'unknown',
        'outcome': 'engaged',
      },
    )!;
    expect(invalid.hadAiBid, isFalse);
    expect(invalid.satisfiedDrive, isNull);
  });
}
