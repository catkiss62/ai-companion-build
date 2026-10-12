import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';

class DailyBalanceView {
  const DailyBalanceView({required this.label, required this.detail,
    this.balanceLabel});
  final String label;
  final String detail;
  final String? balanceLabel;
}

/// A bounded local accumulator, independent of model token/pricing metadata.
/// Each key/currency retains its current day and latest successful observation.
/// Values are fixed-point, so repeated small decreases do not accumulate
/// floating-point rounding errors. No API key is written to the database.
class DailyBalanceSpend {
  static const prefix = 'deepseek_balance_spend_v1:';
  static const scale = 100000000;
  static String day(DateTime at) => at.toLocal().toIso8601String().substring(0, 10);
  static String account(String apiKey) => sha256.convert(utf8.encode(apiKey.trim())).toString();
  static String stateKey(String accountId) => '$prefix$accountId';

  static int? parseAmount(Object? value) {
    if (value is! num && value is! String) return null;
    final number = double.tryParse(value.toString());
    // Keep the fixed-point integer exact even when a backup is read by JS.
    if (number == null || !number.isFinite || number.abs() > 10000000) return null;
    return (number * scale).round();
  }

  static Map<String, dynamic> _decode(String? raw) {
    try {
      final value = jsonDecode(raw ?? '');
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) { return {}; }
  }

  static Future<bool> hasBaseline(AppDatabase db, String accountId,
      {DateTime? now}) async {
    final state = _decode(await db.getSetting(stateKey(accountId)));
    final currencies = state['currencies'];
    return currencies is Map && currencies.values.any((value) =>
      value is Map && value['day'] == day(now ?? DateTime.now()));
  }

  static Future<bool> record(AppDatabase db, {
    required String accountId,
    required Map<String, int> balances,
    required DateTime requestedAt,
    required DateTime observedAt,
    required BrainWorkFence fence,
  }) async {
    if (accountId.isEmpty || balances.isEmpty || observedAt.isBefore(requestedAt)) return false;
    final handle = await db.database;
    return handle.transaction((txn) async {
      // A balance response from before an import/transfer must never write into
      // the newly restored companion, even if its API key stayed the same.
      if (!await fence.matches(txn)) return false;
      final key = stateKey(accountId);
      final state = _decode(await BrainWorkFence.value(txn, key));
      final currencies = state['currencies'] is Map
          ? Map<String, dynamic>.from(state['currencies'] as Map) : <String, dynamic>{};
      var changed = false;
      for (final entry in balances.entries) {
        if (entry.key != 'CNY' && entry.key != 'USD') continue;
        final old = currencies[entry.key] is Map ? currencies[entry.key] as Map : const {};
        final requestMs = requestedAt.millisecondsSinceEpoch;
        final readMs = observedAt.millisecondsSinceEpoch;
        final previousRequest = old['request_at'];
        // Foreground/background and concurrent dialogs can finish out of order.
        if (previousRequest is int && requestMs <= previousRequest) continue;
        final sameDay = old['day'] == day(observedAt) &&
            day(requestedAt) == day(observedAt) &&
            old['last'] is int && old['spent'] is int;
        final previous = sameDay ? old['last'] as int : entry.value;
        final spent = sameDay ? old['spent'] as int : 0;
        final decrease = previous > entry.value ? previous - entry.value : 0;
        currencies[entry.key] = <String, dynamic>{
          'day': day(observedAt), 'started_at': sameDay ? old['started_at'] : readMs,
          'request_at': requestMs, 'read_at': readMs, 'last': entry.value,
          'spent': spent + decrease,
        };
        changed = true;
      }
      if (!changed) return false;
      await txn.rawInsert('INSERT OR REPLACE INTO settings (key,value) VALUES (?,?)',
        [key, jsonEncode({'schema': 1, 'currencies': currencies})]);
      return true;
    });
  }

  static String _money(String currency, int value, {int digits = 2}) =>
      '${currency == 'CNY' ? '¥' : '\$'}${(value / scale).toStringAsFixed(digits)}';

  static String _clock(Object? milliseconds) {
    if (milliseconds is! int) return '未知';
    final at = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  static Future<DailyBalanceView> today(AppDatabase db, String accountId,
      {DateTime? now}) async {
    final state = _decode(await db.getSetting(stateKey(accountId)));
    final currencies = state['currencies'] is Map ? state['currencies'] as Map : const {};
    final parts = <String>[];
    final details = <String>[];
    final amounts = <String>[];
    for (final currency in ['CNY', 'USD']) {
      final item = currencies[currency];
      if (item is! Map || item['day'] != day(now ?? DateTime.now()) ||
          item['spent'] is! int || item['last'] is! int) continue;
      parts.add('-${_money(currency, item['spent'] as int)}');
      amounts.add(_money(currency, item['last'] as int, digits: 4));
      details.add('$currency：${_clock(item['started_at'])} 起算，'
        '${_clock(item['read_at'])} 最近读取；累计约 ${_money(currency, item['spent'] as int, digits: 4)}。');
    }
    const explanation = '按账户余额成功读数估算，包含同一账户其他设备或应用的消耗。'
      '余额下降计入消耗；余额上升视为充值并更新参照，已累计消耗不清零。'
      '充值和使用发生在两次读取之间时可能少计。'
      '按手机本地日期每天 0 点尝试读取；关机、进程停止或断网时无法取得零点余额，'
      '当天首次成功读取后开始统计，不把未知的跨日消耗算进今天。';
    return DailyBalanceView(
      label: parts.isEmpty ? '今日：待记录' : '今日：${parts.join(' / ')}',
      detail: '${details.isEmpty ? '尚未取得今天的余额基线。' : details.join('\n')}\n$explanation',
      balanceLabel: amounts.isEmpty ? null : 'DeepSeek 余额：${amounts.join(' / ')}',
    );
  }
}
