import 'dart:async';
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
  test('subset builds and concurrent writers preserve the full corpus across restart', () async {
    final dir = await Directory.systemTemp.createTemp('independent-indices');
    addTearDown(() => dir.delete(recursive: true));
    final encoded = <String>[];
    LocalSemanticIndex open() => LocalSemanticIndex(enabled: true,
      cacheFile: () async => File('${dir.path}/vectors.json'),
      encoder: (batch) async {
        encoded.addAll(batch);
        return batch.map((_) => vector(0)).toList();
      });
    final corpus = [for (var i = 0; i < 64; i++) item('m$i', '索引样本 $i')];
    final full = open();
    await full.search('检索', corpus);
    while (full.status == 'indexing') {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    expect(full.status, 'ready');
    final shared = open();
    await shared.search('小集合', [corpus.first, item('new', '新的样本')]);
    await ready(shared);
    final additions = [for (var i = 0; i < 24; i++) item('s$i', '并发 $i')];
    await Future.wait(additions.map((row) async {
      final independent = open();
      await independent.search('子集', [row]);
      await ready(independent);
    }));
    encoded.clear();
    final reopened = open();
    final scores = await reopened.search('跨实例验证', [...corpus, ...additions]);
    expect(scores.length, 40); // Search returns at most forty ranked hits.
    expect(reopened.indexedCount, 88);
    expect(encoded, ['跨实例验证']);
  });
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

  test('long query embeds the final question within the QQ deadline', () async {
    final dir=await Directory.systemTemp.createTemp('semantic-long-query-');
    addTearDown(()=>dir.delete(recursive:true));
    final encoded=<String>[];
    final index=LocalSemanticIndex(enabled:true,
      cacheFile:()async=>File('${dir.path}/cache'),encoder:(texts)async {
        encoded.addAll(texts);
        return texts.map((t)=>vector(t.contains('尾部问题')?1:0)).toList();
      });
    final items=[item('tail','尾部问题')];
    final query='${'长资料'*800}尾部问题';
    expect(await index.search(query,items,queryBudget:const Duration(milliseconds:450)),isEmpty);
    await ready(index);encoded.clear();
    final scores=await index.search(query,items,queryBudget:const Duration(milliseconds:450));
    expect(encoded.any((part)=>part.contains('尾部问题')),isTrue);
    expect(encoded.every((part)=>part.runes.length<=480),isTrue);
    expect(scores['tail'],1);
  });

  test(
    'long rows match on a later chunk and return the original ID once',
    () async {
      final dir = await Directory.systemTemp.createTemp('semantic-chunks-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = File('${dir.path}/cache');
      final shortText = LocalSemanticIndex.textFor(item('short', '已有短记忆'));
      final old = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => cache,
        encoder: (texts) async => texts.map((_) => vector(0)).toList(),
      );
      await old.search('初始查询', [item('short', '已有短记忆')]);
      await ready(old);
      final encoded = <String>[];
      final index = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => cache,
        encoder: (texts) async {
          encoded.addAll(texts);
          return texts
              .map((text) => vector(text.contains('目标事实') ? 1 : 0))
              .toList();
        },
      );
      final items = [
        item('short', '已有短记忆'),
        item('long', '${'🐳海' * 300}目标事实${'看' * 508}'),
      ];
      expect(await index.search('目标事实', items), isEmpty);
      await ready(index);
      expect(encoded.any((text) => text.runes.length > 480), isFalse);
      expect(encoded, isNot(contains(shortText)));
      expect(index.indexedCount, 2);
      final scores = await index.search('目标事实', items);
      expect(scores.keys, ['long', 'short']);
      expect(scores['long'], 1);
    },
  );

  for (final (lane, budget, concurrentEviction) in [
    ('App', null, false),
    ('QQ', const Duration(milliseconds: 450), false),
    ('App with concurrent queries', null, true),
  ]) {
    test('$lane retains selected chunks through query cache eviction', () async {
      final dir = await Directory.systemTemp.createTemp('semantic-eviction-');
      addTearDown(() => dir.delete(recursive: true));
      final longQuery = '${'A' * 480}${'B' * 432}${'C' * 432}${'D' * 432}'
          '${'E' * 432}${'F' * 432}${'G' * 432}尾部问题';
      final head = longQuery.substring(0, 480);
      final tailStarted = Completer<void>();
      final resumeTail = Completer<void>();
      final batches = <List<String>>[];
      final index = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => File('${dir.path}/cache'),
        encoder: (texts) async {
          batches.add(texts);
          if (concurrentEviction && texts.any((t) => t.endsWith('尾部问题'))) {
            tailStarted.complete();
            await resumeTail.future;
          }
          return texts.map((text) {
            if (text == head || text.startsWith('开头事实')) return vector(0);
            if (text.contains('尾部问题') || text.startsWith('结尾事实')) {
              return vector(1);
            }
            return vector(2);
          }).toList();
        },
      );
      final items = [item('head', '开头事实'), item('tail', '结尾事实')];
      expect(await index.search('初始化', items), isEmpty);
      await ready(index);
      expect((await index.search(head, items))['head'], 1.0);
      for (var i = 0; i < 15; i++) {
        expect(await index.search('填满缓存 $i', items), isNotEmpty);
      }
      batches.clear();

      final pending = index.search(longQuery, items, queryBudget: budget);
      if (concurrentEviction) {
        try {
          await tailStarted.future.timeout(const Duration(seconds: 2));
          expect(await index.search('并发查询', items), isNotEmpty);
        } finally {
          resumeTail.complete();
        }
      }

      expect(await pending, {'head': 1.0, 'tail': 1.0});
      expect(batches.first, hasLength(budget == null ? 7 : 1));
      expect(batches.first, isNot(contains(head)));
      expect(index.status, 'ready');
      expect((await index.search('开头事实', items))['head'], 1.0);
    });
  }

  test(
    'query deadline reaches the native queue without marking the model unavailable',
    () async {
      final dir = await Directory.systemTemp.createTemp('semantic-deadline-');
      addTearDown(() => dir.delete(recursive: true));
      const channel = MethodChannel('ai_companion/memory_embedding');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var expire = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final texts = call.arguments['texts'] as List;
        if (texts.single == '群摘要\n') {
          expect(call.arguments['budgetMs'], isNull);
        } else {
          expect(call.arguments['budgetMs'], inInclusiveRange(1, 450));
          if (expire) return {'expired': true};
        }
        return {
          'vectors': [vector(0)],
        };
      });
      final index = LocalSemanticIndex(
        enabled: true,
        cacheFile: () async => File('${dir.path}/cache'),
      );
      final items = [item('group', '群摘要')];
      const budget = Duration(milliseconds: 450);
      await index.search('问题', items, queryBudget: budget);
      await ready(index);
      SemanticQueryTiming? timing;
      expect(
        await index.search(
          '问题',
          items,
          queryBudget: budget,
          onTiming: (t) => timing = t,
        ),
        isEmpty,
      );
      expect(timing?.mode, 'fallback_timeout');
      expect(index.status, 'ready');
      expire = false;
      expect(await index.search('问题', items, queryBudget: budget), {
        'group': 1.0,
      });
    },
  );
}
