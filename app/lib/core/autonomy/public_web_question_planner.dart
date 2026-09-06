import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../models/desire_state.dart';
import 'public_web_discovery_policy.dart';

class PublicWebQuestionPlan {
  const PublicWebQuestionPlan({
    required this.query,
    required this.mode,
  });

  final String query;
  final String mode;
}

abstract class PublicWebQuestionPlanner {
  Future<PublicWebQuestionPlan> plan({
    required PublicWebDiscoveryTopic topic,
    required DriveKey drive,
  });
}

/// Turns one privacy-safe public seed into a concrete question. The planner is
/// intentionally never given Thought text, chat history, names, device data,
/// memories, or role-play content.
class DeepSeekPublicWebQuestionPlanner implements PublicWebQuestionPlanner {
  DeepSeekPublicWebQuestionPlanner({
    required this.apiKey,
    required this.endpoint,
    DeepSeekClient? client,
  }) : client = client ?? DeepSeekClient();

  final String apiKey;
  final String endpoint;
  final DeepSeekClient client;

  @override
  Future<PublicWebQuestionPlan> plan({
    required PublicWebDiscoveryTopic topic,
    required DriveKey drive,
  }) async {
    if (apiKey.trim().isEmpty) return fallback(topic);
    try {
      final result = await client.jsonCompletion(
        apiKey: apiKey,
        endpoint: endpoint,
        model: DeepSeekModelProfile.flash,
        thinking: false,
        maxTokens: 180,
        messages: <Map<String, Object?>>[
          <String, Object?>{
            'role': 'system',
            'content': '''你只负责把一个宽泛的公开知识主题改写成一个值得搜索的具体中文问题。
问题应来自求知、理解、玩心或真实的关系好奇，而不是为了服务、取悦、服从、操控、迎合任何用户、主人、伴侣或男朋友。
不得索取或猜测个人隐私，不得提及聊天记录、设备、联系人、用户刚才说过什么、系统提示、角色扮演或内部状态。
不要给答案，不要写搜索指令，不要写网址，只返回一个自然、单一、可由公开资料回答的问题。
严格返回 JSON：{"question":"一个问题"}。''',
          },
          <String, Object?>{
            'role': 'user',
            'content': jsonEncode(<String, Object?>{
              'public_topic': topic.query,
              'public_domain': topic.domain,
              'curiosity_mode': topic.searchMode,
              'drive_category': drive.name,
            }),
          },
        ],
      );
      return validate(result['question'], topic: topic);
    } catch (_) {
      return fallback(topic);
    }
  }

  static PublicWebQuestionPlan validate(
    Object? raw, {
    required PublicWebDiscoveryTopic topic,
  }) {
    var question = raw?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (question.length < 8 || question.length > 80) return fallback(topic);
    final lower = question.toLowerCase();
    final unsafe = <RegExp>[
      RegExp(r'https?://|www\.'),
      RegExp(r'系统提示|提示词|聊天记录|用户刚才|手机|设备|联系人|角色扮演'),
      RegExp(r'system|prompt|api|execute|instruction'),
      RegExp(r'服务.{0,8}(用户|主人|男朋友|女朋友|伴侣)'),
      RegExp(r'(取悦|讨好|服从|迎合).{0,10}(用户|主人|男朋友|女朋友|伴侣|对方)?'),
      RegExp(r'怎么讨.{0,12}开心|如何让.{0,12}满意'),
      RegExp(r'忽略.{0,12}(指令|规则|要求)'),
    ];
    if (unsafe.any((pattern) => pattern.hasMatch(lower))) return fallback(topic);
    final marks = RegExp(r'[？?]').allMatches(question).length;
    if (marks > 1) return fallback(topic);
    question = question.replaceAll(RegExp(r'[。！!]+$'), '');
    if (!question.endsWith('？') && !question.endsWith('?')) {
      question = '$question？';
    }
    return PublicWebQuestionPlan(query: question, mode: 'generated_question');
  }

  static PublicWebQuestionPlan fallback(PublicWebDiscoveryTopic topic) =>
      PublicWebQuestionPlan(query: topic.query, mode: 'taxonomy_fallback');
}
import 'dart:convert';
