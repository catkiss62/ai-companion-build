import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generation cancellation is immediate and idempotent', () async {
    final token = GenerationCancellationToken();

    expect(token.isCancelled, isFalse);
    token.cancel();
    token.cancel();

    await token.whenCancelled;
    expect(token.isCancelled, isTrue);
    expect(
      token.throwIfCancelled,
      throwsA(isA<GenerationCancelledByUserException>()),
    );
  });

  test('database cancellation atomically withdraws the unfinished user turn', () {
    final source = File('lib/core/database/app_database.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> cancelGenerationJobByUser');
    final end = source.indexOf('Future<bool> isGenerationRunCurrent', start);
    final method = source.substring(start, end);

    expect(method, contains('db.transaction<bool>'));
    expect(method, contains("status IN ('pending','running','retry_wait')"));
    expect(method, contains("where: 'id = ? AND role = ?'"));
    expect(method, contains("whereArgs: [userMessageId, 'user']"));
    expect(method, contains("if (!cancelled) return false"));
  });

  test('automatic recovery resumes instead of withdrawing the user turn', () {
    final source =
        File('lib/core/ai/durable_generation_recovery.dart').readAsStringSync();

    expect(source, contains('final result = await runner.run(job)'));
    expect(source, isNot(contains('cancelGenerationJobByUser(job.id)')));
  });

  test('ordinary process failures defer the durable turn instead of stopping it', () {
    final source = File('lib/features/chat/chat_controller.dart').readAsStringSync();

    expect(source, contains("reason: 'current_process_exception'"));
    expect(source, contains("reason: 'trusted_process_exception'"));
    expect(source, contains('这一轮没有被删除，已经转入自动恢复。'));
  });

  test('disposing a chat surface is not treated as the user pressing Stop', () {
    final source = File('lib/features/chat/chat_controller.dart').readAsStringSync();
    final start = source.lastIndexOf('void dispose()');
    final end = source.indexOf('\n}\n\nclass ChatTimelineItem', start);
    final body = source.substring(start, end);

    expect(body, isNot(contains('_activeGenerationCancellation?.cancel()')));
    expect(body, contains('client.close()'));
  });

  test('provider format slips are recoverable durable turns', () {
    final source = File('lib/core/ai/durable_generation_runner.dart')
        .readAsStringSync();

    expect(source, contains('if (error is FormatException) return true'));
  });
}
