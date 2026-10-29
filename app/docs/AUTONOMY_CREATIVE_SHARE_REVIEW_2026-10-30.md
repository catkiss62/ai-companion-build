# 自主创作与自主分享定向复查 · 2026-10-30

后续状态：F1/F2已随+397交付，实际Dart回归与完整CI已通过，见[实施记录](SPEED_SHARE_IMPLEMENTATION_v042153.md)。下文保留+396审查时的事实与合成证据，不将历史复现当作当前版本结论。

状态：复查完成，确认两组逻辑缺口；仅更新文档和合成复现脚本，未修改运行源码、版本、配置、用户存档或工作流，未新建 CI/APK。

基线：v0.42.152+396 / schema67 / `740536e3547a85f82f3fbc4258656e9225aeda32`，分支 `agent/v042107-review-recovery`。本地可用旧快照的创作、分享存储及数据库逻辑，经 GitHub 比对确认与 +396 一致；主动引擎的 +396 差异仅为第三通道诊断接线，另定点读取当前相关领取代码。没有把本地旧版本误当当前安装版本。

## 当前样本与作品恢复

私有样本中两件作品均为 ready，原自主作品也已经 shared，没有 queued/building/checking/paused/failed 工作。自主创作开关开启，构思状态 suspended=false；next_at 已更新，符合现有每六小时一次的成功评估间隔。目前没有“待恢复工作被遗漏”或“成品一直没发出”的样本证据；最近没有新增作品，不能直接判作故障。构思保留旧 building 标签表示该构思已经开工，实际制作以作品元数据为准，不把它当还在运行的任务。

| 情况 | 当前行为与依据 |
|---|---|
| 已登记的用户委托 | 工作轮询独立于普通聊天，继续制作，不要求重新打开深度思考 |
| 自主工作遇到聊天或非空闲窗口 | 工作状态和文件保留，空闲且原权限有效时继续；前提是 App/后台引擎有运行机会 |
| 临时请求错误 | 有界退避后仍 queued，重试到期自动继续 |
| 明确暂停、配置/余额错误、运行或连续错误上限 | 进入 paused，不会被轮询自动拉起；明确继续才重新排队 |
| 导入恢复导致的暂停 | 保留文件但撤销旧执行/试玩权限，需要明确继续；自主设置页已有“继续暂停的自主创作” |
| 已 ready 的作品 | 不重新制作；自主私存作品由独立分享机会决定是否送出 |

入口：CreativeContract.active、CreativeWorker.runOnce、CreativeStore._control/resumeAutonomous、CreativeAutonomyFence、CreativeContract.normalizeImport。继续会重置本次 attempts 和错误恢复计数，同时保留已有文件与工具回执；没有发现“上限暂停后一按继续又立即因旧 attempts 暂停”的问题。

## 分类覆盖与样本边界

| 来源 | 本轮结论 |
|---|---|
| 普通念头：用户对话、旧记忆、自身经历、感知和内部状态 | 核对 readiness、休眠/暂缓与提交后消费链，未确认新增缺陷；强度不足或处于休眠不等于没有心跳 |
| 网页候选 | 临时读取失败的有界恢复和租约超时回收仍在；新增 F1：失效 ready 绑定可阻塞后继候选 |
| 游戏经历和任务回报 | 独立送达凭据、提交及队列确认仍在，近期样本有成功送达；未确认新增问题，不改变三步/30分钟和分享预算 |
| 自主作品 | 样本没有暂停积压；私存等待/失败的两小时 share_after 不把作品变为已送达；消息和公开可见性在一个事务提交 |
| QQ群见闻转本人 | 新增 F2：App 领取后未送达路径缺少结算；QQ直接入口的明确 WAIT 已有 skipped 处理，不能混为同一缺陷 |
| 愿望 | 选择后记录表达尝试，未送达保持未表达；一天联系尝试间隔与来源状态围栏属于既有规则，未确认新增阻塞 |
| 深层反思邀请 | 原状态/重置边界复核和邀请间隔仍在，未确认新增阻塞 |

最新网页样本没有 share_staging/share_ready 占位，最近一批为 history_only，因此本次“没分享”存在正常未入选的解释。样本中的 QQ 记录也没有残留 claimed。以下是源码与合成状态反例，不能宣称该手机已经触发。

## F1 · 网页 ready 候选的绑定念头失效后，仍占用唯一分享槽

**确认：源码链路 + 真实 SQLite 查询反例；不是手机事故复现，尚未运行新增 Dart 回归。**

触发：候选仍 share_ready、verified、valid、未过期，但绑定 Thought 被删除，或已经 dormant/被暂缓。候选本身继续满足 activeReadyPublicWebShareCandidate。

1. activeReadyPublicWebShareCandidate 只查候选状态，没有关联核验 Thought。
2. ProactiveEngine 找不到 Thought 时不修复占位；找到 dormant Thought 时虽补入列表，DesireCorePolicy 仍用 canDriveIntentAt 排除。
3. nextPublicWebCandidateForSharing 见到 ready 就返回 null。
4. claimNextPublicWebCandidateForSharing 也被该 ready 行挡住。
5. deleteThought 只删 Thought 及其关联审计/反馈，没有退出网页 ready 占位。自然休眠也没有对应回收。

影响：旧候选不能进入其专用分享路径，新 unread 候选又不能准备；通常要等候选过期才能解除。影响网页分享入口，不代表普通主动消息或其他分享全部停止。

反例：missing、dormant、snoozed 三种情况下，新候选均不可达；active 绑定仍能正常竞争，expired 占位不再挡后继。现有 +392 的读取失败恢复覆盖的是“准备候选之前/过程中”，不覆盖此“准备完成后绑定失效”边界。

建议修复：就绪候选和绑定 Thought 作为同一有效队列项核验；失效项按原因退出占位，允许下一项竞争。尊重明确删除、休眠、暂缓、拒绝与已分享事实，不通过强行重建/唤醒旧念头解决。补删除、休眠、暂缓、有效绑定、过期及正常送达的生产 Dart 用例。

源码：app_database.dart 的 activeReadyPublicWebShareCandidate、nextPublicWebCandidateForSharing、claimNextPublicWebCandidateForSharing、deleteThought；proactive_engine.dart 的 readyThought 注入；DesireCorePolicy.candidates 与 CompanionThought.canDriveIntentAt。

## F2 · App 领取QQ群见闻后，WAIT/抢占/失败路径可留下 claimed

**确认：源码链路 + 真实 SQLite 状态反例；最新私有样本未见该状态，尚未运行新增 Dart 回归。**

触发：ProactiveEngine 选中 qq_group_share，在生成正文前 QqShareStore.claim 把 pending 改为 claimed、destination=app；随后 WAIT、用户抢占、接口异常或提交拒绝，未完成本地消息事务。

App 的 WAIT 分支只处理网页候选；退出清理只释放待发送媒体与主动租约，没有结算本次 QQ offer。QqShareOffer 仅有 matches/delivered，App 没有对应未送达释放/跳过路径。

影响：
- claimed 计入全局 QQ 见闻分享六小时阻挡条件，可能压住其他见闻候选。
- 六小时后阻挡自然解除，但原记录仍不是 pending，原候选不会自行恢复。
- App 本地消息提交与 sent 状态原本在一个事务中，故明确未提交路径可以和真实 QQ 外发未知结果区分。

反例：WAIT 与 preempted 均留下 claimed，其他候选被暂时挡住，七小时后原候选仍不能再次入选；真正 sent 的对照仍保持终态，不应重发。QQ直接分享入口本身已经把明确 WAIT 改为 skipped。

建议修复：按本次领取身份结算。明确 WAIT 与 QQ 入口保持一致地跳过；生成失败/用户抢占在可证明未提交、未外发时有界释放或延后。迟到清理不得释放后来的新领取。sending/send_uncertain/sent_archive_pending/sent_archive_failed/sent 等真实或未知投递状态保持防重，不恢复为 pending；不新增 QQ 聊天固定冷却/配额。

源码：QqShareStore.candidates/claim，QqShareOffer.matches/delivered，ProactiveEngine 的 qqShare 领取、WAIT/早退/finally，AppDatabase.commitProactiveMessageIfCurrent；QQ直接入口 QqRuntime.shareToOwner 作对照。

## 验证与限制

合成脚本：[autonomy_share_review_20261030.py](review_fixtures/autonomy_share_review_20261030.py)，只读必要源码并在内存 SQLite 使用生产查询条件，九组场景/对照通过预期。脚本不读取用户备份、真实QQ群、凭据或网关，不调用付费模型。它证明 SQL/状态交错反例，不等同于 Flutter/Dart 端到端测试。

既有 +396 的 3180 全量、171 恢复、54 Android15 和其他专项成绩仅为基线证据，不能当本轮两个新边界已修复/已通过。运行代码和版本未变，无新增 APK。

## 网络约束与后续入口

手机位于中国地区，时开时关其他 VPN；方案以不依赖手机常驻组网的普通 HTTPS 公网入口为主。2026-10-30 补充澄清：现有 Funnel 本身就是公网 HTTPS 入口，手机访问不要求安装或开启 Tailscale/VPN；Android 单 VPN 的冲突只针对手机自己加入 tailnet，不能用来否定现有 Funnel。当前先保留已跑通入口，自建公网节点反向隧道作为对照候选，分别验证手机开、关 VPN 的表现，有实测收益再迁移；不承诺换工具必然加速。接续事项见[网络取舍与待办清单](THIRD_CHANNEL_SPEED_AND_SHARE_HANDOFF_2026-10-30.md)。

检索和完整网页读取耗时由用户明确接受，保留按需 Agent 查证能力。前轮的“第三退出识图、App按千问开关/QQ第一识图”及“第三连接复用/短期探活成功缓存/同池预热”仍为讨论方案，未实施。下一轮若获准修改，可把 F1/F2 作为独立修复包，严格保留正常 WAIT、真实送达防重与各来源原预算。

