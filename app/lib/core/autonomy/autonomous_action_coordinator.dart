import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../desire/desire_core_policy.dart';
import '../desire/desire_engine.dart';
import '../models/autonomous_action.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';
import 'autonomous_action_policy.dart';

/// Durable bridge from the existing Desire Intent to a tool Provider.
///
/// v0.34.8 schedules the first provider from the existing heartbeat only after
/// Desire has selected an Intent. That keeps Desire/Thought as the only
/// motivation source; this coordinator never invents a second one.
class AutonomousActionCoordinator {
  AutonomousActionCoordinator(this.db);

  final AppDatabase db;
  final Uuid _uuid = Uuid();

  Future<AutonomousActionRequestResult> requestFromDesire({
    required DesireIntent intent,
    required AutonomousToolKind tool,
    required String dedupeMaterial,
    required bool providerAvailable,
    required bool screenInteractive,
    required bool deviceLocked,
    required bool sensitiveSurface,
    int? budgetLimit,
    Duration? budgetWindow,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final identity = await db.transferStateIdentity();
    await db.recoverStaleAutonomousActions(
      now: instant,
      stateGeneration: identity.generation,
      deviceId: identity.deviceId,
    );
    final dedupeHash = sha256.convert(utf8.encode(dedupeMaterial)).toString();
    final dedupeKey = '${tool.key}:${dedupeHash.substring(0, 24)}';
    final duplicate = await db.hasActiveAutonomousActionDedupe(dedupeKey);
    final budgetUsed = budgetLimit == null || budgetWindow == null
        ? 0
        : await db.autonomousToolUsageSince(
            tool,
            instant.subtract(budgetWindow),
          );
    final context = AutonomousActionContext(
      activeBrain: (await db.getSetting('active_brain')) != '0',
      transferLocked: (await db.getSetting('transfer_lock')) == '1',
      generationActive: await db.blockingGenerationJob() != null,
      screenInteractive: screenInteractive,
      deviceLocked: deviceLocked,
      sensitiveSurface: sensitiveSurface,
      providerAvailable: providerAvailable,
      duplicateActive: duplicate,
      budgetLimit: budgetLimit,
      budgetUsed: budgetUsed,
    );
    final request = AutonomousActionRequest(
      id: _uuid.v4(),
      dedupeKey: dedupeKey,
      tool: tool,
      intentAction: intent.wantAction,
      driveKey: intent.drive.name,
      intentScore: intent.score,
      reasonSource: intent.reasonSource,
      thoughtId: intent.thoughtId,
      requestedAt: instant,
    );
    final decision = AutonomousActionPolicy.evaluate(
      request: request,
      context: context,
    );
    final recorded = await db.recordAutonomousActionRequest(
      request: request,
      context: context,
      decision: decision,
      stateGeneration: identity.generation,
      deviceId: identity.deviceId,
    );
    return AutonomousActionRequestResult(
      request: request,
      decision: decision,
      recorded: recorded,
    );
  }

  Future<AutonomousActionRun?> claim({
    required String id,
    required String runToken,
    DateTime? now,
  }) =>
      db.claimAutonomousAction(id: id, runToken: runToken, now: now);

  Future<bool> completeSuccess({
    required AutonomousActionRun run,
    required String runToken,
    required AutonomousOutcomeKind outcome,
    required int resultCount,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final primaryDrive = DriveKey.values.firstWhere(
      (value) => value.name == run.driveKey,
      orElse: () => DriveKey.curiosity,
    );
    return db.completeAutonomousAction(
      id: run.id,
      runToken: runToken,
      status: AutonomousActionStatus.succeeded,
      outcome: outcome,
      resultCount: resultCount,
      now: instant,
      satisfyOnSuccess: (snapshot) {
        final drives = DesireCorePolicy.satisfiedDrives(
          snapshot: snapshot,
          action: run.intentAction,
          primaryDrive: primaryDrive,
          intensity: 0.32,
        );
        final refractory = Map<DriveKey, DateTime>.from(
          snapshot.refractoryUntil,
        )..[primaryDrive] = instant.add(const Duration(minutes: 30));
        return snapshot.copyWith(
          drives: drives,
          refractoryUntil: refractory,
          lastSatisfiedAction: 'tool:${run.tool.key}:${run.intentAction}',
          lastSatisfiedAt: instant,
          lastWildcardAt: run.intentAction == 'wildcard_share'
              ? instant
              : snapshot.lastWildcardAt,
        );
      },
    );
  }

  Future<bool> completeWithoutSatisfaction({
    required AutonomousActionRun run,
    required String runToken,
    required AutonomousActionStatus status,
    required AutonomousOutcomeKind outcome,
    DateTime? now,
  }) {
    if (status == AutonomousActionStatus.succeeded) {
      return Future<bool>.value(false);
    }
    return db.completeAutonomousAction(
      id: run.id,
      runToken: runToken,
      status: status,
      outcome: outcome,
      resultCount: 0,
      now: now,
    );
  }

  Future<int> completePublicWebSuccess({
    required AutonomousActionRun run,
    required String runToken,
    required List<PublicWebCandidateDraft> candidates,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final primaryDrive = DriveKey.values.firstWhere(
      (value) => value.name == run.driveKey,
      orElse: () => DriveKey.curiosity,
    );
    return db.completePublicWebDiscovery(
      id: run.id,
      runToken: runToken,
      candidates: candidates,
      now: instant,
      satisfyOnSuccess: (snapshot) {
        final drives = DesireCorePolicy.satisfiedDrives(
          snapshot: snapshot,
          action: 'discover_interest',
          primaryDrive: primaryDrive,
          intensity: 0.24,
        );
        final refractory = Map<DriveKey, DateTime>.from(
          snapshot.refractoryUntil,
        )..[primaryDrive] = instant.add(const Duration(minutes: 45));
        return snapshot.copyWith(
          drives: drives,
          refractoryUntil: refractory,
          lastSatisfiedAction: 'tool:public_web:discover_interest',
          lastSatisfiedAt: instant,
        );
      },
    );
  }
}
