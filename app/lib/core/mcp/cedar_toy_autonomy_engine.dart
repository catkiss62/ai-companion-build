import 'dart:convert';
import 'dart:math';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../storage/secure_config.dart';
import 'cedar_toy_activity.dart';
import 'cedar_toy_client.dart';

class CedarAutonomyAvailability {
  const CedarAutonomyAvailability(this.available, this.reason);
  final bool available;
  final String reason;
}

class CedarAutonomyProgress {
  const CedarAutonomyProgress(this.state, {this.notable = false});
  final String state;
  final bool notable;
}

/// Advances at most one Cedar activity step after the shared Desire selector
/// chooses `play_game`. All interpretation is one DeepSeek JSON judgment; MCP
/// itself only supplies real tools and outcomes.
class CedarToyAutonomyEngine {
  CedarToyAutonomyEngine({
    required this.db,
    required this.ai,
    required this.secureConfig,
  });

  static const enabledKey = 'cedar_toy_autonomy_enabled';
  static const shareEnabledKey = 'cedar_toy_game_share_enabled';
  static const lastProgressKey = 'cedar_toy_last_autonomous_progress_at';
  static const minProgressGap = Duration(minutes: 20);

  final AppDatabase db;
  final DeepSeekClient ai;
  final SecureConfig secureConfig;

  Future<CedarAutonomyAvailability> availability({required DateTime now}) async {
    if ((await db.getSetting('cedar_toy_enabled')) == '0' ||
        (await db.getSetting(enabledKey)) == '0') {
      return const CedarAutonomyAvailability(false, 'disabled');
    }
    final token = (await secureConfig.readCedarToyToken())?.trim() ?? '';
    if (token.isEmpty) {
      return const CedarAutonomyAvailability(false, 'unconfigured');
    }
    final session = await CedarToyActivityStore(db).load();
    if (session != null &&
        const <CedarActivityPhase>{
          CedarActivityPhase.awaitingInvitation,
          CedarActivityPhase.waitingUser,
          CedarActivityPhase.waitingRemote,
          CedarActivityPhase.paused,
        }.contains(session.phase)) {
      return const CedarAutonomyAvailability(false, 'waiting');
    }
    final lastMillis = int.tryParse(await db.getSetting(lastProgressKey) ?? '');
    if (lastMillis != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastMillis)) <
            minProgressGap) {
      return const CedarAutonomyAvailability(false, 'cooldown');
    }
    return const CedarAutonomyAvailability(true, 'ready');
  }

  Future<CedarAutonomyProgress> progress({required DateTime now}) async {
    final availability = await this.availability(now: now);
    if (!availability.available) return CedarAutonomyProgress(availability.reason);
    final token = (await secureConfig.readCedarToyToken())?.trim() ?? '';
    final apiKey = (await secureConfig.readApiKey())?.trim() ?? '';
    if (token.isEmpty || apiKey.isEmpty) {
      return const CedarAutonomyProgress('missing_config');
    }
    final endpoint = await secureConfig.readEndpoint();
    final client = CedarToyClient(token: token);
    final store = CedarToyActivityStore(db);
    final session = await store.load();
    await db.setSetting(lastProgressKey, now.millisecondsSinceEpoch.toString());

    if (session == null ||
        session.phase == CedarActivityPhase.completed ||
        session.phase == CedarActivityPhase.failed) {
      final catalogOutcome = await client.listGames();
      if (catalogOutcome.isError || catalogOutcome.text.trim().isEmpty) {
        return const CedarAutonomyProgress('catalog_failed');
      }
      final catalog = CedarToyClient.redactSecrets(catalogOutcome.text);
      await store.saveCatalog(catalog);
      final picked = await _judge(
        apiKey: apiKey,
        endpoint: endpoint,
        instruction: '''从真实 Cedar Toy 游戏列表中，按她此刻想找一点轻松新鲜感的动机选择一个游戏。只返回 JSON：{"game":"精确ID","title":"显示名"}。不得发明列表外 ID。\n\n$catalog''',
      );
      final game = _identifier(picked['game']?.toString() ?? '');
      if (game.isEmpty || !_containsIdentifier(catalog, game)) {
        return const CedarAutonomyProgress('invalid_game_choice');
      }
      final guideOutcome = await client.getGuide(game);
      if (guideOutcome.isError || guideOutcome.text.trim().isEmpty) {
        return const CedarAutonomyProgress('guide_failed');
      }
      final recorded = await store.recordGuide(
        gameId: game,
        gameTitle: picked['title']?.toString().trim() ?? '',
        guide: CedarToyClient.redactSecrets(guideOutcome.text),
      );
      return CedarAutonomyProgress(
        recorded.guideComplete ? 'guide_ready' : 'guide_too_long',
      );
    }

    if (!session.guideComplete) {
      return const CedarAutonomyProgress('guide_incomplete');
    }
    final judged = await _judge(
      apiKey: apiKey,
      endpoint: endpoint,
      instruction: '''你在为 AI 伴侣推进一局真实 Cedar Toy 游戏。只依据完整指南与本机真实局面，返回 JSON：
{"participation_mode":"solo|co_play|multiplayer|hybrid|unknown","action":"指南中的精确动作名","params":{},"next_actor":"companion|user|shared|wait|finished","share_level":"quiet|notable|required"}
共玩、多人或混合模式必须先邀请用户；这时 action 可以为空，绝不能假装已经 play。单人模式每次只推进一步。不得打开 GitHub 或补写结果。

${store.promptContext(session)}''',
    );
    final mode = CedarParticipationMode.fromKey(
      judged['participation_mode']?.toString(),
    );
    if (mode.requiresInvitation && !session.invitationApproved) {
      await store.markInvitationRequired(
        gameId: session.gameId,
        mode: mode,
        reason: '她想玩 ${session.displayName}，真实指南表明需要你一起参与。',
      );
      await _seedThought(
        text: '我在游戏厅看中了“${session.displayName}”，但这是共玩游戏。我想先邀请你，等你答应再开局。',
        strength: 0.82,
        eventId: 'invite-${now.microsecondsSinceEpoch}',
        gameId: session.gameId,
      );
      return const CedarAutonomyProgress('invitation_staged', notable: true);
    }
    if (mode == CedarParticipationMode.unknown) {
      return const CedarAutonomyProgress('mode_unknown');
    }
    final action = _identifier(judged['action']?.toString() ?? '');
    if (action.isEmpty || !_containsIdentifier(session.guide, action)) {
      return const CedarAutonomyProgress('invalid_action_choice');
    }
    final rawParams = judged['params'];
    final params = rawParams is Map
        ? rawParams.map((key, value) => MapEntry(key.toString(), value))
        : <String, Object?>{};
    final outcome = await client.play(session.gameId, action, params);
    final shareLevel = const <String>{'quiet', 'notable', 'required'}
            .contains(judged['share_level'])
        ? judged['share_level'].toString()
        : 'quiet';
    final updated = await store.recordPlay(
      gameId: session.gameId,
      action: action,
      outcome: outcome,
      mode: mode,
      nextActor: judged['next_actor']?.toString() ?? 'companion',
      shareLevel: shareLevel,
      invitationApproved: session.invitationApproved,
    );
    if (!outcome.isError &&
        shareLevel != 'quiet' &&
        (await db.getSetting(shareEnabledKey)) != '0') {
      await _seedThought(
        text: '我刚在 Cedar Toy 的“${session.displayName}”真实推进了一步。${updated.lastOutcome}',
        strength: shareLevel == 'required' ? 0.90 : 0.72,
        eventId: updated.events.last.id,
        gameId: session.gameId,
      );
    }
    return CedarAutonomyProgress(
      outcome.isError ? 'play_failed' : 'played_one_step',
      notable: shareLevel != 'quiet',
    );
  }

  Future<Map<String, dynamic>> _judge({
    required String apiKey,
    required String endpoint,
    required String instruction,
  }) =>
      ai.jsonCompletion(
        apiKey: apiKey,
        model: DeepSeekModelProfile.flash,
        endpoint: endpoint,
        thinking: true,
        effort: ReasoningEffort.high,
        maxTokens: 900,
        messages: <Map<String, Object?>>[
          <String, Object?>{'role': 'system', 'content': instruction},
        ],
      );

  Future<void> _seedThought({
    required String text,
    required double strength,
    required String eventId,
    required String gameId,
  }) =>
      db.upsertThought(
        text: _bounded(text, 12000),
        drive: DriveKey.curiosity,
        kind: 'flit',
        strength: strength,
        source: 'mcp/cedar_game:$gameId:$eventId',
        topicKey: 'cedar_game:$gameId',
      );

  static String _identifier(String value) {
    final clean = value.trim();
    return RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(clean) ? clean : '';
  }

  static bool _containsIdentifier(String source, String identifier) => RegExp(
        '(^|[^A-Za-z0-9_.:-])${RegExp.escape(identifier)}([^A-Za-z0-9_.:-]|\$)',
      ).hasMatch(source);

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';
}
