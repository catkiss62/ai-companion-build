import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import 'cedar_game_protocol.dart';
import 'cedar_toy_activity.dart';

/// Sharing judges saved evidence during the existing next-step planning
/// request. No additional model call sits between a remote write and its save.
class CedarLiveSharePolicy {
  CedarLiveSharePolicy(this.db);
  final AppDatabase db;
  static const key = 'cedar_live_share_v1';

  static List<CedarGameEvent> evidence(
    CedarGameSession session,
    DateTime now,
  ) => session.events
      .where(
        (event) =>
            event.kind == 'outcome' &&
            !CedarPlatformActionPolicy.isReadOnly(event.action) &&
            !CedarPlatformActionPolicy.isPlatformAction(event.action) &&
            !CedarPlatformActionPolicy.isResultSnapshot(event.action) &&
            !now.isBefore(event.createdAt) &&
            now.difference(event.createdAt) <= const Duration(hours: 1),
      )
      .toList()
      .reversed
      .take(6)
      .toList()
      .reversed
      .toList();

  Future<Map<String, dynamic>> _states() async {
    try {
      final raw = jsonDecode(await db.getSetting(key) ?? '{}');
      return raw is Map ? raw.cast<String, dynamic>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(
    CedarGameSession session,
    Map<String, dynamic> value,
  ) async {
    final states = await _states();
    states.remove(session.id);
    states[session.id] = value;
    while (states.length > 20) {
      states.remove(states.keys.first);
    }
    await db.setSetting(key, jsonEncode(states));
  }

  Future<Map<String, dynamic>> _state(CedarGameSession session) async {
    final value = (await _states())[session.id];
    return value is Map ? value.cast<String, dynamic>() : {};
  }

  Future<String> planningContext(CedarGameSession session, DateTime now) async {
    final state = await _state(session);
    final events = evidence(session, now);
    return '【过程分享判断资料】${jsonEncode({
          'saved_outcomes': events.map((event) => {'id': event.id, 'action': event.action, 'at': event.createdAt.toIso8601String(), 'text': event.summary.substring(0, event.summary.length.clamp(0, 1500).toInt())}).toList(),
          'last_evaluated_event': state['evaluated'] ?? '',
          'already_shared_or_shown': state['shown'] ?? '',
          'pending_share': state['pending'] ?? '',
        })}\n'
        'share_previous_outcome只判断这些已保存结果是否出现值得现在告诉用户的新发现、'
        '明显变化、有趣遭遇或阶段进展。可合并多步，小幅重复收益、移动、普通选择或'
        '上次已说过的结果保持false；不要每一步播报。没有新事件或仍有待发分享时填false。'
        '不得把当前计划的动作或尚未返回的结果当已发生；分享决定不影响下一步游戏动作。';
  }

  Future<void> noteForeground(CedarGameSession session) async {
    if (session.events.isEmpty) return;
    final state = await _state(session);
    await _save(session, {
      ...state,
      'evaluated': session.events.last.id,
      'sharedThrough': session.events.last.id,
      'shown': session.lastOutcome.substring(
        0,
        session.lastOutcome.length.clamp(0, 2500).toInt(),
      ),
    });
  }

  Future<void> offer(
    CedarGameSession session, {
    required bool share,
    required DateTime now,
  }) async {
    if (await db.getSetting('cedar_toy_game_share_enabled') == '0') return;
    final events = evidence(session, now);
    if (events.isEmpty) return;
    final state = await _state(session);
    final pending = state['pending']?.toString() ?? '';
    if (pending.isNotEmpty) {
      final sent = await db.messageById('cedar-share:$pending');
      if (sent == null)
        return; // Coalesce while the writer/user-chat lane is busy.
      state['shown'] = state['pendingEvidence'] ?? '';
      state['sharedThrough'] = state['pendingThrough'] ?? '';
      state['pending'] = '';
    }
    final latest = events.last;
    if (state['evaluated'] == latest.id) return;
    state['evaluated'] = latest.id;
    final sharedIndex = events.indexWhere(
      (event) => event.id == state['sharedThrough'],
    );
    final fresh = events.skip(sharedIndex + 1).toList();
    if (fresh.isEmpty) {
      await _save(session, state);
      return;
    }
    final text = fresh
        .map(
          (event) =>
              '${event.action}: ${event.summary.substring(0, event.summary.length.clamp(0, 900).toInt())}',
        )
        .join('\n');
    if (!share || text == state['shown']) {
      await _save(session, state);
      return;
    }
    final thoughtId = 'cedar-${latest.id}';
    final old = await db.thoughtById(thoughtId);
    if (old?.lastActedAt != null || (old?.actionCount ?? 0) > 0) {
      await _save(session, state);
      return;
    }
    if (old == null)
      await db.upsertThought(
        id: thoughtId,
        text: '我在“${session.displayName}”有这些已经确认的游戏进展：\n$text',
        drive: DriveKey.curiosity,
        kind: 'flit',
        strength: .84,
        source: 'mcp/cedar_game:${session.gameId}:${latest.id}',
        topicKey: 'cedar_game:${session.gameId}',
      );
    await CedarToyActivityStore(db).queueDirectShare(thoughtId);
    await _save(session, {
      ...state,
      'pending': thoughtId,
      'pendingEvidence': text,
      'pendingThrough': latest.id,
    });
  }
}
