import '../ai/first_channel_model.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';

class WorkModel {
  const WorkModel(this.model, this.effort);
  final DeepSeekModelProfile model;
  final ReasoningEffort effort;
  static const modelKey = 'commission_model';
  static const effortKey = 'commission_effort';
  static const levels = [ReasoningEffort.low, ReasoningEffort.high, ReasoningEffort.max];
  static Future<WorkModel> read(AppDatabase db) async {
    final name = (await db.getSetting(modelKey) ?? '').trim();
    final level = await db.getSetting(effortKey);
    return WorkModel(
      name.isEmpty ? await FirstChannelModel.read(db) : DeepSeekModelProfile.fromApiName(name),
      levels.where((e) => e.apiName == level).firstOrNull ?? await FirstChannelModel.readEffort(db),
    );
  }
}
