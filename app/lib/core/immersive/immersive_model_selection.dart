import '../ai/chat_api_provider.dart';
import '../ai/first_channel_model.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';

enum ImmersiveModelSource {
  first('first', '第一通道'), second('second', '第二通道'), work('work', '作品模型');
  const ImmersiveModelSource(this.key, this.label);
  final String key, label;
}

/// Credentials stay in this transient object, never in the saved selection.
class ImmersiveModelChoice {
  const ImmersiveModelChoice({required this.source, required this.model,
    required this.apiKey, required this.endpoint, required this.effort});
  final ImmersiveModelSource source;
  final String model, apiKey, endpoint;
  final ReasoningEffort effort;
  ChatApiProvider get provider => source == ImmersiveModelSource.second
      ? ChatApiProvider.aiWangYouGemini : ChatApiProvider.deepSeek;
}

abstract final class ImmersiveModelSelection {
  static const settingKey = 'immersive_model_source_v1';

  static Future<List<ImmersiveModelChoice>> options(AppDatabase db,
      {SecureConfig? secureConfig}) async {
    final secure = secureConfig ?? SecureConfig.instance;
    final firstKey = (await secure.readDeepSeekApiKey())?.trim() ?? '';
    final secondKey = (await secure.readAiWangYouApiKey())?.trim() ?? '';
    final raw = await secure.readPortableSettings();
    final secondModel = raw['aiwangyou_final_reply_model']?.trim() ?? '';
    final workModel = (await db.getSetting('creative_work_model'))?.trim() ?? '';
    final firstModel = await FirstChannelModel.read(db);
    final effort = ReasoningEffort.fromApiName(await db.getSetting('reasoning_effort'));
    final firstEndpoint = await secure.readDeepSeekEndpoint();
    return [
      if (firstKey.isNotEmpty) ImmersiveModelChoice(source: ImmersiveModelSource.first,
        model: firstModel.apiName, apiKey: firstKey, endpoint: firstEndpoint, effort: effort),
      if (secondKey.isNotEmpty && secondModel.isNotEmpty)
        ImmersiveModelChoice(source: ImmersiveModelSource.second, model: secondModel,
          apiKey: secondKey, endpoint: await secure.readAiWangYouEndpoint(), effort: effort),
      if (firstKey.isNotEmpty && workModel.isNotEmpty && workModel != '__custom__')
        ImmersiveModelChoice(source: ImmersiveModelSource.work, model: workModel,
          apiKey: firstKey, endpoint: firstEndpoint,
          effort: ReasoningEffort.fromApiName(await db.getSetting('creative_work_effort'))),
    ];
  }

  static Future<ImmersiveModelChoice> resolve(AppDatabase db,
      {SecureConfig? secureConfig}) async {
    final choices = await options(db, secureConfig: secureConfig);
    final source = await db.getSetting(settingKey) ?? ImmersiveModelSource.first.key;
    for (final choice in choices) {
      if (choice.source.key == source) return choice;
    }
    throw const FormatException('所选沉浸模型尚未配置，请在沉浸房间首页重新选择或补全模型设置。');
  }
}
