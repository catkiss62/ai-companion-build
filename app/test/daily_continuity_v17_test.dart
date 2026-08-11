import 'dart:convert';

import 'package:ai_companion_localfirst/core/continuity/daily_continuity_presentation.dart';
import 'package:ai_companion_localfirst/core/models/daily_continuity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v17 daily continuity decodes factual bounded payload', () {
    final start = DateTime(2026, 8, 11);
    final record = DailyContinuityRecord.fromDb({
      'id': 'd1',
      'local_day': '2026-08-11',
      'window_start': start.millisecondsSinceEpoch,
      'window_end': DateTime(2026, 8, 12).millisecondsSinceEpoch,
      'shared_moments_json': jsonEncode([
        {
          'id': 'e1',
          'label': '你们的约定',
          'summary': '晚上换到平板继续聊天。',
          'created_at': start.add(const Duration(hours: 20)).millisecondsSinceEpoch,
        }
      ]),
      'carried_threads_json': jsonEncode([
        {
          'id': 't1',
          'title': '继续平板接管测试',
          'detail': '等下一次真机阶段再验证。',
          'topic_key': 'project.tablet.takeover',
        }
      ]),
      'cares_json': '[]',
      'awareness_json': jsonEncode(['最近一段时间主要在进行工作学习相关活动。']),
      'message_count': 12,
      'relationship_event_count': 1,
      'quiet_day': 0,
      'source_fingerprint': 'abc',
      'created_at': start.millisecondsSinceEpoch,
      'updated_at': start.millisecondsSinceEpoch,
      'finalized_at': null,
    });

    expect(record.sharedMoments, hasLength(1));
    expect(record.carriedThreads.single.topicKey, 'project.tablet.takeover');
    expect(record.awarenessSummaries.single, contains('工作学习'));
    expect(record.quietDay, isFalse);
  });

  test('quiet day presentation never implies relationship regression', () {
    final start = DateTime(2026, 8, 10);
    final record = DailyContinuityRecord.fromDb({
      'id': 'quiet',
      'local_day': '2026-08-10',
      'window_start': start.millisecondsSinceEpoch,
      'window_end': DateTime(2026, 8, 11).millisecondsSinceEpoch,
      'shared_moments_json': '[]',
      'carried_threads_json': '[]',
      'cares_json': '[]',
      'awareness_json': '[]',
      'message_count': 0,
      'relationship_event_count': 0,
      'quiet_day': 1,
      'source_fingerprint': 'quiet',
      'created_at': start.millisecondsSinceEpoch,
      'updated_at': start.millisecondsSinceEpoch,
      'finalized_at': DateTime(2026, 8, 11).millisecondsSinceEpoch,
    });

    expect(DailyContinuityPresentation.compactSummary(record), contains('不代表'));
    final prompt = DailyContinuityPresentation.formatForPrompt([record]);
    expect(prompt, contains('不要把安静自动解释成疏远'));
    expect(prompt, contains('不是新的事实来源'));
  });

  test('prompt continuity remains capped to two day records', () {
    DailyContinuityRecord make(int day) {
      final start = DateTime(2026, 8, day);
      return DailyContinuityRecord.fromDb({
        'id': 'd$day',
        'local_day': '2026-08-${day.toString().padLeft(2, '0')}',
        'window_start': start.millisecondsSinceEpoch,
        'window_end': start.add(const Duration(days: 1)).millisecondsSinceEpoch,
        'shared_moments_json': jsonEncode([
          {
            'id': 'e$day',
            'label': '共同经历',
            'summary': 'day-$day',
            'created_at': start.millisecondsSinceEpoch,
          }
        ]),
        'carried_threads_json': '[]',
        'cares_json': '[]',
        'awareness_json': '[]',
        'message_count': 2,
        'relationship_event_count': 1,
        'quiet_day': 0,
        'source_fingerprint': '$day',
        'created_at': start.millisecondsSinceEpoch,
        'updated_at': start.millisecondsSinceEpoch,
        'finalized_at': start.millisecondsSinceEpoch,
      });
    }

    final prompt = DailyContinuityPresentation.formatForPrompt([
      make(11),
      make(10),
      make(9),
    ]);
    expect(prompt, contains('day-11'));
    expect(prompt, contains('day-10'));
    expect(prompt, isNot(contains('day-9')));
  });
}
