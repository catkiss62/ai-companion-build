import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tool outcome projection contains only bounded presentation metadata', () {
    final record = AgentToolOutcomeRecord.fromDb({
      'id': 'user_turn:job-1:public_web.search:0',
      'job_id': 'job-1',
      'assistant_message_id': 'assistant-1',
      'tool_id': 'public_web.search',
      'status': 'stopped',
      'result_count': 0,
      'started_at': 1000,
      'finished_at': 2500,
      'source_device_label': 'Android device',
      'display_text': '网页实际返回了三条结果',
    });

    expect(record.jobId, 'job-1');
    expect(record.assistantMessageId, 'assistant-1');
    expect(record.status, AgentToolStatus.stopped);
    expect(record.displayText, '网页实际返回了三条结果');
    expect(record.duration, const Duration(milliseconds: 1500));
  });
}
