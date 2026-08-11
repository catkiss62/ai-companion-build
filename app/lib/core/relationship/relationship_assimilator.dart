import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/relationship_event.dart';

/// Converts durable relationship history into slow inner-life changes exactly
/// once per event/reinforcement. The relationship log remains factual; this
/// layer only translates its emotional meaning into Thought/Desire.
class RelationshipAssimilator {
  RelationshipAssimilator({required this.db});

  final AppDatabase db;

  Future<int> assimilatePending({int limit = 12}) async {
    if ((await db.getSetting('relationship_continuity_enabled')) == '0') return 0;
    if (!await db.brainWorkAllowed()) return 0;
    final acquired = await db.tryAcquireLocalLease(
      'relationship_assimilation_lease_until',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return 0;
    try {
      if (!await db.brainWorkAllowed()) return 0;
      final events = await db.pendingRelationshipEvents(limit: limit);
      var applied = 0;
      for (final event in events) {
        if (!await db.brainWorkAllowed() ||
            !await db.renewLocalLease(
              'relationship_assimilation_lease_until',
              holdFor: const Duration(minutes: 3),
            )) {
          break;
        }
        final pulses = _pulsesFor(event);
        final thoughtDrive = _thoughtDrive(event);
        final thoughtStrength =
            (0.12 + event.intensity * 0.31).clamp(0.12, 0.48).toDouble();
        try {
          final committed = await db.assimilateRelationshipEventAtomic(
            event: event,
            pulses: pulses,
            baselineLearning: _baselineLearning(event),
            thoughtDrive: thoughtDrive,
            thoughtText: _thoughtText(event),
            thoughtStrength: thoughtStrength,
          );
          if (committed) applied++;
        } catch (_) {
          // The whole event assimilation is transactional. If anything fails,
          // neither Desire nor Thought nor internalized_at is partially left
          // behind; a future heartbeat can retry safely.
        }
      }
      return applied;
    } finally {
      await db.releaseLocalLease('relationship_assimilation_lease_until');
    }
  }

  Map<DriveKey, double> _pulsesFor(RelationshipEvent e) {
    final i = e.intensity.clamp(0.0, 1.0).toDouble();
    final v = e.valence.clamp(-1.0, 1.0).toDouble();
    double mag(double base, [double valenceBias = 0.0]) =>
        (base * (0.45 + i * 0.75) + valenceBias * v).clamp(-0.12, 0.12).toDouble();

    return switch (e.kind) {
      'closeness' => {
          DriveKey.attachment: mag(0.035, 0.018),
          DriveKey.reflection: mag(0.014, 0.006),
        },
      'trust' => {
          DriveKey.attachment: mag(0.030, 0.018),
          DriveKey.stress: (-0.018 * (0.5 + i)).clamp(-0.08, 0.0).toDouble(),
        },
      'conflict' => {
          DriveKey.stress: mag(0.045, -0.025),
          DriveKey.reflection: mag(0.030),
          DriveKey.attachment: (-0.012 * i + v * 0.008).clamp(-0.05, 0.03).toDouble(),
        },
      'repair' => {
          DriveKey.attachment: mag(0.040, 0.018),
          DriveKey.reflection: mag(0.024),
          DriveKey.stress: (-0.035 * (0.5 + i)).clamp(-0.09, 0.0).toDouble(),
        },
      'promise' => {
          DriveKey.duty: mag(0.034),
          DriveKey.attachment: mag(0.020, 0.010),
        },
      'milestone' => {
          DriveKey.attachment: mag(0.040, 0.015),
          DriveKey.reflection: mag(0.035),
        },
      'intimacy' => {
          DriveKey.libido: mag(0.032, 0.012),
          DriveKey.attachment: mag(0.030, 0.012),
          DriveKey.reflection: mag(0.015),
        },
      'boundary' => {
          DriveKey.duty: mag(0.030),
          DriveKey.reflection: mag(0.025),
          DriveKey.stress: v < 0 ? mag(0.018) : -0.008 * i,
        },
      'roleplay' => {
          DriveKey.curiosity: mag(0.025),
          DriveKey.social: mag(0.018),
        },
      'support' => {
          DriveKey.attachment: mag(0.030, 0.012),
          DriveKey.social: mag(0.018),
          DriveKey.stress: v >= 0 ? -0.012 * i : 0.006 * i,
        },
      'shared_discovery' => {
          DriveKey.curiosity: mag(0.030),
          DriveKey.reflection: mag(0.022),
          DriveKey.social: mag(0.016),
        },
      _ => {DriveKey.reflection: mag(0.012)},
    };
  }

  DriveKey _thoughtDrive(RelationshipEvent e) {
    if (e.kind == 'promise' || e.kind == 'boundary') return DriveKey.duty;
    if (e.kind == 'conflict') return DriveKey.stress;
    if (e.kind == 'roleplay' || e.kind == 'shared_discovery') return DriveKey.curiosity;
    if (e.kind == 'intimacy') return DriveKey.libido;
    if (e.kind == 'milestone' || e.kind == 'repair') return DriveKey.reflection;
    return DriveKey.attachment;
  }

  String _thoughtText(RelationshipEvent e) => switch (e.kind) {
        'conflict' => '我还在消化这次关系摩擦：${e.summary}',
        'repair' => '我记得我们刚刚修复/缓和了这件事：${e.summary}',
        'promise' => '我把这个约定放在心上：${e.summary}',
        'boundary' => '这条边界/约定需要我认真记住：${e.summary}',
        'milestone' => '这像是我们关系里的一个节点：${e.summary}',
        'intimacy' => '这次亲密经历留下了关系上的余韵：${e.summary}',
        _ => '这件事对我们的关系有一点持续影响：${e.summary}',
      };

  double _baselineLearning(RelationshipEvent e) {
    if (e.kind == 'milestone' || e.kind == 'trust' || e.kind == 'repair') return 0.0045;
    if (e.kind == 'conflict' || e.kind == 'boundary') return 0.0030;
    return 0.0022;
  }
}
