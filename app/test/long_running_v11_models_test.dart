import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/maintenance_run.dart';
import 'package:ai_companion_localfirst/core/models/post_turn_job.dart';
import 'package:ai_companion_localfirst/core/models/unfinished_thread.dart';

void main() {
  test('v0.11 unfinished thread restores one-shot follow-up metadata', () {
    final thread = UnfinishedThread.fromDb({
      'id': 'u11',
      'title': '晚点继续聊项目结果',
      'detail': '用户说今晚再告诉我',
      'importance': 0.72,
      'status': 'active',
      'source_message_id': 'm1',
      'topic_key': 'user.project.result',
      'followup_due_at': 10_000,
      'followup_seeded_at': 11_000,
      'followup_count': 1,
      'last_followup_at': 12_000,
      'retired_at': null,
      'retire_reason': '',
      'created_at': 1_000,
      'updated_at': 2_000,
    });

    expect(thread.topicKey, 'user.project.result');
    expect(thread.followupDueAt?.millisecondsSinceEpoch, 10_000);
    expect(thread.followupSeededAt?.millisecondsSinceEpoch, 11_000);
    expect(thread.followupCount, 1);
    expect(thread.lastFollowupAt?.millisecondsSinceEpoch, 12_000);
    expect(thread.isActive, isTrue);
  });

  test('v0.11 retired thread is no longer an active follow-up source', () {
    final thread = UnfinishedThread.fromDb({
      'id': 'old',
      'title': '很久没有进展的话题',
      'detail': '旧事项',
      'importance': 0.3,
      'status': 'retired',
      'source_message_id': null,
      'topic_key': 'old.topic',
      'followup_due_at': null,
      'followup_seeded_at': null,
      'followup_count': 0,
      'last_followup_at': null,
      'retired_at': 50_000,
      'retire_reason': 'low_importance_stale_14d',
      'created_at': 1_000,
      'updated_at': 50_000,
    });

    expect(thread.isActive, isFalse);
    expect(thread.retiredAt?.millisecondsSinceEpoch, 50_000);
    expect(thread.retireReason, contains('stale'));
  });

  test('post-turn job restores retry diagnostics', () {
    final job = PostTurnJob.fromDb({
      'id': 'job1',
      'user_message_id': 'u1',
      'assistant_message_id': 'a1',
      'status': 'failed',
      'attempts': 2,
      'last_error': 'timeout',
      'created_at': 1_000,
      'updated_at': 2_000,
    });

    expect(job.status, 'failed');
    expect(job.attempts, 2);
    expect(job.lastError, 'timeout');
  });

  test('maintenance run restores pruning counters', () {
    final run = MaintenanceRun.fromDb({
      'id': 'run1',
      'started_at': 1_000,
      'completed_at': 2_000,
      'retired_threads': 2,
      'pruned_lifecycle': 9,
      'pruned_feedback': 3,
      'pruned_history': 4,
      'pruned_perceptions': 5,
      'pruned_device_events': 6,
      'pruned_jobs': 7,
      'notes': '',
    });

    expect(run.retiredThreads, 2);
    expect(run.prunedLifecycle, 9);
    expect(run.prunedDeviceEvents, 6);
    expect(run.prunedJobs, 7);
  });
}
