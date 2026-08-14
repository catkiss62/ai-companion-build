import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';

void main() {
  test('generation job decodes durable retry fields', () {
    final job = GenerationJob.fromDb({
      'id': 'job-1',
      'user_message_id': 'u-1',
      'assistant_message_id': 'a-1',
      'status': 'retry_wait',
      'attempts': 2,
      'model': 'deepseek-v4-pro',
      'reasoning_effort': 'high',
      'thinking': 1,
      'partial_reasoning': 'r',
      'partial_content': 'c',
      'run_token': 'attempt-1',
      'device_id': 'phone',
      'created_at': 1000,
      'started_at': 2000,
      'updated_at': 3000,
      'completed_at': null,
      'last_checkpoint_at': 2500,
      'next_retry_at': 5000,
      'last_error': 'network',
      'resume_reason': 'retry_after_failure',
    });

    expect(job.status, 'retry_wait');
    expect(job.isBlocking, isTrue);
    expect(job.isTerminal, isFalse);
    expect(job.attempts, 2);
    expect(job.runToken, 'attempt-1');
    expect(job.nextRetryAt!.millisecondsSinceEpoch, 5000);
  });

  test('completed generation job is terminal', () {
    final job = GenerationJob.fromDb({
      'id': 'job-2',
      'user_message_id': 'u-2',
      'assistant_message_id': 'a-2',
      'status': 'completed',
      'attempts': 1,
      'model': 'deepseek-v4-flash',
      'reasoning_effort': 'high',
      'thinking': 1,
      'partial_reasoning': '',
      'partial_content': 'done',
      'run_token': 'attempt-2',
      'device_id': 'tablet',
      'created_at': 1000,
      'started_at': 1100,
      'updated_at': 1200,
      'completed_at': 1200,
      'last_checkpoint_at': 1200,
      'next_retry_at': null,
      'last_error': '',
      'resume_reason': '',
    });
    expect(job.isTerminal, isTrue);
    expect(job.isBlocking, isFalse);
  });
  test('cancelled-by-user generation is terminal and never blocking', () {
    final job = GenerationJob.fromDb({
      'id': 'job-cancelled',
      'user_message_id': 'u-cancelled',
      'assistant_message_id': 'a-cancelled',
      'status': 'cancelled_by_user',
      'attempts': 1,
      'model': 'deepseek-v4-pro',
      'reasoning_effort': 'high',
      'thinking': 1,
      'partial_reasoning': '',
      'partial_content': '',
      'run_token': '',
      'device_id': 'phone',
      'created_at': 1000,
      'started_at': 1100,
      'updated_at': 1200,
      'completed_at': 1200,
      'last_checkpoint_at': 1150,
      'next_retry_at': null,
      'last_error': '',
      'resume_reason': 'cancelled_by_user',
    });

    expect(job.isTerminal, isTrue);
    expect(job.isBlocking, isFalse);
  });

}
