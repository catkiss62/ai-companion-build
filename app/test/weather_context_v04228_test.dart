import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/perception/weather_context.dart';

void main() {
  test('weather host accepts the console domain and rejects endpoint URLs', () {
    expect(WeatherContext.parseApiHost('abcxyz.qweatherapi.com')?.origin,
        'https://abcxyz.qweatherapi.com');
    expect(WeatherContext.parseApiHost('https://abcxyz.qweatherapi.com/')?.origin,
        'https://abcxyz.qweatherapi.com');
    expect(WeatherContext.parseApiHost('http://abcxyz.qweatherapi.com'), isNull);
    expect(WeatherContext.parseApiHost('https://abcxyz.qweatherapi.com/v7/weather/now'), isNull);
  });

  test('current weather v1 fact uses the documented fields and retrieval time', () {
    final fact = WeatherContext.describe(
      city: '北京',
      fetchedAt: DateTime(2026, 9, 27, 9, 5),
      current: {
        'condition': {'text': '小雨', 'code': '305'},
        'temperature': {'value': 18.5, 'unit': '°C'},
        'feelsLike': {'value': 17.0, 'unit': '°C'},
        'wind': {'scale': 3},
      },
    );
    expect(fact, contains('北京（读取于 9月27日 09:05）'));
    expect(fact, contains('小雨'));
    expect(fact, contains('18.5°C'));
    expect(fact, contains('体感 17.0°C'));
    expect(fact, contains('风力 3 级'));
    expect(fact, isNot(contains('日落')));
  });
}
