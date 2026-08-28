import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_selection_policy.dart';
import 'package:ai_companion_localfirst/core/diagnostics/proactive_policy_telemetry.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought thought({
  required String id,
  required DriveKey drive,
  required String source,
  double strength = 0.65,
  DateTime? bornAt,
}) {
  final at = bornAt ?? DateTime.utc(2026, 8, 28, 8);
  return CompanionThought(
    id: id,
    text: 'bounded thought data for $id',
    driveKey: drive.name,
    kind: 'flit',
    strength: strength,
    bornAt: at,
    updatedAt: at,
    lastFedAt: at,
    source: source,
  );
}

DesireIntent intent({
  required DriveKey drive,
  required double score,
  required String action,
  CompanionThought? thought,
}) =>
    DesireIntent(
      drive: drive,
      score: score,
      reason: thought?.text ?? 'drive tendency',
      wantAction: action,
      thoughtId: thought?.id,
      reasonSource: thought?.source ?? 'drive_state',
    );

void main() {
  final now = DateTime.utc(2026, 8, 29, 8);

  test('consecutive miss-you is downranked but a real share may win', () {
    final attachment = thought(
      id: 'attachment',
      drive: DriveKey.attachment,
      source: 'internal',
    );
    final reflection = thought(
      id: 'reflection',
      drive: DriveKey.reflection,
      source: 'self_drive/memory',
      bornAt: now.subtract(const Duration(hours: 5)),
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: [
        intent(
          drive: DriveKey.attachment,
          score: 0.78,
          action: 'reach_out',
          thought: attachment,
        ),
        intent(
          drive: DriveKey.reflection,
          score: 0.68,
          action: 'share_thought',
          thought: reflection,
        ),
      ],
      thoughtsById: {
        attachment.id: attachment,
        reflection.id: reflection,
      },
      recentIntentKinds: const ['miss_you', 'miss_you'],
      now: now,
    );

    expect(result, isNotNull);
    expect(result!.intent.thoughtId, reflection.id);
    expect(result.sourceType, 'memory');
    expect(result.intentKind, 'share_thought');
    expect(result.repetitionChangedWinner, isTrue);
    expect(result.changedRawWinner, isTrue);
  });

  test('repetition is friction rather than a ban when no alternative exists', () {
    final attachment = thought(
      id: 'attachment-only',
      drive: DriveKey.attachment,
      source: 'internal',
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: [
        intent(
          drive: DriveKey.attachment,
          score: 0.82,
          action: 'reach_out',
          thought: attachment,
        ),
      ],
      thoughtsById: {attachment.id: attachment},
      recentIntentKinds: const ['miss_you', 'miss_you', 'miss_you'],
      now: now,
    )!;

    expect(result.intent.thoughtId, attachment.id);
    expect(result.repeatDepth, 3);
    expect(result.repetitionPenalty, 0.26);
    expect(result.intent.score, closeTo(0.56, 0.0001));
  });

  test('an old ready web thought gets bounded opportunity without bypass', () {
    final attachment = thought(
      id: 'ordinary',
      drive: DriveKey.attachment,
      source: 'internal',
    );
    final web = thought(
      id: 'web',
      drive: DriveKey.curiosity,
      source: 'public_web_candidate:candidate-1',
      bornAt: now.subtract(const Duration(days: 2)),
    );
    final result = ProactiveSelectionPolicy.select(
      candidates: [
        intent(
          drive: DriveKey.attachment,
          score: 0.70,
          action: 'reach_out',
          thought: attachment,
        ),
        intent(
          drive: DriveKey.curiosity,
          score: 0.58,
          action: 'check_in',
          thought: web,
        ),
      ],
      thoughtsById: {attachment.id: attachment, web.id: web},
      recentIntentKinds: const [],
      readySinceByThoughtId: {
        web.id: now.subtract(const Duration(hours: 25)),
      },
      now: now,
    )!;

    expect(result.intent.thoughtId, web.id);
    expect(result.sourceType, 'public_web');
    expect(result.intentKind, 'social_share');
    expect(result.waitingBoost, 0.16);
    expect(result.intent.score, closeTo(0.74, 0.0001));
    expect(result.intent.score, lessThanOrEqualTo(1.0));
  });

  test('source classification is ready for internal, screen and future MCP', () {
    final cases = <String, String>{
      'self_drive/memory': 'memory',
      'self_reflection_run:abc': 'self_experience',
      'awareness/current_app': 'awareness',
      'screen_observation:abc': 'screen_observation',
      'inference/local': 'inference',
      'public_web_candidate:abc': 'public_web',
      'mcp/calendar': 'mcp',
      'internal': 'internal',
    };
    for (final entry in cases.entries) {
      expect(
        ProactiveSelectionPolicy.sourceTypeFor(
          thought: null,
          reasonSource: entry.key,
        ),
        entry.value,
      );
    }
  });

  test('optional expansion preserves same-drive alternative Thoughts', () {
    final first = thought(
      id: 'first',
      drive: DriveKey.reflection,
      source: 'self_drive/memory',
      strength: 0.78,
    );
    final second = thought(
      id: 'second',
      drive: DriveKey.reflection,
      source: 'awareness/current_app',
      strength: 0.62,
    );
    final drives = <DriveKey, double>{
      for (final drive in DriveKey.values) drive: 0.30,
    };
    drives[DriveKey.reflection] = 0.58;
    final candidates = DesireCorePolicy.candidates(
      drives: drives,
      refractoryUntil: const {},
      thoughts: [first, second],
      now: now,
      includeThoughtAlternatives: true,
      wildcardAllowed: false,
    );
    final reflectionIds = candidates
        .where((candidate) => candidate.drive == DriveKey.reflection)
        .map((candidate) => candidate.thoughtId)
        .toSet();
    expect(reflectionIds, containsAll(<String?>{first.id, second.id}));
  });

  test('policy telemetry collapses arbitrary content into fixed enums', () {
    expect(ProactivePolicyTelemetry.safeSourceType('memory'), 'memory');
    expect(ProactivePolicyTelemetry.safeSourceType('Edge browser'), 'none');
    expect(ProactivePolicyTelemetry.safeOutcome('sent'), 'sent');
    expect(ProactivePolicyTelemetry.safeOutcome('raw model text'), 'failed');
    expect(
      ProactivePolicyTelemetry.appSourceType(
        'accessibility_interactive_window',
      ),
      'accessibility',
    );
    expect(
      ProactivePolicyTelemetry.appSourceType('usage_stats_fallback'),
      'usage_stats',
    );
  });
}
