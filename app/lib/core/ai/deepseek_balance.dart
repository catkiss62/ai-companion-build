import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../diagnostics/daily_balance_spend.dart';
import '../storage/secure_config.dart';

class DeepSeekBalance {
  DeepSeekBalance._();

  static Timer? _midnightTimer;
  static Timer? _catchUpTimer;
  static bool _sampling = false;

  /// Both runtimes install this. Work fences protect restore/transfer, while
  /// observation ordering makes overlapping successful reads harmless.
  /// Installed only after startup recovery. The first catch-up tick is a minute
  /// later, and each tick checks the recovery/active-brain fence again.
  static void installDailySampling(AppDatabase db) {
    _midnightTimer?.cancel();
    _catchUpTimer?.cancel();
    void scheduleMidnight() {
      final now = DateTime.now();
      final next = DateTime(now.year, now.month, now.day + 1);
      _midnightTimer = Timer(next.difference(now), () {
        unawaited(_sampleMissingDay(db));
        scheduleMidnight();
      });
    }
    scheduleMidnight();
    // Also catches process resume and local clock/date changes. A current-day
    // baseline avoids extra network calls on ordinary ticks.
    _catchUpTimer = Timer.periodic(const Duration(minutes: 1),
      (_) => unawaited(_sampleMissingDay(db)));
  }

  static Future<void> _sampleMissingDay(AppDatabase db) async {
    if (_sampling) return;
    _sampling = true;
    try {
      if (!await db.brainWorkAllowed()) return;
      final key = (await SecureConfig.instance.readDeepSeekApiKey() ?? '').trim();
      if (key.isEmpty || await DailyBalanceSpend.hasBaseline(db,
          DailyBalanceSpend.account(key))) return;
      await display(db: db);
    } catch (_) {
      // A failed baseline is retried by the next tick, never treated as zero.
    } finally { _sampling = false; }
  }

  static Future<String> display({AppDatabase? db,
    http.Client Function()? clientFactory,
    Future<String?> Function()? keyReader,
    DateTime Function()? clock,
  }) async {
    final readKey = keyReader ?? SecureConfig.instance.readDeepSeekApiKey;
    final now = clock ?? DateTime.now;
    final key = (await readKey() ?? '').trim();
    if (key.isEmpty) return 'DeepSeek 余额：未配置 Key';
    final database = db ?? AppDatabase.instance;
    final client = clientFactory?.call() ?? http.Client();
    try {
      final fence = await database.captureBrainWorkFence();
      final requestedAt = now();
      // Account balance is an official endpoint, independent of the custom
      // Chat Completions endpoint. Never forward the key to a relay host.
      final response = await client.get(
        Uri.https('api.deepseek.com', '/user/balance'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return 'DeepSeek 余额：查询失败（HTTP ${response.statusCode}）';
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['balance_infos'] is! List) {
        return 'DeepSeek 余额：返回格式不支持';
      }
      final amounts = <String>[];
      final balances = <String, int>{};
      for (final item in decoded['balance_infos'] as List) {
        if (item is! Map) continue;
        final currency = item['currency']?.toString() ?? '';
        final amount = DailyBalanceSpend.parseAmount(item['total_balance']);
        if (amount != null && (currency == 'CNY' || currency == 'USD')) {
          amounts.add('${currency == 'CNY' ? '¥' : '\$'}${(amount / DailyBalanceSpend.scale).toStringAsFixed(2)}');
          balances[currency] = amount;
        }
      }
      if ((await readKey() ?? '').trim() != key) {
        return 'DeepSeek 余额：Key 已切换，请重新查询';
      }
      if (balances.isNotEmpty && fence != null) {
        await DailyBalanceSpend.record(database, accountId: DailyBalanceSpend.account(key),
          balances: balances, requestedAt: requestedAt, observedAt: now(), fence: fence);
      }
      return amounts.isEmpty ? 'DeepSeek 余额：无可显示金额'
          : 'DeepSeek 余额：${amounts.join(' / ')}';
    } catch (_) {
      return 'DeepSeek 余额：暂时无法查询';
    } finally {
      client.close();
    }
  }
}
