import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';

void main() {
  test('thought source is normalized into explicit epistemic provenance', () {
    expect(
      ThoughtProvenancePolicy.fromSource('conversation_turn:m1'),
      ThoughtProvenance.realUserMessage,
    );
    expect(
      ThoughtProvenancePolicy.fromSource('presence/phone_activity'),
      ThoughtProvenance.awareness,
    );
    expect(
      ThoughtProvenancePolicy.fromSource('self_drive/memory'),
      ThoughtProvenance.memory,
    );
    expect(
      ThoughtProvenancePolicy.fromSource('self_drive/thread'),
      ThoughtProvenance.selfExperience,
    );
    expect(
      ThoughtProvenancePolicy.fromSource('inference/guess'),
      ThoughtProvenance.inference,
    );
  });

  test('snooze evaluation can be deterministic with caller supplied time', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final thought = CompanionThought(
      id: 't1',
      text: '内部念头',
      driveKey: 'attachment',
      kind: 'flit',
      strength: 0.4,
      bornAt: now,
      updatedAt: now,
      snoozedUntil: now.add(const Duration(minutes: 20)),
    );
    expect(thought.canDriveIntentAt(now), isFalse);
    expect(
      thought.canDriveIntentAt(now.add(const Duration(minutes: 21))),
      isTrue,
    );
  });
}
