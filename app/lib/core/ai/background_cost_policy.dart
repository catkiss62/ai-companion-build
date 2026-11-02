import 'model_profile.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';

/// Price scheduling only for work that can safely remain pending. Call before
/// taking a lease/cursor or recording an attempt. Never wrap interactive work.
class BackgroundCostPolicy {
  static const enabledKey = 'background_offpeak_enabled';

  // Official Beijing workday windows, independent of the device timezone.
  // Without an authoritative holiday calendar we conservatively also defer on
  // weekday holidays. This can delay optional work, never overcharge it.
  static DateTime? peakEnd(DateTime now) {
    final utc = now.toUtc();
    final beijing = utc.add(const Duration(hours: 8));
    if (beijing.weekday > DateTime.friday) return null;
    final end = beijing.hour >= 9 && beijing.hour < 12 ? 12 :
        beijing.hour >= 14 && beijing.hour < 18 ? 18 : null;
    return end == null ? null : DateTime.utc(beijing.year, beijing.month,
        beijing.day, end).subtract(const Duration(hours: 8));
  }

  static bool paidOfficial(String endpoint, String model) =>
      Uri.tryParse(endpoint.trim())?.host == 'api.deepseek.com' &&
      {'deepseek-flash', 'deepseek-v4-flash', 'deepseek-v4-flash-vision-exp',
        'deepseek-v4-pro'}.contains(model);

  static Future<DateTime?> deferredUntil(AppDatabase db, DateTime now,
      {String? endpoint, String? model, SecureConfig? config}) async {
    final end = peakEnd(now);
    if (end == null || await db.getSetting(enabledKey) == '0') return null;
    try {
      final secure = config ?? SecureConfig.instance;
      // No configured model call (e.g. a local/injected reviewer) has no price.
      if (endpoint == null && ((await secure.readApiKey())?.trim() ?? '').isEmpty) return null;
      return paidOfficial(endpoint ?? await secure.readEndpoint(),
          DeepSeekModelProfile.fromApiName(model ?? await db.getSetting('deepseek_model')).apiName) ? end : null;
    } catch (_) {
      // Pricing is optional; a configuration read failure must not lose work.
      return null;
    }
  }
}
