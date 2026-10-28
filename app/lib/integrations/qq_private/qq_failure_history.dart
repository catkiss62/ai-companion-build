import 'dart:convert';

/// Twenty bounded operations, each retaining its real attempts. No exception
/// strings, message bodies, URLs, tokens or human-readable names are stored.
abstract final class QqFailureHistory {
  static const limit = 20;
  static List<Map<String, dynamic>> decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is List) return value.whereType<Map>().take(limit)
          .where((e)=>e['at'] is int && e['phase'] is String && e['code'] is String)
          .map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return [];
  }
  static String record(String raw, {required String operation, required int at,
    required String phase, required String code, String conversation = '',
    int attempt = 1, int elapsedMs = 0}) {
    final rows = decode(raw);
    final index = rows.indexWhere((r) => r['operation'] == operation);
    final old = index < 0 ? <String, dynamic>{} : rows.removeAt(index);
    final attempts = old['attempts'] is List ? List<Object?>.from(old['attempts'] as List) : <Object?>[];
    attempts.add({'at': at, 'phase': phase, 'code': safeCode(code), 'attempt': attempt, 'elapsed_ms': elapsedMs});
    return jsonEncode([{
      'operation': operation, 'conversation': conversation,
      'at': old['at'] ?? at, 'last_at': at, 'phase': phase, 'code': safeCode(code),
      'attempt': attempt, 'elapsed_ms': elapsedMs, 'outcome': 'pending',
      if(old['continued_to'] is String)'continued_to':old['continued_to'],
      'attempts': attempts.reversed.take(12).toList().reversed.toList(),
    }, ...rows].take(limit).toList());
  }
  static String link(String raw,String previous,String next) {
    final rows=decode(raw);
    for(final row in rows) {if(row['operation']==previous) {row['continued_to']=next;row['outcome']='continued';}}
    return jsonEncode(rows);
  }
  static String finish(String raw, String operation, String outcome) {
    final rows = decode(raw), settled=<String>{operation};
    for(var i=0;i<limit;i++) {
      var added=false;
      for(final row in rows) {
        if(row['continued_to'] is String && settled.contains(row['continued_to']) && row['operation'] is String) {
          added=settled.add(row['operation'] as String)||added;
        }
      }
      if(!added)break;
    }
    for (final row in rows) {if(settled.contains(row['operation']))row['outcome']=safeCode(outcome);}
    return jsonEncode(rows);
  }
  static String safeCode(String value) => RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value) ? value : 'operation_failed';
  static String phaseName(String phase) => const {
    'context': '上下文', 'participation': '参与判断', 'vision': '识图',
    'reply_generation': '正文生成', 'first_reply': '第一通道', 'second_reply': '第二通道',
    'group_boundary': '称呼核验', 'sketch_generation': '涂鸦', 'voice': '语音',
    'media_upload': '媒体上传', 'voice_generation':'语音合成','voice_upload':'语音上传', 'send': '投递', 'archive': '本地归档',
  }[phase] ?? phase;
  static String outcomeName(String state) => switch (state) {
    'sent' => '已恢复并确认送达',
    'sent_archive_failed' || 'sent_archive_pending' => '已确认送达，归档未完成',
    'partially_sent' => '部分成功',
    'send_uncertain' => '投递结果未知，不自动重发',
    'failed' || 'address_rejected' || 'media_failed' => '确定未完成发送',
    'context_invalidated' => '来源或授权已失效',
    'continued' => '已由新追问接续，等待本次结果',
    'cancelled' => '旧请求已结束，不再补发',
    _ => '处理中或后续结果未记录',
  };
  static String explanation(String code) {
    if (code.contains('timeout')) return '等待超时';
    if (code.contains('network')) return '网络连接失败';
    if (code.contains('receipt')) return '未取得有效平台回执';
    if (code.contains('http_')) return '接口返回错误（$code）';
    if (code.contains('format') || code.contains('incomplete') || code.contains('limit')) return '返回内容不完整或格式无效';
    return code;
  }
}
