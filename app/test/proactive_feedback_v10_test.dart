import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/proactive_feedback.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/models/unfinished_thread.dart';

void main() {
  test('v0.10 proactive feedback keeps topic/thread/outcome metadata', () {
    final row = <String, Object?>{
      'id': 'pf1',
      'proactive_message_id': 'm1',
      'thought_id': 't1',
      'topic_key': 'user.project.result',
      'thread_id': 'u1',
      'intent_kind': 'followup',
      'delivery_style': 'quiet',
      'sent_at': 1000,
      'user_response_message_id': 'm2',
      'response_latency_seconds': 90,
      'response_bucket': 'quick',
      'user_text_length': 18,
      'response_quality': 0.8,
      'outcome': 'deferred',
      'outcome_score': 0.2,
      'processed_at': 2000,
      'created_at': 900,
    };
    final feedback = ProactiveFeedback.fromDb(row);
    expect(feedback.topicKey, 'user.project.result');
    expect(feedback.threadId, 'u1');
    expect(feedback.outcome, 'deferred');
    expect(feedback.intentKind, 'followup');
    expect(feedback.deliveryStyle, 'quiet');
    expect(feedback.outcomeProcessed, isTrue);
  });

  test('v0.10 thought keeps consolidation and snooze metadata', () {
    final thought = CompanionThought.fromDb({
      'id': 't1',
      'text': '等他告诉我结果',
      'drive_key': 'duty',
      'kind': 'fixation',
      'strength': 0.7,
      'born_at': 1000,
      'updated_at': 2000,
      'fed_count': 4,
      'source': 'conversation',
      'lifecycle_state': 'residual',
      'topic_key': 'user.project.result',
      'merged_count': 3,
      'last_merged_at': 2100,
      'snoozed_until': 9999999999999,
    });
    expect(thought.topicKey, 'user.project.result');
    expect(thought.mergedCount, 3);
    expect(thought.isSnoozed, isTrue);
    expect(thought.canDriveIntent, isFalse);
  });

  test('unfinished thread keeps stable topic key even if title changes later', () {
    final thread = UnfinishedThread.fromDb({
      'id': 'u1',
      'title': '等待项目结果',
      'detail': '用户说有结果后会回来告诉我',
      'importance': 0.7,
      'status': 'active',
      'source_message_id': 'm0',
      'topic_key': 'user.project.result',
      'created_at': 1000,
      'updated_at': 2000,
    });
    expect(thread.topicKey, 'user.project.result');
    expect(thread.isActive, isTrue);
  });
}
