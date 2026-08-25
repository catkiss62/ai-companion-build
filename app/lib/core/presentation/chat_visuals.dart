import '../emotion/emotion_contract.dart';
import '../models/chat_segment.dart';

enum ChatPortraitAnimation {
  none,
  breathing,
  happyBounce,
  angryJump,
  seriousThink,
  heartBeat,
  naughtyBounce,
  embarrassedShake,
}

/// Presentation-only portrait choice. These labels and keys must never be
/// included in model prompts or companion self-description.
enum ChatPortraitSet {
  smallWhale,
  largeWhale,
}

extension ChatPortraitSetMetadata on ChatPortraitSet {
  String get key => switch (this) {
        ChatPortraitSet.smallWhale => 'small_whale',
        ChatPortraitSet.largeWhale => 'large_whale',
      };

  String get label => switch (this) {
        ChatPortraitSet.smallWhale => '小小鲸',
        ChatPortraitSet.largeWhale => '大肥鱼',
      };

  double get defaultScale => 1.10;

  ChatEffectAnchor get effectAnchor => switch (this) {
        // LingChat pinned source: bubble_left=20, bubble_top=5, followed by
        // GameRoleAvatar's +5/-5 offset and 25% bubble size.
        ChatPortraitSet.smallWhale => const ChatEffectAnchor(
            left: .25,
            top: 0,
            size: .25,
          ),
        // The second set uses the same 1152x2048 aligned canvas, but keeps its
        // own anchor contract so future art revisions remain isolated.
        ChatPortraitSet.largeWhale => const ChatEffectAnchor(
            left: .25,
            top: 0,
            size: .25,
          ),
      };
}

ChatPortraitSet chatPortraitSetFromKey(String? key) =>
    ChatPortraitSet.values.firstWhere(
      (value) => value.key == key,
      orElse: () => ChatPortraitSet.largeWhale,
    );

class ChatEffectAnchor {
  const ChatEffectAnchor({
    required this.left,
    required this.top,
    required this.size,
  });

  final double left;
  final double top;
  final double size;
}

class ChatEmotionVisual {
  const ChatEmotionVisual({
    required this.key,
    required this.zhLabel,
    required this.portraitAsset,
    this.effectAsset,
    this.soundAsset,
    this.animation = ChatPortraitAnimation.none,
  });

  final String key;
  final String zhLabel;
  final String portraitAsset;
  final String? effectAsset;
  final String? soundAsset;
  final ChatPortraitAnimation animation;

  String portraitAssetFor(ChatPortraitSet set) => switch (set) {
        ChatPortraitSet.smallWhale => portraitAsset,
        ChatPortraitSet.largeWhale =>
          'assets/portraits/large_whale/$key.webp',
      };
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

/// LingChat's pinned 19-expression presentation contract.
///
/// The DeepSeek envelope chooses one canonical key. This table only maps that
/// single result to portrait/effect/audio/animation assets; it never performs a
/// second emotion judgement and never replaces the persisted header label.
class ChatVisualResolver {
  const ChatVisualResolver._();

  static const normal = ChatEmotionVisual(
    key: 'normal',
    zhLabel: '正常',
    portraitAsset: 'assets/lingchat/deepseek/normal.webp',
    animation: ChatPortraitAnimation.breathing,
  );

  static const values = <ChatEmotionVisual>[
    normal,
    ChatEmotionVisual(
      key: 'disgust',
      zhLabel: '厌恶',
      portraitAsset: 'assets/lingchat/deepseek/disgust.webp',
      effectAsset: 'assets/lingchat/effects/angry.webp',
      soundAsset: 'assets/lingchat/audio/disgust.wav',
    ),
    ChatEmotionVisual(
      key: 'happy',
      zhLabel: '高兴',
      portraitAsset: 'assets/lingchat/deepseek/happy.webp',
      effectAsset: 'assets/lingchat/effects/happy.webp',
      soundAsset: 'assets/lingchat/audio/joy.wav',
      animation: ChatPortraitAnimation.happyBounce,
    ),
    ChatEmotionVisual(
      key: 'worried',
      zhLabel: '担心',
      portraitAsset: 'assets/lingchat/deepseek/worried.webp',
      effectAsset: 'assets/lingchat/effects/tears.webp',
      soundAsset: 'assets/lingchat/audio/sad.wav',
    ),
    ChatEmotionVisual(
      key: 'angry',
      zhLabel: '生气',
      portraitAsset: 'assets/lingchat/deepseek/angry.webp',
      effectAsset: 'assets/lingchat/effects/angry_alt.webp',
      soundAsset: 'assets/lingchat/audio/angry.wav',
      animation: ChatPortraitAnimation.angryJump,
    ),
    ChatEmotionVisual(
      key: 'nervous',
      zhLabel: '紧张',
      portraitAsset: 'assets/lingchat/deepseek/tense.webp',
      effectAsset: 'assets/lingchat/effects/nervous.webp',
      soundAsset: 'assets/lingchat/audio/awkward.wav',
    ),
    ChatEmotionVisual(
      key: 'afraid',
      zhLabel: '害怕',
      portraitAsset: 'assets/lingchat/deepseek/afraid.webp',
      effectAsset: 'assets/lingchat/effects/surprised.webp',
      soundAsset: 'assets/lingchat/audio/shock.wav',
    ),
    ChatEmotionVisual(
      key: 'shy',
      zhLabel: '害羞',
      portraitAsset: 'assets/lingchat/deepseek/shy.webp',
      effectAsset: 'assets/lingchat/effects/shy.webp',
      soundAsset: 'assets/lingchat/audio/shy.wav',
    ),
    ChatEmotionVisual(
      key: 'flustered',
      zhLabel: '慌张',
      portraitAsset: 'assets/lingchat/deepseek/flustered.webp',
      effectAsset: 'assets/lingchat/effects/flustered.webp',
      soundAsset: 'assets/lingchat/audio/shock.wav',
    ),
    ChatEmotionVisual(
      key: 'serious',
      zhLabel: '认真',
      portraitAsset: 'assets/lingchat/deepseek/serious.webp',
      animation: ChatPortraitAnimation.seriousThink,
    ),
    ChatEmotionVisual(
      key: 'helpless',
      zhLabel: '无奈',
      portraitAsset: 'assets/lingchat/deepseek/helpless.webp',
      effectAsset: 'assets/lingchat/effects/sigh.webp',
      soundAsset: 'assets/lingchat/audio/sigh.wav',
    ),
    ChatEmotionVisual(
      key: 'excited',
      zhLabel: '兴奋',
      portraitAsset: 'assets/lingchat/deepseek/excited.webp',
      effectAsset: 'assets/lingchat/effects/dialogue.webp',
      soundAsset: 'assets/lingchat/audio/chat.wav',
      animation: ChatPortraitAnimation.happyBounce,
    ),
    ChatEmotionVisual(
      key: 'confused',
      zhLabel: '疑惑',
      portraitAsset: 'assets/lingchat/deepseek/confused.webp',
      effectAsset: 'assets/lingchat/effects/question.webp',
      soundAsset: 'assets/lingchat/audio/question.wav',
    ),
    ChatEmotionVisual(
      key: 'crying',
      zhLabel: '伤心',
      portraitAsset: 'assets/lingchat/deepseek/sad.webp',
      effectAsset: 'assets/lingchat/effects/tears.webp',
      soundAsset: 'assets/lingchat/audio/sad.wav',
    ),
    ChatEmotionVisual(
      key: 'affection',
      zhLabel: '心动',
      portraitAsset: 'assets/lingchat/deepseek/affection.webp',
      effectAsset: 'assets/lingchat/effects/heart.webp',
      soundAsset: 'assets/lingchat/audio/affection.wav',
      animation: ChatPortraitAnimation.heartBeat,
    ),
    ChatEmotionVisual(
      key: 'playful',
      zhLabel: '调皮',
      portraitAsset: 'assets/lingchat/deepseek/playful.webp',
      effectAsset: 'assets/lingchat/effects/happy.webp',
      soundAsset: 'assets/lingchat/audio/pleasant.wav',
      animation: ChatPortraitAnimation.naughtyBounce,
    ),
    ChatEmotionVisual(
      key: 'embarrassed',
      zhLabel: '难为情',
      portraitAsset: 'assets/lingchat/deepseek/ashamed.webp',
      effectAsset: 'assets/lingchat/effects/embarrassed.webp',
      soundAsset: 'assets/lingchat/audio/noticed.wav',
      animation: ChatPortraitAnimation.embarrassedShake,
    ),
    ChatEmotionVisual(
      key: 'confident',
      zhLabel: '自信',
      portraitAsset: 'assets/lingchat/deepseek/confident.webp',
      effectAsset: 'assets/lingchat/effects/happy.webp',
      soundAsset: 'assets/lingchat/audio/pleasant.wav',
    ),
    ChatEmotionVisual(
      key: 'surprised',
      zhLabel: '惊讶',
      portraitAsset: 'assets/lingchat/deepseek/surprised.webp',
      effectAsset: 'assets/lingchat/effects/surprised.webp',
      soundAsset: 'assets/lingchat/audio/noticed.wav',
    ),
    ChatEmotionVisual(
      key: 'calm',
      zhLabel: '平静',
      portraitAsset: 'assets/lingchat/deepseek/calm.webp',
      animation: ChatPortraitAnimation.breathing,
    ),
  ];

  static ChatEmotionVisual resolve(String text) {
    final value = text.trim();
    if (_contains(value, const ['兴奋', '迫不及待', '太棒了', '冲呀'])) {
      return _byKey('excited');
    }
    if (_contains(value, const ['喜欢', '爱你', '抱抱', '亲亲', '想你', '贴贴', '心动'])) {
      return _byKey('affection');
    }
    if (_contains(value, const ['难为情', '尴尬', '羞耻', '窘'])) {
      return _byKey('embarrassed');
    }
    if (_contains(value, const ['害羞', '脸红', '不好意思', '耳鳍红'])) {
      return _byKey('shy');
    }
    if (_contains(value, const ['厌恶', '恶心', '反感'])) {
      return _byKey('disgust');
    }
    if (_contains(value, const ['生气', '气鼓鼓', '不许', '可恶', '讨厌'])) {
      return _byKey('angry');
    }
    if (_contains(value, const ['伤心', '哭', '失落', '委屈', '心疼'])) {
      return _byKey('crying');
    }
    if (_contains(value, const ['害怕', '吓到', '恐怕'])) {
      return _byKey('afraid');
    }
    if (_contains(value, const ['慌张', '慌了', '手忙脚乱'])) {
      return _byKey('flustered');
    }
    if (_contains(value, const ['紧张', '忐忑', '不安'])) {
      return _byKey('nervous');
    }
    if (_contains(value, const ['什么？', '诶？', '居然', '竟然', '惊讶', '！'])) {
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
    if (_contains(value, const ['无奈', '无语', '叹气', '拿你没办法', '真是的'])) {
      return _byKey('helpless');
    }
    if (_contains(value, const ['嘿嘿', '才没有', '骗你的', '逗你', '笨蛋', '哼'])) {
      return _byKey('playful');
    }
    if (_contains(value, const ['自信', '交给我', '当然能'])) {
      return _byKey('confident');
    }
    if (_contains(value, const ['开心', '高兴', '好耶', '谢谢', '哈哈', '笑'])) {
      return _byKey('happy');
    }
    return normal;
  }

  static ChatEmotionVisual resolveEmotionKey(String key) {
    final normalized = key.trim().toLowerCase();
    final canonical = switch (normalized) {
      'sad' => 'crying',
      'ashamed' => 'embarrassed',
      'tense' => 'nervous',
      'heart' || 'love' => 'affection',
      _ => EmotionCatalog.labelsByKey.containsKey(normalized)
          ? normalized
          : 'normal',
    };
    return _byKey(canonical);
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
