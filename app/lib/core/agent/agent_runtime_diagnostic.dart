import 'dart:convert';
import '../database/app_database.dart';
import '../mcp/cedar_toy_activity.dart';
import '../mcp/cedar_timed_play_task.dart';

/// Observed local task state, never credentials, payloads or a guessed cause.
class AgentRuntimeDiagnostic {
  static Map<String, dynamic> _map(String? raw) {
    try { final v=jsonDecode(raw ?? ''); if(v is Map)return Map<String,dynamic>.from(v); }
    catch (_) { /* Missing legacy records stay unknown. */ }
    return {};
  }
  static Future<Map<String, Object?>> read(AppDatabase db, {String turnId=''}) async {
    final raw=_map(await db.getSetting('route_task_intent_v1'));
    final sameTurn=turnId.isEmpty || raw['turn_id']==turnId;
    final intent=sameTurn && raw['intent'] is Map ? raw['intent'] as Map : const {};
    final state=await CedarToyActivityStore(db).loadState();
    final requestedGame=intent['game_id']?.toString() ?? '';
    final game=requestedGame.isEmpty ? state.activeGameId : requestedGame;
    final session=state.sessions[game];
    final pending=game.isEmpty ? null : await CedarToyActivityStore(db).unresolvedWrite(game);
    final task=await CedarTimedPlayTaskStore(db).active();
    final staged=_map(await db.getSetting(CedarTimedPlayTaskStore.pendingKey));
    return {
      'observations_only':true, 'task_intent_available':intent['available']==true,
      'game_action':intent['game_action'], 'target_game':game,
      'target_session_present':session!=null, 'target_phase':session?.phase.key,
      'last_remote_result_at':session?.lastOutcomeAt?.millisecondsSinceEpoch,
      'unresolved_fields':intent['unresolved_fields'] ?? const [],
      'action_resolution':intent['action_resolution'],
      'action_probabilities':intent['action_probabilities'] ?? const {},
      'duration_minutes':intent['minutes'], 'guide_complete':session?.guideComplete,
      'unknown_write_present':pending!=null, 'unknown_write_state':pending?['state'],
      'reconciliation_attempts':pending?['query_attempts'],
      'active_timed_task':task!=null,
      'active_task_matches_target':task!=null && task['gameId']==game,
      'staged_timed_task':staged.isNotEmpty, 'blocked_reason':task?['blockReason'],
      'actual_progress_count':task?['progressCount'], 'effective_used_ms':task?['usedMs'],
      'game_enabled':await db.getSetting('cedar_toy_enabled')!='0',
      'background_game_enabled':await db.getSetting('cedar_toy_autonomy_enabled')!='0',
      'interpretation':'未登记表示没有这次后台任务；未知写入不证明远端失败。只能按已观测状态解释，不可声称读到了源码或查明了未核实的根因。',
    };
  }
}
