import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/post_turn_job.dart';

void main() {
  test('post-turn job decodes durable ownership and cached proposal', () {
    final job = PostTurnJob.fromDb({
      'id': 'pt-1',
      'user_message_id': 'u-1',
      'assistant_message_id': 'a-1',
      'status': 'running',
      'attempts': 3,
      'last_error': '',
      'run_token': 'run-3',
      'result_json': '{"memories":[]}',
      'started_at': 1000,
      'heartbeat_at': 1500,
      'next_retry_at': null,
      'model_completed_at': 1400,
      'desire_applied_at': 1450,
      'created_at': 500,
      'updated_at': 1500,
    });

    expect(job.isRunning, isTrue);
    expect(job.hasProposal, isTrue);
    expect(job.runToken, 'run-3');
    expect(job.modelCompletedAt!.millisecondsSinceEpoch, 1400);
    expect(job.desireAppliedAt!.millisecondsSinceEpoch, 1450);
  });

  test('retry-wait post-turn job is not owned by a stale runner', () {
    final job = PostTurnJob.fromDb({
      'id': 'pt-2',
      'user_message_id': 'u-2',
      'assistant_message_id': 'a-2',
      'status': 'retry_wait',
      'attempts': 2,
      'last_error': 'network',
      'run_token': '',
      'result_json': '{"threads":[]}',
      'started_at': 1000,
      'heartbeat_at': 1100,
      'next_retry_at': 5000,
      'model_completed_at': 1050,
      'desire_applied_at': null,
      'created_at': 500,
      'updated_at': 1100,
    });

    expect(job.isRunning, isFalse);
    expect(job.hasProposal, isTrue);
    expect(job.runToken, isEmpty);
    expect(job.nextRetryAt!.millisecondsSinceEpoch, 5000);
  });
}
