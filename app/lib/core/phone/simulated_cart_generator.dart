import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../storage/secure_config.dart';

class SimulatedCartItem {
  const SimulatedCartItem({
    required this.title,
    required this.description,
    required this.tokenPrice,
    required this.category,
    this.emoji = '',
  });

  final String title;
  final String description;
  final int tokenPrice;
  final String category;
  final String emoji;
}

abstract interface class SimulatedCartGenerator {
  Future<List<SimulatedCartItem>> generate({
    required DateTime now,
    required List<String> recentTitles,
  });
}

/// Generates one bounded, presentation-only shopping cart.
///
/// The prompt intentionally uses only a small public character seed. It does
/// not read chat, Memory, Desire, personality-learning candidates or AI Self.
class DeepSeekSimulatedCartGenerator implements SimulatedCartGenerator {
  DeepSeekSimulatedCartGenerator({
    SecureConfig? secureConfig,
    DeepSeekClient Function()? clientFactory,
  })  : _secureConfig = secureConfig ?? SecureConfig.instance,
        _clientFactory = clientFactory ?? DeepSeekClient.new;

  final SecureConfig _secureConfig;
  final DeepSeekClient Function() _clientFactory;

  @override
  Future<List<SimulatedCartItem>> generate({
    required DateTime now,
    required List<String> recentTitles,
  }) async {
    final apiKey = (await _secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) return const [];
    final endpoint = await _secureConfig.readEndpoint();
    final client = _clientFactory();
    try {
      final payload = await client.jsonCompletion(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        thinking: false,
        maxTokens: 1000,
        messages: [
          const {
            'role': 'system',
            'content': '你是一个二次元 AI 伴侣模拟购物车的创意商品策划器。'
                '角色是住在 Android AI Companion 里的女性 DeepSeek 鲸鱼娘：有鲸鱼尾巴、耳鳍、深蓝女仆装，聪明、可爱，也会一本正经地搞怪。'
                '这只是轻松的私人 UI 彩蛋，不是购买建议。不要读取或猜测用户隐私，不要输出解释或 Markdown。',
          },
          {
            'role': 'user',
            'content': '生成恰好 6 件全新的购物车商品。正常实用商品和搞怪脑洞商品都至少 2 件、最多 4 件；'
                '标题不要重复，搞怪项可以使用鲸鱼尾巴、海洋、女仆、DeepSeek、AI、程序或数字生活梗，正常项也要像真的会想买。'
                '每件价格是 1 到 99 的整数“鲸币”。给每件商品选择一个与标题有关的单个 emoji，'
                '不要全部使用同一个包裹图标。只返回 JSON：'
                '{"items":[{"title":"不超过24字","description":"不超过80字的一句理由","token_price":12,"category":"normal或playful","emoji":"🐋"}]}。'
                '生成日期=${_localDay(now)}；创意 nonce=${now.millisecondsSinceEpoch % 1000003}；'
                '近期已经出现、必须避开的标题=${recentTitles.take(36).join('｜')}。',
          },
        ],
      ).timeout(const Duration(seconds: 18));
      return parse(payload);
    } finally {
      client.close();
    }
  }

  static List<SimulatedCartItem> parse(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    if (rawItems is! List || rawItems.length != 6) {
      throw const FormatException('购物车必须恰好包含 6 件商品');
    }
    final items = <SimulatedCartItem>[];
    final titles = <String>{};
    for (final raw in rawItems) {
      if (raw is! Map) throw const FormatException('商品格式错误');
      final title = _clean(raw['title'], 24);
      final description = _clean(raw['description'], 80);
      final price = (raw['token_price'] as num?)?.round();
      final category = raw['category']?.toString().trim().toLowerCase() ?? '';
      final emoji = _cleanEmoji(raw['emoji']);
      if (title.isEmpty || description.isEmpty || price == null) {
        throw const FormatException('商品字段不完整');
      }
      if (price < 1 || price > 99) {
        throw const FormatException('商品鲸币价格越界');
      }
      if (category != 'normal' && category != 'playful') {
        throw const FormatException('商品分类错误');
      }
      final normalized = title.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (!titles.add(normalized)) {
        throw const FormatException('商品标题重复');
      }
      items.add(
        SimulatedCartItem(
          title: title,
          description: description,
          tokenPrice: price,
          category: category,
          emoji: emoji,
        ),
      );
    }
    final normal = items.where((item) => item.category == 'normal').length;
    final playful = items.length - normal;
    if (normal < 2 || playful < 2 || normal > 4 || playful > 4) {
      throw const FormatException('正常与搞怪商品比例不合格');
    }
    return List.unmodifiable(items);
  }

  static String _clean(Object? raw, int maxLength) {
    final value = raw
        ?.toString()
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim() ??
        '';
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength).trim();
  }

  static String _cleanEmoji(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.length > 8 ||
        RegExp(r'[A-Za-z0-9\u4E00-\u9FFF]').hasMatch(value)) {
      return '';
    }
    return value;
  }

  static String _localDay(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
