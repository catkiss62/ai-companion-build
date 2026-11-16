import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/memory_item.dart';

typedef SemanticQueryTiming = ({
  String mode,
  int? embeddingMs,
  int? inferenceMs,
});

/// Derived, disposable index. Source rows remain authoritative on every lookup.
/// Model identity includes tokenizer and pooling; never shares cloud vectors.
class LocalSemanticIndex {
  LocalSemanticIndex({this.encoder, this.cacheFile, bool? enabled})
    : enabled = enabled ?? Platform.isAndroid;
  final Future<List<Float32List>> Function(List<String>)? encoder;
  final Future<File> Function()? cacheFile;
  final bool enabled;
  static const modelIdentity = 'bge-small-zh-75c43b0-mean-normalized-v1';
  static const _channel = MethodChannel('ai_companion/memory_embedding');
  final Map<String, Float32List> _vectors = {};
  final Map<String, Float32List> _queries = {};
  Future<void>? _loading;
  bool _building = false;
  DateTime? _retryAfter;
  String status = 'not_started';
  int indexedCount = 0;
  int pendingCount = 0;
  int? _modelLoadMs;
  Stopwatch? _indexClock;
  int _indexedThisBuild = 0;
  final _recent = Queue<Map<String, Object?>>();

  void recordRecallTiming({
    required String mode,
    required SemanticQueryTiming query,
    required int totalMs,
    required int semanticOnlySelected,
  }) {
    if (!enabled) return;
    if (_recent.length == 8) _recent.removeFirst();
    _recent.add({
      'retrievalMode': mode,
      'queryMode': query.mode,
      'embeddingMs': query.embeddingMs,
      'nativeInferenceMs': query.inferenceMs,
      'totalMs': totalMs,
      'semanticOnlySelected': semanticOnlySelected,
    });
  }

  Map<String, Object?> timingStats() => {
    'modelLoadMs': _modelLoadMs,
    'indexBuildMs': _indexClock?.elapsedMilliseconds,
    'indexBuildRunning': _indexClock?.isRunning ?? false,
    'indexBuildItems': _indexedThisBuild,
    'latest': _recent.toList().reversed.toList(),
  };

  static String textFor(MemoryItem item) =>
      '${item.content}\n${item.tags.join(' ')}';
  static String keyFor(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  static Iterable<String> _chunks(String text) sync* {
    // WordPiece yields at most one token per input code point in this model.
    // Leave room for special tokens and overlap to preserve boundary context.
    const length = 480;
    const overlap = 48;
    if (text.length <= length) {
      yield text;
      return;
    }
    final points = text.runes.toList();
    for (var start = 0; start < points.length; start += length - overlap) {
      final end = min(start + length, points.length);
      yield String.fromCharCodes(points, start, end);
      if (end == points.length) break;
    }
  }

  Future<File> _file() async => cacheFile != null
      ? await cacheFile!()
      : File(
          '${(await getApplicationCacheDirectory()).path}/$modelIdentity.json',
        );
  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final e in data.entries) {
        final bytes = base64Decode(e.value as String);
        if (bytes.length != 512 * 4) continue;
        final values = Float32List.view(bytes.buffer, bytes.offsetInBytes, 512);
        if (values.every((v) => v.isFinite)) _vectors[e.key] = values;
      }
    } catch (_) {
      _vectors.clear();
    }
  }

  Future<({List<Float32List> vectors, int? inferenceMs})> _embed(
    List<String> texts, {
    Duration? budget,
  }) async {
    if (encoder != null) {
      final pending = encoder!(texts);
      return (
        vectors: await (budget == null ? pending : pending.timeout(budget)),
        inferenceMs: null,
      );
    }
    final raw = await _channel
        .invokeMapMethod<String, dynamic>('embed', {
          'texts': texts,
          if (budget != null) 'budgetMs': max(1, budget.inMilliseconds),
        })
        .timeout(budget ?? const Duration(seconds: 10));
    if (raw?['expired'] == true) throw TimeoutException('embedding deadline');
    _modelLoadMs ??= raw?['loadMs'] as int?;
    final vectors = raw?['vectors'] as List?;
    if (vectors == null || vectors.length != texts.length)
      throw const FormatException('embedding_count');
    final decoded = vectors.map((v) {
      final vector = Float32List.fromList(
        (v as List).map((n) => (n as num).toDouble()).toList(),
      );
      if (vector.length != 512 || !vector.every((n) => n.isFinite)) {
        throw const FormatException('embedding_shape');
      }
      return vector;
    }).toList();
    return (vectors: decoded, inferenceMs: raw?['inferenceMs'] as int?);
  }

  /// Old archives are indexed asynchronously. A partially built index is never
  /// used to bias retrieval toward whichever rows happened to finish first.
  Future<Map<String, double>> search(
    String query,
    List<MemoryItem> items, {
    void Function(SemanticQueryTiming)? onTiming,
    Duration? queryBudget,
  }) async {
    final queryClock = queryBudget == null ? null : (Stopwatch()..start());
    void timing(String mode, {int? embeddingMs, int? inferenceMs}) =>
        onTiming?.call((
          mode: mode,
          embeddingMs: embeddingMs,
          inferenceMs: inferenceMs,
        ));
    if (!enabled || query.trim().isEmpty || items.isEmpty) {
      timing('skipped');
      return {};
    }
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      timing('fallback_unavailable');
      return {};
    }
    await (_loading ??= _load());
    final texts = <String, String>{};
    final chunkKeysByText = <String, Set<String>>{};
    final chunkKeysById = <String, Set<String>>{};
    for (final item in items) {
      final text = textFor(item);
      chunkKeysById[item.id] = chunkKeysByText.putIfAbsent(text, () {
        final keys = <String>{};
        for (final chunk in _chunks(text)) {
          final key = keyFor(chunk);
          texts[key] = chunk;
          keys.add(key);
        }
        return keys;
      });
    }
    final missing = texts.entries
        .where((e) => !_vectors.containsKey(e.key))
        .toList();
    final pendingItems = chunkKeysByText.values
        .where((keys) => !keys.every(_vectors.containsKey))
        .toList();
    pendingCount = pendingItems.length;
    indexedCount = chunkKeysByText.length - pendingCount;
    if (missing.isNotEmpty) {
      if (!_building) {
        unawaited(_build(texts, missing, pendingItems, chunkKeysByText.length));
      }
      timing('fallback_indexing');
      return {};
    }
    Stopwatch? embeddingClock;
    int? inferenceMs;
    try {
      final remaining = queryBudget == null
          ? null
          : queryBudget - queryClock!.elapsed;
      if (remaining != null && remaining <= Duration.zero) {
        timing('fallback_timeout');
        return {};
      }
      final chunks = _chunks(query).toList(growable: false);
      final limit = queryBudget == null ? 8 : 2;
      final chosen = chunks.length <= limit
          ? chunks
          : [
              for (var i = 0; i < limit; i++)
                chunks[(i * (chunks.length - 1) / (limit - 1)).round()],
            ];
      // Hold cache hits across the await and any subsequent cache eviction.
      final queryVectors = <String, Float32List>{};
      final uncached = <String, String>{};
      for (final chunk in chosen) {
        final key = keyFor(chunk);
        final cached = _queries[key];
        if (cached == null) {
          uncached[key] = chunk;
        } else {
          queryVectors[key] = cached;
        }
      }
      if (uncached.isNotEmpty) {
        embeddingClock = Stopwatch()..start();
        final result = await _embed(
          uncached.values.toList(),
          budget: remaining,
        );
        embeddingClock.stop();
        inferenceMs = result.inferenceMs;
        var i = 0;
        for (final key in uncached.keys) {
          final vector = result.vectors[i++];
          queryVectors[key] = vector;
          _queries[key] = vector;
          if (_queries.length > 16) _queries.remove(_queries.keys.first);
        }
      }
      final scored = <MapEntry<String, double>>[];
      for (final item in chunkKeysById.entries) {
        var best = double.negativeInfinity;
        for (final key in item.value) {
          final v = _vectors[key];
          if (v == null) {
            timing('fallback_indexing');
            return {};
          }
          for (final q in queryVectors.values) {
            var dot = 0.0;
            for (var i = 0; i < 512; i++) {
              dot += q[i] * v[i];
            }
            if (dot.isFinite) best = max(best, dot);
          }
        }
        if (best.isFinite) scored.add(MapEntry(item.key, best.clamp(-1, 1)));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      status = 'ready';
      timing(
        embeddingClock == null ? 'cache_hit' : 'inference',
        embeddingMs: embeddingClock?.elapsedMilliseconds,
        inferenceMs: inferenceMs,
      );
      return Map.fromEntries(scored.take(40));
    } catch (error) {
      if (error is TimeoutException && queryBudget != null) {
        timing(
          'fallback_timeout',
          embeddingMs: embeddingClock?.elapsedMilliseconds,
        );
        return {};
      }
      status = 'unavailable';
      _retryAfter = DateTime.now().add(const Duration(minutes: 1));
      timing(
        'fallback_error',
        embeddingMs: embeddingClock?.elapsedMilliseconds,
        inferenceMs: inferenceMs,
      );
      return {};
    }
  }

  Future<void> _build(
    Map<String, String> texts,
    List<MapEntry<String, String>> missing,
    List<Set<String>> pendingItems,
    int itemCount,
  ) async {
    _building = true;
    status = 'indexing';
    _indexClock = Stopwatch()..start();
    _indexedThisBuild = 0;
    try {
      for (var i = 0; i < missing.length; i += 2) {
        final batch = missing.sublist(i, min(i + 2, missing.length));
        final result = await _embed(batch.map((e) => e.value).toList());
        for (var j = 0; j < batch.length; j++) {
          _vectors[batch[j].key] = result.vectors[j];
        }
        final before = pendingItems.length;
        pendingItems.removeWhere((keys) => keys.every(_vectors.containsKey));
        _indexedThisBuild += before - pendingItems.length;
        pendingCount = pendingItems.length;
        indexedCount = itemCount - pendingCount;
        if (i % 32 == 0) await _save();
        // Yield between batches so foreground inference can share CPU resources.
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      _vectors.removeWhere((key, _) => !texts.containsKey(key));
      await _save();
      status = 'ready';
    } catch (_) {
      status = 'unavailable';
      _retryAfter = DateTime.now().add(const Duration(minutes: 1));
    } finally {
      _indexClock?.stop();
      _building = false;
    }
  }

  Future<void> _save() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        for (final e in _vectors.entries)
          e.key: base64Encode(
            e.value.buffer.asUint8List(
              e.value.offsetInBytes,
              e.value.lengthInBytes,
            ),
          ),
      }),
    );
    await tmp.rename(f.path);
  }
}
