/// Deterministic backstop for explicit complaints that an active topic is
/// being repeated. The model still handles ordinary engagement and timing,
/// but it may not turn a clear repetition complaint into positive topic fit.
abstract final class ProactiveTopicFeedbackPolicy {
  static bool isRepetitionComplaint(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) return false;
    if (_negatedCues.any(text.contains)) return false;
    return _directCues.any(text.contains) ||
        _repeatedVerb.hasMatch(text) ||
        _stopRepeating.hasMatch(text);
  }

  static const _directCues = <String>[
    '翻来覆去',
    '反反复复',
    '像复读机',
    '跟复读机一样',
    '又是这个话题',
    '怎么又是这个',
    '一直绕着这个',
    '总绕着这个',
  ];

  static const _negatedCues = <String>[
    '没有一直念叨',
    '并没有一直念叨',
    '不是说你一直念叨',
    '不是嫌你重复',
    '没有嫌你重复',
  ];

  static final RegExp _repeatedVerb = RegExp(
    r'(一直|老是|总是|反复|重复).{0,6}(念叨|提起|提这个|说这个|聊这个|说同一|讲同一)',
  );

  static final RegExp _stopRepeating = RegExp(
    r'(别|不要|不用).{0,3}(再|一直|老是|反复|重复).{0,5}(念叨|提|说|聊)',
  );
}
