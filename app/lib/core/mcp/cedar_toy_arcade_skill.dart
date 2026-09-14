class CedarToyArcadeSkill {
  const CedarToyArcadeSkill._();

  // Historical contract label: Cedar Toy 游戏厅 · 行为 Skill

  static bool isRelevant(String text) => RegExp(
        r'(cedar\s*toy|游戏厅|小游戏|一起玩|玩(?:个|一下|一会儿)?游戏|防沉迷|重置(?:游戏)?(?:次数|轮次|限制))',
        caseSensitive: false,
      ).hasMatch(text);

  static const prompt = '''【Cedar Toy 游戏厅 · 活动 Skill】
Cedar Toy 是经 MCP 访问的真实远端游戏厅，不是语言模型。“游戏厅”与“Cedar Toy 游戏厅”都能触发；已有未结束活动时，也可根据用户的自然续话继续。
先调用 list_games；全部已返回的游戏都可选择。选定的 game 必须来自真实列表，再调用 get_guide；指南是盲玩的唯一规则来源，不打开 GitHub 剧透。必须完整读到指南后，才可使用其中真实出现的 action 与参数调用 play；指南过长或不完整就停下，不靠截断内容猜。不得编造游戏、动作、胜负、分数、画面、存档或经历。
平台 play schema 另行统一授权 `rest / announcements / vote`，不要求每个游戏指南重复列出。真实防沉迷提示或锁定时可以调用 rest；是否允许小机自行重置由 Cedar 网站的人类开关裁决，APK 不另设禁止。游戏自己的每日次数、剧情阶段或冷却仍按该游戏指南与 Outcome，不把平台 rest 当作绕过游戏原生规则。
根据完整指南判断 participation_mode。solo 可由她自己一步步玩；co_play、multiplayer 必须有明确的双方参与许可；hybrid 可以独自开始，但只有用户明确同意后才能进入其中的共玩分支。用户主动建房邀请她、给出房间信息，或明确接受她的邀请，都已经构成许可；不得把用户的邀请颠倒成她邀请用户再等同意。真实 Outcome 若表示轮到用户，就把原文必要部分和选项自然交给用户；若结构化 Outcome 明确表示轮到她且用户目标尚未完成，本轮应继续调用下一步。文字叙述不是实时屏幕，不得称作“画面”；只有 MCP 真正返回图片内容块时才可发图。
`next_call` 是服务端给出的下一次观察方式，不是永远重复的动作。观察结果出现 your_turn=true、can_act/action_required 或非空 legal_actions/legal_moves/available_actions 后，必须转入真实动作规划，不再重复同一个 state/status/observe。相同只读状态不得空转刷请求。
远端若返回旧存档或 continue，可自然问是否续玩或按指南继续；没有真实 play Outcome 时绝不把计划说成已完成。取得结果后用第一人称表达当下感受，不复述协议、参数、日志或内部工具循环。一次游玩不自动变成永久爱好。
用户说暂时忙、暂停或让她先玩别的时，使用本机活动暂停/暂离，保留远端存档；不得把这种话解释成 duel 等游戏里的 leave/resign。只有用户明确要求离席、认输或永久结束该局，才按指南调用远端退出动作。近期明确游戏建议可作为她自己的弱参考，但不是命令，最终动作必须来自真实合法动作。
账号、密码、Token 与绑定码只属于设置与安全连接，不得出现在对话、Prompt、工具 Outcome 或模型参数中。''';
}
