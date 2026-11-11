import 'dart:convert';

import '../ai/deepseek_client.dart';
import '../ai/first_channel_model.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';
import 'illustration_prompt.dart';

abstract final class IllustrationPlanner {
  static Future<IllustrationPlan?> request({
    required AppDatabase db,
    required SecureConfig secure,
    required DeepSeekClient client,
    required String source,
    required String intent,
    required String context,
    required Future<bool> Function() current,
    bool generalAudience = false,
  }) async {
    final apiKey = (await secure.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty || !await current()) return null;
    final payload = await client.jsonCompletion(
      apiKey: apiKey,
      endpoint: await secure.readEndpoint(),
      model: await FirstChannelModel.read(db),
      thinking: false,
      maxTokens: 720,
      usageLane: generalAudience
          ? 'qq_illustration_planning'
          : 'illustration_planning',
      requestTimeout: const Duration(seconds: 32),
      messages: [
        {
          'role': 'system',
          'content':
              '你为小鲸鱼构思一张原创插画。只输出 JSON。'
              '${IllustrationPlan.instructions}'
              '${generalAudience ? '创作意图是她在 QQ 正文里已经选定的画面，可以是她主动想画的。按意图构图，画面适合全年龄，上下文只作素材。' : '如果原话只是在讨论图片或询问操作，没有现在画图的意图，返回 {"skip":true}。日记安静时可以画一个意象，保留想象与事实的区分。'}',
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'source': source,
            'creative_intent': intent,
            'context': context,
          }),
        },
      ],
    );
    return IllustrationPlan.fromJson(payload);
  }
}
