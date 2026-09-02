import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/desire/ordinary_desire_response.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
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
    expect(plan.askAuthorized, isFalse);
    expect(
      plan.alternatives,
      isNot(contains(ConversationInitiativeMode.probeUserTopic)),
    );
  });

  test('bare curiosity cannot manufacture a probe without a thought', () {
    final curious = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.curiosity, 0.94),
      thoughts: const [],
    );
    final social = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.social, 0.94),
      thoughts: const [],
    );

    expect(curious.primary, ConversationInitiativeMode.stayWithUserTopic);
    expect(curious.curiosityGateReason, 'no_source');
    expect(social.primary, ConversationInitiativeMode.stayWithUserTopic);
  });

  test('specific curiosity thought authorizes one grounded probe', () {
    final now = DateTime(2026, 9, 2, 21);
    final plan = ConversationInitiativePolicy.select(
      snapshot: snapshotWith(DriveKey.curiosity, 0.94),
      thoughts: [
        CompanionThought(
          id: 'curious-1',
          text: '我确实想知道他为什么突然这么烦。',
          driveKey: 'curiosity',
          kind: 'flit',
          strength: 0.82,
          bornAt: now,
          updatedAt: now,
          source: 'conversation_turn:user-1',
        ),
      ],
      now: now,
    );

    expect(plan.primary, ConversationInitiativeMode.probeUserTopic);
    expect(plan.askAuthorized, isTrue);
    expect(plan.curiosityGateReason, 'authorized');
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

  test('committed move overrides model attempt to invent or erase a bid', () {
    final authoritative = OrdinaryDesireResponseOutcome.parse(
      hasPreviousOrdinaryAssistant: true,
      authoritativeHadAiBid: true,
      authoritativeDrive: 'curiosity',
      authoritativeAction: 'check_in',
      raw: const {
        'had_ai_bid': false,
        'drive': 'attachment',
        'action': 'reach_out',
        'outcome': 'engaged',
        'resolution': 0.7,
      },
    )!;
    final blocked = OrdinaryDesireResponseOutcome.parse(
      hasPreviousOrdinaryAssistant: true,
      authoritativeHadAiBid: false,
      raw: const {
        'had_ai_bid': true,
        'drive': 'curiosity',
        'action': 'check_in',
        'outcome': 'engaged',
        'resolution': 1.0,
      },
    )!;

    expect(authoritative.drive, DriveKey.curiosity);
    expect(authoritative.action, 'check_in');
    expect(authoritative.satisfactionIntensity, greaterThan(0));
    expect(blocked.hadAiBid, isFalse);
    expect(blocked.satisfiedDrive, isNull);
  });
}
