import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/brain_work_fence.dart';
import '../self/dream_store.dart';

/// Private creation has its own permission; chat's thinking switch is unrelated.
class CreativeAutonomyPolicy {
  static const enabledKey = 'creative_autonomy_enabled';
  static const epochKey = 'creative_autonomy_epoch';
  static const stateKey = 'creative_inspiration_v1';
  static const attemptKey = 'creative_inspiration_attempt_v1';
  static const lease = 'creative_inspiration_lease_until';
  static const maxIdeas = 12;
  static const maxPrivateWorks = 8;
  static bool autonomous(Map work) => work['origin'] == 'autonomous';
  static bool visible(Map work) => work.isNotEmpty && work['status'] != 'deleted' &&
      (!autonomous(work) || work['visibility'] == 'shared');

  static Future<bool> idle(DatabaseExecutor sql, DateTime now, {bool grace = true}) async =>
      await BrainWorkFence.value(sql, enabledKey) == '1' &&
      await DreamStore.idle(sql, now, manual: !grace);

  static void validateState(Map state) {
    if (state.isEmpty) return;
    if (state['schema'] != 1 || state['ideas'] is! List ||
        (state['ideas'] as List).length > maxIdeas ||
        utf8.encode(jsonEncode(state)).length > 48000) {
      throw const FormatException('自主构思存档无效');
    }
    if ((state.containsKey('suspended') && state['suspended'] is! bool) ||
        (state.containsKey('next_at') && state['next_at'] is! int) ||
        (state.containsKey('blocked_sources') && (state['blocked_sources'] is! List ||
          (state['blocked_sources'] as List).length > 64 ||
          (state['blocked_sources'] as List).any((s) => s is! String)))) {
      throw const FormatException('自主构思恢复状态无效');
    }
    for (final raw in state['ideas'] as List) {
      if (raw is! Map || raw['id'] is! String || raw['brief'] is! String ||
          raw['motive'] is! String || raw['evidence'] is! List ||
          (raw['brief'] as String).length > 3000 || (raw['motive'] as String).length > 800 ||
          (raw['evidence'] as List).length > 3 ||
          !{'held', 'building', 'retired'}.contains(raw['status'])) {
        throw const FormatException('自主构思记录无效');
      }
      for (final e in raw['evidence'] as List) {
        if (e is! Map || e['id'] is! String || e['fingerprint'] is! String || e['quote'] is! String) {
          throw const FormatException('自主构思来源无效');
        }
      }
    }
  }

  static void validateWork(Map data) {
    if (data.containsKey('origin') && !{'commission', 'autonomous'}.contains(data['origin'])) {
      throw const FormatException('作品来源无效');
    }
    if (autonomous(data) && (!{'private', 'shared'}.contains(data['visibility']) ||
        data['idea_id'] is! String || data['request_id'] is! String ||
        data['motive'] is! String || data['versions'] is! List ||
        (data['versions'] as List).any((s) => s is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(s)) ||
        (data['status'] == 'ready' && (data['current'] is! String || (data['current'] as String).isEmpty)))) {
      throw const FormatException('自主作品可见性或来源丢失');
    }
    if (data.containsKey('completed_request') && data['completed_request'] is! String) {
      throw const FormatException('制作完成回执无效');
    }
  }
}

/// Repeat the idle check inside the checkpoint transaction, so a chat that
/// starts after preview/model completion can still prevent the late write.
class CreativeAutonomyFence extends BrainWorkFence {
  CreativeAutonomyFence(BrainWorkFence source, this.now) : super(
    identity: source.identity, leaseKey: source.leaseKey,
    leaseToken: source.leaseToken, expectedSettings: source.expectedSettings);
  final DateTime Function() now;

  @override
  Future<bool> matches(DatabaseExecutor db) async =>
      await super.matches(db) && await CreativeAutonomyPolicy.idle(db, now(), grace: false);
}
