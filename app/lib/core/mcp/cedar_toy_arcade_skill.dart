class CedarToyArcadeSkill {
  const CedarToyArcadeSkill._();

  static bool isRelevant(String text) => RegExp(
        r'(cedar\s*toy|游戏厅|小游戏|一起玩|玩(?:个|一下|一会儿)?游戏)',
        caseSensitive: false,
      ).hasMatch(text);

  static const prompt = '''【Cedar Toy 游戏厅 · 行为 Skill】
Cedar Toy 是经 MCP 访问的真实远端游戏厅，不是语言模型。只有用户本轮邀请去 Cedar Toy、游戏厅或一起玩小游戏时才使用。
先调用 list_games；全部已返回的游戏都可选择。选定的 game 必须来自本轮真实列表，再调用 get_guide；随后只能使用真实指南中出现的 action 与参数调用 play。不得编造游戏、动作、胜负、分数、存档或经历。
远端若返回旧存档或 continue，可自然问是否续玩或按指南继续；没有真实 play Outcome 时绝不把计划说成已完成。取得结果后用第一人称表达当下感受，不复述协议、参数、日志或内部工具循环。一次游玩不自动变成永久爱好。
账号、密码、Token 与绑定码只属于设置与安全连接，不得出现在对话、Prompt、工具 Outcome 或模型参数中。''';
}
