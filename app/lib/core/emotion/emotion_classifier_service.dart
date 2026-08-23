import 'emotion_contract.dart';

class EmotionClassifierService {
  const EmotionClassifierService();

  static const EmotionClassifierService instance = EmotionClassifierService();

  Future<CompanionEmotion> resolve({
    required String rawTag,
    required String visibleText,
  }) async {
    final normalized = EmotionCatalog.normalizeTag(rawTag);
    final directKey = EmotionCatalog.keyForLabel(normalized);
    if (directKey.isNotEmpty) {
      return CompanionEmotion(
        rawTag: normalized,
        key: directKey,
        label: EmotionCatalog.labelForKey(directKey),
        confidence: 1,
        top3: <EmotionScore>[
          EmotionScore(
            key: directKey,
            label: EmotionCatalog.labelForKey(directKey),
            confidence: 1,
          ),
        ],
        source: 'llm',
      );
    }

    // v0.37.2 stability hotfix: never invoke a native classifier from the
    // reply finalization path. The DeepSeek 19-label envelope is authoritative;
    // malformed/missing tags degrade deterministically and cannot crash Android.
    return _heuristic(
      normalized.isEmpty ? visibleText : '$normalized\n$visibleText',
      rawTag: normalized,
    );
  }

  CompanionEmotion _heuristic(String text, {required String rawTag}) {
    String label = '平静';
    if (_has(text, const ['喜欢', '爱你', '抱抱', '亲亲', '想你', '贴贴', '心动'])) {
      label = '心动';
    } else if (_has(text, const ['害羞', '脸红', '不好意思', '耳鳍红'])) {
      label = '害羞';
    } else if (_has(text, const ['生气', '气鼓鼓', '不许', '可恶', '讨厌'])) {
      label = '生气';
    } else if (_has(text, const ['难过', '伤心', '哭', '失落', '委屈'])) {
      label = '哭泣';
    } else if (_has(text, const ['害怕', '吓到', '恐惧'])) {
      label = '害怕';
    } else if (_has(text, const ['惊讶', '居然', '竟然', '诶？', '什么？'])) {
      label = '惊讶';
    } else if (_has(text, const ['担心', '小心', '还好吗', '没事吧'])) {
      label = '担心';
    } else if (_has(text, const ['认真', '关键是', '结论', '需要注意'])) {
      label = '认真';
    } else if (_has(text, const ['无奈', '叹气', '拿你没办法', '真是的'])) {
      label = '无奈';
    } else if (_has(text, const ['疑惑', '为什么', '怎么会', '不明白'])) {
      label = '疑惑';
    } else if (_has(text, const ['紧张', '忐忑'])) {
      label = '紧张';
    } else if (_has(text, const ['慌', '糟了', '手忙脚乱'])) {
      label = '慌张';
    } else if (_has(text, const ['嘿嘿', '逗你', '骗你的', '笨蛋', '调皮'])) {
      label = '调皮';
    } else if (_has(text, const ['开心', '高兴', '太好了', '好耶', '哈哈'])) {
      label = '高兴';
    }
    final key = EmotionCatalog.keyForLabel(label);
    return CompanionEmotion(
      rawTag: rawTag.substring(0, rawTag.length.clamp(0, 20).toInt()),
      key: key,
      label: label,
      confidence: label == '平静' ? 0 : 0.34,
      top3: <EmotionScore>[
        EmotionScore(
          key: key,
          label: label,
          confidence: label == '平静' ? 0 : 0.34,
        ),
      ],
      source: 'heuristic',
    );
  }

  bool _has(String text, List<String> words) => words.any(text.contains);
}
