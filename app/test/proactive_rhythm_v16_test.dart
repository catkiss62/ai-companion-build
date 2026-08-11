import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_rhythm_engine.dart';
import 'package:ai_companion_localfirst/core/models/proactive_feedback.dart';

void main() {
  test('v16 proactive feedback keeps timing and activity context', () {
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
      'response_latency_seconds': 120,
      'response_bucket': 'quick',
      'user_text_length': 18,
      'response_quality': 0.8,
      'outcome': 'deferred',
      'outcome_score': 0.2,
      'processed_at': 2000,
      'context_hour_bucket': 'evening',
      'context_activity': 'game',
      'context_busy': 0.64,
      'timing_fit': -0.8,
      'topic_fit': 0.1,
      'created_at': 900,
    };
    final feedback = ProactiveFeedback.fromDb(row);
    expect(feedback.contextHourBucket, 'evening');
    expect(feedback.contextActivity, 'game');
    expect(feedback.contextBusy, closeTo(0.64, 0.0001));
    expect(feedback.timingFit, closeTo(-0.8, 0.0001));
    expect(feedback.topicFit, closeTo(0.1, 0.0001));
  });

  test('v16 daypart buckets stay coarse and deterministic', () {
    expect(ProactiveRhythmContext.hourBucketFor(DateTime(2026, 8, 11, 2)), 'late_night');
    expect(ProactiveRhythmContext.hourBucketFor(DateTime(2026, 8, 11, 8)), 'morning');
    expect(ProactiveRhythmContext.hourBucketFor(DateTime(2026, 8, 11, 14)), 'afternoon');
    expect(ProactiveRhythmContext.hourBucketFor(DateTime(2026, 8, 11, 21)), 'evening');
  });

  test('legacy v15 proactive feedback remains neutral for new context fields', () {
    final feedback = ProactiveFeedback.fromDb({
      'id': 'legacy',
      'proactive_message_id': 'm0',
      'sent_at': 1000,
      'created_at': 900,
    });
    expect(feedback.contextHourBucket, isEmpty);
    expect(feedback.contextActivity, 'unknown');
    expect(feedback.contextBusy, 0);
    expect(feedback.timingFit, isNull);
    expect(feedback.topicFit, isNull);
  });
}
