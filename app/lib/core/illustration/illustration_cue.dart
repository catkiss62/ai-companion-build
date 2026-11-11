/// Optional machine-only cue on the existing reply. The actual drawing plan
/// is requested from the first channel only after this reply has committed.
abstract final class IllustrationCue {
  static const _tag = 'illustrate';
  static final _complete = RegExp(
    r'<\s*illustrate\s*>([\s\S]*?)<\s*/\s*illustrate\s*>',
    caseSensitive: false,
  );
  static final _open = RegExp(r'<\s*illustrate\b', caseSensitive: false);
  static final _close = RegExp(r'<\s*/\s*illustrate\s*>', caseSensitive: false);

  static String? read(String raw) {
    final cue = _complete.firstMatch(raw)?.group(1)?.trim();
    if (cue == null || cue.isEmpty || cue.length > 240) return null;
    return cue;
  }

  static String visible(String raw) {
    var value = raw.replaceAll(_complete, '').replaceAll(_close, '');
    final opening = _open.firstMatch(value);
    if (opening != null) value = value.substring(0, opening.start);
    final tail = value.lastIndexOf('<');
    if (tail >= 0) {
      final token = value
          .substring(tail)
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      if ('<$_tag>'.startsWith(token) || '</$_tag>'.startsWith(token)) {
        value = value.substring(0, tail);
      }
    }
    return value;
  }

  static bool vetoed(String text) =>
      RegExp(r'别画|不用画|不要画|先不画|不生图|暂停生图|取消生图|今天不画').hasMatch(text);

  static bool requestsStyledArtwork(String text) {
    final value = text.trim();
    return value.length <= 180 &&
        !vetoed(value) &&
        !RegExp(r'相册|图库|现成|原图|截图|提示词|我自己画|我来画|别来|不用来|不要来').hasMatch(value) &&
        RegExp(
          r'^(?:(?:那就|那|再|你|请|帮我|给我|麻烦|能不能|可以)\s*)*'
          r'(?:来|整|做|生成)(?:一)?(?:张|幅)[^\n。！？!?；;]{0,36}'
          r'(?:画风|q\s*版|chibi)[^\n。！？!?；;]{0,48}(?:图|插画|自拍|$)',
          caseSensitive: false,
        ).hasMatch(value);
  }

  static bool explicitRequest(String text) {
    final value = text.trim();
    if (vetoed(value) ||
        value.isEmpty ||
        value.length > 800 ||
        RegExp(r'怎么生图|生图设置|生图功能|提示词|测试接口|我自己画|我来画').hasMatch(value)) {
      return false;
    }
    return requestsStyledArtwork(value) ||
        RegExp(
          r'^生图[。！!]?$|画一张|画个|画幅|画一幅|画给我|给我画|生成一张.{0,16}(图|照片|插画)|^生图[：:\s]|来张.{0,8}自拍|画张|画一下',
        ).hasMatch(value);
  }

  static String instruction({required bool requested}) => requested
      ? '用户本轮可能在请求原创插画。确认是现在实际画图时，可在正常正文末尾加 '
            '<illustrate>一句中文创作意图</illustrate>。正文可以说接下来要画，图片完成前不要说已发图。'
      : '只有你此刻确实想用一张原创插画表达具体内容时，才在正常正文末尾加 '
            '<illustrate>一句中文创作意图</illustrate>。普通聊天省略，图片完成前不要说已发图。';
}
