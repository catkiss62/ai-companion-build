import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_balance.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/diagnostics/daily_balance_spend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final at = DateTime(2026, 10, 12, 0);
  final account = DailyBalanceSpend.account('test-only-key');
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async { await db.closeForTesting(); });

  Future<bool> record(String amount, int minutes, {String? accountId,
    String currency = 'CNY', DateTime? time}) async {
    final requested = time ?? at.add(Duration(minutes: minutes));
    return DailyBalanceSpend.record(db, accountId: accountId ?? account,
      balances: {currency: DailyBalanceSpend.parseAmount(amount)!},
      requestedAt: requested, observedAt: requested.add(const Duration(milliseconds: 20)),
      fence: (await db.captureBrainWorkFence())!);
  }
  Future<DailyBalanceView> today({String? accountId, DateTime? time}) =>
    DailyBalanceSpend.today(db, accountId ?? account, now: time ?? at.add(const Duration(hours: 1)));

  test('first reading establishes a baseline; only decreases add spending', () async {
    expect((await today()).label, '今日：待记录');
    await record('5', 0);
    expect((await today()).label, '今日：-¥0.00');
    await record('4.75', 1);
    await record('4.50', 2);
    expect((await today()).label, '今日：-¥0.50');
    expect((await today()).detail, contains('00:00 起算'));
    expect((await today()).detail, contains('00:02 最近读取'));
    expect((await today()).detail, contains('其他设备或应用'));
  });

  test('top-ups replace the reference without erasing already observed spending', () async {
    await record('5', 0);
    await record('4', 1);
    await record('15', 2);
    expect((await today()).label, '今日：-¥1.00');
    await record('14', 3);
    expect((await today()).label, '今日：-¥2.00');
    await record('30', 4);
    await record('29.5', 5);
    expect((await today()).label, '今日：-¥2.50');
  });

  test('midnight resets spend; a late first reading never assigns unknown overnight use', () async {
    await record('5', 0);
    await record('4', 2);
    final tomorrow = at.add(const Duration(days: 1, hours: 8));
    expect((await today(time: tomorrow)).label, '今日：待记录');
    await record('2', 0, time: tomorrow);
    expect((await today(time: tomorrow)).label, '今日：-¥0.00');
    expect((await today(time: tomorrow)).detail, contains('08:00 起算'));
    await record('1.5', 0, time: tomorrow.add(const Duration(minutes: 1)));
    expect((await today(time: tomorrow)).label, '今日：-¥0.50');
  });

  test('out-of-order or duplicate responses cannot invent recharge or spending', () async {
    await record('5', 0);
    await record('4', 3);
    expect(await record('2', 2), false);
    expect(await record('8', 3), false);
    expect((await today()).label, '今日：-¥1.00');
    await record('3', 4);
    expect((await today()).label, '今日：-¥2.00');
  });

  test('a request spanning midnight starts the new baseline and cannot replace a newer one', () async {
    final midnight = at.add(const Duration(days: 1));
    await record('5', 0);
    final fence = (await db.captureBrainWorkFence())!;
    expect(await DailyBalanceSpend.record(db, accountId: account,
      balances: {'CNY': DailyBalanceSpend.parseAmount('3')!},
      requestedAt: midnight.subtract(const Duration(seconds: 1)),
      observedAt: midnight.add(const Duration(seconds: 1)), fence: fence), true);
    expect((await today(time: midnight)).label, '今日：-¥0.00');
    await record('2', 0, time: midnight.add(const Duration(minutes: 1)));
    expect(await DailyBalanceSpend.record(db, accountId: account,
      balances: {'CNY': DailyBalanceSpend.parseAmount('4')!},
      requestedAt: midnight.subtract(const Duration(milliseconds: 500)),
      observedAt: midnight.add(const Duration(minutes: 2)), fence: fence), false);
    expect((await today(time: midnight)).label, '今日：-¥1.00');
  });

  test('accounts and currencies never share a baseline', () async {
    final other = DailyBalanceSpend.account('another-key');
    await record('5', 0);
    await record('4', 1);
    await record('20', 2, accountId: other);
    await record('18', 3, accountId: other);
    await record('3', 4, currency: 'USD');
    await record('2.50', 5, currency: 'USD');
    expect((await today()).label, '今日：-¥1.00 / -\$0.50');
    expect((await today(accountId: other)).label, '今日：-¥2.00');
    expect(account, isNot(contains('test-only-key')));
  });

  test('fixed-point reads keep tiny charges; invalid numbers are not zero balances', () async {
    for (final value in [null, true, {}, 'NaN', 'Infinity', 'bad']) {
      expect(DailyBalanceSpend.parseAmount(value), isNull);
    }
    expect(DailyBalanceSpend.parseAmount('0.00000001'), 1);
    await record('5', 0);
    await record('4.99999999', 1);
    final state = jsonDecode((await db.getSetting(DailyBalanceSpend.stateKey(account)))!) as Map;
    expect(state['currencies']['CNY']['spent'], 1);
    await record('-0.01', 2);
    expect((await today()).label, '今日：-¥5.01');
  });

  test('state survives export/import and later readings continue the same day', () async {
    await record('5', 0);
    await record('4.25', 1);
    final backup = await db.exportAll();
    expect(jsonEncode(backup), isNot(contains('test-only-key')));
    await db.importAll(Map<String, dynamic>.from(backup));
    expect((await today()).label, '今日：-¥0.75');
    await record('3.75', 2);
    expect((await today()).label, '今日：-¥1.25');
    final rows = await (await db.database).query('settings', where: 'key LIKE ?',
      whereArgs: ['${DailyBalanceSpend.prefix}%']);
    expect(rows, hasLength(1)); // Aggregate only, no per-read history growth.
  });

  test('restore and transfer invalidate asynchronous writes inside their transaction', () async {
    await record('5', 0);
    final fence = (await db.captureBrainWorkFence())!;
    await db.setSetting('runtime_state_epoch_v1', 'new-restored-state');
    expect(await DailyBalanceSpend.record(db, accountId: account,
      balances: {'CNY': DailyBalanceSpend.parseAmount('1')!},
      requestedAt: at.add(const Duration(minutes: 1)),
      observedAt: at.add(const Duration(minutes: 2)), fence: fence), false);
    expect((await today()).label, '今日：-¥0.00');
    final current = (await db.captureBrainWorkFence())!;
    await db.setSetting('transfer_lock', '1');
    expect(await DailyBalanceSpend.record(db, accountId: account,
      balances: {'CNY': 0}, requestedAt: at.add(const Duration(minutes: 3)),
      observedAt: at.add(const Duration(minutes: 4)), fence: current), false);
  });

  test('official successful balance reads persist before display resolves; failures do not overwrite', () async {
    var minutes = 0;
    var response = http.Response('{"balance_infos":[{"currency":"CNY","total_balance":"5"}]}', 200);
    final clientFactory = () => MockClient((request) async {
      expect(request.url.toString(), 'https://api.deepseek.com/user/balance');
      expect(request.headers['Authorization'], 'Bearer test-only-key');
      return response;
    });
    Future<String> fetch() => DeepSeekBalance.display(db: db,
      clientFactory: clientFactory, keyReader: () async => 'test-only-key',
      clock: () => at.add(Duration(minutes: minutes)));
    expect(await fetch(), 'DeepSeek 余额：¥5');
    expect((await today()).label, '今日：-¥0.00');
    minutes++;
    response = http.Response('{"balance_infos":[{"currency":"CNY","total_balance":"4.5"}]}', 200);
    await fetch();
    expect((await today()).label, '今日：-¥0.50');
    minutes++;
    response = http.Response('failed', 500);
    expect(await fetch(), contains('查询失败'));
    response = http.Response('{"balance_infos":[{"currency":"CNY","total_balance":"NaN"}]}', 200);
    expect(await fetch(), contains('无可显示金额'));
    expect((await today()).label, '今日：-¥0.50');
  });

  test('switching the configured key during HTTP discards the old account response', () async {
    final pending = Completer<http.Response>();
    final entered = Completer<void>();
    var key = 'test-only-key';
    final response = DeepSeekBalance.display(db: db, keyReader: () async => key,
      clock: () => at,
      clientFactory: () => MockClient((request) { entered.complete(); return pending.future; }));
    await entered.future;
    key = 'new-key';
    pending.complete(http.Response('{"balance_infos":[{"currency":"CNY","total_balance":"5"}]}', 200));
    expect(await response, contains('Key 已切换'));
    expect(await DailyBalanceSpend.hasBaseline(db, account, now: at), false);
    expect(await DailyBalanceSpend.hasBaseline(db, DailyBalanceSpend.account(key), now: at), false);
  });
}
