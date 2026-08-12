import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/features/chat/chat_timestamp_formatter.dart';

void main() {
  test('formats message time without modifying message content', () {
    expect(ChatTimestampFormatter.time(DateTime(2026, 8, 12, 3, 7)), '03:07');
  });

  test('date separator appears only when local calendar day changes', () {
    final a = DateTime(2026, 8, 12, 23, 58);
    final b = DateTime(2026, 8, 13, 0, 1);
    expect(ChatTimestampFormatter.shouldShowDateSeparator(a, null), isTrue);
    expect(
      ChatTimestampFormatter.shouldShowDateSeparator(
        DateTime(2026, 8, 12, 23, 59),
        a,
      ),
      isFalse,
    );
    expect(ChatTimestampFormatter.shouldShowDateSeparator(b, a), isTrue);
  });

  test('today and yesterday labels are chat-app friendly', () {
    final now = DateTime(2026, 8, 12, 23, 30);
    expect(
      ChatTimestampFormatter.dateSeparator(
        DateTime(2026, 8, 12, 20, 0),
        now: now,
      ),
      '今天 · 周三',
    );
    expect(
      ChatTimestampFormatter.dateSeparator(
        DateTime(2026, 8, 11, 20, 0),
        now: now,
      ),
      '昨天 · 周二',
    );
  });
}
