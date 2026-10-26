/// The writer chooses complete messages in one generation. Ordinary sentence
/// punctuation and paragraph breaks never become message boundaries.
abstract final class QqReplyParts {
  static const separator = '<qq_next_message/>';
  static const prompt = '【QQ消息节奏】一次回复由你自主决定发1、2或3条完整短消息。'
    '一条就能表达时只发一条，不凑数量，不把一句话硬切成几份。'
    '需要继续补一句、接一个反应或自然分开发时，在两条完整消息之间单独一行写<qq_next_message/>。'
    '普通换行只是同一条消息中的段落；每条保持简短，最多1800字。不要解释分条标记。'
    '这一整组只生成一次，宿主会在后续消息之间随机等待1–2秒。'
    '表情包选择仍放在整个回复最后，图文时与最后一条合并；只发表情包或WAIT时不要加分条标记。';

  static List<String> parse(String visible) {
    final parts = visible.split(RegExp(r'<qq_next_message\s*/>'))
      .map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    // Preserve content if the writer exceeds its three-message contract.
    return parts.length <= 3 ? parts : [parts[0], parts[1], parts.skip(2).join('\n')];
  }
}
