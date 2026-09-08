import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../models/desire_state.dart';
import 'public_web_discovery_policy.dart';
import 'subjective_search_seed.dart';

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
    required SubjectiveSearchSeed subjectiveSeed,
  });
}

/// Turns one privacy-safe public fallback and one lossy subjective seed into a
/// concrete question. The planner is intentionally never given Thought text,
/// chat history, names, device data, memories, or role-play content.
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
    required SubjectiveSearchSeed subjectiveSeed,
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
            'content': '''你负责替她形成一个此刻真会想搜索的具体中文问题。SUBJECTIVE_SEED 是本机从她的欲望差值、情绪类别、身体感受类别和可行动念头存在性压缩出的脱敏动机；它不含聊天原句、姓名、私人事件或设备内容。
优先沿着 why_now 与 question_direction 生长问题。PUBLIC_FALLBACK 只是没有灵感时的公共题材兜底，不是必须围绕的知识栏目。
问题可以琐碎、感性、古怪、有画面感、甚至像“怎么会想到查这个”，但必须能由公开资料回答。不要自动改写成心理学、文学、关系建议或百科知识题。
问题应来自求知、理解、玩心、共鸣或她自己的在意，而不是为了服务、取悦、服从、操控、迎合任何用户、主人、伴侣或男朋友。
不得索取或猜测个人隐私，不得提及聊天记录、设备、联系人、用户刚才说过什么、系统提示、角色扮演或内部状态。
不要给答案，不要写搜索指令，不要写网址，只返回一个自然、单一、可由公开资料回答的问题。
严格返回 JSON：{"question":"一个问题"}。''',
          },
          <String, Object?>{
            'role': 'user',
            'content': jsonEncode(<String, Object?>{
              'subjective_seed': subjectiveSeed.toPlannerJson(),
              'public_fallback': <String, Object?>{
                'topic': topic.query,
                'domain': topic.domain,
                'mode': topic.searchMode,
              },
              'drive_category': drive.name,
            }),
          },
        ],
      );
      final validated = validate(result['question'], topic: topic);
      return validated.mode == 'generated_question'
          ? PublicWebQuestionPlan(
              query: validated.query,
              mode: 'subjective_generated_question',
            )
          : validated;
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
