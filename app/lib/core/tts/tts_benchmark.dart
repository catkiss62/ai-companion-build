import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../models/chat_language_variant.dart';
import '../models/chat_message.dart';
import 'genie_fixed_text_segmenter.dart';
import 'native_tts_provider.dart';
import 'tts_provider.dart';
import 'tts_service.dart';
import 'tts_text_processor.dart';
import 'tts_voice_profile.dart';

/// A real generated reply is frozen locally, including its production speech
/// boundaries. Reports contain hashes and timing, never dialogue plaintext.
class TtsBenchmark {
  TtsBenchmark(this.db);
  final AppDatabase db;

  static const fixtureKey = 'tts_benchmark_fixture_v1';
  static const historyKey = 'tts_benchmark_history_v1';
  static const championKey = 'tts_benchmark_champion_v1';

  Future<String> champion() async =>
      (await db.getSetting(championKey)) == 'hybrid' ? 'hybrid' : 'auto';

  Future<String> run(String profile) async {
    final fixture = await _fixture();
    final raw = await NativeTtsProvider.instance.benchmark(
      profile,
      (fixture['segments'] as List)
          .map((segment) => Map<String, String>.from(segment as Map))
          .toList(growable: false),
    );
    final entry = <String, dynamic>{
      'fixtureId': fixture['id'],
      'fixtureHash': fixture['hash'],
      'fixtureScope': fixture['scope'],
      'timestamp': DateTime.now().toIso8601String(),
      ...raw.map((key, value) => MapEntry(key.toString(), value)),
    };
    final history = await _history();
    history.add(entry);
    if (history.length > 12) history.removeRange(0, history.length - 12);
    await db.setSetting(historyKey, jsonEncode(history));
    final auto = _latest(history, 'auto', fixture['hash']);
    final hybrid = _latest(history, 'hybrid', fixture['hash']);
    if (auto != null && hybrid != null && _comparable(auto, hybrid)) {
      final a = _wall(auto);
      final b = _wall(hybrid);
      if (a > 0 && b > 0 && (a - b).abs() / a > .05) {
        final winner = b < a ? 'hybrid' : 'auto';
        await db.setSetting(championKey, winner);
        await db.setSetting('tts_auto_affinity_enabled', '1');
        await db.setSetting('tts_hybrid_vits_enabled', winner == 'hybrid' ? '1' : '0');
      }
    }
    return '${profile == 'auto' ? '自动核亲和档' : '混合档'}完成：'
        '${entry['complete'] == true ? '全部成功' : '部分失败'}，'
        '无声生成 ${_wall(entry)} ms；'
        '${fixture['scope'] == 'full_text_fallback' ? '最近回复没有对白，改用真实回复全文测试；' : ''}'
        '两档完成后可复制对照报告。';
  }

  Future<void> chooseNewFixture() async {
    await db.setSetting(fixtureKey, '');
  }

  Future<String> report() async {
    final history = await _history();
    if (history.isEmpty) return '尚无 TTS 无声对照记录。';
    final last = history.last;
    final auto = _latest(history, 'auto', last['fixtureHash']);
    final hybrid = _latest(history, 'hybrid', last['fixtureHash']);
    final comparable = auto != null && hybrid != null && _comparable(auto, hybrid);
    final saving = comparable && auto != null && hybrid != null && _wall(auto) > 0
        ? '${((_wall(auto) - _wall(hybrid)) / _wall(auto) * 100).toStringAsFixed(1)}%'
        : '不可比较';
    return '''AI Companion · TTS 专项无声对照
同一 API 真实回复 / 同一预处理分段；只生成 PCM，不播放。
测试范围：${last['fixtureScope'] == 'full_text_fallback' ? '当前朗读范围没有对白，改用真实回复全文比较' : '当前朗读范围'}。
当前胜出档：${await champion()}；混合档相对自动核亲和耗时变化：$saving
当前样本可比较：$comparable。更换样本后旧数据仅作历史参考。
记录（最多 12 次；不含聊天原文）：
${const JsonEncoder.withIndent('  ').convert(history)}''';
  }

  Future<Map<String, dynamic>> _fixture() async {
    final stored = await db.getSetting(fixtureKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        if ((data['segments'] as List).isNotEmpty) return data;
      } catch (_) {}
    }
    final messages = (await db.recentMessages(limit: 80))
        .where((m) => m.isAssistant && m.content.trim().isNotEmpty)
        .toList(growable: false);
    if (messages.isEmpty) throw StateError('请先在聊天中生成一条真实回复。');
    final language = ChatLanguage.tryParse(await db.getSetting('tts_language')) ??
        ChatLanguage.chinese;
    final processor = const TtsTextProcessor();
    final scope = TtsReadingScope.fromSetting(
      await db.getSetting('tts_reading_scope'),
    );
    final replacements = processor.decodeReplacementJson(
      await db.getSetting('tts_replacements_json'),
    );
    // A benchmark uses the *same* production speech preprocessing, but must
    // not initialize the engine merely to choose a fixture. Long replies can
    // contain only actions; skip them and find the newest speakable reply.
    final newest = messages.reversed.toList(growable: false);
    final candidates = [
      ...newest.where((m) => m.content.runes.length >= 90),
      ...newest.where((m) => m.content.runes.length < 90),
    ];
    Iterable<({ChatMessage message, List<TtsPreparedUnit> units})> options(
        TtsReadingScope effectiveScope) => candidates.map((message) => (
          message: message,
          units: processor.processUnits(
            message.contentFor(language),
            language: language,
            scope: effectiveScope,
            replacements: replacements,
          ),
        )).where((item) => item.units.isNotEmpty);
    var prepared = options(scope);
    var effectiveScope = scope.key;
    if (prepared.isEmpty && scope == TtsReadingScope.dialogueOnly) {
      prepared = options(TtsReadingScope.fullText);
      effectiveScope = 'full_text_fallback';
    }
    if (prepared.isEmpty) {
      throw StateError('最近的真实回复没有所选语种的可朗读内容；请先聊一轮或切换朗读语种。');
    }
    final fixtureSource = prepared.first;
    final selected = fixtureSource.message;
    final units = fixtureSource.units;
    final tts = TtsService(db: db);
    final voice = await tts.resolveVoice(selected.emotionKey.isEmpty
        ? null
        : TtsEmotionCue(
            key: selected.emotionKey,
            label: selected.emotionLabel,
            confidence: selected.emotionConfidence,
            source: selected.emotionSource,
          ));
    final segments = <Map<String, String>>[];
    for (final unit in units) {
      for (final chunk in GenieFixedTextSegmenter.splitFirstImmediate(unit.text, language)) {
        if (chunk.trim().isNotEmpty) {
          segments.add({
            'text': chunk,
            'language': language.key,
            'voice': (unit.role == TtsSpeechRole.narration
                    ? TtsVoiceMode.gentle : voice).key,
          });
        }
      }
    }
    if (segments.isEmpty) throw StateError('当前回复经语音文字处理后没有可朗读片段。');
    final fixture = <String, dynamic>{
      'id': selected.id,
      'scope': effectiveScope,
      'hash': sha256.convert(utf8.encode(jsonEncode(segments))).toString(),
      'segments': segments,
    };
    await db.setSetting(fixtureKey, jsonEncode(fixture));
    return fixture;
  }

  Future<List<Map<String, dynamic>>> _history() async {
    try {
      return (jsonDecode(await db.getSetting(historyKey) ?? '[]') as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _latest(List<Map<String, dynamic>> history,
      String profile, Object? hash) {
    for (final item in history.reversed) {
      if (item['profile'] == profile && item['fixtureHash'] == hash) return item;
    }
    return null;
  }

  bool _comparable(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['complete'] != true || b['complete'] != true ||
        a['fixtureHash'] != b['fixtureHash']) return false;
    final left = a['segments'] as List? ?? [];
    final right = b['segments'] as List? ?? [];
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if ((left[i] as Map)['sha256'] != (right[i] as Map)['sha256']) return false;
    }
    return (((a['thermalAfter'] as num?)?.toInt() ?? 0) -
            ((b['thermalAfter'] as num?)?.toInt() ?? 0)).abs() <= 1;
  }

  int _wall(Map<String, dynamic> entry) =>
      (entry['segments'] as List? ?? []).fold<int>(0, (sum, item) =>
          sum + (((item as Map)['durationMs'] as num?)?.toInt() ?? 0));
}
