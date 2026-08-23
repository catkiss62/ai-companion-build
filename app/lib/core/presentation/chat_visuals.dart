import '../emotion/emotion_contract.dart';
import '../models/chat_segment.dart';

class ChatEmotionVisual {
  const ChatEmotionVisual({
    required this.key,
    required this.zhLabel,
    required this.portraitAsset,
    this.soundAsset,
  });

  final String key;
  final String zhLabel;
  final String portraitAsset;
  final String? soundAsset;
}

class ChatVisualChunk {
  const ChatVisualChunk({
    required this.segments,
    required this.emotion,
  });

  final List<ChatSegment> segments;
  final ChatEmotionVisual emotion;

  String get plainText => segments.map((segment) => segment.text).join('\n');
  String get displayText => segments.map((segment) {
        if (segment.kind == ChatSegmentKind.dialogue) {
          return '「${segment.text}」';
        }
        return '（${segment.text}）';
      }).join('\n\n');
}

class ChatVisualResolver {
  const ChatVisualResolver._();

  static const normal = ChatEmotionVisual(
    key: 'normal',
    zhLabel: '自然',
    portraitAsset: 'assets/lingchat/deepseek/normal.webp',
  );

  static const values = <ChatEmotionVisual>[
    normal,
    ChatEmotionVisual(
      key: 'happy',
      zhLabel: '开心',
      portraitAsset: 'assets/lingchat/deepseek/happy.webp',
      soundAsset: 'assets/lingchat/audio/joy.wav',
    ),
    ChatEmotionVisual(
      key: 'playful',
      zhLabel: '俏皮',
      portraitAsset: 'assets/lingchat/deepseek/playful.webp',
      soundAsset: 'assets/lingchat/audio/noticed.wav',
    ),
    ChatEmotionVisual(
      key: 'affection',
      zhLabel: '亲昵',
      portraitAsset: 'assets/lingchat/deepseek/affection.webp',
      soundAsset: 'assets/lingchat/audio/affection.wav',
    ),
    ChatEmotionVisual(
      key: 'shy',
      zhLabel: '害羞',
      portraitAsset: 'assets/lingchat/deepseek/shy.webp',
      soundAsset: 'assets/lingchat/audio/shy.wav',
    ),
    ChatEmotionVisual(
      key: 'sad',
      zhLabel: '难过',
      portraitAsset: 'assets/lingchat/deepseek/sad.webp',
      soundAsset: 'assets/lingchat/audio/sad.wav',
    ),
    ChatEmotionVisual(
      key: 'angry',
      zhLabel: '生气',
      portraitAsset: 'assets/lingchat/deepseek/angry.webp',
      soundAsset: 'assets/lingchat/audio/angry.wav',
    ),
    ChatEmotionVisual(
      key: 'surprised',
      zhLabel: '惊讶',
      portraitAsset: 'assets/lingchat/deepseek/surprised.webp',
      soundAsset: 'assets/lingchat/audio/surprised.wav',
    ),
    ChatEmotionVisual(
      key: 'confused',
      zhLabel: '疑惑',
      portraitAsset: 'assets/lingchat/deepseek/confused.webp',
      soundAsset: 'assets/lingchat/audio/question.wav',
    ),
    ChatEmotionVisual(
      key: 'worried',
      zhLabel: '担心',
      portraitAsset: 'assets/lingchat/deepseek/worried.webp',
      soundAsset: 'assets/lingchat/audio/troubled.wav',
    ),
    ChatEmotionVisual(
      key: 'serious',
      zhLabel: '认真',
      portraitAsset: 'assets/lingchat/deepseek/serious.webp',
      soundAsset: 'assets/lingchat/audio/thinking.wav',
    ),
    ChatEmotionVisual(
      key: 'helpless',
      zhLabel: '无奈',
      portraitAsset: 'assets/lingchat/deepseek/helpless.webp',
      soundAsset: 'assets/lingchat/audio/sigh.wav',
    ),
  ];

  static ChatEmotionVisual resolve(String text) {
    final value = text.trim();
    if (_contains(value, const ['喜欢', '爱你', '抱抱', '亲亲', '想你', '贴贴'])) {
      return _byKey('affection');
    }
    if (_contains(value, const ['害羞', '脸红', '不好意思', '羞', '耳鳍红'])) {
      return _byKey('shy');
    }
    if (_contains(value, const ['生气', '气鼓鼓', '不许', '哼！', '可恶', '讨厌'])) {
      return _byKey('angry');
    }
    if (_contains(value, const ['难过', '伤心', '哭', '失落', '委屈', '心疼'])) {
      return _byKey('sad');
    }
    if (_contains(value, const ['什么？', '诶？', '居然', '竟然', '吓', '惊讶', '！'])) {
      return _byKey('surprised');
    }
    if (_contains(value, const ['为什么', '怎么会', '疑惑', '不明白', '？', '?'])) {
      return _byKey('confused');
    }
    if (_contains(value, const ['担心', '小心', '还好吗', '没事吧', '别熬夜', '休息'])) {
      return _byKey('worried');
    }
    if (_contains(value, const ['认真', '首先', '结论', '需要注意', '关键是'])) {
      return _byKey('serious');
    }
    if (_contains(value, const ['无奈', '叹气', '拿你没办法', '真是的'])) {
      return _byKey('helpless');
    }
    if (_contains(value, const ['嘿嘿', '才没有', '骗你的', '逗你', '笨蛋', '哼'])) {
      return _byKey('playful');
    }
    if (_contains(value, const ['开心', '太好了', '好耶', '谢谢', '哈哈', '笑'])) {
      return _byKey('happy');
    }
    return normal;
  }

  static ChatEmotionVisual resolveEmotionKey(String key) {
    final visualKey = switch (key) {
      'excited' || 'happy' || 'confident' => 'happy',
      'disgust' || 'angry' => 'angry',
      'crying' || 'afraid' => 'sad',
      'shy' || 'embarrassed' => 'shy',
      'affection' => 'affection',
      'surprised' || 'flustered' || 'nervous' => 'surprised',
      'worried' => 'worried',
      'helpless' => 'helpless',
      'confused' => 'confused',
      'serious' => 'serious',
      'playful' => 'playful',
      _ => 'normal',
    };
    final visual = _byKey(visualKey);
    final label = EmotionCatalog.labelForKey(key);
    return label.isEmpty
        ? visual
        : ChatEmotionVisual(
            key: visual.key,
            zhLabel: label,
            portraitAsset: visual.portraitAsset,
            soundAsset: visual.soundAsset,
          );
  }

  static List<ChatVisualChunk> chunks(
    List<ChatSegment> segments, {
    String emotionKey = '',
  }) {
    if (segments.isEmpty) return const <ChatVisualChunk>[];
    final result = <ChatVisualChunk>[];
    var pending = <ChatSegment>[];
    for (final segment in segments) {
      pending.add(segment);
      if (segment.kind == ChatSegmentKind.dialogue) {
        result.add(ChatVisualChunk(
          segments: List<ChatSegment>.unmodifiable(pending),
          emotion: emotionKey.isEmpty
              ? resolve(pending.map((item) => item.text).join('\n'))
              : resolveEmotionKey(emotionKey),
        ));
        pending = <ChatSegment>[];
      }
    }
    if (pending.isNotEmpty) {
      result.add(ChatVisualChunk(
        segments: List<ChatSegment>.unmodifiable(pending),
        emotion: emotionKey.isEmpty
            ? resolve(pending.map((item) => item.text).join('\n'))
            : resolveEmotionKey(emotionKey),
      ));
    }
    return result;
  }

  static bool _contains(String text, List<String> words) =>
      words.any(text.contains);

  static ChatEmotionVisual _byKey(String key) =>
      values.firstWhere((item) => item.key == key, orElse: () => normal);
}
