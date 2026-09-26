import 'package:lunar/lunar.dart';

/// Calendar facts for the device-local date. No dialogue or reminder schedule.
class FestivalContext {
  const FestivalContext._();

  static List<String> onDate(DateTime instant) {
    final day = DateTime(instant.year, instant.month, instant.day);
    final lunar = Lunar.fromDate(day);
    final tomorrow = Lunar.fromDate(DateTime(day.year, day.month, day.day + 1));
    final names = <String>[];

    final solarName = switch ((day.month, day.day)) {
      (1, 1) => '元旦',
      (2, 14) => '情人节',
      (4, 1) => '愚人节',
      (5, 1) => '劳动节',
      (6, 1) => '儿童节',
      (10, 1) => '国庆节',
      (10, 31) => '万圣节',
      (12, 24) => '平安夜',
      (12, 25) => '圣诞节',
      _ => null,
    };
    if (solarName != null) names.add(solarName);

    // The library represents leap lunar months with a negative month.
    final lunarName = switch ((lunar.getMonth(), lunar.getDay())) {
      (1, 1) => '春节',
      (1, 15) => '元宵节',
      (5, 5) => '端午节',
      (7, 7) => '七夕节',
      (8, 15) => '中秋节',
      (9, 9) => '重阳节',
      (12, 8) => '腊八节',
      _ => null,
    };
    if (lunarName != null) names.add(lunarName);
    if (tomorrow.getMonth() == 1 && tomorrow.getDay() == 1) {
      names.add('除夕'); // Also covers a 29-day twelfth lunar month.
    }
    if (lunar.getJieQi() == '清明') names.add('清明节');
    if (lunar.getJieQi() == '冬至') names.add('冬至');
    return List.unmodifiable(names);
  }

  static String forPrompt(DateTime now) {
    final names = onDate(now);
    if (names.isEmpty) return '';
    final local = '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
    return '【今日节日 · 本机日期事实】$local：${names.join('、')}。'
        '这是节日本身的日期，不代表当地法定放假、你正在庆祝，或她已经发送祝福。'
        '若对话自然相关可以提起；不要求主动联系，不要每轮重复或套固定祝福。';
  }
}
