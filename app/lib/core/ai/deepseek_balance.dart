import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secure_config.dart';

class DeepSeekBalance {
  DeepSeekBalance._();

  static Future<String> display() async {
    final key = (await SecureConfig.instance.readDeepSeekApiKey() ?? '').trim();
    if (key.isEmpty) return 'DeepSeek 余额：未配置 Key';
    final client = http.Client();
    try {
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
      for (final item in decoded['balance_infos'] as List) {
        if (item is! Map) continue;
        final currency = item['currency']?.toString() ?? '';
        final total = item['total_balance']?.toString() ?? '';
        if (total.isNotEmpty && (currency == 'CNY' || currency == 'USD')) {
          amounts.add('${currency == 'CNY' ? '¥' : '\$'}$total');
        }
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
