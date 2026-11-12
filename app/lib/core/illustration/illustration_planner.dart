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
      usageLane: source == 'creative_work' ? 'creative_illustration_planning' : generalAudience
          ? 'qq_illustration_planning'
          : 'illustration_planning',
      requestTimeout: const Duration(seconds: 32),
      messages: [
        {
          'role': 'system',
          'content':
              '你为小鲸鱼构思一张原创插画。只输出 JSON。'
              '${IllustrationPlan.instructions}'
              '构图以创作意图为主。当前用户明确指定的画风优先于意图里的概括或更早的聊天。'
              '${source == 'creative_work' ? '创作意图用于作品配图。按请求的构图提供完整画面，适合全年龄。' : generalAudience ? '创作意图来自她的 QQ 回复或当前明确的绘图请求，也可以是她主动想画的。画面适合全年龄。' : '如果原话只是在讨论图片或询问操作，没有现在画图的意图，返回 {"skip":true}。日记安静时可以画一个意象，保留想象与事实的区分。'}',
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
