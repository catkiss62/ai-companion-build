import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/memory/local_semantic_index.dart';
import '../lib/core/models/memory_item.dart';

MemoryItem item(String id, String content) => MemoryItem(
  id: id,
  kind: 'user_profile',
  content: content,
  importance: .7,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Float32List vector(int dimension) => Float32List(512)..[dimension] = 1;
Future<void> ready(LocalSemanticIndex index) async {
  for (var i = 0; i < 100 && index.status == 'indexing'; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(index.status, 'ready');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'embedding diagnostics separate cold load, indexing and cached queries',
    () async {
      final dir = await Directory.systemTemp.createTemp('semantic-timing-');
      addTearDown(() => dir.delete(recursive: true));
      const channel = MethodChannel('ai_companion/memory_embedding');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'embed');
        return {
          'vectors': [vector(0)],
          'loadMs': calls++ == 0 ? 17 : null,
          'inferenceMs': 5,
        };
      });
      final index = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => File('${dir.path}/vectors.json'),
      );
      Future<void> recall() async {
        final clock = Stopwatch()..start();
        SemanticQueryTiming? timing;
        await index.search('问句不会记录', [
          item('id', '记忆正文不会记录'),
        ], onTiming: (sample) => timing = sample);
        index.recordRecallTiming(
          mode: 'userTurn',
          query: timing!,
          totalMs: clock.elapsedMilliseconds,
          semanticOnlySelected: 0,
        );
      }

      await recall();
      expect(
        (index.timingStats()['latest'] as List).first['queryMode'],
        'fallback_indexing',
      );
      await ready(index);
      await recall();
      final inference = (index.timingStats()['latest'] as List).first;
      expect(inference['queryMode'], 'inference');
      expect(inference['nativeInferenceMs'], 5);
      for (var i = 0; i < 10; i++) {
        await recall();
      }
      final stats = index.timingStats();
      expect(stats['modelLoadMs'], 17);
      expect(stats['indexBuildItems'], 1);
      expect(stats['indexBuildMs'], greaterThanOrEqualTo(0));
      expect(stats['indexBuildRunning'], false);
      final latest = stats['latest'] as List;
      expect(latest, hasLength(8));
      expect(latest.first['queryMode'], 'cache_hit');
      expect(latest.first['nativeInferenceMs'], isNull);
      expect(stats.toString(), isNot(contains('不会记录')));
      expect(calls, 2);
    },
  );
  test(
    'incremental edits, deletion and archive replacement use current source rows',
    () async {
      final dir = await Directory.systemTemp.createTemp('semantic-test-');
      addTearDown(() => dir.delete(recursive: true));
      var encoded = 0;
      final index = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => File('${dir.path}/vectors.json'),
        encoder: (texts) async {
          encoded += texts.length;
          return texts.map((t) => vector(t.contains('面试') ? 0 : 1)).toList();
        },
      );
      final old = [item('a', '面试'), item('b', '火锅')];
      expect(await index.search('面试', old), isEmpty);
      await ready(index);
      expect((await index.search('面试', old))['a'], closeTo(1, 1e-6));
      final before = encoded;
      await index.search('面试', old);
      expect(
        encoded,
        before,
        reason: 'unchanged rows and identical query reuse vectors',
      );
      final changed = [item('a', '火锅')];
      final result = await index.search('面试', changed);
      expect(result.keys, ['a']);
      expect(
        result['a'],
        0,
        reason: 'same ID with edited text must not reuse old embedding',
      );
      expect(
        result.containsKey('b'),
        false,
        reason: 'deleted source cannot be recalled',
      );
      expect(await index.search('面试', []), isEmpty);
    },
  );
  test('encoder failure does not block lexical caller or mark ready', () async {
    final dir = await Directory.systemTemp.createTemp('semantic-failure-');
    addTearDown(() => dir.delete(recursive: true));
    final index = LocalSemanticIndex(
      enabled: true,
      cacheFile: () async => File('${dir.path}/cache'),
      encoder: (_) async => throw const FormatException('bad model'),
    );
    expect(await index.search('query', [item('a', 'text')]), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(index.status, 'unavailable');
    expect(await index.search('query', [item('a', 'text')]), isEmpty);
  });
}
