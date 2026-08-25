import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_classifier_service.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_contract.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';

void main() {
  test('emotion envelope is machine-only throughout streaming', () {
    expect(EmotionEnvelope.streamingVisible('<emo'), isEmpty);
    expect(EmotionEnvelope.streamingVisible('[emo'), isEmpty);
    expect(EmotionEnvelope.streamingVisible('【情绪'), isEmpty);
    expect(
      EmotionEnvelope.streamingVisible('情绪会自然变化。'),
      '情绪会自然变化。',
    );
    expect(
      EmotionEnvelope.streamingVisible(
        '<emotion>害羞</emotion>\n（她轻轻偏开脸）\n\n「别看。」',
      ),
      '\n（她轻轻偏开脸）\n\n「别看。」',
    );
    expect(
      EmotionEnvelope.streamingVisible('（她抬起眼）\n<emotion>心动'),
      '（她抬起眼）\n',
    );
  });

  test('misplaced and duplicate emotion tags never reach visible content', () {
    final parsed = EmotionEnvelope.parse(
      '（她靠近了一点）\n<emotion>心动</emotion>\n'
      '「过来。」\n<emotion>害羞</emotion>',
    );
    expect(parsed.found, isTrue);
    expect(parsed.status, EmotionEnvelopeStatus.canonical);
    expect(parsed.rawTag, '心动');
    expect(parsed.visibleText, '（她靠近了一点）\n\n「过来。」');
    expect(parsed.visibleText, isNot(contains('<emotion')));
  });

  test('empty and whitespace-only envelopes are removed without body loss', () {
    for (final raw in const [
      '<emotion></emotion>\n「正文还在。」',
      '<EMOTION>   </EMOTION>\n「正文还在。」',
      '< emotion >\t< / emotion >\n「正文还在。」',
      '<emotion />\n「正文还在。」',
    ]) {
      final parsed = EmotionEnvelope.parse(raw);
      expect(parsed.rawTag, isEmpty);
      expect(parsed.visibleText, '「正文还在。」');
      expect(parsed.visibleText.toLowerCase(), isNot(contains('emotion')));
    }
  });

  test('safe first-line variants recover without leaking machine metadata', () async {
    const service = EmotionClassifierService();
    final cases = <String, String>{
      '<emotion>害羞\n「正文还在。」': 'shy',
      '[emotion:高兴]\n「正文还在。」': 'happy',
      '【情绪：心动】\n「正文还在。」': 'affection',
      '情绪：生气\n「正文还在。」': 'angry',
    };
    for (final entry in cases.entries) {
      final parsed = EmotionEnvelope.parse(entry.key);
      expect(parsed.found, isTrue);
      expect(parsed.status, EmotionEnvelopeStatus.recovered);
      expect(parsed.visibleText, '「正文还在。」');
      final result = await service.resolve(
        rawTag: parsed.rawTag,
        visibleText: parsed.visibleText,
        envelopeStatus: parsed.status,
      );
      expect(result.key, entry.value);
      expect(result.source, EmotionSource.llmRecovered);
      expect(result.confidence, 0.92);
    }
  });

  test('ordinary visible emotion wording is never mistaken for metadata', () {
    final parsed = EmotionEnvelope.parse('「我今天的情绪：高兴。」\n「正文还在。」');
    expect(parsed.status, EmotionEnvelopeStatus.missing);
    expect(parsed.visibleText, '「我今天的情绪：高兴。」\n「正文还在。」');
  });

  test('malformed explicit first line is hidden without losing its body', () {
    final parsed = EmotionEnvelope.parse(
      '<emotion mood="high">害羞\n「正文还在。」',
    );
    expect(parsed.status, EmotionEnvelopeStatus.malformed);
    expect(parsed.visibleText, '「正文还在。」');
  });

  test('invalid envelope falls back but never leaks into body', () async {
    const service = EmotionClassifierService();
    final parsed = EmotionEnvelope.parse(
      '<emotion>非常非常开心</emotion>\n「正文还在。」',
    );
    expect(parsed.found, isTrue);
    expect(parsed.status, EmotionEnvelopeStatus.invalid);
    expect(parsed.rawTag, '非常非常开心');
    expect(parsed.visibleText, '「正文还在。」');
    final result = await service.resolve(
      rawTag: parsed.rawTag,
      visibleText: parsed.visibleText,
      envelopeStatus: parsed.status,
    );
    expect(result.key, 'happy');
    expect(result.source, EmotionSource.fallbackInvalid);
  });

  test('canonical DeepSeek tag is the authoritative 19-label emotion', () async {
    const service = EmotionClassifierService();
    final result = await service.resolve(
      rawTag: '心动',
      visibleText: '「过来一点。」',
      envelopeStatus: EmotionEnvelopeStatus.canonical,
    );
    expect(result.key, 'affection');
    expect(result.label, '心动');
    expect(result.source, 'llm');
    expect(result.confidence, 1);
  });

  test('normal is an explicit presentation token outside the 19 emotions', () async {
    const service = EmotionClassifierService();
    final parsed = EmotionEnvelope.parse(
      '<emotion>正常</emotion>\n「这事就是这样。」',
    );
    expect(EmotionCatalog.labelsByKey, hasLength(19));
    expect(parsed.status, EmotionEnvelopeStatus.canonical);
    final result = await service.resolve(
      rawTag: parsed.rawTag,
      visibleText: parsed.visibleText,
      envelopeStatus: parsed.status,
    );
    expect(result.key, 'normal');
    expect(result.label, '正常');
    expect(result.source, EmotionSource.llm);
    expect(EmotionCatalog.minimaxEmotionForKey('normal'), 'neutral');
  });

  test('noncanonical tag degrades without calling native code', () async {
    const service = EmotionClassifierService();
    final result = await service.resolve(
      rawTag: '有点坏心眼',
      visibleText: '「猜错了，重来。」',
      envelopeStatus: EmotionEnvelopeStatus.invalid,
    );
    expect(result.key, 'normal');
    expect(result.source, EmotionSource.fallbackInvalid);
  });

  test('missing tags use deterministic 19-label cue scoring', () async {
    const service = EmotionClassifierService();
    final cases = <String, String>{
      'excited': '（她一下蹦了起来，眼睛发亮。）',
      'disgust': '（她皱了皱鼻，嫌弃地后退半步。）',
      'crying': '（眼泪掉了下来，声音发颤。）',
      'afraid': '（她被吓到，缩了缩身子。）',
      'shy': '（她偏开脸，耳鳍红了。）',
      'calm': '（她安静地坐在旁边。）\n「嗯。」',
      'affection': '（她蹭了蹭你。）\n「想你。」',
      'surprised': '（她睁大眼。）\n「居然是这样？！」',
      'flustered': '（她手忙脚乱地扶住杯子。）\n「糟了。」',
      'worried': '（她皱起眉。）\n「你没事吧？」',
      'helpless': '（她叹了口气。）\n「真是拿你没办法。」',
      'angry': '（她一下炸毛，抬手拍桌。）',
      'confused': '（她歪了歪头。）\n「这是什么意思？」',
      'nervous': '（她忐忑地捏着衣角。）',
      'confident': '（她拍了拍胸口。）\n「交给我。」',
      'serious': '（她正色坐直。）\n「有件事需要注意。」',
      'playful': '（她眨了眨眼，露出坏笑。）',
      'embarrassed': '（她尴尬地僵住了。）',
      'happy': '（她笑眯眯地晃了晃尾巴。）',
    };
    expect(cases, hasLength(19));
    for (final entry in cases.entries) {
      final first = await service.resolve(
        rawTag: '',
        visibleText: entry.value,
        envelopeStatus: EmotionEnvelopeStatus.missing,
      );
      final second = await service.resolve(
        rawTag: '',
        visibleText: entry.value,
        envelopeStatus: EmotionEnvelopeStatus.missing,
      );
      expect(first.key, entry.key, reason: entry.value);
      expect(second.key, first.key);
      expect(second.top3Json, first.top3Json);
      expect(first.source, EmotionSource.fallbackMissing);
      expect(first.confidence, inInclusiveRange(0.18, 0.82));
      expect(first.top3.length, inInclusiveRange(1, 3));
    }
  });

  test('negated cues do not manufacture an emotion', () async {
    const service = EmotionClassifierService();
    final result = await service.resolve(
      rawTag: '',
      visibleText: '「我没有生气，也不害怕。」',
      envelopeStatus: EmotionEnvelopeStatus.missing,
    );
    expect(result.key, 'normal');
    expect(result.source, EmotionSource.fallbackMissing);
  });

  test('missing tag without a cue uses normal while real calm stays calm', () async {
    const service = EmotionClassifierService();
    final ordinary = await service.resolve(
      rawTag: '',
      visibleText: '「这事就是这样。」',
      envelopeStatus: EmotionEnvelopeStatus.missing,
    );
    final calm = await service.resolve(
      rawTag: '',
      visibleText: '（她闭了闭眼，缓了口气。）\n「嗯，先安静一下。」',
      envelopeStatus: EmotionEnvelopeStatus.missing,
    );
    expect(ordinary.key, 'normal');
    expect(ordinary.confidence, 0.18);
    expect(calm.key, 'calm');
    expect(calm.confidence, greaterThan(ordinary.confidence));
  });

  test('source diagnostics expose categories without raw tags', () {
    expect(EmotionSource.diagnosticStatus('llm'), 'valid_tag');
    expect(
      EmotionSource.diagnosticStatus(EmotionSource.llmRecovered),
      'recovered_tag',
    );
    expect(
      EmotionSource.diagnosticStatus(EmotionSource.fallbackMissing),
      'missing_tag',
    );
    expect(
      EmotionSource.diagnosticStatus(EmotionSource.fallbackInvalid),
      'invalid_tag',
    );
  });

  test('19 labels have stable keys and future MiniMax mappings', () {
    expect(EmotionCatalog.labelsByKey, hasLength(19));
    expect(EmotionCatalog.keyForLabel('正常'), 'normal');
    expect(EmotionCatalog.labelForKey('normal'), '正常');
    expect(EmotionCatalog.labelForKey('crying'), '伤心');
    expect(EmotionCatalog.keyForLabel('哭泣'), 'crying');
    expect(EmotionCatalog.keyForLabel('羞耻'), 'embarrassed');
    expect(EmotionCatalog.keyForLabel('尴尬'), 'embarrassed');
    expect(EmotionCatalog.keyForLabel('无语'), 'helpless');
    expect(EmotionCatalog.keyForLabel('情动'), 'affection');
    expect(EmotionCatalog.keyForLabel('慌乱'), 'flustered');
    final cue = TtsEmotionCue(
      key: 'angry',
      label: '生气',
      confidence: 0.9,
      source: 'llm',
    );
    expect(cue.minimaxEmotion, 'angry');
    expect(cue.toChannelMap()['emotion_label'], '生气');
  });
}
