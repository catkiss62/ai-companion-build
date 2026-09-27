import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../storage/secure_config.dart';

/// A cached observation for dialogue. Fetching weather never owns or advances
/// an autonomous heartbeat; failure simply omits this optional context.
class WeatherContext {
  WeatherContext._();

  static const interval = Duration(minutes: 10);
  static const maxAge = Duration(minutes: 40);
  static Future<String?>? _refreshing;

  static Future<String> forPrompt(AppDatabase db, DateTime now) async {
    if (await db.getSetting('weather_enabled') != '1') return '';
    try {
      // A weather HTTP timeout must never hold a user reply or autonomous
      // generation. Refresh for the next prompt and use only fresh cached data.
      unawaited(refresh(db, now: now).catchError((Object _) => null));
      final last = int.tryParse(await db.getSetting('weather_updated_at') ?? '');
      final city = await db.getSetting('weather_city');
      if (last == null || city != await db.getSetting('weather_cached_city') ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(last)) >= maxAge) {
        return '';
      }
      final observation = await db.getSetting('weather_observation');
      if (observation == null || observation.isEmpty) return '';
      return '【现实天气 · 和风天气】$observation。'
          '这是带更新时间的外部天气资料，供你自行判断是否与当前话题有关；'
          '不要求谈论天气，也不产生主动联系任务。预报不是已发生的事实。';
    } catch (_) {
      return '';
    }
  }

  static Future<String?> refresh(AppDatabase db, {DateTime? now, bool force = false}) async {
    final time = now ?? DateTime.now();
    if (await db.getSetting('weather_enabled') != '1') return null;
    final last = int.tryParse(await db.getSetting('weather_updated_at') ?? '');
    final city = (await db.getSetting('weather_city') ?? '').trim();
    final cachedCity = await db.getSetting('weather_cached_city');
    final cached = await db.getSetting('weather_observation');
    if (city.isEmpty) return null;
    if (!force && city == cachedCity && last != null &&
        time.difference(DateTime.fromMillisecondsSinceEpoch(last)) < interval) {
      return cached;
    }
    final pending = _refreshing;
    if (pending != null) return pending;
    final task = _fetch(db, city, time);
    _refreshing = task;
    try {
      return await task;
    } catch (_) {
      if (city == cachedCity && last != null &&
          time.difference(DateTime.fromMillisecondsSinceEpoch(last)) < maxAge) {
        return cached;
      }
      rethrow;
    } finally {
      if (identical(_refreshing, task)) _refreshing = null;
    }
  }

  static Future<String> _fetch(AppDatabase db, String city, DateTime time) async {
    final key = (await SecureConfig.instance.readWeatherApiKey() ?? '').trim();
    final hostText = (await db.getSetting('weather_api_host') ?? '').trim();
    final host = Uri.tryParse(hostText.startsWith('https://') ? hostText : 'https://$hostText');
    if (key.isEmpty || host == null || host.scheme != 'https' || host.host.isEmpty ||
        host.userInfo.isNotEmpty || host.path.isNotEmpty && host.path != '/') {
      throw const FormatException('请配置有效的和风天气 HTTPS API Host 和 Key');
    }
    final client = http.Client();
    Future<Map<String, dynamic>> get(String path, Map<String, String> params) async {
      final uri = host.replace(path: path, queryParameters: {...params, 'key': key});
      final response = await client.get(uri).timeout(const Duration(seconds: 12));
      final value = jsonDecode(response.body);
      if (response.statusCode != 200 || value is! Map || value['code'] != '200') {
        throw StateError('和风天气 HTTP ${response.statusCode} / ${value is Map ? value['code'] : '无响应'}');
      }
      return Map<String, dynamic>.from(value);
    }
    try {
      var location = await db.getSetting('weather_location_id') ?? '';
      if (await db.getSetting('weather_cached_city') != city || location.isEmpty) {
        final geo = await get('/geo/v2/city/lookup', {'location': city, 'number': '1', 'lang': 'zh'});
        final places = geo['location'];
        if (places is! List || places.isEmpty || places.first is! Map) {
          throw StateError('未找到天气城市');
        }
        location = places.first['id']?.toString() ?? '';
        if (location.isEmpty) throw StateError('天气城市缺少位置 ID');
      }
      final current = await get('/v7/weather/now', {'location': location, 'lang': 'zh'});
      final observed = current['now'];
      if (observed is! Map) throw StateError('天气实况缺少数据');
      // Daily data changes slowly; a failed optional request must not suppress
      // the current observation or any autonomous conversation.
      Map<String, dynamic>? daily;
      try {
        daily = await get('/v7/weather/3d', {'location': location, 'lang': 'zh'});
      } catch (_) {}
      final result = describe(
        city: city,
        current: Map<String, dynamic>.from(observed),
        daily: daily,
        updated: current['updateTime']?.toString() ?? time.toIso8601String(),
      );
      await db.setSetting('weather_observation', result);
      await db.setSetting('weather_updated_at', time.millisecondsSinceEpoch.toString());
      await db.setSetting('weather_location_id', location);
      await db.setSetting('weather_cached_city', city);
      return result;
    } finally {
      client.close();
    }
  }

  static String describe({
    required String city,
    required Map<String, dynamic> current,
    required String updated,
    Map<String, dynamic>? daily,
  }) {
    final observedAt = DateTime.tryParse(updated)?.toLocal();
    final stamp = observedAt == null ? updated :
        '${observedAt.month}月${observedAt.day}日 ${observedAt.hour.toString().padLeft(2, '0')}:${observedAt.minute.toString().padLeft(2, '0')}';
    final parts = <String>['$city（实况更新 $stamp）'];
    final condition = current['text']?.toString().trim() ?? '';
    if (condition.isNotEmpty) parts.add(condition);
    final temperature = current['temp']?.toString().trim() ?? '';
    if (temperature.isNotEmpty) parts.add('$temperature°C');
    final feels = current['feelsLike']?.toString().trim() ?? '';
    if (feels.isNotEmpty) parts.add('体感 $feels°C');
    final wind = current['windScale']?.toString().trim() ?? '';
    if (wind.isNotEmpty) parts.add('风力 $wind 级');
    final days = daily?['daily'];
    if (days is List && days.isNotEmpty && days.first is Map) {
      final today = days.first as Map;
      final sunset = today['sunset']?.toString() ?? '';
      if (sunset.isNotEmpty) parts.add('今日预计日落 $sunset');
    }
    return parts.join('，');
  }
}
