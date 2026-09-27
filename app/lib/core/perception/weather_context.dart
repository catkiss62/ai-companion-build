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

  static Uri? parseApiHost(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery || uri.hasFragment) return null;
    return Uri.parse(uri.origin);
  }

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
          '这是带读取时间的外部天气资料，供你自行判断是否与当前话题有关；'
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
    final host = parseApiHost(await db.getSetting('weather_api_host') ?? '');
    if (key.isEmpty || host == null) {
      throw const FormatException('请配置有效的和风天气 HTTPS API Host 和 Key');
    }
    final client = http.Client();
    Future<Map<String, dynamic>> get(String path, Map<String, String> params,
        {bool geo = false}) async {
      final uri = host.replace(path: path, queryParameters: params);
      final response = await client.get(
        uri, headers: {'X-QW-Api-Key': key},
      ).timeout(const Duration(seconds: 12));
      final value = jsonDecode(response.body);
      if (response.statusCode != 200 || value is! Map ||
          (geo && value['code'] != '200')) {
        throw StateError('和风天气 HTTP ${response.statusCode} / ${value is Map ? value['code'] : '无响应'}');
      }
      return Map<String, dynamic>.from(value);
    }
    try {
      var latitude = await db.getSetting('weather_lat') ?? '';
      var longitude = await db.getSetting('weather_lon') ?? '';
      if (await db.getSetting('weather_cached_city') != city ||
          latitude.isEmpty || longitude.isEmpty) {
        final locationResult = await get('/geo/v2/city/lookup',
            {'location': city, 'number': '1', 'lang': 'zh'}, geo: true);
        final places = locationResult['location'];
        if (places is! List || places.isEmpty || places.first is! Map) {
          throw StateError('未找到天气城市');
        }
        latitude = places.first['lat']?.toString() ?? '';
        longitude = places.first['lon']?.toString() ?? '';
        if (double.tryParse(latitude) == null || double.tryParse(longitude) == null) {
          throw StateError('天气城市缺少有效坐标');
        }
      }
      final current = await get('/weather/v1/current/$latitude/$longitude',
          {'lang': 'zh'});
      if (current['condition'] is! Map || current['temperature'] is! Map) {
        throw StateError('天气实况缺少数据');
      }
      final result = describe(
        city: city,
        current: current,
        fetchedAt: time,
      );
      await db.setSetting('weather_observation', result);
      await db.setSetting('weather_updated_at', time.millisecondsSinceEpoch.toString());
      await db.setSetting('weather_lat', latitude);
      await db.setSetting('weather_lon', longitude);
      await db.setSetting('weather_cached_city', city);
      return result;
    } finally {
      client.close();
    }
  }

  static String describe({
    required String city,
    required Map<String, dynamic> current,
    required DateTime fetchedAt,
  }) {
    final observedAt = fetchedAt.toLocal();
    final stamp = '${observedAt.month}月${observedAt.day}日 ${observedAt.hour.toString().padLeft(2, '0')}:${observedAt.minute.toString().padLeft(2, '0')}';
    final parts = <String>['$city（读取于 $stamp）'];
    final condition = (current['condition'] as Map?)?['text']?.toString().trim() ?? '';
    if (condition.isNotEmpty) parts.add(condition);
    String measure(dynamic value) {
      if (value is! Map || value['value'] == null) return '';
      return '${value['value']}${value['unit'] ?? ''}';
    }
    final temperature = measure(current['temperature']);
    if (temperature.isNotEmpty) parts.add(temperature);
    final feels = measure(current['feelsLike']);
    if (feels.isNotEmpty) parts.add('体感 $feels');
    final wind = (current['wind'] as Map?)?['scale']?.toString().trim() ?? '';
    if (wind.isNotEmpty) parts.add('风力 $wind 级');
    return parts.join('，');
  }
}
