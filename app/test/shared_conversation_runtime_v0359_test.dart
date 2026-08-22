import 'dart:io';

import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interrupted generation is terminal and remains local-only', () {
    final now = DateTime(2026, 8, 22, 12);
    final job = GenerationJob(
      id: 'job',
      userMessageId: 'user',
      assistantMessageId: 'assistant',
      status: 'interrupted',
      attempts: 1,
      model: 'deepseek',
      reasoningEffort: 'high',
      thinking: true,
      partialReasoning: '',
      partialContent: '',
      runToken: '',
      createdAt: now,
      updatedAt: now,
    );
    final marker = GenerationInterruption(
      jobId: job.id,
      createdAt: now,
      reason: 'generation_interrupted',
    );

    expect(job.isTerminal, isTrue);
    expect(job.isBlocking, isFalse);
    expect(marker.jobId, job.id);

    final database =
        File('lib/core/database/app_database.dart').readAsStringSync();
    final markerStart = database.indexOf(
      'Future<List<GenerationInterruption>> recentGenerationInterruptions',
    );
    final markerEnd = database.indexOf(
      'Future<bool> isGenerationRunCurrent',
      markerStart,
    );
    final markerBlock = database.substring(markerStart, markerEnd);
    expect(markerBlock, contains("generation_jobs"));
    expect(markerBlock, isNot(contains("insert('messages'")));
  });

  test('both surfaces consume shared timeline and generation state', () {
    final controller =
        File('lib/features/chat/chat_controller.dart').readAsStringSync();
    final server = File(
      'lib/core/platform/background_chat_command_server.dart',
    ).readAsStringSync();
    final overlay = File(
      'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt',
    ).readAsStringSync();

    expect(controller, contains('bool get generationActive'));
    expect(controller, contains('recentGenerationInterruptions'));
    expect(server, contains("'role': 'system_notice'"));
    expect(server, contains("'attachments': attachments"));
    expect(overlay, contains('setComposerGenerationState(sending = sharedSending)'));
    expect(overlay, contains('formatDateSeparator(message.createdAt)'));
  });
}
