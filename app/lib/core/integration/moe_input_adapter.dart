import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/personality_trial.dart';
import '../moe/domain/moe_models.dart';

/// Narrow, one-way adapter from committed application facts into Moe signals.
/// It reads no message body or reasoning text and exposes no write path back to
/// Desire, emotion, relationship, personality, prompt, tools, or actions.
class MoeInputAdapter {
  const MoeInputAdapter();

  MoeInputSnapshot fromCompletedTurn({
    required ChatMessage assistant,
    required DesireSnapshot desire,
    required int relationshipDay,
    PersonalityTrial? personalityTrial,
    SpecialStyleTrial? specialStyleTrial,
  }) {
    final emotion = assistant.emotionKey.trim().isEmpty
        ? 'calm'
        : assistant.emotionKey.trim();
    final pulses = <MoeAxis, double>{};
    final tags = <String>{};

    void add(MoeAxis axis, double value) {
      pulses[axis] = ((pulses[axis] ?? 0) + value)
          .clamp(-40.0, 40.0)
          .toDouble();
    }

    switch (emotion) {
      case 'affection':
        add(MoeAxis.closenessBid, 15);
        add(MoeAxis.unfilteredDirectness, 10);
        add(MoeAxis.cuteDisplay, 8);
        tags.addAll(const {'seeking_closeness', 'clear_affection'});
        break;
      case 'happy':
      case 'excited':
        add(MoeAxis.playfulImpulse, 13);
        add(MoeAxis.cuteDisplay, 11);
        add(MoeAxis.closenessBid, 6);
        tags.addAll(const {'play', 'celebration'});
        break;
      case 'playful':
        add(MoeAxis.playfulImpulse, 16);
        add(MoeAxis.strategicSubtext, 11);
        add(MoeAxis.verbalSpice, 7);
        tags.addAll(const {
          'playful_prank',
          'playful_plot',
          'expressive_teasing',
        });
        break;
      case 'shy':
      case 'embarrassed':
        add(MoeAxis.bashfulInhibition, 16);
        add(MoeAxis.flusteredBumble, 10);
        add(MoeAxis.closenessBid, 7);
        tags.addAll(const {'intimacy_exposed', 'sensitive_topic'});
        break;
      case 'confused':
        add(MoeAxis.flusteredBumble, 14);
        add(MoeAxis.unfilteredDirectness, 7);
        tags.addAll(const {'confusion', 'small_mistake'});
        break;
      case 'surprised':
      case 'flustered':
      case 'nervous':
        add(MoeAxis.flusteredBumble, 13);
        add(MoeAxis.bashfulInhibition, 8);
        tags.addAll(const {'surprise', 'small_mistake'});
        break;
      case 'angry':
      case 'disgust':
        add(MoeAxis.verbalSpice, 15);
        add(MoeAxis.unfilteredDirectness, 10);
        add(MoeAxis.defensiveMask, 7);
        tags.addAll(const {'assertive_response', 'real_flaw'});
        break;
      case 'worried':
      case 'crying':
        add(MoeAxis.closenessBid, 12);
        add(MoeAxis.defensiveMask, 9);
        add(MoeAxis.bashfulInhibition, 5);
        tags.addAll(const {'concern', 'care_exposed'});
        break;
      case 'serious':
      case 'confident':
        add(MoeAxis.unfilteredDirectness, 12);
        add(MoeAxis.strategicSubtext, 8);
        tags.add('honest_disclosure');
        break;
      case 'helpless':
        add(MoeAxis.flusteredBumble, 9);
        add(MoeAxis.verbalSpice, 6);
        tags.addAll(const {'small_mistake', 'expressive_teasing'});
        break;
      case 'normal':
      case 'calm':
        add(MoeAxis.unfilteredDirectness, 2);
        tags.add('honest_disclosure');
        break;
    }

    final attachment = _drive(desire, DriveKey.attachment);
    final social = _drive(desire, DriveKey.social);
    final libido = _drive(desire, DriveKey.libido);
    final stress = _drive(desire, DriveKey.stress);
    add(MoeAxis.closenessBid, (attachment - .5) * 6 + (libido - .5) * 3);
    add(MoeAxis.playfulImpulse, (social - .5) * 5);
    add(MoeAxis.defensiveMask, (stress - .5) * 4);

    // Trial identity contributes only a small numeric modifier; its free-form
    // content is intentionally never read by this adapter.
    if (personalityTrial != null) {
      add(MoeAxis.unfilteredDirectness, 2);
      add(MoeAxis.strategicSubtext, 2);
    }
    if (specialStyleTrial != null) add(MoeAxis.playfulImpulse, 2);

    return MoeInputSnapshot(
      capturedAt: assistant.createdAt,
      relationshipStage: _relationshipStage(relationshipDay),
      normalizedSignals: {
        'attachment': attachment,
        'social': social,
        'libido': libido,
        'stress': stress,
        'relationship_maturity':
            ((relationshipDay - 1) / 90).clamp(0.0, 1.0).toDouble(),
        'personality_trial_active': personalityTrial == null ? 0 : 1,
        'special_style_trial_active': specialStyleTrial == null ? 0 : 1,
      },
      event: MoeObservedEvent(
        idempotencyKey: 'turn:${assistant.id}',
        sourceType: 'completed_assistant_turn',
        causeTag: 'emotion:$emotion',
        occurredAt: assistant.createdAt,
        axisPulses: pulses,
        contextTags: tags,
      ),
    );
  }

  double _drive(DesireSnapshot desire, DriveKey key) =>
      (desire.drives[key] ?? desire.baselines[key] ?? .5)
          .clamp(0.0, 1.0)
          .toDouble();

  String _relationshipStage(int day) {
    if (day <= 3) return 'new';
    if (day <= 14) return 'familiarizing';
    if (day <= 60) return 'established';
    return 'long_term';
  }
}
