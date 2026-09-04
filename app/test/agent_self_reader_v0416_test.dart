import 'package:ai_companion_localfirst/core/agent/agent_self_reader.dart';
import 'package:flutter_test/flutter_test.dart';

// Historical validator compatibility: build=v0.41.31+170 schema=45

void main() {
  test('facts distinguish executable capabilities from future placeholders', () {
    final result = AgentSelfReader.composePromptData(
      scope: AgentSelfReadScope.facts,
      activeBrain: true,
      currentDeviceId: 'raw-device-id',
      currentDeviceLabel: 'REDMI K80 Ultra',
    );

    expect(result.promptData, contains('build=v0.41.32+171 schema=46'));
    expect(result.promptData, contains('id=system_self.read status=executable'));
    expect(
      result.promptData,
      contains('id=screen_observation.inspect status=executable'),
    );
    expect(result.promptData, contains('id=mcp.invoke status=not_implemented'));
    expect(result.promptData, contains('不得声称这些功能是你自己编写的'));
    expect(result.promptData, isNot(contains('raw-device-id')));
    expect(result.outcomeCount, 0);
  });

  test('outcomes merge newest first, cap eight and redact raw device ids', () {
    Map<String, Object?> userRow(int index) => <String, Object?>{
          'tool_id': 'memory.search',
          'origin': 'user_turn',
          'status': index.isEven ? 'succeeded' : 'no_result',
          'outcome_kind': index.isEven ? 'result_available' : 'no_useful_result',
          'result_count': index,
          'finished_at': DateTime(2026, 8, 30, 12, index)
              .millisecondsSinceEpoch,
          'source_device_id': index == 9 ? 'other-secret-id' : 'local-secret-id',
          'source_device_label': index == 9 ? 'Other Phone' : 'Local Phone',
          // Unexpected historical fields must never be formatted.
          'query': 'PRIVATE SEARCH BODY',
          'url': 'https://private.example',
          'reasoning': 'PRIVATE REASONING',
        };

    final result = AgentSelfReader.composePromptData(
      scope: AgentSelfReadScope.outcomes,
      activeBrain: true,
      currentDeviceId: 'local-secret-id',
      currentDeviceLabel: 'Local Phone',
      userRows: List<Map<String, Object?>>.generate(10, userRow),
      autonomousRows: <Map<String, Object?>>[
        <String, Object?>{
          'tool_kind': 'public_web',
          'status': 'failed',
          'outcome_kind': 'provider_failure',
          'result_count': 0,
          'finished_at': DateTime(2026, 8, 30, 13).millisecondsSinceEpoch,
          'device_id': 'local-secret-id',
        },
      ],
    );

    expect(result.outcomeCount, 8);
    expect(
      result.promptData,
      contains('origin=autonomous tool=public_web.search'),
    );
    expect(result.promptData, contains('device=本机'));
    expect(result.promptData, contains('device=其他设备'));
    for (final secret in <String>[
      'local-secret-id',
      'other-secret-id',
      'PRIVATE SEARCH BODY',
      'https://private.example',
      'PRIVATE REASONING',
      'Other Phone',
    ]) {
      expect(result.promptData, isNot(contains(secret)), reason: secret);
    }
    expect(result.promptData, isNot(contains('SYSTEM_FACT id=')));
  });

  test('empty outcome history is explicit and never invented', () {
    final result = AgentSelfReader.composePromptData(
      scope: AgentSelfReadScope.outcomes,
      activeBrain: false,
      currentDeviceId: 'device',
      currentDeviceLabel: 'Phone',
    );
    expect(result.outcomeCount, 0);
    expect(result.promptData, contains('没有可读取的 terminal tool Outcome'));
    expect(result.promptData, contains('不得补写未提供的具体内容'));
  });

  test('growth scope exposes only bounded Phase 2B metadata', () {
    final result = AgentSelfReader.composePromptData(
      scope: AgentSelfReadScope.growth,
      activeBrain: true,
      currentDeviceId: 'device',
      currentDeviceLabel: 'Phone',
      growthStats: <String, Object?>{
        'enabled': true,
        'candidateCount': 2,
        'evidenceCount': 4,
        'statusCounts': <String, int>{
          'established': 1,
          'contradicted': 1,
        },
        'latestObservedAt':
            DateTime(2026, 9, 1, 7, 20).millisecondsSinceEpoch,
        'phase2b': <String, Object?>{'activationCount': 3},
        // Unexpected bodies must never be formatted.
        'subject': 'PRIVATE SUBJECT',
        'proposition': 'PRIVATE PROPOSITION',
        'evidenceQuote': 'PRIVATE USER QUOTE',
      },
    );
    expect(result.factCount, 0);
    expect(result.outcomeCount, 0);
    expect(result.growthCount, 3);
    expect(result.promptData, contains('phase=phase2b_bounded_bias'));
    expect(result.promptData, contains('activations=3'));
    expect(result.promptData, contains('candidates=2 evidence=4'));
    expect(result.promptData, contains('established=1'));
    for (final secret in <String>[
      'PRIVATE SUBJECT',
      'PRIVATE PROPOSITION',
      'PRIVATE USER QUOTE',
    ]) {
      expect(result.promptData, isNot(contains(secret)));
    }
  });
}
