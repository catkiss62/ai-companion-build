import 'dart:convert';

/// Counts observed new communication content, never notification callbacks as
/// people, unread totals or proof that the user is busy. Old unknown rows stay
/// unknown; no body text is emitted into awareness or diagnostics.
class NotificationActivity {
  const NotificationActivity(this.messageTimes, this.unknownCount, this.ignoredCount);
  final List<int> messageTimes;
  final int unknownCount, ignoredCount;
  int get count30m => messageTimes.length;
  int countSince(DateTime since) => messageTimes.where((t) => t > since.millisecondsSinceEpoch).length;
  int recentCount(DateTime now) => countSince(now.subtract(const Duration(minutes: 5)));

  static NotificationActivity collect(List<Map<String, Object?>> rows, DateTime now) {
    final end = now.millisecondsSinceEpoch;
    final start = now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch;
    final sorted = rows.where((r) => r['source'] == 'notification').toList()
      ..sort((a, b) => _time(a).compareTo(_time(b)));
    final seen = <String>{};
    final messages = <int>[];
    var unknown = 0, ignored = 0;
    for (final row in sorted) {
      final posted = _time(row);
      if (posted <= start || posted > end) continue;
      final meta = metadata(row['metadata_json'] ?? row['metadata']);
      final category = (meta['category'] ?? '').toString();
      final package = (row['app_package'] ?? '').toString();
      if (meta['ongoing'] == true || meta['foreground_service'] == true ||
          meta['group_summary'] == true || package == 'com.aicompanion.localfirst' ||
          const {'service', 'transport', 'progress', 'promo', 'recommendation', 'sys', 'status'}.contains(category)) {
        ignored++; continue;
      }
      final communication = category == 'msg' || meta['messaging_style'] == true ||
          // Conservative compatibility for old rows, whose source did not save
          // Android category flags. Other packages need actual message metadata.
          (category.isEmpty && const {
            'com.tencent.mobileqq', 'com.tencent.mm', 'org.telegram.messenger',
            'com.whatsapp', 'com.google.android.apps.messaging',
          }.contains(package));
      if (!communication) { unknown++; continue; }
      final messageAt = meta['message_time'] is num ? (meta['message_time'] as num).toInt() : 0;
      // MessagingStyle timestamps prevent a re-post of old conversation content
      // from making old messages look newly received.
      final at = messageAt > 0 ? messageAt : posted;
      if (at <= start || at > end) { ignored++; continue; }
      final identity = meta['notification_key_hash'] ?? meta['notification_id'] ?? '';
      final digest = meta['message_digest'] ?? meta['content_digest'] ?? row['summary'] ?? '';
      if (digest.toString().trim().isEmpty) { unknown++; continue; }
      final key = '$package|$identity|$digest|${messageAt > 0 ? messageAt : "legacy"}';
      if (!seen.add(key)) { ignored++; continue; }
      messages.add(at);
    }
    messages.sort();
    return NotificationActivity(messages, unknown, ignored);
  }

  static Map<String, dynamic> metadata(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) { return {}; }
  }
  static int _time(Map<String, Object?> row) => row['occurred_at'] is num
      ? (row['occurred_at'] as num).toInt() : 0;
}
