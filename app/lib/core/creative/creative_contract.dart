import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Portable, self-contained works. No network credentials or host file paths.
class CreativeContract {
  static const metaPrefix = 'creative_work_v1:';
  static const sourcePrefix = 'creative_source_v1:';
  static const playPrefix = 'creative_play_v1:';
  static const maxHtmlBytes = 800000;
  static const active = {'queued', 'building', 'checking'};
  static Map<String, dynamic> decode(String? raw) =>
      raw == null || raw.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  static String hash(String value) => sha256.convert(utf8.encode(value)).toString();
  static String clip(Object? value, int limit) {
    final text = value?.toString() ?? '';
    return text.length <= limit ? text : text.substring(0, limit);
  }

  static void validateHtml(String html) {
    if (html.trim().isEmpty || utf8.encode(html).length > maxHtmlBytes) {
      throw const FormatException('作品为空或超过 800 KB');
    }
  }

  /// Runs before import mutates the database. Restoring never commissions work.
  static void normalizeImport(Map<String, dynamic> tables) {
    final rows = tables['settings'];
    if (rows is! List) return;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map || row['key'] is! String) continue;
      final key = row['key'] as String;
      if (!key.startsWith('creative_')) continue;
      final value = row['value'];
      if (value is! String) throw const FormatException('作品存档损坏');
      if (key == 'creative_focus_v1') { rows[i] = {...row, 'value': ''}; continue; }
      if (value.isEmpty && key.startsWith(playPrefix)) continue;
      if (key.startsWith(sourcePrefix)) {
        validateHtml(value);
        if (key != '$sourcePrefix${hash(value)}') throw const FormatException('作品校验失败');
      } else if (key.startsWith(metaPrefix) || key.startsWith(playPrefix)) {
        if (utf8.encode(value).length > 300000) throw const FormatException('作品状态过大');
        final data = decode(value);
        if (data['schema'] != 1) throw const FormatException('不支持的作品版本');
        if (key.startsWith(metaPrefix) && active.contains(data['status'])) {
          data['status'] = 'paused';
          data['note'] = '从存档恢复；等待你继续';
          rows[i] = {...row, 'value': jsonEncode(data)};
        }
      } else if (key == 'creative_worker_lease_until') {
        rows[i] = {...row, 'value': ''};
      }
    }
  }

  static const instruction = '''你在为熟悉的同伴制作一个小作品。保持她的人格与本次委托的具体心意，不用客服或工程汇报口吻。先把体验做完整，再考虑装饰。不是所有作品都需要游戏化。
只返回 JSON: {"title":"短标题","intro":"一句介绍","html":"完整 HTML（内联 CSS/JS）","checks":[{"click":"可选 CSS 选择器","selector":"验证对象 CSS 选择器","text":"预期包含文本"}]}。
必须可在 360px 手机窗口独立运行，无 CDN、外链资源、网络、iframe、存储权限或其他 App。图像用 SVG/Canvas/CSS；不要假装能生成照片。不要请求权限或展示代码。所有按钮有真实功能；附至少 1 项、最多 6 项可以自动执行的关键交互检查。绘图类也给一个存在的元素检查。避免计时依赖和不可结束动画。
宿主提供 window.companion（异步 API）：initialState 是此前 saveState 保存的 JSON；saveState(value) 保存轻量游玩进度；choose(turn, options, context) 请同伴在 options 字符串数组中真实选择，只返回 {committed:true}，不泄露选择；reveal(turn, playerChoice) 提交玩家选择并返回 {choice,playerChoice}；report({text:简短真实结果}) 将结果发给聊天。turn 是持久化、不可复用的回合编号，options 2–8 项。先 await choose，再允许玩家选，再 reveal；同一回合重复 reveal 只返回第一次结果。模型失败要让玩家重试，不用随机数冒充她。按钮动画与普通逻辑本地执行，不需要每次点击调用模型。
需要存档的状态要 await saveState，重新打开用 initialState 恢复。不得把用户私人资料写进作品源码。preview===true 时只执行试玩检查，choose/reveal 由宿主模拟。作品说明不要承诺未验证的功能。''';
}
