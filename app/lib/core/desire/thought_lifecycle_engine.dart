import 'dart:math';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';

class ThoughtLifecycleEngine {
  ThoughtLifecycleEngine({required this.db, Random? random}) : _random = random ?? Random();

  final AppDatabase db;
  final Random _random;

  Future<void> advance({bool forceForDebug = false}) async {
    if ((await db.getSetting('thought_lifecycle_enabled')) == '0') return;
    if (!await db.brainWorkAllowed()) return;
    final acquired = await db.tryAcquireLocalLease(
      'thought_lifecycle_lease_until',
      holdFor: const Duration(minutes: 4),
    );
    if (!acquired) return;
    try {
      if (!await db.brainWorkAllowed()) return;
      final now = DateTime.now();
      final thoughts = await db.lifecycleThoughts(limit: 160);
      for (final thought in thoughts) {
        if (!await db.brainWorkAllowed()) break;
        if (!await db.renewLocalLease(
          'thought_lifecycle_lease_until',
          holdFor: const Duration(minutes: 4),
        )) {
          break;
        }
        switch (thought.lifecycleState) {
          case 'active':
          case 'fixation':
            await _advanceActive(thought, now);
            break;
          case 'acted':
            await _advanceActed(thought, now);
            break;
          case 'residual':
            await _advanceResidual(thought, now, forceForDebug: forceForDebug);
            break;
          case 'dormant':
            await _maybeResurfaceDormant(thought, now, forceForDebug: forceForDebug);
            break;
        }
      }
    } finally {
      await db.releaseLocalLease('thought_lifecycle_lease_until');
    }
  }

  Future<void> _advanceActive(CompanionThought t, DateTime now) async {
    final hours = max(0.05, now.difference(t.updatedAt).inMinutes / 60.0);
    final retention = t.isFixation ? 0.972 : 0.915;
    final next = (t.strength * pow(retention, hours)).clamp(0.0, 1.0).toDouble();
    if (next < 0.075) {
      final changed = await db.updateThoughtLifecycle(
        t.id,
        lifecycleState: 'dormant',
        strength: max(0.03, next),
        residualStrength: max(t.residualStrength, next),
        expectedUpdatedAt: t.updatedAt,
      );
      if (!changed) return;
      await db.addThoughtLifecycleEvent(
        thoughtId: t.id,
        eventType: 'dormant',
        detail: '闪念自然沉下去，没有被直接删除。',
      );
      return;
    }
    final fixation = t.isFixation || t.fedCount >= 3 || next >= 0.68;
    final changed = await db.updateThoughtLifecycle(
      t.id,
      lifecycleState: fixation ? 'fixation' : 'active',
      kind: fixation ? 'fixation' : 'flit',
      strength: next,
      expectedUpdatedAt: t.updatedAt,
    );
    if (!changed) return;
    if (fixation && !t.isFixation) {
      await db.addThoughtLifecycleEvent(
        thoughtId: t.id,
        eventType: 'fixation',
        detail: '同一念头被反复强化，升级为 fixation。',
      );
    }
  }

  Future<void> _advanceActed(CompanionThought t, DateTime now) async {
    final actedAt = t.lastActedAt;
    if (actedAt == null) {
      await db.updateThoughtLifecycle(
        t.id,
        lifecycleState: 'residual',
        expectedUpdatedAt: t.updatedAt,
      );
      return;
    }
    // After acting, the thought stays in an awaiting-feedback state for a while.
    if (now.difference(actedAt) < const Duration(hours: 10)) return;
    final residual = max(0.16, max(t.residualStrength, t.strength * 0.72));
    final changed = await db.updateThoughtLifecycle(
      t.id,
      lifecycleState: 'residual',
      strength: residual,
      residualStrength: residual,
      clearOutboundMessage: true,
      expectedUpdatedAt: t.updatedAt,
    );
    if (!changed) return;
    await db.addThoughtLifecycleEvent(
      thoughtId: t.id,
      eventType: 'unanswered_residual',
      detail: '主动表达后暂时没有得到回应，念头保留为余韵而不是立刻再次打扰。',
    );
  }

  Future<void> _advanceResidual(
    CompanionThought t,
    DateTime now, {
    required bool forceForDebug,
  }) async {
    final hours = max(0.05, now.difference(t.updatedAt).inMinutes / 60.0);
    final next = (max(t.strength, t.residualStrength) * pow(0.985, hours))
        .clamp(0.0, 1.0)
        .toDouble();
    if (next < 0.12) {
      final changed = await db.updateThoughtLifecycle(
        t.id,
        lifecycleState: 'dormant',
        strength: next,
        residualStrength: next,
        expectedUpdatedAt: t.updatedAt,
      );
      if (!changed) return;
      await db.addThoughtLifecycleEvent(
        thoughtId: t.id,
        eventType: 'dormant',
        detail: '余韵逐渐沉入背景。',
      );
      return;
    }

    // A user may explicitly defer a topic. Keep the trace but do not let it
    // resurface until the local snooze expires.
    if (t.snoozedUntil?.isAfter(now) ?? false) {
      await db.updateThoughtLifecycle(
        t.id,
        strength: next,
        residualStrength: next,
        expectedUpdatedAt: t.updatedAt,
      );
      return;
    }

    final reference = t.lastSatisfiedAt ?? t.lastActedAt ?? t.updatedAt;
    final oldEnough = now.difference(reference) >= const Duration(hours: 7);
    final capped = t.resurfacedCount >= 4;
    final chance = (0.05 + next * 0.10).clamp(0.05, 0.17).toDouble();
    if (oldEnough && !capped && (forceForDebug || _random.nextDouble() < chance)) {
      final strength = (next * 0.82 + 0.10).clamp(0.18, 0.62).toDouble();
      final changed = await db.updateThoughtLifecycle(
        t.id,
        lifecycleState: 'active',
        kind: strength >= 0.55 ? 'fixation' : 'flit',
        strength: strength,
        residualStrength: next,
        lastResurfacedAt: now,
        resurfacedCount: t.resurfacedCount + 1,
        clearOutboundMessage: true,
        clearSnooze: true,
        expectedUpdatedAt: t.updatedAt,
      );
      if (!changed) return;
      await db.addThoughtLifecycleEvent(
        thoughtId: t.id,
        eventType: 'resurfaced',
        detail: '旧念头在余韵中重新浮上来，可再次影响行为，但不会无限循环。',
      );
      return;
    }
    await db.updateThoughtLifecycle(
      t.id,
      strength: next,
      residualStrength: next,
      expectedUpdatedAt: t.updatedAt,
    );
  }

  Future<void> _maybeResurfaceDormant(
    CompanionThought t,
    DateTime now, {
    required bool forceForDebug,
  }) async {
    if (t.snoozedUntil?.isAfter(now) ?? false) return;
    if (t.resurfacedCount >= 4) return;
    final reference = t.lastResurfacedAt ?? t.updatedAt;
    if (now.difference(reference) < const Duration(days: 2)) return;
    final base = max(t.residualStrength, t.strength);
    if (base < 0.08) return;
    if (!forceForDebug && _random.nextDouble() > 0.035) return;
    final next = (base * 0.72 + 0.08).clamp(0.12, 0.42).toDouble();
    final changed = await db.updateThoughtLifecycle(
      t.id,
      lifecycleState: 'active',
      kind: 'flit',
      strength: next,
      lastResurfacedAt: now,
      resurfacedCount: t.resurfacedCount + 1,
      clearSnooze: true,
      expectedUpdatedAt: t.updatedAt,
    );
    if (!changed) return;
    await db.addThoughtLifecycleEvent(
      thoughtId: t.id,
      eventType: 'resurfaced_from_dormant',
      detail: '一个沉下去的念头很久以后又被想起。',
    );
  }

  Future<void> markActed({
    required CompanionThought thought,
    required String messageId,
  }) async {
    if (await db.hasThoughtLifecycleEvent(
      thoughtId: thought.id,
      eventType: 'acted',
      messageId: messageId,
    )) {
      return;
    }
    final now = DateTime.now();
    final residual = (thought.strength * (thought.isFixation ? 0.82 : 0.68))
        .clamp(0.12, 0.78)
        .toDouble();
    await db.updateThoughtLifecycle(
      thought.id,
      lifecycleState: 'acted',
      actionCount: thought.actionCount + 1,
      lastActedAt: now,
      residualStrength: residual,
      lastOutboundMessageId: messageId,
      clearSnooze: true,
    );
    await db.addThoughtLifecycleEvent(
      thoughtId: thought.id,
      eventType: 'acted',
      messageId: messageId,
      detail: '这个念头已经转化为一次主动行动，等待用户回应。',
    );
  }

  /// Immediate local acknowledgement when the user replies to an outbound
  /// message. This deliberately does not decide whether the underlying topic
  /// was actually resolved; the post-turn extractor can refine that later.
  Future<void> markResponseReceived({
    required String thoughtId,
    required double responseQuality,
    String? responseMessageId,
  }) async {
    if (responseMessageId != null && responseMessageId.isNotEmpty) {
      await db.markThoughtResponseReceivedAtomic(
        thoughtId: thoughtId,
        responseQuality: responseQuality,
        responseMessageId: responseMessageId,
      );
      return;
    }
    // Compatibility path for callers without a durable response message ID.
    final thought = await db.thoughtById(thoughtId);
    if (thought == null) return;
    final quality = responseQuality.clamp(0.0, 1.0).toDouble();
    final base = max(thought.residualStrength, thought.strength);
    final residual = (base * (0.78 - quality * 0.20)).clamp(0.16, 0.64).toDouble();
    await db.updateThoughtLifecycle(
      thought.id,
      lifecycleState: 'residual',
      strength: residual,
      residualStrength: residual,
      clearOutboundMessage: true,
    );
  }

  /// Refines the originating thought after the whole reply turn has enough
  /// context to distinguish “继续聊”“晚点说”“已经解决”“别再提”等结果。
  Future<void> applyResponseOutcome({
    required String thoughtId,
    required String outcome,
    required double resolution,
    String? responseMessageId,
  }) async {
    if (responseMessageId != null && responseMessageId.isNotEmpty) {
      await db.applyThoughtResponseOutcomeAtomic(
        thoughtId: thoughtId,
        outcome: outcome,
        resolution: resolution,
        responseMessageId: responseMessageId,
      );
      return;
    }
    // Compatibility path for callers without a durable response message ID.
    final thought = await db.thoughtById(thoughtId);
    if (thought == null) return;
    final now = DateTime.now();
    final r = resolution.clamp(0.0, 1.0).toDouble();
    final base = max(thought.residualStrength, thought.strength);
    late final String state;
    late final double residual;
    DateTime? snooze;
    switch (outcome) {
      case 'resolved':
        residual = (base * (0.30 - r * 0.18)).clamp(0.04, 0.16).toDouble();
        state = residual <= 0.10 ? 'dormant' : 'residual';
        break;
      case 'engaged':
        residual = (base * (0.62 - r * 0.22)).clamp(0.14, 0.46).toDouble();
        state = 'residual';
        break;
      case 'deferred':
        residual = (base * 0.88).clamp(0.28, 0.70).toDouble();
        state = 'residual';
        snooze = now.add(const Duration(hours: 4));
        break;
      case 'dismissed':
        residual = (base * 0.22).clamp(0.03, 0.14).toDouble();
        state = 'dormant';
        snooze = now.add(const Duration(days: 7));
        break;
      case 'redirected':
        residual = (base * 0.48).clamp(0.08, 0.34).toDouble();
        state = residual <= 0.10 ? 'dormant' : 'residual';
        snooze = now.add(const Duration(hours: 12));
        break;
      case 'acknowledged':
      default:
        residual = (base * 0.60).clamp(0.12, 0.40).toDouble();
        state = 'residual';
        break;
    }
    await db.updateThoughtLifecycle(
      thought.id,
      lifecycleState: state,
      strength: residual,
      residualStrength: residual,
      lastSatisfiedAt: now,
      snoozedUntil: snooze,
      clearOutboundMessage: true,
      clearSnooze: snooze == null,
    );
  }

  /// Kept for compatibility with older callers/tests.
  Future<void> markSatisfied({
    required String thoughtId,
    required double responseQuality,
    String? responseMessageId,
  }) => applyResponseOutcome(
        thoughtId: thoughtId,
        outcome: 'resolved',
        resolution: responseQuality,
        responseMessageId: responseMessageId,
      );

  CompanionThought? strongestForIntent(
    DriveKey drive,
    List<CompanionThought> thoughts,
  ) {
    final candidates = thoughts.where(
      (t) => t.driveKey == drive.name && t.canDriveIntent,
    );
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.strength >= b.strength ? a : b);
  }
}
