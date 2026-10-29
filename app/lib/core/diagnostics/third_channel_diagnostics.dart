import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../ai/third_channel_event.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import 'third_channel_failure_notice.dart';

/// Optional diagnostics never delay a request or grant retry/fallback authority.
/// Each sink captures its brain identity before the asynchronous transport.
class ThirdChannelDiagnostics {
  ThirdChannelDiagnostics(this.db, this.fence, this.lane);
  static const settingKey = 'third_channel_diagnostics_v1';
  static const maxEvents = 40;
  static const lanes = {'final_reply', 'proactive_final_reply',
    'qq_private_reply', 'qq_group_reply', 'app_vision', 'qq_vision',
    'connection_test', 'calendar_followup', 'cedar_live_share',
    'immersive_final_reply'};
  final AppDatabase db;
  final BrainWorkFence fence;
  final String lane;
  Future<void> _pending = Future<void>.value();

  static Future<ThirdChannelDiagnostics?> capture(AppDatabase db,
      {required String lane}) async {
    try {
      final fence = await db.captureBrainWorkFence();
      return fence == null ? null : ThirdChannelDiagnostics(db, fence, lane);
    } catch (_) { return null; }
  }
  void record(ThirdChannelEvent event) {
    _pending = _pending.then((_) async {
      final handle = await db.database;
      await handle.transaction((txn) async {
        if (!await fence.matches(txn)) return;
        final rows = decode(await BrainWorkFence.value(txn, settingKey));
        rows.add(sanitize({...event.toJson(), 'lane': lane}));
        final bounded = rows.length <= maxEvents ? rows : rows.sublist(rows.length - maxEvents);
        await txn.insert('settings', {'key': settingKey, 'value': jsonEncode(bounded)},
          conflictAlgorithm: ConflictAlgorithm.replace);
        // Persist a visible, dismissible status independently of reply success.
        // Connection tests already show their own error; cancellation and stale
        // ownership are never reported as gateway failures.
        final dismissedAt = int.tryParse(await BrainWorkFence.value(
          txn, ThirdChannelFailureNotice.dismissedAtKey)) ?? 0;
        if (lanes.contains(lane) && lane != 'connection_test' &&
            event.outcome == 'failed' && event.at > dismissedAt &&
            !{'user_cancelled', 'not_current'}.contains(event.code)) {
          await txn.insert('settings', {
            'key': ThirdChannelFailureNotice.settingKey,
            'value': ThirdChannelFailureNotice.message(event.code),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    }).catchError((Object _) { /* Diagnostics cannot break a reply. */ });
  }
  Future<void> flush() => _pending;

  static Map<String, Object?> sanitize(Map raw) {
    String member(String key, Set<String> allowed, String fallback) =>
      allowed.contains(raw[key]) ? raw[key] as String : fallback;
    int number(String key, int maximum) => raw[key] is int
      ? (raw[key] as int).clamp(0, maximum).toInt() : 0;
    return {
      'at': number('at', 8640000000000000),
      'lane': member('lane', lanes, 'unclassified'),
      'stage': member('stage', {'health', 'model', 'configuration'}, 'configuration'),
      'outcome': member('outcome', {'success', 'incomplete', 'failed', 'cancelled', 'suspended'}, 'failed'),
      'code': ThirdChannelEvent.safeCode(raw['code']),
      'transport': member('transport', {'none', 'dns', 'tls', 'timeout', 'connection', 'unknown'}, 'unknown'),
      for (final key in ['elapsed_ms', 'health_elapsed_ms', 'health_timeout_ms',
          'model_elapsed_ms', 'headers_elapsed_ms', 'first_event_elapsed_ms', 'first_content_elapsed_ms'])
        key: number(key, 86400000),
      'request_id': raw['request_id'] is String &&
          RegExp(r'^[a-z0-9]{1,20}-[a-z0-9]{1,12}$').hasMatch(raw['request_id'] as String)
          ? raw['request_id'] : '',
      'reasoning_effort': member('reasoning_effort', {'low','medium','high'}, ''),
      'streaming': raw['streaming'] == true,
      'request_bytes': number('request_bytes', 100000000),
      'transport_reused': raw['transport_reused'] == true,
      'sse_tail_aborted': raw['sse_tail_aborted'] == true,
      'attempts': number('attempts', 2),
      'health_http_status': number('health_http_status', 599),
      'model_http_status': number('model_http_status', 599),
    };
  }
  static List<Map<String, Object?>> decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is! List) return [];
      return value.whereType<Map>().map(sanitize).toList().reversed
        .take(maxEvents).toList().reversed.toList();
    } catch (_) { return []; }
  }
  static Future<Map<String, Object?>> read(AppDatabase db) async => {
    'maxEvents': maxEvents,
    'events': decode(await db.getSetting(settingKey) ?? ''),
    'contentIncluded': false, 'credentialsIncluded': false,
    'urlsIncluded': false, 'rawErrorsIncluded': false,
  };
}
