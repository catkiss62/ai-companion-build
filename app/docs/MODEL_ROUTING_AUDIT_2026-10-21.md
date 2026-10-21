# 模型来源全量审查 · 2026-10-21

后续状态：用户已授权按方案实施，+367候选已将下表调用改为显式配置来源。以下各节保留审查时的证据和讨论经过，最终验证以唯一总账+367交付记录为准。

状态：只读审查与修改范围整理。唯一已做的后续功能修改仍是DreamEngine本地模型来源调整；以下26处固定Flash尚未修改/测试/推送。已交付+366不含后续梦境修改。

## 已确认范围

扫描主项目Dart实际调用点、model/modelName赋值与DeepSeekModelProfile常量，交叉检查原生Java/Kotlin、辅助脚本/网页及配置。未把测试样例、旧文档、费用映射、模型选项和历史消息中的模型标签计为线上固定调用。不能只搜deepseek字符串：大多数调用通过DeepSeekModelProfile.flash间接固定。

当前本地代码仍有21个文件、26处请求点固定Flash（deepseek-v4-flash）。用户安装的+365另有梦境1处固定Pro，总计27处；梦境本地已按授权改成作品优先、未设回落第一通道，尚未交付。下表行号以本轮审查时源码为准。

| 文件 | 行号 | 请求职责 |
|---|---|---|
| app/lib/core/agent/agent_tool_runner.dart | 1118 | 游戏工具结果后续判定 |
| app/lib/core/ai/memory_extractor.dart | 397, 907, 1840 | 记忆提取/证据评审等三个请求点 |
| app/lib/core/ai/message_language_variant_service.dart | 79 | 聊天正文翻译 |
| app/lib/core/ai/nsfw_context_router.dart | 280 | 普通聊天短判断的DeepSeek路径 |
| app/lib/core/ai/playful_breakthrough_judge.dart | 66 | 形态/突破短判断的DeepSeek路径 |
| app/lib/core/ai/playful_self_judge.dart | 111 | 自我反应短判断的DeepSeek路径 |
| app/lib/core/ai/playful_turn_judge.dart | 86 | 用户交互短判断的DeepSeek路径 |
| app/lib/core/ai/reasoning_translation_service.dart | 166 | 思考摘要翻译 |
| app/lib/core/autonomy/public_web_deepseek_appraiser.dart | 65 | 网页候选评估 |
| app/lib/core/autonomy/public_web_question_planner.dart | 52 | 联网检索问题规划 |
| app/lib/core/desire/proactive_engine.dart | 1703 | 普通主动正文及第二通道失败后的兜底 |
| app/lib/core/immersive/immersive_nsfw_router.dart | 170 | 沉浸短判断的DeepSeek路径 |
| app/lib/core/mcp/cedar_toy_autonomy_engine.dart | 141, 319, 2394, 2568 | 游戏判断/表达/房间发言兜底等四个请求点 |
| app/lib/core/memory/memory_query_expander.dart | 14 | 记忆检索查询扩展 |
| app/lib/core/phone/calendar_reminder_followup.dart | 152 | 日历提醒后续正文的DeepSeek路径 |
| app/lib/core/phone/simulated_cart_generator.dart | 55 | 购物车 |
| app/lib/core/phone/simulated_diary_generator.dart | 144 | 日记 |
| app/lib/core/phone/simulated_note_generator.dart | 99 | 随笔 |
| app/lib/core/phone/simulated_phone_reflection_generator.dart | 81 | 查手机后反思 |
| app/lib/core/reflection/deep_reflection_engine.dart | 57 | 深层反思 |
| app/lib/core/wishes/wish_engine.dart | 49 | 愿望整理 |

上述短判断中部分仅在Jev未启用/不可用时走DeepSeek，并非每次都调用；第二通道正文分支有modelName覆盖，固定Flash主要影响单通道及DeepSeek兜底。仍应读取明确的第一通道模型配置，不能假定Flash是用户选择。

## 不能误判成强制调用的常量

- model_profile.dart的Pro/Flash枚举是可选项；chat_controller/settings_category_pages的字段初始值随后被设置覆盖。
- app_database.dart的新安装/旧数据默认、GenerationJob.fromDb缺model时默认Pro，是遗留兜底值，需要统一默认策略；不是本次每次都暗中使用Pro的证据。不能改写已有任务/消息中保存的真实模型历史。
- reasoning_translation_service与calendar_reminder_followup另有固定Flash元数据，统一请求模型时应同步改来源记录，避免调用与诊断不一致。
- 作品创建/导入的deepseek-flash只在作品模型为空时补默认，正常作品执行使用任务快照model。普通正文/Agent主要使用job.model；模型对谈、沉浸和归档已有设置或任务/房间模型快照，应保留进行中任务的语义。
- Gemini、Qwen、Agnes的常量是空配置默认，各自有已核实的配置读取和请求覆盖路径，应保留独立通道。
- JevDecisionGateway固定typesafe/jev-1.13并请求专用decisions协议，是有意的专用短判断服务，不能替换成第一通道DeepSeek聊天模型。应与本轮通用DeepSeek配置缺口分开。

## 统一修复方向（待实施）

通用DeepSeek请求读取deepseek_model；必要时兼容旧model，再使用统一默认。作品制作和梦境使用creative_work_model，未设回落明确的第一通道；作品任务/生成任务已入队模型快照保留。第二通道/识图/网页阅读/Jev继续各自的来源，不对全项目做字符串盲替换。无DB的翻译、查询扩展等网关需要显式传入解析后的模型，而非让底层客户端静默覆盖所有请求；后者会误覆盖作品/房间的明确模型。验证应覆盖自定义模型名、单通道、第二通道失败回落、独立作品模型及真实请求载荷与诊断一致。

## 单DeepSeek未发送的新证据

07:48:40Z报告及07:48:33Z存档仍为+365，配置已是deepseek。15:32:03、15:34:51、15:42:48、15:46:11、15:46:19五次主动记录decision=wait；源码该值在gateScore<threshold的正文请求之前写入，与调用后model_wait不同。最新presence_last_gate_breakdown：gate=0.580、threshold=0.590、busy=true、busyMultiplier=0.72、frequencyPenalty=0.275；配额仍有余量。此份记录没有新的单DeepSeek主动正文请求，旧Gemini请求/成功字段保留的是13:13历史，不能证明还偷偷走第二通道。也不能拿这些wait归因于模型别名失败。本次未测试供应商别名是否等价，不把别名视作已证实错误。

她的内心页现有“测试主动找我”调用evaluate(forceForDebug:true)，可跳过自然发送评分/额度门进行一次实际生成测试；运行状态/来源/用户轮次等保护及模型WAIT仍可阻止，UI会显示没有发送的具体原因。这是实际模型/聊天测试，不是纯本地通知测试，不承诺不消耗额度或不留下消息。

## 第二通道异常内容的处理判断

两个独立读档样本均由第二通道正常结束后发出：一种是选项控制格式，另一种纯文字解释内部生成任务。主问题是任务执行偏离角色正文，标签只是表象。多system主动提示缺真实user时，FinalReplyRoute.prepareMessages补一条60字内部user封装；样本与该封装语义对应。不能仅凭同版本突然异常证明全是供应商或全是本地原因，也不能证明实际底层模型身份。

不建议给每条普通/主动回复新增一次Jev网络判断：增加请求和延迟，短判断本身也可能误判正常元讨论，且不能修复上游的任务理解。优先定位主动任务封装的角色/收信人和执行动作；若补防护，应局限于明确的内部指令复述、流程菜单等异常，把失败候选留在私有生成阶段，按既有重试/兜底处理，不直接删标签后发送，不把异常正文当正常消息计次数/满足欲望/提取记忆。已落库异常消息的清理不能盲改真实历史。

可先暂缓每轮Jev审核和广泛风格规则，换正常通道并用现有测试入口对照。若上游恢复且问题消失，可以暂缓扩大正文检查；统一模型来源、明确失败诊断仍值得修。持续每次异常时，应局部处理主动封装/不可用输出，不能长期把此类内容发送给用户。以上处理方案尚未改代码，等待与用户确定的修改范围统一实施。

本轮为源码/附件检查，没有调用真实付费模型、没有跑新的Flutter/CI/真机，不以先前+366的CI通过为后续修改背书。私有诊断和存档不入仓库。


## 08:12样本后续与用户暂缓决定

用户明确固定Flash通用调用必须跟随第一通道可变模型，并新增本轮手动切DeepSeek的生成状态按钮；这两项先记录、继续讨论后再实施。新样本普通追问也出现同一第二通道混合角色/技术助手正文，排查范围已超出主动封装；另确认前置Jev工具子题冲突触发房间目录。完整后续见SECOND_CHANNEL_ANOMALY_REVIEW_2026-10-21.md，不以本报告先前的“仅主动任务封装”假说定案。


08:21回档样本追加：16:19单通道主动使用deepseek-v4-flash成功，16:20普通第二通道回复也成功、未回落。别名在此样本被接受，固定模型配置缺口仍须统一，不能把此前wait解释成别名错误。Jev主/子题均同批Jev，用户容忍无害误查；跨题冲突的执行合并策略仅记待议，不做额外每轮审核。新增修改仍按用户要求暂停实施。


最新讨论收敛：异常主动任务和Jev无害误查均暂不实施行为改造。固定模型统一、梦境及手动接管的完整待实施方案见MODEL_ROUTING_AND_MANUAL_FALLBACK_PLAN_2026-10-21.md；仍未开始26处批量修改。
