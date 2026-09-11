import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../storage/secure_config.dart';

class SimulatedNoteMaterial {
  const SimulatedNoteMaterial({
    required this.localDay,
    required this.items,
  });

  final String localDay;
  final List<String> items;

  Map<String, Object?> toPromptJson() => {
        'local_day': localDay,
        'grounded_items': items,
      };
}

class SimulatedNoteDraft {
  const SimulatedNoteDraft({required this.title, required this.body});

  final String title;
  final String body;
}

abstract interface class SimulatedNoteGenerator {
  Future<SimulatedNoteDraft?> generate({
    required SimulatedNoteMaterial material,
    required List<String> recentBodies,
  });
}

class SimulatedNoteQuality {
  const SimulatedNoteQuality._();

  static bool acceptable(
    SimulatedNoteDraft draft, {
    required List<String> recentBodies,
  }) {
    final title = draft.title.trim();
    final body = draft.body.trim();
    if (title.isEmpty || title.length > 18 || body.length < 12 || body.length > 180) {
      return false;
    }
    const boilerplate = {'根据以上资料', '作为一个AI', '作为AI', '随手记一下'};
    if (boilerplate.any(body.contains)) return false;
    return recentBodies.take(10).every(
          (recent) => _similarity(body, recent) < 0.72,
        );
  }

  static double _similarity(String left, String right) {
    Set<String> bigrams(String value) {
      final normalized = value
          .toLowerCase()
          .replaceAll(RegExp(r'[\s，。！？；：、…“”「」【】（）()\-—_]+'), '');
      if (normalized.length < 2) {
        return normalized.isEmpty ? const {} : {normalized};
      }
      return {
        for (var i = 0; i < normalized.length - 1; i++)
          normalized.substring(i, i + 2),
      };
    }

    final a = bigrams(left);
    final b = bigrams(right);
    if (a.isEmpty || b.isEmpty) return 0;
    final union = <String>{...a, ...b};
    return a.intersection(b).length / union.length;
  }
}

class DeepSeekSimulatedNoteGenerator implements SimulatedNoteGenerator {
  DeepSeekSimulatedNoteGenerator({
    SecureConfig? secureConfig,
    DeepSeekClient Function()? clientFactory,
  })  : _secureConfig = secureConfig ?? SecureConfig.instance,
        _clientFactory = clientFactory ?? DeepSeekClient.new;

  final SecureConfig _secureConfig;
  final DeepSeekClient Function() _clientFactory;

  @override
  Future<SimulatedNoteDraft?> generate({
    required SimulatedNoteMaterial material,
    required List<String> recentBodies,
  }) async {
    final apiKey = (await _secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty || material.items.isEmpty) return null;
    final client = _clientFactory();
    try {
      final payload = await client.jsonCompletion(
        apiKey: apiKey,
        endpoint: await _secureConfig.readEndpoint(),
        model: DeepSeekModelProfile.flash,
        thinking: false,
        maxTokens: 360,
        messages: [
          const {
            'role': 'system',
            'content': '你为 Android AI Companion 中持续存在的女性小鲸鱼写一条私人随笔。'
                '只能使用给出的真实派生资料，不得补造用户说过的话或现实经历。'
                '随笔只是随机展示层，不是新的记忆、人格结论或学习证据。只输出 JSON。',
          },
          {
            'role': 'user',
            'content': '从这一天的资料里自由挑一个真实细节或心绪，写成自然、不套模板的第一人称短随笔。'
                '正文 12 到 120 个中文字符；标题 2 到 10 个中文字符。避开近期随笔的开头、句式和中心。'
                '不要解释资料来源，不要使用“根据资料”“作为AI”“随手记一下”等元话术。'
                '只返回 {"title":"标题","body":"正文"}。\n'
                '随机选中的日期资料=${jsonEncode(material.toPromptJson())}\n'
                '近期随笔=${jsonEncode(recentBodies.take(10).toList())}',
          },
        ],
      ).timeout(const Duration(seconds: 18));
      final draft = SimulatedNoteDraft(
        title: payload['title']?.toString().trim() ?? '',
        body: payload['body']?.toString().trim() ?? '',
      );
      return SimulatedNoteQuality.acceptable(
        draft,
        recentBodies: recentBodies,
      )
          ? draft
          : null;
    } finally {
      client.close();
    }
  }
}
