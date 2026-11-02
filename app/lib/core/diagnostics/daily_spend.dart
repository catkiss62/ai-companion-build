import 'dart:convert';
import '../ai/deepseek_client.dart';
import '../database/app_database.dart';

/// App-local estimate, deliberately independent of balance changes/top-ups.
class DailySpend {
  static const prefix = 'deepseek_spend_v1:';
  static const priceVersion = '2026-11-02';
  static String day(DateTime at) => at.toLocal().toIso8601String().substring(0, 10);

  static void install(AppDatabase db) {
    DeepSeekClient.costRecorder = (attempt) => record(db, attempt);
  }

  // Official CNY pricing, checked 2026-11-02:
  // https://api-docs.deepseek.com/zh-cn/quick_start/pricing/
  // Holiday exclusions can lower peak pricing; this remains an estimate.
  static double? estimate(Map<String, Object?> attempt) {
    if (Uri.tryParse(attempt['endpoint'] as String? ?? '')?.host != 'api.deepseek.com') return null;
    final model = attempt['model'];
    final List<double> rates;
    if ({'deepseek-flash', 'deepseek-v4-flash', 'deepseek-v4-flash-vision-exp'}.contains(model)) {
      rates = [0.02, 1, 4];
    } else if (model == 'deepseek-v4-pro') {
      rates = [0.15, 4.5, 13.5];
    } else { return null; }
    final usage = attempt['usage'];
    if (usage is! Map) return null;
    final hit = usage['prompt_cache_hit_tokens'];
    final miss = usage['prompt_cache_miss_tokens'];
    final out = usage['completion_tokens'];
    if (hit is! num || miss is! num || out is! num || hit < 0 || miss < 0 || out < 0) return null;
    final instant = DateTime.fromMillisecondsSinceEpoch(attempt['at'] as int, isUtc: true);
    final peak = instant.weekday <= 5 && ((instant.hour >= 1 && instant.hour < 4) || (instant.hour >= 6 && instant.hour < 10));
    return (hit * rates[0] + miss * rates[1] + out * rates[2]) * (peak ? 2 : 1) / 1000000;
  }

  static Future<void> record(AppDatabase db, Map<String, Object?> attempt) async {
    // No API key, endpoint query string, prompt, reply or reasoning is stored.
    final at = DateTime.fromMillisecondsSinceEpoch(attempt['at'] as int);
    final amount = estimate(attempt);
    final key = '$prefix${day(at)}:${attempt['id']}';
    final handle = await db.database;
    await handle.transaction((txn) async {
      final previous = await txn.query('settings', columns: ['value'], where: 'key = ?', whereArgs: [key]);
      final before = previous.isEmpty ? <String, dynamic>{} :
          Map<String, dynamic>.from(jsonDecode(previous.first['value'] as String) as Map);
      final rawUsage = attempt['usage'];
      final tokens = <String, int>{};
      if (Uri.tryParse(attempt['endpoint'] as String? ?? '')?.host == 'api.deepseek.com' && rawUsage is Map) {
        for (final field in ['prompt_cache_hit_tokens', 'prompt_cache_miss_tokens', 'completion_tokens']) {
          final value = rawUsage[field];
          if (value is num && value.isFinite && value >= 0 && value == value.truncateToDouble()) tokens[field] = value.toInt();
        }
      }
      if (before['known'] == true && (before['tokens'] is Map || tokens.length != 3)) return;
      await txn.rawInsert('INSERT OR REPLACE INTO settings (key,value) VALUES (?,?)', [key,
        jsonEncode({'known': before['known'] == true || amount != null,
          'amount': before['known'] == true ? before['amount'] : amount, 'at': attempt['at'],
          'lane': attempt['lane'], 'price_version': before['price_version'] ?? priceVersion,
          if (tokens.length == 3) 'tokens': tokens,
        })]);
      final cutoff = '$prefix${day(DateTime.now().subtract(const Duration(days: 8)))}';
      await txn.delete('settings', where: 'key LIKE ? AND key < ?', whereArgs: ['$prefix%', cutoff]);
    });
  }

  static Future<({String label, String detail})> today(AppDatabase db, {DateTime? now}) async {
    final handle = await db.database;
    final rows = await handle.query('settings', columns: ['value'], where: 'key LIKE ?',
        whereArgs: ['$prefix${day(now ?? DateTime.now())}:%']);
    var amount = 0.0;
    var unknown = 0;
    var hits = 0, misses = 0, measured = 0;
    for (final row in rows) {
      final item = jsonDecode(row['value'] as String) as Map;
      final tokens = item['tokens'];
      if (tokens is Map && tokens['prompt_cache_hit_tokens'] is num && tokens['prompt_cache_miss_tokens'] is num) {
        hits += (tokens['prompt_cache_hit_tokens'] as num).toInt();
        misses += (tokens['prompt_cache_miss_tokens'] as num).toInt();
        measured++;
      }
      if (item['known'] != true) { unknown++; } else { amount += (item['amount'] as num).toDouble(); }
    }
    return (label: unknown > 0 ? '今日：—' : '今日：-￥${amount.toStringAsFixed(2)}',
      detail: '本 App 今日 DeepSeek 用量估算，含聊天、后台和作品。按手机日期统计，首日从启用时开始。已知约 ￥${amount.toStringAsFixed(4)}。'
        '${unknown > 0 ? '另有 $unknown 次调用等待用量、缺失用量或价格未知，因此暂不显示完整金额。' : ''}'
        '${hits + misses > 0 ? '已记录输入缓存命中率 ${(hits * 100 / (hits + misses)).toStringAsFixed(1)}%（$measured 次完整用量；升级前未记录的调用不计入）。' : ''}'
        '不是账户账单，不包含其他设备或 App。价格参考 $priceVersion；工作日高峰价未扣除节假日优惠，可能偏高。');
  }
}
