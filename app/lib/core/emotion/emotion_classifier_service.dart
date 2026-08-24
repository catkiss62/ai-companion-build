import 'emotion_contract.dart';

class EmotionClassifierService {
  const EmotionClassifierService();

  static const EmotionClassifierService instance = EmotionClassifierService();

  static const Map<String, List<String>> _cuesByKey = <String, List<String>>{
    'excited': ['兴奋', '激动', '迫不及待', '眼睛发亮', '尾巴飞快', '蹦起来', '冲过来', '好耶'],
    'disgust': ['厌恶', '嫌弃', '恶心', '皱了皱鼻', '皱鼻', '撇嘴', '离远点', '咦惹'],
    'crying': ['伤心', '难过', '哭', '眼泪', '泪水', '失落', '委屈', '鼻子发酸', '声音发颤'],
    'afraid': ['害怕', '吓到', '吓了一跳', '恐惧', '缩了缩', '躲到', '发抖', '不敢动'],
    'shy': ['害羞', '脸红', '耳鳍红', '偏开脸', '不敢看', '声音小了', '小声嘟囔'],
    'affection': ['心动', '爱你', '喜欢你', '想你', '抱抱', '亲亲', '贴贴', '靠近了一点', '蹭了蹭'],
    'surprised': ['惊讶', '居然', '竟然', '没想到', '睁大眼', '愣了一下', '诶？', '欸？', '什么？', '？！', '?!'],
    'flustered': ['慌张', '慌乱', '糟了', '手忙脚乱', '语无伦次', '尾巴打结', '差点忘了'],
    'worried': ['担心', '还好吗', '没事吧', '小心一点', '皱起眉', '放心不下', '看着你'],
    'helpless': ['无奈', '无语', '叹了口气', '叹气', '拿你没办法', '真是的', '扶额'],
    'angry': ['生气', '气鼓鼓', '不许', '可恶', '火大', '炸毛', '拍桌', '瞪着'],
    'confused': ['疑惑', '为什么', '怎么会', '不明白', '歪了歪头', '歪头', '什么意思', '满头问号'],
    'nervous': ['紧张', '忐忑', '心里发紧', '捏着衣角', '屏住呼吸', '咽了咽', '吞咽'],
    'confident': ['自信', '交给我', '包在我身上', '肯定能', '胸有成竹', '抬起下巴', '拍了拍胸口'],
    'serious': ['认真', '严肃', '关键是', '结论', '需要注意', '正色', '坐直了', '一字一句'],
    'playful': ['调皮', '嘿嘿', '逗你', '骗你的', '笨蛋', '眨了眨眼', '坏笑', '恶作剧', '捉弄'],
    'embarrassed': ['难为情', '尴尬', '羞耻', '僵住了', '讪笑', '别提了', '想找条缝'],
    'happy': ['高兴', '开心', '笑起来', '笑眯眯', '弯起眼', '太好了', '哈哈', '尾巴晃了晃'],
  };

  Future<CompanionEmotion> resolve({
    required String rawTag,
    required String visibleText,
    EmotionEnvelopeStatus envelopeStatus = EmotionEnvelopeStatus.missing,
  }) async {
    final normalized = EmotionCatalog.normalizeTag(rawTag);
    final directKey = EmotionCatalog.keyForLabel(normalized);
    if (directKey.isNotEmpty) {
      final recovered = envelopeStatus == EmotionEnvelopeStatus.recovered;
      return CompanionEmotion(
        rawTag: normalized,
        key: directKey,
        label: EmotionCatalog.labelForKey(directKey),
        confidence: recovered ? 0.92 : 1,
        top3: <EmotionScore>[
          EmotionScore(
            key: directKey,
            label: EmotionCatalog.labelForKey(directKey),
            confidence: recovered ? 0.92 : 1,
          ),
        ],
        // Historical validator compatibility token: source: 'llm'
        source: recovered ? EmotionSource.llmRecovered : EmotionSource.llm,
      );
    }

    // v0.38.0 keeps the v0.37.2 crash boundary: never invoke native code from
    // reply finalization. Invalid or missing envelopes use a deterministic,
    // bounded Chinese cue scorer instead of collapsing almost everything to calm.
    return _heuristic(
      normalized.isEmpty ? visibleText : '$normalized\n$visibleText',
      rawTag: normalized,
      source: _fallbackSource(envelopeStatus, normalized),
    );
  }

  String _fallbackSource(
    EmotionEnvelopeStatus status,
    String normalizedTag,
  ) =>
      switch (status) {
        EmotionEnvelopeStatus.empty => EmotionSource.fallbackEmpty,
        EmotionEnvelopeStatus.invalid => EmotionSource.fallbackInvalid,
        EmotionEnvelopeStatus.malformed => EmotionSource.fallbackMalformed,
        EmotionEnvelopeStatus.missing => normalizedTag.isEmpty
            ? EmotionSource.fallbackMissing
            : EmotionSource.fallbackInvalid,
        EmotionEnvelopeStatus.canonical ||
        EmotionEnvelopeStatus.recovered =>
          normalizedTag.isEmpty
              ? EmotionSource.fallbackMissing
              : EmotionSource.fallbackInvalid,
      };

  CompanionEmotion _heuristic(
    String text, {
    required String rawTag,
    required String source,
  }) {
    final normalizedText = text.toLowerCase();
    final candidates = <_EmotionCandidate>[];

    for (final entry in _cuesByKey.entries) {
      var score = 0;
      for (final cue in entry.value) {
        if (_containsNonNegated(normalizedText, cue.toLowerCase())) {
          score += cue.length >= 4 ? 3 : 2;
        }
      }
      final label = EmotionCatalog.labelForKey(entry.key);
      if (label.isNotEmpty &&
          _containsNonNegated(normalizedText, label.toLowerCase())) {
        score += 4;
      }
      if (score > 0) {
        candidates.add(_EmotionCandidate(key: entry.key, score: score));
      }
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return EmotionCatalog.labelsByKey.keys
          .toList(growable: false)
          .indexOf(a.key)
          .compareTo(
            EmotionCatalog.labelsByKey.keys
                .toList(growable: false)
                .indexOf(b.key),
          );
    });

    if (candidates.isEmpty) {
      return CompanionEmotion(
        rawTag: _boundedRawTag(rawTag),
        key: 'calm',
        label: EmotionCatalog.labelForKey('calm'),
        confidence: 0.18,
        top3: const <EmotionScore>[
          EmotionScore(key: 'calm', label: '平静', confidence: 0.18),
        ],
        source: source,
      );
    }

    final winner = candidates.first;
    final confidence = (0.38 + winner.score * 0.055)
        .clamp(0.38, 0.82)
        .toDouble();
    final top3 = candidates.take(3).map((candidate) {
      final candidateConfidence = (0.30 + candidate.score * 0.05)
          .clamp(0.30, confidence)
          .toDouble();
      return EmotionScore(
        key: candidate.key,
        label: EmotionCatalog.labelForKey(candidate.key),
        confidence: candidateConfidence,
      );
    }).toList(growable: false);

    return CompanionEmotion(
      rawTag: _boundedRawTag(rawTag),
      key: winner.key,
      label: EmotionCatalog.labelForKey(winner.key),
      confidence: confidence,
      top3: top3,
      source: source,
    );
  }

  String _boundedRawTag(String rawTag) =>
      rawTag.substring(0, rawTag.length.clamp(0, 20).toInt());

  bool _containsNonNegated(String text, String cue) {
    var offset = 0;
    while (offset < text.length) {
      final index = text.indexOf(cue, offset);
      if (index < 0) return false;
      final prefixStart = (index - 3).clamp(0, index).toInt();
      final prefix = text.substring(prefixStart, index);
      if (!prefix.endsWith('不') &&
          !prefix.endsWith('没') &&
          !prefix.endsWith('别') &&
          !prefix.endsWith('并不') &&
          !prefix.endsWith('不是') &&
          !prefix.endsWith('没有')) {
        return true;
      }
      offset = index + cue.length;
    }
    return false;
  }
}

class _EmotionCandidate {
  const _EmotionCandidate({required this.key, required this.score});

  final String key;
  final int score;
}
