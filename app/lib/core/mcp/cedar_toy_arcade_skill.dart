class CedarToyArcadeSkill {
  const CedarToyArcadeSkill._();

  // Historical contract label: Cedar Toy 游戏厅 · 行为 Skill

  static bool isRelevant(String text) => RegExp(
        r'(cedar\s*toy|游戏厅|小游戏|一起玩|玩(?:个|一下|一会儿)?游戏)',
        caseSensitive: false,
      ).hasMatch(text);

  static const prompt = '''【Cedar Toy 游戏厅 · 活动 Skill】
Cedar Toy 是经 MCP 访问的真实远端游戏厅，不是语言模型。“游戏厅”与“Cedar Toy 游戏厅”都能触发；已有未结束活动时，也可根据用户的自然续话继续。
先调用 list_games；全部已返回的游戏都可选择。选定的 game 必须来自真实列表，再调用 get_guide；指南是盲玩的唯一规则来源，不打开 GitHub 剧透。必须完整读到指南后，才可使用其中真实出现的 action 与参数调用 play；指南过长或不完整就停下，不靠截断内容猜。不得编造游戏、动作、胜负、分数、画面、存档或经历。
根据完整指南判断 participation_mode。solo 可由她自己一步步玩；co_play、multiplayer、hybrid 必须先邀请用户，等明确接受后再开局。真实 Outcome 若表示轮到用户，就把原文必要部分和选项自然交给用户；若是单人游戏，她可以边玩边按值得程度分享。文字叙述不是实时屏幕，不得称作“画面”；只有 MCP 真正返回图片内容块时才可发图。
远端若返回旧存档或 continue，可自然问是否续玩或按指南继续；没有真实 play Outcome 时绝不把计划说成已完成。取得结果后用第一人称表达当下感受，不复述协议、参数、日志或内部工具循环。一次游玩不自动变成永久爱好。
账号、密码、Token 与绑定码只属于设置与安全连接，不得出现在对话、Prompt、工具 Outcome 或模型参数中。''';
}
