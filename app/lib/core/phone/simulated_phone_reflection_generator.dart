import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../storage/secure_config.dart';

/// Presentation text only. Neither result is a new memory, emotion, or fact.
class SimulatedPhoneReflectionGenerator {
  SimulatedPhoneReflectionGenerator({
    SecureConfig? config,
    DeepSeekClient Function()? clientFactory,
  })  : _config = config ?? SecureConfig.instance,
        _clientFactory = clientFactory ?? DeepSeekClient.new;

  final SecureConfig _config;
  final DeepSeekClient Function() _clientFactory;

  Future<({String title, String body})?> mood({
    required Map<String, Object?> evidence,
    required List<String> recentBodies,
  }) async {
    final result = await _generate(
      lane: 'simulated_mood',
      instruction: '依据结构化的当日欲望、情绪和真实日常摘要，写她今天第一人称的心情短评。'
          '标题4到15字、正文20到110字，描述当下真实倾向而非永久性格。'
          '不要逐项报数、套话、自称AI，也不要补造用户行为或当天事件。'
          '如果资料只够说当前感受，就只谈感受。近期正文用于避免重复。'
          '只返回 JSON {"title":"...","body":"..."}。',
      evidence: evidence,
      recentBodies: recentBodies,
    );
    if (result == null) return null;
    final title = result['title']?.toString().trim() ?? '';
    final body = result['body']?.toString().trim() ?? '';
    if (title.length < 2 || title.length > 18 ||
        body.length < 12 || body.length > 160 || !body.contains('我')) {
      return null;
    }
    if (recentBodies.take(5).any((old) => old.trim() == body)) return null;
    return (title: title, body: body);
  }

  Future<({String self, String user})?> tarot({
    required Map<String, Object?> cards,
  }) async {
    final result = await _generate(
      lane: 'simulated_tarot',
      instruction: '给今天两张塔罗牌分别写她的第一人称短评，每条25到100字。'
          'self谈我如何理解自己的牌；user是我对“你”的牌的想法。'
          '只根据牌名、正逆位和给出的牌义与谨慎的当日状态解读。'
          '塔罗是观察角度，不是现实预言；不能声称用户做过或会做某件事。'
          '避免两张牌用相同句式、固定收尾或服务式建议。'
          '只返回 JSON {"self":"...","user":"..."}。',
      evidence: cards,
      recentBodies: const [],
    );
    if (result == null) return null;
    final self = result['self']?.toString().trim() ?? '';
    final user = result['user']?.toString().trim() ?? '';
    if (self.length < 15 || self.length > 140 ||
        user.length < 15 || user.length > 140 ||
        !self.contains('我') || !user.contains('我') || self == user) {
      return null;
    }
    return (self: self, user: user);
  }

  Future<Map<String, dynamic>?> _generate({
    required String lane,
    required String instruction,
    required Map<String, Object?> evidence,
    required List<String> recentBodies,
  }) async {
    final key = (await _config.readApiKey())?.trim() ?? '';
    if (key.isEmpty) return null;
    final client = _clientFactory();
    try {
      return await client.jsonCompletion(
        apiKey: key,
        endpoint: await _config.readEndpoint(),
        model: DeepSeekModelProfile.flash,
        thinking: false,
        maxTokens: 420,
        usageLane: lane,
        messages: [
          const {
            'role': 'system',
            'content': '你为持续存在的女性小鲸鱼写私人手机里的展示短评。'
                '真实资料是唯一事实边界；不生成记忆，不改动人格、欲望或主动聊天。只输出 JSON。',
          },
          {
            'role': 'user',
            'content': '$instruction\n资料=${jsonEncode(evidence)}\n近期正文=${jsonEncode(recentBodies.take(5).toList())}',
          },
        ],
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
