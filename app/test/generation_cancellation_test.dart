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
}
