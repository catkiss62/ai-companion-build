# Cedar Toy 游戏兼容矩阵 · v0.41.74+218

本表是开发接入审计，不是伴侣的游戏攻略。运行时仍只使用 Cedar 实时 `list_games`、完整 `get_guide` 与真实 Outcome；公开仓库内容、谜题答案和隐藏状态不得进入普通游玩 Prompt。

## 统一协议层

- 动态目录：不固化“当前有哪些游戏”，只解析目录里的 `id·中文简介·作者` 用于显示和提及识别。
- 动作权限：单游戏 action 来自完整指南；`rest / announcements / vote` 来自 Cedar 实时 `play` schema 的平台公共合同。
- 回合归属：优先消费 `terminal / next_actor / your_turn / current_actor / seat / can_act / action_required / available_actions / legal_actions / legal_moves`，模糊文本才交给 DeepSeek 分类。
- 观察与写入：`next_call` 只授权下一次观察；观察确认轮到伴侣后转入动作规划。写入超时先同步，不盲目重放；相同只读动作在伴侣回合不得空转。
- 生命周期：远端 `leave/resign` 与本机 `pause/pause_and_release/resume` 分离；暂停和暂离保留远端存档。
- 参与模式：`co_play/multiplayer` 开始前必须有明确许可；`hybrid` 可独自开始，只有进入其中共玩分支时才要求许可。
- 上下文：当前用户回合可直接参考聊天；后台只接收最多三条明确游戏建议，作为弱信号，不复制整段聊天。
- 房间对白：固定走内部 DeepSeek，且只使用当前 session 的房间消息、真实动作、Outcome 和建议；普通聊天与沉浸房间的最终 Provider 不变。

## 当前目录覆盖

| game id | 公开来源 | 生命周期类型 | 接入时必须覆盖的合同 |
|---|---|---|---|
| `mbti` | Cedar 站内 | 测评/逐题或批量 | 开始参数、题目输入、完成态、存档槽 |
| `enneagram` | Cedar 站内 | 测评/两种量表 | 模式选择、逐题/批量、完成态 |
| `dnd` | Cedar 站内 | 测评 | 开始、答题、完成态 |
| `love` | Cedar 站内 | 测评/双人可选 | 单人和双人参与方式、待用户输入 |
| `ecr` | Cedar 站内 | 测评/双人可选 | 量表、双人许可、待用户输入 |
| `humanity` | Cedar 站内 | 娱乐测评 | 题目输入、完成态 |
| `sins_virtues` | Cedar 站内 | 娱乐测评 | 题目输入、非诊断提示、完成态 |
| `bdsmtest` | Cedar 站内/外部展示 | 成人测评 | 成人确认、题目输入、完成态 |
| `turtle_soup` | Cedar 站内 | 共玩房间/推理 | join/ask/guess/status、房间消息、用户输入、暂离不退房 |
| `duel` | [cedarduet](https://github.com/Zizuixixiang/cedarduet) | 2～6 人房间/长轮询 | catalog/new/join/accept/move/state、revision、bootstrap/增量、私密状态、`your_turn`、`next_call`、离席即弃权 |
| `fishing` | [ai-fishing-game](https://github.com/tutusagi/ai-fishing-game) | 简单 `cmd` 单机/批量 | 批命令、紧凑状态、长期存档、平台防沉迷与游戏状态分离 |
| `bar` | [ai-bar-game](https://github.com/dan521627-hash/ai-bar-game) | 版本选择/生成式经营 | full/lite 必选、长期状态、普通聊天后效应 |
| `forest` | [mo-yao-play-games](https://github.com/ai11231123alal11-ui/mo-yao-play-games) | 人机共玩叙事/人类网页 | lines/start/choose/status、每日 3/5 线原生限制、用户选择与平台 rest 分离 |
| `moonlit` | [moonlit-myriad](https://github.com/xinwithyu/moonlit-myriad) | 长线卡牌构筑 | 建局牌组/难度、preview 不消耗 RNG、严格阶段动作、长期存档 |
| `eco` | [cedareco](https://github.com/Zizuixixiang/cedareco) | 惰性生态/共享网页 | new/observe/wait/summon/status、灾害人类事件、不能只 wait 空转 |
| `ciyuwu` | [ci-yu-wu](https://github.com/yuyixuanfu/ci-yu-wu) | `cmd` Roguelike/子状态机 | new/cmd、phase/sub-state、批量、长期存档 |
| `leek` | [leek](https://github.com/Asti-Z/leek) | `cmd` 模拟经营 | 市场/交易阶段、wait N、紧凑状态、长期存档 |
| `delve` | [delve-ai-companion](https://github.com/liyana31811/delve-ai-companion) | 半托管流程 | new→handshake→play、默认协商、分享事件与存档 |
| `travel` | [travel-mcp](https://github.com/shenchesilas-stack/travel-mcp) | 多工具惰性时钟/可共游 | 行程、照片、nudge、下次调用结算时间、单人/共游切换 |
| `arcade` | [claude-arcade](https://github.com/reneyuxi0402/claude-arcade) | 子游戏大厅/筹码 | enter、购买前询问人类金额、子游戏状态、长期存档 |
| `burger` | [noon-burger-shop](https://github.com/linzhi-524/noon-burger-shop) | 多步骤经营/自动模式 | 建局选项、订单/烹饪步骤、auto day/order、长期存档 |
| `crucible_echoes` | [crucible-echoes](https://github.com/megabaka404/crucible-echoes) | 严格单步状态机 | 每步只从 `[STATE].available_actions` 选择，难度/趣味模式建局 |
| `imitator_td` | [random-imitator-td](https://github.com/wxynora/random-imitator-td) | 严格布阵/等待/可围观 | 首步卡槽配置、特殊模式选择、wait、原生每 5 决策提醒、恢复与重开区分 |
| `memoria` | [Memoria-Station](https://github.com/hatakeyuyuko-dotcom/Memoria-Station) | 多关文字推理 | 前三关难度、cmd、用户提示、长期存档；不读取人类攻略 |
| `white_room` | [echoing-white-room](https://github.com/hatakeyuyuko-dotcom/echoing-white-room) | 自由输入长叙事 | 标准/长模式、自由文本、重开确认、约 90～140 轮存档 |
| `market` | [shangzhuochifan](https://github.com/yuyixuanfu/shangzhuochifan) | 一餐生命周期/共同行为 | 买菜→做饭→用餐、用户伴侣反应、批命令、单 session |
| `workkk` | [workkk](https://github.com/zhizhou-xiee/workkk) | 每日行动/人类围观 | 每日 3～5 动作、网页刷新、明信片 message、长期存档 |
| `garden_cat` | [Garden-Cat-Engine](https://github.com/racy1501/Garden-Cat-Engine) | 长期养成/共享网页 | 花园状态、两小时冷却、便签/花束礼物、人类与 AI 同存档 |
| `camping_plaza` | [Camping-Plaza](https://github.com/racy1501/Camping-Plaza) | 严格计划-推进/共享网页 | state→actions→submit plan→advance→result、session id、长期经营 |

## 验证策略

不要求为每款游戏复制一套 APK 逻辑，也不能用自动化冒充真实服务器逐局通关。自动化按协议类型固定夹具覆盖：简单 `cmd`、建局选项、严格合法动作、惰性时间、共享网页事件、用户输入、多人 long-poll、平台公共 action、暂停恢复和终局。真机验收再从每一类型抽代表游戏；只有服务器实际返回了矩阵之外的新结构，才补协议解析，而不是按游戏 id 打补丁。
