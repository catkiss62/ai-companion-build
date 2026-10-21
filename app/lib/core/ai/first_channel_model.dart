import '../database/app_database.dart';
import 'model_profile.dart';

/// Resolve at the business boundary; explicit work/room/job models stay intact.
abstract final class FirstChannelModel {
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
