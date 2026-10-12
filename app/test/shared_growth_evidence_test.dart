import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/form_context_snapshot.dart';
import 'package:ai_companion_localfirst/core/self/dream_contract.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';

void main() {
  const words = '我想按自己的兴趣慢慢探索这个地方。';
  final now = DateTime(2026, 10, 13, 0, 10);
  Map<String, dynamic> proposal(String quote) => {
    'changes': [
      {
        'action': 'upsert',
        'id': 'play.own_interest',
        'domain': 'play',
        'stance': 'considered',
        'understanding': '我喜欢按自己的兴趣决定探索的节奏。',
        'choice': '有兴趣时可以先多看一会儿。',
        'uncertainty': '也可能只适用于这次游玩。',
        'reason': '这次真实的选择让我理解自己的兴趣。',
        'basis': 'new_experience',
        'evidence': [
          {'id': 'chat:source', 'quote': quote, 'role': 'support'},
        ],
      },
    ],
  };

  for (final form in ['normal', 'q']) {
    for (final role in ['user', 'assistant']) {
      test('$form keeps the same $role evidence standard', () {
        final metadata = FormContextSnapshot(
          form: form,
          capturedAt: now.millisecondsSinceEpoch - 60000,
          captureKind: role == 'user' ? 'user_received' : 'generation',
        ).encode();
        final source = DreamStore.chatSource({
          'id': 'source',
          'role': role,
          'content': words,
          'created_at': now.millisecondsSinceEpoch - 60000,
          'form_context_json': metadata,
        }, fresh: true)!;
        expect(source.text, words);
        expect(source.toJson()['form_context'], jsonDecode(metadata));
        final next = DreamContract.apply(
          payload: proposal(words), state: {}, sources: [source], now: now,
        )!;
        final insight = DreamContract.records(next['insights']).single;
        // Either form can support growth; self-assertion alone remains tentative.
        expect(insight['stance'], role == 'user' ? 'considered' : 'tentative');
        expect(DreamContract.apply(
          payload: proposal('当时形态是小豆丁'),
          state: {}, sources: [source], now: now,
        ), isNull); // Source metadata is not a quote the speaker actually said.
      });
    }
  }

  test('legacy unknown form preserves existing source fingerprints', () {
    final source = DreamStore.chatSource({
      'id': 'source', 'role': 'assistant', 'content': words, 'created_at': 42,
    })!;
    expect(source.formContextJson, isEmpty);
    expect(source.toJson().containsKey('form_context'), isFalse);
    expect(source.fingerprint,
      sha256.convert(utf8.encode('assistant_text|42|false|$words')).toString());
  });

  test('changing stored form provenance invalidates its old evidence hash', () {
    final row = <String, Object?>{
      'id': 'source', 'role': 'user', 'content': words, 'created_at': 42,
    };
    final normal = DreamStore.chatSource({...row,
      'form_context_json': const FormContextSnapshot(form: 'normal', capturedAt: 42).encode(),
    })!;
    final small = DreamStore.chatSource({...row,
      'form_context_json': const FormContextSnapshot(form: 'q', capturedAt: 42).encode(),
    })!;
    expect(normal.fingerprint, isNot(small.fingerprint));
  });
}
