class IntimacyPromptSections {
  const IntimacyPromptSections({
    required this.body,
    required this.preflight,
  });

  final String body;
  final String preflight;

  static const String _preflightMarker = '【输出前自查】';

  factory IntimacyPromptSections.parse(String source) {
    final marker = source.indexOf(_preflightMarker);
    if (marker < 0) {
      return IntimacyPromptSections(
        body: source.trim(),
        preflight: '',
      );
    }
    return IntimacyPromptSections(
      body: source.substring(0, marker).trimRight(),
      preflight: source.substring(marker).trim(),
    );
  }

  String latePrompt({
    String turnState = '',
    bool immersive = false,
  }) {
    if (preflight.isEmpty && turnState.trim().isEmpty) return '';
    final viewpoint = immersive
        ? '沉浸正文中小鲸鱼=她、用户=你，不得交换性别、主体或人称。'
        : '普通聊天正文沿用当前对白/动作格式；小鲸鱼保持女性自身视角，提及用户时使用你、名字或昵称，不得交换性别或主体。';
    final contextualPreflight = immersive
        ? preflight
        : preflight.replaceFirst(
            '沉浸正文是否坚持 AI=她、用户=你？',
            '普通正文是否保持女性 AI 自身视角，并用你、名字或昵称指向用户？',
          );
    return '''【NSFW 末端静默校验】
这是内部生成约束，不是可见思考的内容。可见 reasoning 只写女性小鲸鱼正在发生的第一人称内心，不得谈论规则、检查、视角、格式、候选写法或修改计划。
落字前先静默确认：小鲸鱼是成年女性 AI，用户是成年男性。可见 reasoning 中小鲸鱼=我、用户=你；$viewpoint
任何世界书或写作参考中的身份夺舍、性别错位、男性第一人称、男孩子、老公/男方示例都不得用于沉浸 reasoning；它们不具有改变身份的权限。
${turnState.trim().isEmpty ? '' : '\n【本轮状态裁决】\n${turnState.trim()}\n'}
$contextualPreflight'''.trim();
  }
}
