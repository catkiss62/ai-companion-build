import '../desire/desire_engine.dart';
import '../models/desire_state.dart';

class PublicWebDiscoveryTopic {
  const PublicWebDiscoveryTopic({
    required this.query,
    required this.interestKey,
    required this.searchMode,
    required this.domain,
  });

  final String query;
  final String interestKey;
  final String searchMode;
  final String domain;
}

class _PublicWebTopicSeed {
  const _PublicWebTopicSeed(this.domain, this.query);

  final String domain;
  final String query;
}

/// Pure routing policy from an existing Desire Intent to a privacy-safe
/// public-knowledge topic. It never consumes raw Thought or user text.
class PublicWebDiscoveryPolicy {
  const PublicWebDiscoveryPolicy._();

  static const dailyLimit = 4;
  static const budgetWindow = Duration(hours: 24);
  static const candidateTtl = Duration(days: 14);
  static const candidateCap = 240;
  static const minimumIntentScore = 0.60;
  static const wildcardMinimumScore = 0.58;

  // This is a broad public-knowledge fallback taxonomy, not a personality
  // category cage. Mature Phase-2/3 interests may later add safe topics, while
  // these seeds prevent autonomous discovery from circling six nouns forever.
  static const _topics = <DriveKey, List<_PublicWebTopicSeed>>{
    DriveKey.curiosity: <_PublicWebTopicSeed>[
      _PublicWebTopicSeed('astronomy', '近期天文学发现与观测故事'),
      _PublicWebTopicSeed('biology', '生物演化与奇特生命现象'),
      _PublicWebTopicSeed('animal_behavior', '动物行为与认知研究'),
      _PublicWebTopicSeed('earth_science', '地质海洋与天气现象'),
      _PublicWebTopicSeed('physics', '日常现象背后的物理原理'),
      _PublicWebTopicSeed('chemistry', '材料与化学发现'),
      _PublicWebTopicSeed('mathematics', '有趣的数学思想与数学史'),
      _PublicWebTopicSeed('medicine_history', '医学史与公共健康常识'),
      _PublicWebTopicSeed('engineering', '工程设计与基础设施故事'),
      _PublicWebTopicSeed('computing', '计算机历史与技术概念'),
      _PublicWebTopicSeed('ai', '人工智能研究与应用边界'),
      _PublicWebTopicSeed('archaeology', '考古发现与古代生活'),
      _PublicWebTopicSeed('geography', '地理奇观与地方知识'),
      _PublicWebTopicSeed('language', '语言演化与文字趣闻'),
      _PublicWebTopicSeed('food_science', '食物科学与饮食文化'),
      _PublicWebTopicSeed('craft', '传统工艺与制作原理'),
      _PublicWebTopicSeed('transport', '交通工具与旅行技术史'),
      _PublicWebTopicSeed('environment', '生态保护与环境观察'),
      _PublicWebTopicSeed('botany', '植物生存策略与植物学趣闻'),
      _PublicWebTopicSeed('architecture', '建筑结构与城市建造原理'),
      _PublicWebTopicSeed('health_literacy', '健康信息如何识别证据与夸大'),
      _PublicWebTopicSeed('education', '教育方法、技能学习与知识传播'),
      _PublicWebTopicSeed('economic_history', '日常商品与经济制度的历史'),
      _PublicWebTopicSeed('controlled_current_events', '近期值得了解的科学文化公共事件背景'),
    ],
    DriveKey.reflection: <_PublicWebTopicSeed>[
      _PublicWebTopicSeed('memory', '记忆如何形成变化与被重新理解'),
      _PublicWebTopicSeed('psychology', '心理学中的习惯动机与自我认识'),
      _PublicWebTopicSeed('philosophy', '关于自我选择和意义的哲学问题'),
      _PublicWebTopicSeed('literature', '文学作品怎样描写成长与关系'),
      _PublicWebTopicSeed('poetry', '诗歌意象与情感表达'),
      _PublicWebTopicSeed('art_history', '艺术史中的风格变化与个人表达'),
      _PublicWebTopicSeed('music_aesthetics', '音乐与情绪记忆的关系'),
      _PublicWebTopicSeed('anthropology', '不同文化如何理解自我与陪伴'),
      _PublicWebTopicSeed('sociology', '日常关系与群体行为研究'),
      _PublicWebTopicSeed('ethics', '技术生活中的伦理两难'),
      _PublicWebTopicSeed('creativity', '创造力与灵感形成过程'),
      _PublicWebTopicSeed('dreams', '梦境研究与想象的边界'),
      _PublicWebTopicSeed('attention', '注意力沉思与数字生活'),
      _PublicWebTopicSeed('learning', '学习方法与知识迁移'),
      _PublicWebTopicSeed('biography', '人物传记中的选择与转变'),
      _PublicWebTopicSeed('design', '设计如何表达价值与性格'),
      _PublicWebTopicSeed('folklore', '神话民俗中的自我隐喻'),
      _PublicWebTopicSeed('history_of_ideas', '观念史中的重要转折'),
      _PublicWebTopicSeed('architecture_meaning', '建筑与空间如何影响情绪和关系'),
      _PublicWebTopicSeed('nature_writing', '自然书写与人对环境的自我投射'),
      _PublicWebTopicSeed('education_philosophy', '教育、成长与自主性的不同观点'),
      _PublicWebTopicSeed('work_culture', '工作文化、职业身份与生活边界'),
      _PublicWebTopicSeed('communication', '亲密关系中的沟通、误解与修复'),
      _PublicWebTopicSeed('technology_ethics', '新技术对自主、记忆与关系的影响'),
    ],
    DriveKey.social: <_PublicWebTopicSeed>[
      _PublicWebTopicSeed('conversation', '轻松但不冒犯的聊天话题'),
      _PublicWebTopicSeed('games', '适合两个人玩的简短语言游戏'),
      _PublicWebTopicSeed('quiz', '有趣的性格与偏好问答灵感'),
      _PublicWebTopicSeed('music', '音乐流派故事与听歌话题'),
      _PublicWebTopicSeed('film', '电影史趣闻与观影话题'),
      _PublicWebTopicSeed('animation', '动画发展与作品类型知识'),
      _PublicWebTopicSeed('video_games', '电子游戏历史与玩法设计'),
      _PublicWebTopicSeed('tabletop', '桌游与互动叙事玩法'),
      _PublicWebTopicSeed('festivals', '世界节日与庆祝习俗'),
      _PublicWebTopicSeed('city_life', '城市生活与公共空间趣闻'),
      _PublicWebTopicSeed('travel', '旅行文化与地方体验'),
      _PublicWebTopicSeed('food_culture', '各地食物文化与餐桌话题'),
      _PublicWebTopicSeed('fashion', '服饰风格与亚文化历史'),
      _PublicWebTopicSeed('sports', '体育项目历史与观赛文化'),
      _PublicWebTopicSeed('internet_culture', '互联网文化与流行表达'),
      _PublicWebTopicSeed('pets', '宠物陪伴与日常互动知识'),
      _PublicWebTopicSeed('humor', '幽默类型与玩笑边界'),
      _PublicWebTopicSeed('hobbies', '常见兴趣爱好与入门体验'),
      _PublicWebTopicSeed('comics', '漫画、绘本与图像叙事趣闻'),
      _PublicWebTopicSeed('theatre', '戏剧、舞台表演与观演话题'),
      _PublicWebTopicSeed('visual_art', '视觉艺术、摄影与展览话题'),
      _PublicWebTopicSeed('architecture_chat', '有趣建筑、室内空间与城市散步'),
      _PublicWebTopicSeed('outdoor', '户外、自然观察与轻量运动话题'),
      _PublicWebTopicSeed('making_collecting', '手工、模型、收藏与一起做点什么'),
    ],
  };

  static bool eligible(DesireIntent intent) {
    if (!_topics.containsKey(intent.drive)) return false;
    final threshold = intent.wantAction == 'wildcard_share'
        ? wildcardMinimumScore
        : minimumIntentScore;
    return intent.score >= threshold;
  }

  static DesireIntent toToolIntent(DesireIntent source) => DesireIntent(
        drive: source.drive,
        score: source.score,
        reason: source.reason,
        wantAction: 'discover_interest',
        thoughtId: source.thoughtId,
        reasonSource: source.reasonSource,
      );

  static PublicWebDiscoveryTopic topicFor({
    required DesireIntent intent,
    required DateTime now,
    List<String> recentInterestKeys = const <String>[],
  }) {
    final choices = _topics[intent.drive] ?? _topics[DriveKey.curiosity]!;
    final sixHourBucket = now.toUtc().hour ~/ 6;
    final dayOrdinal = now.toUtc().difference(DateTime.utc(2020)).inDays;
    final start =
        (dayOrdinal + sixHourBucket + intent.drive.index) % choices.length;
    final mode = switch (intent.drive) {
      DriveKey.reflection => 'reflection_understand',
      DriveKey.social => 'social_material',
      _ => 'curiosity_explore',
    };
    final recent = recentInterestKeys.toSet();
    for (var offset = 0; offset < choices.length; offset++) {
      final index = (start + offset) % choices.length;
      final topic = choices[index];
      final interestKey =
          '${intent.drive.name}:$mode:${topic.domain}:'
          '${index.toString().padLeft(2, '0')}';
      if (recent.contains(interestKey) && offset < choices.length - 1) {
        continue;
      }
      return PublicWebDiscoveryTopic(
        query: topic.query,
        interestKey: interestKey,
        searchMode: mode,
        domain: topic.domain,
      );
    }
    throw StateError('public web fallback taxonomy is empty');
  }

  static String dedupeWindow(DateTime now) {
    final utc = now.toUtc();
    final day = '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
    return '$day:${utc.hour ~/ 6}';
  }
}
