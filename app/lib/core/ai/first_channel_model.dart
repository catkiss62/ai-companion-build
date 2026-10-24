import 'chat_api_provider.dart';
import '../database/app_database.dart';
import 'model_profile.dart';

/// Resolve at the business boundary; explicit work/room/job models stay intact.
abstract final class FirstChannelModel {
  static Future<ReasoningEffort> readEffort(AppDatabase db) async =>
      ChatApiProvider.deepSeek.normalizeEffort(ReasoningEffort.fromApiName(
        await db.getSetting('deepseek_reasoning_effort') ?? await db.getSetting('reasoning_effort')));

  static Future<DeepSeekModelProfile> read(AppDatabase db) async {
    final primary = (await db.getSetting('deepseek_model'))?.trim() ?? '';
    final legacy = (await db.getSetting('model'))?.trim() ?? '';
    return DeepSeekModelProfile.fromApiName(
      primary.isNotEmpty && primary != DeepSeekModelProfile.custom.apiName
          ? primary : legacy,
    );
  }

  static Future<DeepSeekModelProfile> work(AppDatabase db) async {
    final value = (await db.getSetting('creative_work_model'))?.trim() ?? '';
    return value.isEmpty || value == DeepSeekModelProfile.custom.apiName
        ? read(db) : DeepSeekModelProfile.fromApiName(value);
  }
}
