import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/agent_outcome_journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journal accepts only content-free machine codes', () {
    final valid = AgentOutcomeJournal.create(
      capabilityId: 'album.autonomous_review',
      origin: 'background',
      status: 'succeeded',
      outcome: 'saved',
      resultCount: 1,
      occurredAt: DateTime(2026, 8, 30, 12),
    );
    final unsafe = AgentOutcomeJournal.create(
      capabilityId: 'public_web.search user query',
      origin: 'background',
      status: 'succeeded',
      outcome: 'title=private text',
      resultCount: 1,
      occurredAt: DateTime(2026, 8, 30, 12),
    );

    expect(valid, isNotNull);
    expect(unsafe, isNull);
    expect(
      valid!.toJson().keys,
      unorderedEquals(<String>[
        'capability',
        'origin',
        'status',
        'outcome',
        'result_count',
        'occurred_at',
      ]),
    );
  });

  test('journal keeps the newest 24 valid events in time order', () {
    var encoded = '';
    for (var index = 0; index < 30; index++) {
      final event = AgentOutcomeJournal.create(
        capabilityId: 'tool.$index',
        origin: 'user_turn',
        status: 'succeeded',
        outcome: 'completed',
        resultCount: index,
        occurredAt: DateTime(2026, 8, 30).add(Duration(minutes: index)),
      )!;
      encoded = AgentOutcomeJournal.append(encoded, event);
    }

    final decoded = AgentOutcomeJournal.decode(encoded);
    expect(decoded, hasLength(24));
    expect(decoded.first.capabilityId, 'tool.6');
    expect(decoded.last.capabilityId, 'tool.29');
    expect(decoded.last.resultCount, 29);
  });

  test('malformed or extra free-text journal fields are not propagated', () {
    final raw = jsonEncode([
      {
        'capability': 'public_web.search',
        'origin': 'user_turn',
        'status': 'succeeded',
        'outcome': 'completed',
        'result_count': 2,
        'occurred_at': DateTime(2026, 8, 30).millisecondsSinceEpoch,
        'query': 'private query',
        'summary': 'private result body',
      },
    ]);

    final decoded = AgentOutcomeJournal.decode(raw);
    expect(decoded, hasLength(1));
    final reencoded = AgentOutcomeJournal.append('', decoded.single);
    expect(reencoded, isNot(contains('private query')));
    expect(reencoded, isNot(contains('private result body')));
    expect(AgentOutcomeJournal.decode('{broken'), isEmpty);
  });
}
