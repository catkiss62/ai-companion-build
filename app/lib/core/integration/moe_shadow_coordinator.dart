import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/world_book_turn_context.dart';
import '../moe/application/moe_dynamics_policy.dart';
import '../moe/domain/moe_models.dart';
import '../moe/infrastructure/sqlite_moe_repository.dart';
import 'moe_input_adapter.dart';

/// D2 shadow runtime: observes durable assistant commits and advances numeric
/// Moe state. It is fail-open and has no Prompt/action/tool integration.
class MoeShadowCoordinator {
  MoeShadowCoordinator(
    this.db, {
    MoeInputAdapter adapter = const MoeInputAdapter(),
    MoeDynamicsPolicy policy = const MoeDynamicsPolicy(),
  })  : _adapter = adapter,
        _policy = policy,
        _repository = SqliteMoeRepository(() => db.database);

  final AppDatabase db;
  final MoeInputAdapter _adapter;
  final MoeDynamicsPolicy _policy;
  final SqliteMoeRepository _repository;

  Future<void> observeCompletedTurn(ChatMessage assistant) async {
    if (!assistant.isAssistant) return;
    if (WorldBookTurnContext.decode(assistant.worldBookContextJson).hasRoleplay) {
      return;
    }
    try {
      await _observe(assistant).timeout(const Duration(seconds: 3));
      await db.setSetting('moe_shadow_status', 'healthy');
      await db.setSetting('moe_shadow_last_error_category', '');
    } catch (error) {
      try {
        await db.setSetting('moe_shadow_status', 'degraded');
        await db.setSetting(
          'moe_shadow_last_error_category',
          error.runtimeType.toString(),
        );
      } catch (_) {
        // Shadow diagnostics must not surface an error into chat delivery.
      }
    }
  }

  Future<void> _observe(ChatMessage assistant) async {
    final input = _adapter.fromCompletedTurn(
      assistant: assistant,
      desire: await db.loadDesire(),
      relationshipDay: (await db.relationshipAge(now: assistant.createdAt))
          .dayNumber,
      personalityTrial:
          await db.activePersonalityTrial(now: assistant.createdAt),
      specialStyleTrial:
          await db.activeSpecialStyleTrial(now: assistant.createdAt),
    );
    final event = input.event!;
    final state = await _repository.advanceEventIfNew(
      event,
      advance: (previous) => _policy.advance(
        previous: previous,
        input: input,
        now: assistant.createdAt,
      ),
    );
    final plan = _policy.expressionPlan(state);
    await db.setSetting(
      'moe_shadow_last_observed_at',
      assistant.createdAt.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting('moe_shadow_last_message_id', assistant.id);
    await db.setSetting(
      'moe_shadow_last_primary',
      plan.primary?.key ?? '',
    );
  }

  /// Reconciles only turns committed after D2 was first enabled. Existing chat
  /// history never produces a one-time attribute spike after an upgrade.
  Future<void> reconcileRecentCommittedTurns() async {
    final now = DateTime.now();
    final rawCursor = await db.getSetting('moe_shadow_reconciled_at');
    if (rawCursor == null || rawCursor.isEmpty) {
      await db.setSetting(
        'moe_shadow_started_at',
        now.millisecondsSinceEpoch.toString(),
      );
      await db.setSetting(
        'moe_shadow_reconciled_at',
        now.millisecondsSinceEpoch.toString(),
      );
      await db.setSetting('moe_shadow_status', 'ready');
      return;
    }
    final cursorMs = int.tryParse(rawCursor);
    final cursor = cursorMs == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(cursorMs);
    final messages = await db.messagesAfter(cursor, limit: 120);
    var latest = cursor;
    for (final message in messages) {
      if (message.isAssistant) await observeCompletedTurn(message);
      if (message.createdAt.isAfter(latest)) latest = message.createdAt;
    }
    await db.setSetting(
      'moe_shadow_reconciled_at',
      latest.millisecondsSinceEpoch.toString(),
    );
  }
}
