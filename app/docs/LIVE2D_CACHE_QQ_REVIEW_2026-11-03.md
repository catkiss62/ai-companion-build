# Live2D、第一通道缓存与 QQ 只读检查

检查日期：2026-11-03（北京时间）。
源码基线：`agent/v042107-review-recovery` / `c176e1f17b232a73dca6e945ae7aca92dccf273b`。运行版本仍为 **v0.42.166+410 / schema67**；该提交及此前 DSH 比较提交只改文档。
范围：DeepSeek 与菜菜的开场四拍、真实语音阶段、19 情绪及附加表情；第一通道缓存与查手机各栏目；QQ 提及、接话、投递、恢复及语音。
本轮只做检查和记录，未修改运行代码、版本、资源、测试或工作流，未构建 APK。“家”的玩法已按用户决定搁置。

## 结论与优先顺序

1. **Q1：应补的功能缺陷。** QQ 首段发送之前的明确未投递临时故障，被当前自动重试条件漏掉。原发送结果未知、部分已送达和归档失败仍必须禁止自动重发。
2. **C1：明确遗漏的缓存机会。** 当轮经验整合器把变化的工具回执、作品状态放在长固定 JSON 契约之前，变化时会截断可复用前缀。保持全部事实和规则，仅重排/拆分静态与动态部分。
3. **L1/L2：已确认的表现差异，是否改动属于微调。** DeepSeek 普通附加表情约3.2秒后淡出；菜菜约4.5秒完成释放。DeepSeek 用途判断的说明也没有菜菜细，且开场少了每拍独立眼部 wink 路径。不能据此声称已测得当前触发率下降。
4. 查手机绝大多数生成器本来已使用轻量身份与固定任务说明，并未加载整套聊天人设。继续省 token 应针对实际资料体积、稳定前缀与重复工作，不能统一删人格或事实契约。

## 证据范围与限制

- 将远端精确 tree 与本地副本逐文件计算 Git blob SHA-1：检查范围内 **877 个运行文本源文件一致，6 个本地依赖包源文件一致**。其他文档副本可能旧，不作为当前交付状态依据。
- 对 Q1 执行源码条件绑定的控制流真值表：首段前 token 刷新网络失败、首段明确 HTTP429、未知投递、部分投递、归档失败五类均没有进入发送阶段自动重试分支；前两类本可在保持归属和期限时有限恢复。这是控制流反例，不是手机或 QQ 实网测试。
- 当前环境没有可用的 Flutter/Dart SDK，本轮没有重跑 Flutter 回归或调用真实模型。既有 +410 CI 通过不能证明下面新增发现已被覆盖。
- 上次通用诊断为 **+406**，上次 Live2D 专项为 **+408**。专项含105个渲染样本，未提供当前 JEV 问答频次或 API 缓存用量。因此不把这些旧样本当作 +410 当前频率、命中率或费用的测量。
- 私人聊天、存档正文、密钥和原始诊断不进入此公开记录。

## 一、Live2D

### 1. 基础目标并未再次系统性缩小

| 项目 | 菜菜 | DeepSeek | 解释 |
| --- | --- | --- | --- |
| 四拍左右转头 | ±25 | ±25 | 单位均为各自模型输入参数，视觉角度仍需实机比较 |
| 四拍低头/抬头 | ±24 | ±24 | 组合姿态有各自差异 |
| 四拍歪头 | ±23，双关联参数 | ±23，单输入参数 | 不能按参数个数推断视觉幅度 |
| 四拍身体 | X多为±4、Y±7、Z约±4 | X可到±14、Y可到+13、Z可到±12 | DeepSeek数值并非统一更小，模型变形量各自不同 |
| 额外幅度选择 | 每拍0.8/1.0/1.12 | 当前没有对应每拍强度题；使用目录基准值 | 菜菜可选112%强调，DeepSeek不等于被统一乘低增益 |
| 真实语音点头 | 头Y -10，身体Y -1.8 | 头Y -10，身体Y -5 | DeepSeek目标不比菜菜弱 |
| 真实语音侧头 | 头Z 8，身体Z 1.5及X -1 | 头Z 10，身体Z 5 | 保留两模型不同动作，不按同一视觉模板硬套 |

来源：[菜菜规划器](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/caicai_motion_planner.dart)、[DeepSeek规划器](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/deepseek_motion_planner.dart)、[菜菜语音动作](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/speech_performance_plan.dart)。
DeepSeek四拍过渡时间为拍间隔×0.65，菜菜为×0.34；DeepSeek身体X/Z及整模水平移动还采用较慢原生收敛。它们会影响节奏体感，不代表JEV概率把幅度打折。当前不建议整体再次加大，以免破坏刚修好的小豆丁和支点。

19情绪也未发现统一缩小：DeepSeek开心嘴形1、眯眼0.85；兴奋眯眼1；生气眉-1、嘴形-1；惊讶眼开1.5。菜菜相近语义大多也接近其各自参数范围。普通情绪期限复用同一策略类、实例独立；语音时最终由PCM重写嘴部，不建议解除嘴型保护。
来源：[DeepSeek表情](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekExpressions.java)、[菜菜表情](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiFaceMotion.java)、[DeepSeek更新顺序](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekAvatarModel.java#L328)。

### L1. 普通附加表情比菜菜短

DeepSeek的`trigger`把普通附加表情剩余时间设为3.2秒，随后以本地权重淡出；菜菜开场预设在4.12秒开始释放，约4.5秒完成。该差异同样影响被选中的圈圈眼、脸红、汗等层的可见时间，足以影响“表情有没有出现”的体感，但不是触发频率统计。

普通wink则已经大致对齐：DeepSeek普通1.2秒、吐舌1.6秒；菜菜对应包含淡出后的总时长也是1.2/1.6秒。菜菜额外的比耶wink是2秒，DeepSeek没有这个手势。不应把所有wink延长到4.5秒。
来源：[DeepSeek附加层与wink](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekExpressions.java#L29)、[菜菜开场预设期限](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/SenLive2DModel.java#L518)、[菜菜语音预设期限](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiSpeechPresetLease.java#L15)。

建议：仅对可持续的附加表情对齐菜菜的整体可见时长；语音停播、换段/换模型、摸头抢占仍按原生命周期收尾。wink和手势各自保持专门期限。

### L2. DeepSeek的附加表情资格描述不够具体，开场眼部入口也不同

- 菜菜的`face_use`明确列出七种语义，允许轻微/中等/强烈自然反应，且明确“已有其他层不是不用理由”。DeepSeek将face/effect/wink复用同一段泛化说明，use题主要使用英文层名，未把各自完整候选含义写入资格题；脸红、冷汗等轻微反应的提示不如菜菜充分。
- DeepSeek分为特殊眼型、效果、wink三道资格题；特殊眼型与wink本地互斥符合模型约束，效果可叠加，不宜取消这些物理兼容边界。
- 菜菜四拍目录还有独立`eyes`频道，可直接选单眼笑眼wink；DeepSeek四拍没有对应频道，wink只经整轮/语音段预设资格进入。它可能减少开场眼部变化，但不等于缺失所有按键表情。
- 两边的JEV网关都取合法分布最高项，未发现DeepSeek专属的低置信度压no或概率幅度衰减。
- 四拍是四组姿态目标，不是必播四个按键。19情绪、五官、附加按键分别决策；选择某个19情绪不会自动按下同名特殊按钮。

来源：[DeepSeek预设资格](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/deepseek_motion_planner.dart#L73)、[菜菜资格与每拍眼部](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/caicai_motion_planner.dart)、[共享JEV裁决](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/jev_decision_gateway.dart)。

建议：先补齐DeepSeek各附加层的具体含义及轻微反应资格，保持爱心眼和有意wink的语义边界，不强制每轮有特殊表情。按同类对话比较use/type/最终原生接收，区分“未选中”“选中后未播”“播放很短”。开场眼部是否增加独立动作，可单独决定，避免与完整wink抢眼睛。

### 语音衔接和观察限制

两模型都会在真实音频已经开始时跳过迟到的开场四拍，转由语音段动作承担；该策略保护口型和同步。不能把跳过开场本身当作DeepSeek专属故障。
长回复最多8语音段，完整目录情况下DeepSeek最多107个JEV题，菜菜95个，共用8秒请求超时。题量差异是后续诊断点，不证明接口已经超限或失败；不据此直接放宽超时或追加模型重试。

## 二、第一通道缓存与查手机

### C1. 经验整合器的动态前置仍挡住长固定契约

[memory_extraction消息顺序](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/memory_extractor.dart#L419)在固定长JSON契约之前放入：
1. 条件出现的后台旧经历提示；
2. 含`roomOutcomes`的系统事实/工具来源段；
3. 含`creativeFacts`和`creativeSnapshot`的作品事实段；
4. 才是经验整合固定契约和用户可编辑记忆规则。

当工具回执或作品上下文变化，后面的固定长契约无法作为完整共同前缀继续复用。它并不说明缓存改坏了记忆，而是此前优化尚未覆盖这条高频调用的早期动态片段。

建议拆出固定来源/能力契约和固定JSON要求放在前面，将本轮回执、作品事实、条件提示及当前对话放后面，保留全部来源、事实优先级、用户可编辑规则、角色和时间。不能删除实际作品回执来换取命中。

必须验证：动态材料变化时固定前缀不变；真实回执和新对话仍进入请求；旧引用、QQ资料、作品事实和用户新表达的记忆准入规则不变。遵守DeepSeek的实际前缀缓存规则，最终用`prompt_cache_hit_tokens`/`prompt_cache_miss_tokens`评估，不按提示词字符数承诺省费。

### 查手机八栏目逐项结论

| 栏目 | 生成/读取方式与当前人设 | 检查结论 |
| --- | --- | --- |
| 相册 | 查看已有图片本地进行；新增收藏用观察/收藏契约、形象特征和弱审美偏好 | 没有整套聊天人设；较长部分主要是像素证据/收藏业务规则 |
| 浏览器 | 已有浏览记录本地展示；获取网页和价值判断在外部发现链完成 | 不因查看列表重新模拟浏览或调用完整人格 |
| 随笔 | 固定身份/写作规则+一条真实派生日常素材+最近10条随笔 | 已轻量；保留近期重复约束，不能为缓存复用旧随笔 |
| 心情 | 简短身份+当日欲望/情绪/少量真实日常摘要+近期正文 | 已轻量、非思考，maxTokens420；不加载整套人格 |
| 愿望单 | 界面刷新仅迁移/投影；后台WishEngine按来源维护 | 没有整套聊天人设；长提示主要是完成/暂停/去重等事实契约 |
| 日记 | 固定身份/日记契约+真实日连续性资料+最近7篇 | 已轻量、非思考；固定任务说明在变化资料之前 |
| 购物车 | 短角色种子+固定商品结构+近期标题/日期/nonce | 已轻量、非思考；不读聊天/Memory/Desire/人格学习/AI Self |
| 塔罗 | 简短身份+固定解读契约+当天两张牌义 | 已轻量；两张牌一次请求，不每次翻页重新抽牌 |

来源：[手机仓库及刷新入口](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_phone_repository.dart#L415)、[只读手机工具](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_phone_reader.dart)、[日记生成器](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_diary_generator.dart#L135)、[随笔生成器](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_note_generator.dart#L90)、[心情/塔罗](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_phone_reflection_generator.dart#L70)、[购物车](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/phone/simulated_cart_generator.dart#L45)、[愿望评估](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/wishes/wish_engine.dart#L40)、[图像观察契约](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/core/ai/qwen_vision_client.dart#L301)。

重要区分：打开手机总入口会运行有到期判断的刷新协调器，可能恰好触发尚未生成的栏目；并不是点击每一个本地列表都完全不可能伴随后台生成。`phone.search/read`本身使用只读快照，没有为了查看记录再次生成。用户在聊天里让她评论手机内容，最终正文仍需要正常人格；不能因工具读取是只读，就同时砍掉正文人格。

### 继续省费的可选项，尚未修改

- 普通手机展示维持现有轻量身份。可以统一很短的基础称谓/口语风格种子，但不是给每项补完整人格，也不应为提高缓存率故意填长提示词。
- WishEngine每次送出active愿望和最多116条非active愿望的完整`toJson`；包含多个时间、证据和进展字段。后续可把历史去重摘要与真正需要更新的条目分开，保留原目标/状态/用户手动暂停等约束。它是资料体积机会，不是重人设问题；错误精简可能让旧愿望复活，不能直接删掉历史。
- 日记带最近7篇、随笔最近10条用于避重复；若以后压缩，必须保留当前篇章的重复判断信息，不能只按条数一刀切。
- 购物车/塔罗/心情大多一天一次或有限修订，固定段较短、跨请求间隔较长，缓存可命中不等于必命中。缺失命中也不能直接定性为缓存失效。
- 当前指南重排、愿望/作品材料稳定排序、工具schema规范化均保留了实时材料，未见把旧模型答案缓存后当新结果的实现。游戏每步真实局面和回执继续更新；不建议为省费降低现有Agent动作权限。
- 缓存顺序优化与避峰调度是不同问题。查手机展示并未统一受避峰控制；如考虑让昨日记补写等非即时工作离峰执行，应单独决定，不能直接延迟用户正在等待的内容。

## 三、QQ

### Q1. 明确未送出的首段临时失败，不会自动重试

位置：[运行时异常/重试分支](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/integrations/qq_private/qq_runtime.dart#L536)、[投递包装](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/integrations/qq_private/qq_reply_delivery.dart#L105)、[临时失败分类](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/lib/integrations/qq_private/qq_failure.dart#L44)、[token获取及发送](https://github.com/catkiss62/ai-companion-build/blob/c176e1f17b232a73dca6e945ae7aca92dccf273b/app/packages/qq_private_bridge/lib/src/qq_api.dart#L68)。

生产路径：
- `QqReplyDelivery`只有已有投递确认后才把后续异常包装为`QqDeliveryFailure`。首段前获取token失败，通常直接抛出`QqApiException('network'/'timeout', uncertain:false)`；平台明确HTTP429也可确定未投递。
- Runtime会把这种情况标为`failed`，且失败分类器将其判为可重试。
- 但发送阶段还要求`knownUnsentSend=true`；该变量只接受`QqDeliveryFailure`。
- 包装异常的state又只会是`partially_sent`、`send_uncertain`或`sent_archive_failed`，无法满足外层`state=='failed'`。
- 因而发送阶段的自动重试路径事实上不可达。没有设置重试元数据的failed任务，不会被5秒恢复轮询自动捡起；新用户消息仍可触发接续。

这可以解释一类“生成好了，临时故障后不再尝试”的现象，但不是对用户此前所有网络故障的归因。

建议仅放行无任何已确认/继承投递、无unknown标记、明确未上行/明确拒绝的临时错误，保留原消息有效期、来源、配置与存档代次，复用现有有限退避。结果未知不重发，部分成功不整轮重播，归档失败只补本地提交。

必要新增回归：通过真实Runtime而不只测`retryable/defer`；首段token临时失败及HTTP429可以恢复，首段已上行超时/5xx不重发，第二段失败不重复第一段，归档失败不重发，存档冻结后恢复仍核验原来源和期限。
既有`qq_stability_v042155_test.dart`检查了失败分类和恢复器，但没有覆盖这个生产分支组合，所以“各单元都通过”仍可漏掉此漏洞。

### 其他核对结果与保留边界

- @她：可信`GROUP_AT_MESSAGE_CREATE`进入直接提及路径，平台is_you与已知本群ID也有独立识别；群聊异步判断后重读提及，即使初判watch仍可纠正为direct。没有再次发现“官方机器人不能被@”的代码依据。实际平台事件仍需对应诊断确认。
- 普通接话：direct/continuing优先于普通插话频率；休息、群开关、每小时120条等宿主边界仍在，并非所有@都无条件强制发言。
- 生成：第二通道两次尝试后回第一通道；流式草稿全部生成完成才交投递，避免半截正文跨通道重复。
- 恢复：普通备份期间入站事件用本机队列暂存，解冻后同身份/同策略且有效期内才重入；导入/换档不能重放旧出站。sending孤儿标unknown，保守不重发。
- 图像/语音：QQ识图当前显式第一通道；SVG异常保留分类和可读失败提示；QQ语音继续使用模型选定参考档位，普通形态音高为保存值-1半音，未发现本轮检查导致回退。
- 群资料与私人资料：主库只读连接、群与私聊身份分离、群友不认主等边界保留。本轮不是全面安全审计，不宣称QQ没有其他问题。

## 下一次实施建议

先补Q1生产路径回归并修复；再做C1的固定/动态消息拆分并验证事实契约不变；随后对DeepSeek附加层说明与持续时间做局部对齐。现有头身幅度、普通wink期限、PCM嘴型所有权、双模型存档和第二/第三正文链路不整体重写。
历史愿望资料精简属于单独可选优化，先验证去重/暂停/满足/完成语义，不与上述小修捆成全面重构。
