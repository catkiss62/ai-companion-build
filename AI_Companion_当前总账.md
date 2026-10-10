# AI Companion · 当前总账

更新时间：2026-10-11（+338 IMPLEMENTED / CI PENDING；+337 CI PASSED / APK READY / TRUE DEVICE PENDING；+336 CI PASSED / APK READY / TRUE DEVICE PENDING；+335 CI PASSED / APK READY / TRUE DEVICE PENDING；+334 CI PASSED / APK READY / TRUE DEVICE PENDING；+333 CI PASSED / APK READY / TRUE DEVICE PENDING；+332 CI PASSED / APK READY / USER EAR PLACEMENT ACCEPTED；+329 CI PASSED / APK READY / TRUE DEVICE PENDING；+328 CI PASSED / APK READY / TRUE DEVICE PENDING；+327 CI PASSED / APK READY / TRUE DEVICE PENDING；+326 CI PASSED / APK READY / TRUE DEVICE PENDING；+325 CI PASSED / APK READY / TRUE DEVICE PENDING；+324 CI PASSED / APK READY / TRUE DEVICE PENDING；+323 CI PASSED / APK READY / TRUE DEVICE PENDING；+322 CI PASSED / APK READY / TRUE DEVICE PENDING；+321 CI PASSED / APK READY / TRUE DEVICE PENDING；+320 CI PASSED / APK READY / TRUE DEVICE PENDING；+319 CI PASSED / APK READY / TRUE DEVICE PENDING；+318 USER DEVICE ACCEPTED；+317 CI PASSED / APK READY / TRUE DEVICE PENDING；+316 CI PASSED / APK READY / TRUE DEVICE PENDING；+315 CI PASSED / APK READY / TRUE DEVICE PENDING；+314 CI PASSED / APK READY / TRUE DEVICE PENDING；+313 CI PASSED / APK READY / TRUE DEVICE PENDING；+312 CI PASSED / APK READY / TRUE DEVICE PENDING；+311 CI PASSED / APK READY / TRUE DEVICE PENDING；+310 CI PASSED / APK READY / TRUE DEVICE PENDING；+309 CI PASSED / APK READY / TRUE DEVICE PENDING；+308 CI PASSED / APK READY / TRUE DEVICE PENDING；+307 CI PASSED / APK READY / USER DEVICE ACCEPTED；+306 CI PASSED / APK READY / TRUE DEVICE PENDING；+305 CI PASSED / APK READY / DEVICE REPORTED REPLY STALL；+304 CI PASSED / APK READY / TRUE DEVICE PENDING；+303 CI PASSED / APK READY / TRUE DEVICE PENDING；+302 CI PASSED / APK READY / TRUE DEVICE PENDING；+301 CI PASSED / APK READY / TRUE DEVICE PENDING；+300 CI PASSED / APK READY / TRUE DEVICE PENDING；+299 CI PASSED / APK READY / TRUE DEVICE PENDING；+298 CI PASSED / APK READY / TRUE DEVICE PENDING；+297 CI PASSED / APK READY / TRUE DEVICE PENDING；+295 恢复真机成功、背景回归 PARTIAL；+293 DEVICE VISUAL BASELINE）

> 本文件是唯一的当前接班入口，继续采用“总账 v2”。顶部是快速接班索引；标记后的正式记录按版本持续追加，不设总容量上限。
>
> 判断优先级：用户最新明确决定 > 当前 GitHub 源码与 Actions > 同时刻脱敏真机诊断/备份 > 本文件 > 冻结归档与 Git 历史。`DESIGNED`、`IMPLEMENTED`、`CI PASSED`、`APK READY`、`TRUE DEVICE PASSED`、`PENDING` 必须严格区分。



## 当前任务 · +338 游戏意图连续性（IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING）

用户授权1–4及Android 8低风险修复。0.42.94+338，agent/v04294-game-intent-continuity；范围和验证见app/docs/GAME_INTENT_CONTINUITY_v0.42.94.md。小作品/梦境第6项仅讨论，梦境是标题美化，不制造做梦事实。+337用户已反馈正常。本轮不增加普通聊天逐轮Agent，私密备份和诊断不入库。

## 当前交付 · +337 相关网页读取与近期发现（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户授权相关网页重读优化及兴趣驱动近期发现；不降低完整阅读质量，不增普通聊天逐轮Agent。偏好形成与工作区只审计讨论。基线+336/8085b22，agent/v04293-web-relevance-recency，目标0.42.93+337。方案、偏好审计和验证入口app/docs/WEB_RELEVANCE_RECENCY_v0.42.93.md，证据见文末。完整38028661621/专项38028661659成功，150源码/1478全量/528专项/29原生及资源签名通过；同签名未发布APK已就绪。

## 前次交付 · +336 表情面板读取优化

CI PASSED / APK READY / TRUE DEVICE PENDING。完整37983371136/专项37983371114成功；150源码/1469全量/483专项/29原生及资源签名通过。详细交付见文末及app/docs/STICKER_PICKER_SPEED_v0.42.92.md。

## 前次交付 · +335 表情图库共享原图（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-10用户授权实施。基线+334，agent/v04291-shared-stickers，目标0.42.91+335。图库与聊天共用内容寻址原图；迁移先校验/提交引用再删副本，发送不经普通图片草稿。保护删包、重导入、删除消息和恢复备份边界；保持当前备份不携带完整图库的决定。设计/验证入口app/docs/SHARED_STICKERS_v0.42.91.md；后续其他任务仍从6.3读取。本轮未获真机通过，不上传用户备份或诊断。 最终源码6cf1b72；完整37960129667、专项37960129742成功，1460全量/474专项及资源签名通过。同签名未发布APK与SHA见文末+335最终交付。

## 前次交付 · +333 右耳定版

0.42.89+333，CI PASSED / APK READY / TRUE DEVICE PENDING；参数和交付记录见app/docs/RIGHT_EAR_PLACEMENT_v0.42.89.md及文末。

## 前次交付 · +329（CI PASSED / APK READY / 待办提醒USER DEVICE ACCEPTED）

0.42.85+329，源码8513ea5，完整37713200224成功；428专项、29原生通过，右下角小卡/来电音量和缓存诊断已交付。下载与失败路线保留在文末及app/docs/REMINDER_COMPACT_CACHE_v0.42.85.md。用户仅确认待办提醒正常，不外推全部真机边界。

## 当前交付 · +328 系统待办确认（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.84+328，agent/v04284-reminder-confirmation，源码deba3136bc2dc61ecaa7754d99136fea703478d0。深色紫色确认卡片、最长5分钟；到点发起不占主动次数的提醒，秒确认保留初次提醒，用户实际发消息取消未发提醒。确认/超时供后续对话理解；响铃及实际结束后10分钟暂停普通主动聊天。支持每日/自定义星期/每年/仅一次及启用开关，多个发生记录独立，系统调度不依赖AI开关。完整37673051886/专项37673051744成功：149源码、1424全量Flutter、424专项、26原生；APK同签名未发布，已提供直链。下载、签名及边界见文末和app/docs/REMINDER_CONFIRMATION_v0.42.84.md；HyperOS锁屏/浮窗/实际响铃及网络行为仍待用户真机验证。+327尚无新增真机验收。

## 前次交付 · +327 背景逐帧平滑（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.83+327，源码6dbde7c49a96f732a8f35975b2461ec27ac1e077，最终文档44f8e57。姿态请求60Hz及Flutter/native显示帧35ms平滑，静止停ticker；原效果幅度保持。完整37650541415/专项37650541791成功，149源码/1413全量/413专项/22原生。下载、签名和真实验证见文末及app/docs/BACKGROUND_SMOOTHING_v0.42.83.md；用户设备FPS/手感仍待验收。

## 前次交付 · +326 背景Device Motion（CI PASSED / APK READY / DEVICE REPORTED BACKGROUND LOW FPS）

0.42.82+326，agent/v04282-device-motion，源码b3258c94f2c8d379dd1a571d0021fcecb41a3d6f；Flutter/Live2D整体移动叠加深度，沿用开关和强度，边缘预留通过。完整37637286301、专项37637286323成功，149源码/1409全量/409专项/21原生通过。用户报告背景不够顺滑、人物正常，现由+327修复更新节奏；此前+325深度观感已获认可。+326下载、SHA/签名、参考APK和完整验证见文末及app/docs/DEVICE_MOTION_v0.42.82.md。

## 前次交付 · +325 新版立体背景入口（CI PASSED / APK READY / 立体观感单项TRUE DEVICE PASSED）

0.42.81+325，agent/v04281-depth-settings-entry，源码4df64d8c7a099de60fe8317ea10c6a7674b6152d。修复默认Material3聊天画面缺少开关，真实SQLite保存/重进通过；完整Actions37619987572、专项37619987582成功，1407全量/407专项/20原生通过。用户21:40确认立体效果不错；当时整体平移尚未实现，现由+326补齐。耗电和长期表现待观察。该轮构建约24分钟，主要耗在测试/资源/编译；远程Git读写有等待，但无证据将全部停滞归因于总账。完整交付、哈希、根因和反馈见文末+325正式记录及app/docs/DEPTH_SETTINGS_ENTRY_v0.42.81.md。

## 当前接班快照 · +324 立体背景与旧连接清理（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-07 用户授权的两项已完成并交付：`v0.42.80+324`，分支 `agent/v04280-depth-background-cleanup`，交付源码 `d6314bd3d0701bc81509d5a1de9fc9e41c48a422` / tree `de20d265b84bf70d96d5b7122e49c7be36b78ada`。Nearby专用入口、传输、依赖和权限已移除；页面改为“备份与恢复”，保留.aibackup、旧包兼容、手动换机及共用恢复/身份围栏。原日夜背景新增可开关深度视差，默认关闭、强度55%，普通立绘与原生Live2D均接入；页面离开/后台停用，重新进入校准，人物与文字不参与位移。完整审查范围见 `app/docs/DEPTH_BACKGROUND_CLEANUP_v0.42.80.md`。

完整Actions `37612706122` 与专项 `37612706291` 成功：149项源码门、1406项全量Flutter、406项专项、20项Android35原生及Kotlin/签名/资源检查通过。[同签名未发布+324测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6662961f1fda0dcaf434)已就绪；文件哈希、失败路线与交付证据见文末“+324 最终CI与未发布APK交付”。仅CI通过，立体观感、耗电与实际设备备份操作仍待真机观察。未合并main、未正式发布。

用户确认+323小豆丁恢复本体后仍自称小豆丁的问题已解决（本项TRUE DEVICE PASSED）；其余长期效果继续自然观察。旧手机平板伴随路线取消；未来独立平板陪玩App与手机同步同一条台词、手机提供聊天入口，另案设计，本批未实现。闪退仍缺堆栈，不猜修。下一步承接+324真机反馈，其余从本总账6.3和对应任务文档定点读取，不恢复已取消路线。

## 前次交付 · +323 游戏授权、愿望自主处置、滚动与形态事实（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-07 14:22 用户要求核对上下文后完成其余修改和 APK。分支 agent/v04279-wish-chat-fixes，基线+322，目标0.42.79+323。范围见 app/docs/WISH_CHAT_FIXES_v0.42.79.md：仅 Jev 游戏授权同方向合并，愿望既有评估允许有证据的自主暂放/放下和主观向往满足，最终消息布局收敛滚动。自主性浅约束明确不做；人设、梦境、愿望生成、桌宠和 Live2D 保持；不新增逐轮规划、不改游戏分享次数。不新建第三总账。追加正常形态历史污染修正（仅实时形态事实，不改性格/气焰规则）。14:40:57主进程crash有记录但无堆栈，根因未定，不猜修。首轮新恢复测试夹具冲突已修。完整Actions37583889573第二次尝试与专项37583889487通过；1402项全量Flutter、402项专项、18项Android原生及现行源码/资源门通过。同签名未发布APK已就绪，最终下载页与哈希见文末+323交付记录；真机效果待用户验证。

> +323 失败路线：愿望恢复测试夹具冲突已修；随后原生星谷长按DOM等待超时，同源码重跑18/18通过，未删断言或改星谷。详细记录见app/docs/WISH_CHAT_FIXES_v0.42.79.md；不能与用户14:40闪退混为一谈。

## 当前交付 · +322 午夜梦境与可修订的自我理解（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-06 03:53 用户授权实施此前多轮灵魂/梦境讨论，要求先整理文档。基线+321本地d59998c/远端9cdd5129同树419ec3fc，分支agent/v04278-nightly-dream，目标0.42.78+322。设计先落app/docs/NIGHTLY_DREAM_v0.42.78.md。午夜空档每日最多一次成功整理，断网/中断日间补做；周回顾替代当日整理，保留原事件日期与可核对出处，允许暂定认识、自主愿望、修订和撤回，旧重复不累计为永久人格。沿用自我整理开关，接管旧自动AI Self反思，保留事实记忆、正式性格、关系/Desire和具体问题讨论。紧凑理解进入普通聊天、合适的主动正文和已有自主游戏选择；新话题专用来源隔离/角色扮演边界保留，不增主动额度、不自动汇报、不加每轮规划。状态/游标/完成日原子提交，真机长期表现待用户观察。完整Actions37371248037与专项37371248110第二次运行通过，1392项全量Flutter、380项专项、18项原生及148项源码门通过。同签名未发布APK已就绪，下载页与最终证据见文末+322交付记录。

## 当前任务 · +321 自主话题与按钮缩小（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-05用户授权实施话题讨论方案并允许合理改进。分支agent/v04277-conversation-topics，基线+320远端ad8bc459/本地01ca6d9，目标0.42.77+321。先表达只是选项；按语义承接短回复、真实兴趣与少量发展中线程、重复开题降权；复用已有机制，不增加每轮模型调用，不改次数/起床/游戏分享独立额度。同步缩小直接开始可见框与文字。范围见app/docs/CONVERSATION_TOPICS_v0.42.77.md；完整Actions37318345621与专项37318345719成功，同签名未发布APK已就绪，详细交付证据见文末。

## 当前交付 · +320 命运之轮直接开始与面板透明（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-05 19:39用户授权两项：SPIN右边增加竖排“直接开始”，使用现有显示且不重抽；沉浸房间命运之轮设定面板半透明。基线+319功能5fcc2b35/交付9f4a5f19，本地同树cc66725；分支agent/v04276-fate-wheel-start，版本0.42.76+320。按钮位于SPIN与拉杆之间，读取已选且未锁定卷轴中央标签，首开无需转动；转动/单独重抽期间禁用。房间面板底色约65%不透明，文字完全不透明，独立于聊天底色避免叠加变实。完整Actions37305657345与专项37305657322通过，同签名[未发布+320 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-eda462918686630190f8)已就绪；真机观感待用户体验。

## 当前交付 · +319 每日起床时间与醒后疲劳（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-05 08:08 用户授权实施 +318 APK 后讨论。用户明确白天游戏分享正常、不占普通主动次数是故意设计，禁止因本次清晨问题改为共用额度。每日零点后首次打开/运行检查保存 08:00—09:00 的一个起床时间；自主游戏及旧待发分享、主动额度夜间/白天边界、清晨门槛共用它。起床后 45 分钟困意平缓消退，只使用原疲劳竞争，不新增游戏概率或复杂睡眠模拟；不自动问候、不固定揉眼睛话术。保留明确请求的用户游戏与任务回报。当前分支 agent/v04275-daily-wake，基线 b9a8349（远端同树 47f9a903）；完整范围见 app/docs/DAILY_WAKE_v0.42.75.md。+318 用户已确认“ok，没有问题”，仅代表此次日常验收。

完整Actions37281178394与专项回归37281178329成功，1340项全量Flutter、319项专项、18项原生、148项源码门通过。同签名[未发布+319 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4ec9a13fa3760b8d153e)可覆盖安装，最终哈希和接班证据见文末。

## 前次交付 · +318 表情包整理与编辑（CI PASSED / APK READY / USER DEVICE ACCEPTED）

2026-10-05用户明确批准本窗口完整方案并开始：四套整合包A/B/Q版鲸鱼娘/大肥鱼，定点补动物和猫猫头描述，重整小分类，新增普通图片ZIP导入，选择提示不因外观不同拒选，编辑器仅保存生效且草稿异常退出丢弃。基线f64cf655/+317；开发分支agent/v04274-sticker-workbench。完整范围、附件对应、边界和验收清单见app/docs/STICKER_WORKBENCH_v0.42.74.md。原ID/路径和禁用策略保留，同ID覆盖不叠加；不改其他产品链路。代码、整合ZIP及同签名APK完成，完整Actions37235636484通过；用户已确认本次日常使用无问题，不外推所有边界场景。最终证据见文末+318交付记录。

## 前次交付 · +317 手机活动证据优化（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-05 01:41用户授权，仅优化手机活动加分的累计与时效。基线+316，本地200b571，分支agent/v04273-phone-activity-evidence，目标0.42.73+317。保留解锁唤醒、独立念头、原发送门槛及+316额度；不加解锁后禁止发送时间。改成有效感知间的新使用证据，新会话/长期感知中断先建基线，积攒通知不代表用户操作；仅过时的手机活动念头失效。不改Token缓存、第二通道、Live2D、桌宠、游戏和其他念头。本地及完整CI通过，同签名APK已就绪，真机待观察；交付证据见文末+317最终记录。

## 当前交付 · +316 主动消息分时与夜间窗口

2026-10-04 23:58用户批准只修改主动消息；DeepSeek token缓存优化后续单独做。基线+315总账5b8f793，分支agent/v04272-proactive-windows，目标0.42.72+316。安静/自然/频繁白天总额10/18/24，9/14/19点累计开放3/6/10、6/12/18、8/16/24；未用顺延、不预借、不跨日。0–9点独立共用2次，只给机会不补发。切换按新档当前累计额度扣实际发送，失败/WAIT不扣，冷却不重置。夜间去掉沉默加成，保留疲劳/休息竞争及同次正文WAIT。当前CI PASSED / APK READY / TRUE DEVICE PENDING；1306全量Flutter/292专项/18原生/146源码门通过，同签名Draft403105475可下载，详细交付见文末。+315愿望/反思仍自然测试，不扩展。

## 历史交付 · +312 深度思考与网页证据

+312功能ef2d71c/总账5d3df82，完整Actions37153220612成功，1225 Flutter/18原生/143源码门，同签名未发布APK已交付；TRUE DEVICE PENDING。完整范围、签名、哈希与原快速索引保留在文末。+313沿用普通按需规划、深度5轮10次、后台不新增逐轮规划及网页原文共用边界。

## 历史交付 · +311 持续心情

功能e883203/Actions37130412433成功，1214项Flutter、18原生、142源码门；同签名未发布测试包可回退。用户+310日常真机确认无问题不外推为+311验收；+311仍TRUE DEVICE PENDING。完整范围、发布证据与原快速索引保留在正式记录及文末，+312沿用心情与余波模块。

## 当前交付 · +310 记忆连续性与表情语义

2026-10-03 18:01用户授权实施：现有记忆合格，以玩家体验改善为目标。扩大近期上下文约64条、结合近期话题消解指代、扩大旧总结检索、按可靠来源补回少量共同经历；远期语义召回先验证收益，不盲加向量依赖或每轮规划。保持原提取/总结/衰减，不制造随机遗忘、不装记不清、不增加固定角色话术。补充JEV原装表情适用语义，不强制情绪映射、不改阈值、不规定频率。深度模式/网页原文转交另批；心情与拒绝另议；TTS及Nearby不修。基于+309功能39c3bcf及总账65548fd，开发分支agent/v04266-memory-continuity。状态CI PASSED / APK READY / TRUE DEVICE PENDING。功能88a2bee，完整Actions37119329162全绿：1196项Flutter、18项Android原生、141项源码门通过；[未发布+310测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-2bf4989e9ecec904aae3)，同签名覆盖安装。最终哈希与语义边界见文末+310交付记录。

## 历史交付 · +309 气焰完整性

功能39c3bcf/Actions37109660394通过，+310沿用。完整接班记录移至正式记录末尾，保留全部气焰、搜索和延期边界。

## +308 历史交付索引

+308已交付与真机/回归边界原文完整保留在文末“+334整理保留的+308顶部接班索引”；当前不扩读。

## 历史交付 · v0.42.63+307 稳定性第一批

用户已指定 **0.42.62+306 为真机可用的对照/回退基线**，无需额外整包备份。基线源码 65b21322693b4e9b67f907a9d476d9ff90cf286f；新分支 agent/v04263-stability 从公开提交 a77f5191c7dc74ee6daaede040ac60fec6f6be10 开始。CI PASSED / APK READY / USER DEVICE ACCEPTED（本次日常验收，非所有极端场景）。

本批完成恢复一致性、异步写入、下载等待、提醒同步及沉浸房间写入边界；1136项Flutter、18项原生、139项源码门及APK签名/资源检查通过。保留手动停止、中性回报、两分钟推进及设置读档不重载 Live2D。桌宠渲染和图片地址过滤暂缓；工作区、陪玩模型及低频澄清另批。基线可用不代表此前所有长时场景都已验证；具体历史证据保留。

## 历史交付 · v0.42.62+306（CI PASSED / APK READY / TRUE DEVICE PENDING）

+305用户真机报告：指定时长工具登记后正文等待、读档慢，不能再视为已验收。新诊断01:29/01:31两次停在工具完成到最终正文；现有证据不证明第二通道服务端原因。修无输出期间聊天租约过期、SSE保活无限延长超时；读档76418行改有界批次、单事务完整回滚。手动Stop/中性回报、两分钟游戏间隔、Live2D设置导入不重载均保留。新增无正文请求阶段和恢复阶段耗时诊断，不存用户正文或密钥。先专项验证再构建；未经手机实测不标TRUE DEVICE PASSED。

## +304 已交付基线

+304功能9ba2f176/Actions36871635441成功，设置导入热同步并保留Live2D视图、旧资源包兼容；原生17/17、Flutter1059通过，Draft401037240可回退。真机导入观感待验。原快速交付全文迁至正式记录末尾，完整SHA与APK证据保留。

## +303 已交付基线

+303功能afe1baa5/Actions36860037884成功，设置存档不打包外部资源、持续单人两分钟与5/10/1轮分享保留；导出已获用户真机确认，导入重载由+304修正。旧快速索引全文迁至正式记录末尾，失败路线和APK证据保留。

## +302 历史交付索引

导出刷新、侧栏焦点与星谷交互已交付；完整证据原文移至文末“+302完整历史交付索引”。本批不改这些行为。


## 当前交付 · v0.42.57+301（CI PASSED / APK READY / TRUE DEVICE PENDING）

记忆星谷只读分页、星空入口与四角吸附已实现。Actions36789231773成功，Flutter1042/原生12项；用户随后表示整体效果挺好，但不扩展为+302真机验收。完整源码/签名/PNG与APK资源证据及任务边界移至正式记录末尾“+301完整交付索引”，旧证据完整保留。

## +300 历史交付索引

游戏5/10/1轮分享、两分钟单人推进、持续摸头和设置存档完整性已交付；完整源码、CI、签名、APK和任务边界保留在文末“+300完整历史交付索引”。本批沿用原行为。

## +299 存档大值读取与白天背景（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 已完成加急两项，基线功能a2341425/tree dbd8558e、总账526e1bb4/tree df232243；[Actions36731605271](https://github.com/catkiss62/ai-companion-build/actions/runs/36731605271)全绿，133项门、Flutter1018项、原生6项通过。完整实施与回归证据在正文“+299完整接班记录”。
- [未发布+299测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-96970c13c85e77efbdd1)，Draft400107673/asset601202681，SHA-256 8f848e1ceeaf992a3f54fb2bd1a5721d2316a478515906cf8be4f19302c242d3；签名沿用稳定签名，可覆盖安装。真机仍待备份和白天图验收。
- +300保留settings无损分段读取及已批准day.webp（SHA-256 6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7）；不重新生成图片，不清空/截断存档。

## +298 指定时长游戏与过程分享（已构建）

完整实施、CI与APK证据保留在正文“+298完整接班记录”；+300在此基线上统一轮数分享间隔。

## +295 历史交付索引

原生直接合成的完整失败路线、签名与验证记录保留在文末“+295历史索引原文”，当前任务不改Live2D。

## +294 历史索引

完整原文迁至文末“+321整理保留的+294历史索引”；既有真机失败结论和回退证据不变。

## 当前任务 · +293 Cedar 目标核对、菜菜动作与模型联网配置迁移（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户最新决定：Jev 提示词、选项、概率接近时的本地中性改写、气焰值计分均暂不调整；须用后续明显错误再评估。诊断 2026-09-29 22:50:47 “好啊，走，去玩白房间游戏”：Jev `accept=.89` 且 `applied=accept`，但距上条助手消息约 39 分钟，本地 `recentAssistant<=15分钟` 否决，工具入口关闭，规划 0 轮、Cedar 0 次。移除有效 Jev `accept` 后的时间否决；不可用时窄候选仍有原边界。22:11 的另一问题是 Agent 确实调用了旧钓鱼游戏，这两条因果分别修。
- Cedar：从本轮与近期用户真实游戏名称取目标线索给按需 DeepSeek Agent，旧活动状态保留以供自主续玩；若本轮目标与旧活动不同，首轮不注入旧游戏完整指南。拟调用不同目标游戏的 `get_guide/play` 时，在 MCP 执行前最多重规划一次；仍不一致则不执行并如实说明，普通聊天不新增 DS 工具调用。游戏名称仅来自真实目录；多游戏歧义由 Agent 判断，不按固定关键词直接调用游戏。
- 菜菜：仅说话表演的横向整模平移、身体 X/Z 缩小目标和减慢原生过渡；身体 X 不再每拍强制释放，头、身体 Y、视线、嘴、眉、既有动作照旧。原装 `wink`、`wink吐舌`、`比耶wink吐舌` 进入 Jev 可选短时表情，原生 4.5 秒租期/冲突规则生效；装扮保持手动。需要真机观察实际幅度和速度。
- 模型与联网页右上角导入/导出：仅当前已保存的本页配置，版本化 JSON 包含 API Key，导出前提示妥善保管；导入先完整校验，再写安全存储与原子 DB，失败尽量恢复旧设置、成功刷新并唤醒待重试任务。不包含聊天、记忆、Cedar Token、模型 ZIP。检测无本地 Flutter SDK，依赖 Actions Flutter analyze/test 与 APK 构建。
- 多 Live2D 收口：当前已是菜菜专有的文件目录 `caicai-live2d`、私有 `caicai_stage` 舞台偏好、MethodChannel/PlatformView、`CaicaiMotionPlanner` 参数映射和单 active native runtime。此批保持既有独立边界；第二模型接入时再增加 modelId/profile、独立存储及 modelId+generation 异步结果防串，不能把菜菜 ID 强加给新模型。未声称已实现双模型切换。
- 版本 `0.42.49+293`，分支 `agent/v04249-cedar-target-caicai-config`。最终功能提交远端 `b548cf37375ba6b577c85d12e3214579fa19982b`，tree `ff555e3e6c2a19e796d838606bd69fb13dcf1bad` 与本地源码树一致。早期 Actions 分别由历史版本白名单、旧平移收尾测试容差、目录短名称提取测试拦截；逐项修复后最终 [Actions 36595936006](https://github.com/catkiss62/ai-companion-build/actions/runs/36595936006) conclusion=success：原生烟测、130 项源码回归、Kotlin 测试、Flutter analyze、Dart 测试、release APK、资源和持久测试签名检查通过。
- 未发布 Draft Release `399274286`：[+293 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b372f5486ed637a4230c)，target=`b548cf37`，asset `598685345`，文件名 `AI-Companion-v0.42.49-293-Cedar-Caicai-Config-APK.apk`，726108578 字节，SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`；Release 另附 `.sha256` 与 CI Monitor。未合并 main，未正式发布。
- 待真机验收：Jev `accept` 隔 39 分钟能进入按需 Agent；白房间目标不会执行钓鱼；明确续钓旧存档仍可用；普通聊天仍无额外 DS；三轴和三个 Wink 观感；配置 JSON 往返及错误文件不覆盖。自动测试和 APK 可用不等于实际设备语义与视觉已通过。

## 当前任务 · +292 Jev 游戏语义入口与 Live2D 回前台计时（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户在 2026-09-29 切换至 6sol 后批准开始此批并要求复核上下文；本批包含 Jev 语义游戏入口与 Live2D 回前台耗时诊断。菜菜现有模型与未来第二模型的隔离/切换收口仍为后续批次；用户暂缓 Live2D 真机观感验收。
- Jev 游戏意图加入回复前现有 `chat_intimacy_route` 合批问题，无每轮额外 Jev/DeepSeek 调用；`act_now` 或有近期助手回合承接的 `accept` 打开按需 Cedar 规划，`chat/defer` 阻止显式正则误触发，接近概率时归 `chat`。Jev 不可用时仅原显式/窄候选进入 DeepSeek 规划；普通聊天不新增工具请求。唯一 Cedar owner、真实 Outcome 守卫与预算继续有效。诊断新增语义选择及门状态，不写正文。语义准确率仍需独立改写样本和设备实测，不把单元测试当自然语言准确率。
- Live2D 现有 surface 诊断增加 view 身份、Cubism owner 等待、context 初始化、surfaceChanged（含 renderer/纹理重载）耗时、最近 context 的贴图解码/上传累计及恢复后首次有效模型帧耗时。保留当前 EGL、模型加载和桌宠行为；这些本地耗时不能单独证明屏幕合成呈现时间。用户可在诊断导出中比较 context/surface/首帧事件。
- 版本 `0.42.48+292`，分支 `agent/v04248-jev-cedar-live2d-trace` 基于远端 +291 总账 `fb6177f`。首轮功能提交本地 `3e6b100` 与远端 `195da8e` 同 tree `712b753`；Actions `36564832663` 原生冒烟通过，但源码门第 1 项还要求旧版候选轮单独 Jev 调用，未进 Flutter 阶段便失败。已更新该历史门以验证新合批路线，并把 NativeTextureManager/SenRenderer 的受审计源树摘要重钉。本地源码门跑至 28/130 项通过，第 29 项因缺 CI 构建时恢复的 417 个私有桌宠帧而停；后续第二轮 CI 结果见下一条。
- 修复提交本地 `4893b96` 与远端 `8fbbad51e4486c096d4bdb26d5492b18d588f83f` 同 tree `066fc71c00bd3848d3b72dc56e716cb0746a49e9`。第二轮 Actions [36566315566](https://github.com/catkiss62/ai-companion-build/actions/runs/36566315566) conclusion=success：原生冒烟、130 项源码门、Kotlin 桌宠/悬浮窗测试、Flutter analyze 与测试、arm64 Release、资源及稳定签名校验通过。Draft Release `399109401`：[+292 未发布测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0646b808f36e63198f97)，target=`8fbbad51`，asset `598175410`，文件名 `AI-Companion-v0.42.48-292-Jev-Cedar-Live2D-Trace-APK.apk`，726106342 字节，SHA-256 `e64b827c9726476d97d2d516a7c6ea0596bb9de62ba492340763cf6a9818a510`。签名验证步骤成功，同一持久私有测试签名身份；未发布正式 Release。
- 真机待验：邀请的改写/反问/否定/延期/话题切换和“走着”“开始吧”后是否出现正确 Cedar Outcome，普通聊天不触发工具规划；统计 Jev 的实际选择、误触发/漏触发与费用。Live2D 回前台导出 `surface` 的 view_id、owner_wait_ms、context_init_ms、surface_changed_ms、texture_decode_ms、texture_upload_ms、resume_first_model_frame_ms，结合 GL context 和 frame trace 判断空白阶段；当前 CI 与耗时指标不等于真机可见观感通过。+290 Jev 动作真机验收仍独立待定。

## 2026-09-29 后续检查 · Jev 路由与多 Live2D 收口（DISCUSSION / NOT IMPLEMENTED）

- 用户暂缓Live2D真机观感验收，要求检查+291游戏入口、DeepSeek附件建议及未来第二套Live2D切换；本轮仅检查及方案，未改产品代码/未构建新APK。
- 路由事实：9月25日`4171c67`已有按需DeepSeek工具规划；近期`a6d08fa`已有Jev上下文判断；+291新加用户邀请短时续接，非整段回退。显式正则直接开规划；候选续话只有第二通道模式才先问Jev，单DeepSeek模式交同次工具请求判断。续接先受24字/固定开头、原始用户邀请、15分钟/6条消息/最多两次确认约束；未进入候选者Jev看不到。Jev两类概率差≤0.10时本地归chat；Jev无效才候选轮交DeepSeek。985项CI通过不构成自然语言准确率评测。
- 建议待批准：将“现在执行/接受邀请/讨论/拒绝延期”等语义交回复前Jev，优先与同阶段短判断合批；后置表演Jev不能用于提前路由。避免继续增加固定口令作为必要入口。需用未参与提示词设计的改写/否定/反问/延后/话题切换样例量误触发、漏触发、Jev与DS调用数和费用，不宣称已有准确率。
- 附件定点核查：NativeTextureManager确实decodeFile后recycle；上下文恢复reloadRenderer重建渲染器/贴图而保留CPU模型，hostResume已requestRender。contexts计数onSurfaceCreated，surfaces计数onSurfaceChanged（尺寸事件也加），不能单凭计数断言耗时原因。CaicaiRuntime.attach会dispose旧owner，不能由IndexedStack断言永久双owner争抢；信号量等待仍需owner/等待时长证据。优先补context/surface/view身份与decode/upload/首帧耗时。CPU缓存需实测收益与内存预算；RGB565无alpha不适合透明贴图；直接draw不能保证交换缓冲与合成显示，不将其承诺为消除秒级空白。自管EGL/不onPause/改composition均暂不采纳为默认修复。
- 多模型收口建议：共用宿主+单活动renderer+每模型adapter/capability profile；菜菜现有已验证渲染与配件数学封装保留。素材与舞台/摸头/衣装/幅度设置按modelId隔离；模型档案提供语义动作、实际参数ID/方向/范围/中性值、物理后写入及混合优先级、预设与可用能力。Jev根据活动档案取得选项。每次切换递增session generation，Jev/动作/异步回调都校验modelId+generation，防旧模型结果落到新模型；保留两套磁盘资源，默认只驻留一套渲染实例，失败恢复旧模型。以上尚未实施，第二套模型具体参数需拿到后标定。

## 当前任务 · +291 Cedar 邀请路由与诊断导出（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-29 用户明确授权修改、推送与构建；基于 +290 总账 `48d1e0e` 开始。+290 Jev 动作真机验收继续独立待定。原调查与失败路线见下节。
- 实现：`陪你/跟你/和你 + 钓鱼/下棋/打牌/游戏` 纳入显式邀请，延期表达不视为立即进入；最近15分钟且最多6条消息、两次简短同意内的原始用户邀请成为候选。若期间拒绝/延后、话题转移或已有实际 Cedar Outcome，候选撤销。含糊确认由 Jev 判断，Jev 失效时仅候选轮开放原 DeepSeek 工具规划；普通聊天不增加 DeepSeek 调用。保留现有 Cedar 工具 owner、预算、Stop 及运营声明守卫。
- 路由诊断保存最近12条时间、候选原因、规划轮数、Cedar Outcome 数及 Jev 门状态，不保存正文/参数。Android 报告保存上限2→16 MiB，流式复制保持；缺失/超限错误区分并在页面显示类别与大小，完整 Jev 报告不截断。
- 2026-09-29 用户再次明确批准将本地 `4f6ab85` 推往指定公开仓库的现有分支并触发未发布测试 APK。Git HTTPS 因本机无凭据失败；用已连接的 GitHub 仓库接口上传同一 tree `37f4f27e4bf175b7f7893abfa1c32ca6f1d16642`，与本地提交 tree 完全一致，远端功能提交 `964483e6c63ff13ef0021195e393744c7f155106`，父提交 `48d1e0e`。两次早期自动审批拒绝及无凭据失败仅是交付路径，不是代码 CI 失败。
- Actions [36553832513](https://github.com/catkiss62/ai-companion-build/actions/runs/36553832513) conclusion=success：原生模拟器、源码门、Kotlin、Flutter analyze、985项 Flutter 测试、arm64 Release、资源与签名校验通过。Draft Release `399039624`：[本次 +291 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cccaadca93c93fd4c7d9)，target=`964483e`，asset `597938006`，文件名 `AI-Companion-v0.42.47-291-Cedar-Diagnostic-APK.apk`，726099994 字节，SHA-256 `dfe11685cdc81f2dcf0744171c5349f1e7465544d6b65ef42a70aeff8ed927a4`；Release digest 与 CI 一致。签名 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +290 相同，可覆盖安装保留数据。仓库另有同版本号 +291 的不同草稿，务必以本段目标提交与 asset 识别本次包。
- 真机待验：用“陪你钓鱼？看你今天都没钓鱼”直接邀请，及“走着”“开始吧”续话，确认 Cedar 真实工具调用、结果与对白一致；再试普通闲聊、拒绝/改天、15分钟过期与已有 Outcome 后无多余 DeepSeek 规划。导出超过2 MiB的完整脱敏诊断报告，并查看 `cedarRealtime.recentUserRoutes`。CI 不能替代真机语义和系统文件选择器验收。+290 Jev 可见动作仍单独待验。
- 新版本 `0.42.47+291`，已补单元测试和历史版本门；本地7项历史版本门、Cedar相关源码门与差异格式检查通过；本环境没有Flutter SDK，Dart/Android测试待CI。推送至 `catkiss62/ai-companion-build` 的现有分支两次被自动审批拒绝，远端仍为 `48d1e0e`，因此当前尚无 CI、APK 或真机证据。自动审批认为上传仓库源码/历史到该目的地有外传风险，需用户对具体目标再明确批准；不得通过其他通道绕过。

## 当前接班调查 · Cedar 跨轮漏触发与脱敏诊断导出（DESIGNED / NOT IMPLEMENTED）

- 2026-09-29 接班调查已完成，承接用户“先出方案”的要求；本节仅记录证据与拟实施方案，没有修改产品代码、运行新 CI 或生成新 APK。基线仍为 +290；+290 真机动作验收独立待定。
- 用户私有备份仅在本地分析，没有上传仓库。末尾三轮含一次共同钓鱼邀请和两次简短确认，均有正常模型正文，却没有新增 Cedar 工具 Outcome；不得把拟开始的对白算作游戏实际推进。存档当时活动游戏为另一款、会话 mode=unknown / phase=guide_ready。当前 `CedarToyArcadeSkill.isRelevant` 未覆盖“陪你+钓鱼”句式；续话候选要求可续玩的 solo 会话，`hasUserTurnContinuation` 对 guide_ready 不开放；因此这三轮都可能在 DeepSeek 工具规划之前被挡住。已核对相关源码，最终真机路由仍需新诊断证据。
- 历史入口：`4171c67856`（2026-09-25）在 `durable_generation_runner.dart` 通过显式意图或用户回合续接决定 `cedarSkillActive`，普通聊天不因此调用 DeepSeek。后来 `98f42ac9cf` 和 `be9bbf5f35` 扩展上下文入口，`a6d08fad9a` 收窄并加入 Jev 决策。应保留按需门控结构，不直接回退旧代码；旧规则同样不完整覆盖这次跨轮邀请。
- 方案：显式“陪你/和你+游玩动作”仅作为窄候选，普通提及游戏、筹码、摸鱼不触发；根据最近少量用户/助手轮次维护有时限、可取消的未完成游戏邀请，短句同意只在有用户原始邀请且尚无真实 Outcome 时成为候选。候选有歧义时一次 Jev 判断；Jev 不可用才在这个候选回合交给既有 DeepSeek 工具规划。真正确认后仍由唯一 Cedar Agent owner 读实时目录/指南并执行，遵守预算、Stop、切换与服务端事实；不得从助手自行承诺开启游戏。正文若无真实 Outcome，不能声称已开始、已落子或已下潜。新增每轮有界路由诊断：候选原因、是否 Jev/DeepSeek、工具规划与 Outcome 数、零调用原因；不记录私密正文。
- 诊断导出根因：`SystemBridge.startDiagnosticReportSave` 在打开系统文件选择器前拒绝大于 2 MiB 的报告，错误为 `diagnostic_source_invalid`；`PreflightDiagnosticsService.run` 完整纳入最多120条 Jev 问题、上下文、概率及费用。此备份 `jev_short_usage_v1` 原始 1,645,590 字节，按双空格缩进的 UTF-8 JSON 单独约 2,103,848 字节，已超过 2,097,152 字节上限，尚未计入报告其他字段。方案是在原生保存入口采用明确更高且有界的本地报告上限（建议 16 MiB）并保留流式复制、完整 Jev 证据与脱敏约束；页面显示具体错误类别/体积，避免只有异常类型。不得截断 Jev 历史掩盖问题。
- 实施时验证：用末轮三回合语义重放，确认只开一次按需工具规划、真实 Outcome 才能支持完成声明；普通游戏闲聊、无关短句、拒绝/延后、旧会话不同游戏及 Stop 不误触发；诊断报告超过2 MiB可保存且内容完整，取消和超上限显示明确原因。实现、CI/APK、真机三项分别登记，不提前勾选。下一步从本节进入上述两项修复，随后返回 +290 Jev 动作真机验收。

## 当前任务 · +290 Jev 四拍可见动作恢复与适中调节（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户真机确认 +289 桌宠尺寸已经修好，但 Jev 对话动作偏小且与待机难区分；随后明确发现可见动作次数变少，要求恢复此前 Jev 每拍的可见动作，只在幅度与速度上按已讨论的适中方案调整。+289 功能及 APK 是回退基准；无需改桌宠、待机、摸头、视线、输入法画布和双通道正文。
- 代码差异：+289 把四拍的“夸张”选择本地压为仅一拍，整模探身压为最多一次，同方向身体 X 取消了拍内释放；Jev 文案也引导保持同一姿势。上述改变减少可见姿势变化，叠加较小目标值和较慢过渡，不能单凭提高参数目标修复。用户当前没有提供这版逐轮 Jev 原始选择，不能冒称模型实际选择次数已确认。
- +290 恢复四拍各自强度/整模选择和身体 X 每拍释放；Jev 文案鼓励有语义的多次姿势变化，但不强制机械左右交替。头部侧头 ±25（强调 ±28）、俯仰 ±24、歪头 ±23；身体 X/Z 常用约 ±6、强调约 ±6.72，整模探身 5.5% 模型宽，腿支点约 5°；同时选整模和身体 X/Z 时保留 0.75 混合限幅。节奏每拍 .82/.95/1.10 秒，空间插值 3.4（+289 为 2.7），过渡 34% 拍长；人脸、口型及自主待机不变。四拍仍严格最多八个原生 keyframe；任何实际行为/手感待真机验收。
- 开发分支 `agent/v04246-jev-visible-motion`，版本 `0.42.46+290`。本地功能提交 `3943d4b01c895a0fdf840934acc69b1f9bd058a3` 与公开分支功能提交 `dd3347faa279468d88cedaed0d8fe06d96b1915f` 共享完全相同的 tree `fdc9b086ec4090ca371adf7ad466f302222eeea0`，均基于 +289 总账提交 `8d318c6f`。只推公开源码、测试、总账；无用户存档/诊断/模型素材；未合并 main、未正式发布。
- Actions [36527469120](https://github.com/catkiss62/ai-companion-build/actions/runs/36527469120) conclusion=success：原生模拟器、源码回归、Kotlin 桌宠/悬浮窗测试、Flutter analyze 与测试、Release 编译、签名身份和包内资源校验通过。未发布 Draft Release `398862838`：[+290 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fdf0e1749b6a7d2d8112)，target=`dd3347f`，asset `597420421`，文件名 `AI-Companion-v0.42.46-290-Jev-Visible-Motion-APK.apk`，726100546 字节，SHA-256 `f36a463e844d0cbb3f6a009137880c1bb57b5f466a14253dbf5ab8d2c27ff863`，Release digest 与 CI 日志一致。签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +289 相同，可以覆盖安装保留数据。
- 真机待测：同一类对话比较 +289 和 +290 的动作次数、头身幅度、左右位移与节奏，看是否恢复可见变化且没有回到 +288 的“到处乱撞”。四拍可自主选择，不保证每次对话一定四次大动作；以具体 Jev 选择和最终画面复验。用户已确认 +289 桌宠修好，+290 没有改桌宠代码；输入法保持 +288 的固定画布。

## 当前任务 · +289 Jev 动作贴近待机、桌宠重装后尺寸（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户确认输入法打开时 Live2D 不再错误缩小，要求维持这一版为回退基准；但 2026-09-29 09:00 中国时间三份实测文件标为 `0.42.43+287`，不是 +288，故不把 +288 标记为设备正式通过。用户明确批准本轮实施上一轮与本轮讨论的幅度、速度调整；待机效果满意，应保留。
- 存档最后两轮 Jev 说话计划：均用 0.62 秒的“俏皮快拍”，末轮四拍全选 120%“夸张”并重复“右侧头＋俏皮侧身”；身体 X/Z 和头 X 被截到各自模型边界，整模左移达到模型宽度 12%。旧计划每 .341 秒中途释放身体 X，即便下一拍仍是同一姿势也会反复回弹。
- +289 实施：Jev 说话专用预设头部常用约 ±20～22、强调最高约 24～25；身体 X/Z 基准约 ±5、强调不超过约 ±6，身体 Y 约 ±6～7；整模水平探身基准 4%、腿支点约 4°。强拍全选四次时本地只保留一次强拍，整模动作至多一次；整模与身体 X/Z 同时选中时后者降低 25%。节奏每拍 .86/.98/1.15 秒，过渡 42% 拍长；原生仅减缓空间参数插值，嘴、眼等短反应保持原速。重复同方向身体 X 保持，不在中途释放；末拍回待机。`CaicaiIdleMotion` 自主待机与视线、摸头不改，全局用户调节数值也不改。需在真机看是否仍偏快或偏弱。
- 桌宠代码证据：`PetOverlayWindow.attach()` 在无障碍窗口管理器暂未连接时以普通悬浮窗挂载，只分配旧正方形宽度；新版 16:9 帧由 `PetFrameView.displayScale()` 的宽度适配缩小，旧动画影响不明显。打开系统文件选择器会触发悬浮窗移除/重建；若无障碍服务此时已经连接，重建为宽窗口便恢复原尺寸。+289 在无障碍 `onServiceConnected()` 通知悬浮服务，仅在桌宠仍挂在旧窄窗且无系统遮盖/聊天展开时进行一次受控宽窗重绑，不更改现有透明触摸区域或桌宠校准默认值。诊断尚缺缩小当时的 `attach trusted=false` 记录，机理与复现匹配，标记为待真机验收，不能冒称已证明设备因果。
- 开发分支 `agent/v04245-jev-motion-pet-scale` 基于 +288 head `3bd5fc0dd25c760e7d4ca9760e45b47e1da1f1e3`，版本 `0.42.45+289`。用户在当前对话明确授权公开分支推送和未发布测试 APK 构建；本机 Git HTTPS 无凭据，使用仓库所有者连接创建远端功能提交 `f853ef397f972d552f2517f0aff670556100fc35`，tree `269a3350a8b1d98b498314a03c7cb0971a7cc018` 与本地已检查工作区逐字节一致。没有将用户存档、私有分片或诊断加入提交；保留 +288/+287 回退，不合并 main，不正式发布。
- Actions [36517195317](https://github.com/catkiss62/ai-companion-build/actions/runs/36517195317) conclusion=success：菜菜原生冒烟、130 项源码门、Kotlin 桌宠/菜菜单测、Flutter analyze、983 项 Flutter 测试、arm64 Release、资源与签名核对通过。本地源码回归因缺少 417 个构建时恢复的私有桌宠帧，在第 29 项停止；CI 在恢复帧包后完整通过，不能把本地暂停误记为 CI 失败。
- 未发布 Draft Release `398808965`：[测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-43632f0cf8e06a13f5d5)，tag `v0.42.45-jev-pet-scale-test`，target=`f853ef3`。APK `AI-Companion-v0.42.45-289-Jev-Pet-Scale-APK.apk` asset `597176654`，726101222 字节，SHA-256 `07b3686022ce40ad0177dfaeb612548bd7866f695e0a4aa1b18e82768cf83085`，与构建日志和 Release digest 一致。签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +288 相同；可覆盖安装，不卸载数据。
- 真机待测：最近两轮相同语境观察 Jev 是否仍过快/过大，同时确认待机没有被压小；重装或覆盖安装后立即看新版桌宠动画与点击动画，不能先打开系统文件页面，随后可打开文件页面对照是否还发生尺寸跳变。无障碍服务完全未授权时仍走普通窄窗回退，不能宣称该路径已与宽窗同尺寸；若变小，立即导出普通脱敏诊断对照 `attach trusted` 与 `fit` 轨迹。输入法尺寸问题沿用 +288 的固定画布，未在 +289 改动。

## 当前任务 · +288 输入法固定画布与桌宠尺寸追踪（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 事实：用户确认 +287 头部动作已灵动、总体效果很好，但打开输入法 Live2D 仍会缩小。2026-09-29 05:48 中国时间导出的 Live2D 诊断在同一进程记录到 surface/view 由 1280×2052 缩到 1280×1322，sceneHeight 同时到 1321.5；关闭输入法期间 surface 一度达 2205。+287 的“IME仅遮挡”没有在真机成立，不能标作已验收。
- 修复：Flutter CaicaiStageViewport 以已知完整高度为基准，忽略输入法动画里零 inset 但窗口仍短、以及 inset 与布局临时超额的中间帧；聊天舞台的 AndroidView 本身保持完整高度，外层布局遮住下半截，原生缓冲不再随可见聊天高度重新适配。背景既有完整高度保留。新增时序测试，更新旧源码门检查固定画布。
- 桌宠：用户报告仅新版动画（含点击）偶发缩小，旧动画正常，导出后恢复。之前诊断可证明文件选择器导致悬浮窗脱离并成功重建，但不能证明变小那一刻具体原因。本版不猜测性调高已有正确视觉的默认数值；脱敏诊断新增最近24条桌宠渲染轨迹，含动作ID、bitmap尺寸、视图/逻辑窗口、留白、适配比例、实验动画开关和校准值，并记录挂载时可信悬浮窗状态。再复现时应在异常发生后立即导出普通脱敏诊断，对比相邻记录。
- 回退主基准：+287 功能提交 `3582ff0ce6399aa0eeb5998e38acfe0ada852907`，APK SHA256 `21cd6c313ccca3091e6d1e76914a4650775b2a4b468cb57e71d1cc47b5707aca`；+286、+285 也仍可追溯。覆盖安装须用更高 versionCode 的恢复包，不卸载用户数据。
- +288 功能与版本最终提交 `e4655ea8357897052c7e8b72d5b18ee03b78f91f`，Actions `36492157673` conclusion=success。原生3项模拟器测试、130源码回归、Kotlin桌宠/悬浮窗测试、Flutter analyze与982项Flutter测试、release打包、资源校验与签名均通过。前两轮构建 `36489492272`、`36490815159` 分别由历史固定画布断言和历史版本白名单拒绝，均已更新后重跑通过。
- Draft Release `398665497`，tag `v0.42.44-caicai-ime-pet-trace-test`，target_commitish=上述功能提交，未正式发布：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-21985d5229af921530dc)。APK `AI-Companion-v0.42.44-288-Caicai-IME-Pet-Trace-APK.apk` asset `596598655`，726099246字节，SHA256 `c0457e8d92d0157689546f01f39cad21db7ad6981500f8d813a79310fcaf0b42`，构建日志与release digest一致。sidecar `596598654`，CI monitor `596598670`。签名SHA256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与 +287 相同，可覆盖安装，无需重新导入模型。
- 真机验收：反复开关输入法，观察头宽/人物大小与背景位置保持，键盘只遮住下半截；如仍改变，在键盘保持打开时导出Live2D专用诊断。桌宠若再次变小，当场导出普通脱敏诊断。桌宠缩小仍为待定因，不能称此版已修好。没有将私有存档/诊断/模型上传仓库；未合并main。

## 上一版 · +287 固定场景与菜菜交互收口（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户 2026-09-29 04:19 中国时间批准上一轮八项方案全部实施；查询进度/网页卡住导致的打断不取消任务。禁止遗漏或将“命令发出”算作视觉通过。

- [ ] 1. IME 仅遮挡下半身、模型大小/锚点不变：+287 真机仍缩小，+288 代码重修，待实机复验；背景和渲染目标同步保留。
- [x] 2. 以菜菜实验室“左右大幅/上下大幅”按钮的成功执行顺序为基准，统一 Jev/待机/视线的头部控制，记录写入/物理后/最终参数。
- [x] 3. 保留 +286 满意的动作基础，增加动作族/参数变体/近期去重/连续衔接。
- [x] 4. 参考 Sen 完整摸头（按住/释放/彩蛋/从当前表情渐变），与待机及视线混合，映射使用菜菜参数。
- [x] 5. 消失重现尚未定因；补有限容量可导出诊断、成功绘制/上下文/可见性/画面边界和 FPS，摘要并入脱敏诊断。
- [x] 6. 情绪及临时表情/按钮总时长4.5秒含淡出；事件去重避免重建续期；衣装持续。
- [x] 7. 对应白袜/白丝按钮显示“丝袜”，内部预设 ID 不变。
- [x] 8. 目标60FPS，保持已存在的512px高精度蒙版，实测FPS不冒称设备稳定60。

回退：+286 功能 `0627376f4f787a072cdabe94c8f25ab78da8b445` / APK SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`，用户确认比+285更好；+285仍保留。+286遗留以上缺陷，不标整版真机全通过。
保护：GLSurfaceView导入/生命周期、配件原始标定、TTS口型、双形态、第二通道正文/修正及400失败兜底、桌宠默认；私有资源及既有脏part-075.bin排除提交。开发分支持续推送/Actions/Draft APK已授权，不合并main不正式发布。
下一步：实施并逐项验证；版本 `0.42.43+287`。完整构建与手机观感分别报告。交付必须包含修复清单、未证实项、总账更新确认。

实施说明：八项实现已落地，勾选仅表示代码完成，不表示真机通过。头部复用实验室X3/Y2的物理后最终写入，三个生产入口共用CaicaiHeadPose；捕捉X/Y同时进入诊断，未盲目改名。裁切放在原配件标定完成后的共用最终矩阵，原标定源码哈希保持通过。摸头状态独立混合，普通按住/释放、10%彩蛋及手动彩蛋预览；待机8类动作及参数变体、最近3类去重。所有情绪按回复事件计时、同事件Jev修订不续期、界面重建不重播。细诊断180条/每秒一条内存缓冲；60FPS目标/512px蒙版。

本地验证：纯Java实际算法检查通过（相机像素不变、物理后目标恢复、4.5秒事件租约、摸头持续/释放、待机去重与连续性），原生基线/资源哈希通过；完整source suite因本地未物化417张旧桌宠帧在资源门停止，将在CI物化后验证，不删门禁。Flutter/Android完整测试和APK尚未完成；消失重现仍属于待诊断项。

构建进行中：功能首提交 `2cb8d94ccf8e601cbb710abc0e7ec846d81c3da0`；补齐当前脸部渐变、编辑场景坐标及可见性诊断后，最新功能提交 `3582ff0ce6399aa0eeb5998e38acfe0ada852907`。当前 Actions `36480742163`；较早 `36480332751` 因同分支新提交自动取消，不是测试失败。工作区无功能修改待推送；原有私密分片脏文件保留未提交。最新 Actions 全绿：原生冒烟 job `109125728718` 的3项测试成功（视图创建/生命周期/resize/导入事务）；主构建 job `109127573579` 的130项源回归、Android/Kotlin单元测试、Flutter analyze、982项Flutter测试、release打包、签名和资源校验全部通过。

### +287 交付核验 · 2026-09-29 05:02 中国时间

- 功能提交：`3582ff0ce6399aa0eeb5998e38acfe0ada852907`；Actions `36480742163` conclusion=success。APK Artifact `10998290387`；原生测试 Artifact `10997007849`。
- Draft Release `398607461`，tag `v0.42.43-caicai-interaction-test`，target_commitish已核对为上述功能提交；仍为未发布草稿：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a70c7a69b15ad2fc6c12)。
- APK `AI-Companion-v0.42.43-287-Caicai-Interaction-APK.apk`，asset `596404892`，726,098,462字节。SHA256 `21cd6c313ccca3091e6d1e76914a4650775b2a4b468cb57e71d1cc47b5707aca`，已核对构建日志与Release asset digest一致；sha256 sidecar `596404894`，CI monitor `596404896`。
- 签名与+285/+286一致：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。无需卸载；未将APK下载回工作区，未合并main、未正式发布。
- 八项代码与自动化已交付，真实手机上的固定视觉尺寸、明显头部运动、连续摸头观感、4.5秒表情以及实际FPS仍待用户验收。模型消失重现未宣称修复：若复现从Live2D设置单独导出诊断。
- 测试顺序：开关键盘看人物头宽/位置不变；左右大幅/上下大幅对照生产待机、跟随和Jev；连续摸头/松手/彩蛋；情绪按钮4.5秒淡出；观察待机丰富度及诊断实际FPS。不要求重新导入模型。

## 上一批 · +286 菜菜表演调节与输入法几何修复（CI PASSED / APK READY）

- 用户明确确认：+285 头部各轴已有效，现阶段是幅度/速度调节；+285 功能成功，作为可回退基准。已授权直接实施，无需继续方案确认。
- 回退基准：`0.42.41+285` / 功能 `6cfca5ae303f384283a653d1627ff4a548150322`；Actions `36455411205`；Draft APK SHA256 `0f28b4dd43a2b5ffe00bedcd21878984c086cbe077d22d3433199f6b454968c6`。已知缺陷：输入法拉伸；动作偏小偏慢、摸头/视线优先级待修。不以整体 TRUE DEVICE PENDING 覆盖用户已确认的功能成功。
- 范围：稳定输入法期间舞台与 Cubism 渲染尺寸；明显的头眼跟随、摸头；更快且夸张的待机/Jev；统一整模水平位移和小腿支点倾斜，由 Jev 选择方向、幅度和节奏。本地逐帧执行，仍只有每条回复一个批量 Jev 请求，不新增循环所有者。
- 证据：当前窗口变化仅更新 glViewport，未同步 Cubism render target；摸头参数计划后执行的 applyAttention 会覆盖其头部 Y。两者是代码问题，尚不冒称已证明真机拉伸/卡顿全部原因。头部参数按用户确认有效处理。
- 保护：+285 GLSurfaceView/导入事务、原 renderer/三配件标定数学、TTS 口型、19 情绪/衣装/4.5 秒预设、第二通道正文及 400 兜底、桌宠默认不回退。已有脏二进制 part-075.bin 排除提交；不上传私密模型/诊断，不合并 main、不正式发布。
- 验证：位移支点/逆变换、参数上下界和优先级、Jev 请求及本地动作、窗口尺寸与生命周期；现有源/资源/路由门禁和 Flutter/Android 测试，Draft APK。私有模型视觉、键盘延迟与夸张程度仍需用户设备调节，不用空场景GL测试代替。
- 交付：`0.42.42+286` / 功能 `0627376f4f787a072cdabe94c8f25ab78da8b445`，Actions `36468439975` 全绿（129源门、3原生冒烟、Android单元测试、Flutter analyze、982 Flutter测试、release与签名/资源门）。Draft `398534068`：[测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6536c4ec9e8814a55b44)，SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`。默认幅度100%/速度100%/支点88%；先原样实测再调节，尚不标 TRUE DEVICE PASSED。

## 上一批 · +285 恢复 Live2D 并核对全部正文入口（CI 通过，测试 APK 已交付）

- 用户 22:46 明确批准：先修 Live2D，保留 +284 的大动作/表情、4.5 秒释放、按钮回聊天、同屏舞台/摸头框编辑、全界面视线、气焰修正；同时核对所有正文与真实性修正优先第二通道（400 可 DeepSeek 兜底），桌宠只改截图可见默认值。网页卡住暂不处理。
- 基线：`1a08a2d` / 功能 `b7b578a` / `v0.42.40+284`，分支 `agent/v04232-caicai-import-pet-touch`。+284 状态更正为 **CI PASSED / APK READY / TRUE DEVICE FAILED**。
- 已定位：TextureView 构造函数沿用 setBackgroundColor 导致原生视图创建异常；导入路径混用 canonicalFile 与未规范化根目录，目录别名下可复现移动后读回失败；主动回复存档记录第二通道 HTTP 400，最近主动 prompt 只有 system 消息。设备实际路径与 400 响应细节未保存，不能冒称两者均已真机定因。
- 计划：恢复已验证 GLSurfaceView 宿主、统一规范路径和导入事务、捕获创建及首帧失败；审计普通/主动/分享/悬浮/沉浸/游戏房间正文及修正分支，统一请求适配和路由；默认缩放151%、宽91%、x0/y1dp、色阶0/0.86/230、输出0/255、饱和度100%。
- 保护：原菜菜 renderer/三配件数学及资源哈希、TTS 口型、衣装、19 情绪、已实现的交互和大动作不丢；桌宠偶发缩小仍无证据，不猜修；不上传私密存档/诊断/模型；不合并 main、不发布正式 Release。
- 验证要求：路径别名/重导/回滚、真实 Android View 创建与生命周期、各正文入口路由/修正/400 兜底回归；CI 与真机分开。真机画面、键盘延迟和触摸观感须用户设备验收，不用测试数量代替。

### +285 实施与 CI 记录

- 状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。最终功能提交 `6cfca5a`，Actions `36455411205` 全绿，979 项 Flutter 测试及原生回归通过；最终包和证据见本文件末尾 +285 交付核验。恢复 GLSurfaceView 原生宿主，保留 30 FPS 节奏与 +284 全部表演接口；释放事件在原 GL 线程退出前完成，进程级 Cubism 所有权串行交接。原始 renderer/三配件数学哈希未动。
- 修复导入 root/file canonical 混用：所有索引都相对于规范化目录；staging 提升 current、backup 回滚和索引恢复使用同一规范。构造异常纳入错误通道；素材存在不再显示为画面就绪，30 秒加载看门狗仅在前台活跃舞台计时。诊断增加 build/首模型绘制帧，旧记录标 legacy_unknown。
- 第二通道：普通/后台聊天与桌宠共用 runner；主动所有 intent（含网页/游戏分享）共用 proactive；另核对 Cedar 房间、沉浸、日历。各正文入口显式使用 FinalReplyRoute，真实性/重复修正不改变路由，实际失败（含400）才兜底。系统消息专用任务增加“内部表达任务，不是真实用户发言”封装，不写聊天历史；400根因仍未证实，只修复已发现的system-only请求兼容风险。内部规划/Jev继续保留原通道。
- 桌宠默认：151% / 宽91% / x0dp / y1dp / RGB输入0、0.86、230 / 输出0、255 / 饱和100%；已有用户设置保留，截图外配置不改。
- 继续审计发现工具规划的 DeepSeek 前言会拼接到最终正文；双通道模式禁止拼接该内部前言，Gemini 截断待确认候选的即时展示也标记实际通道；手动保留旧截断草稿时的历史 model 元数据不可作为正文实际供应商证据。
- 宿主生命周期补强：临时 detach/reparent 只让 GLSurfaceView 重建 EGL，不把模型标成永久释放；真正 dispose 在原线程仍在时排队释放，若 Flutter 先 detach 再 dispose，则在旧 EGL 已销毁后清理剩余 Cubism CPU 状态并移交所有权。测试增加临时重挂和先 detach 后 dispose。
- 新增真实 Android emulator 门禁：直接编译生产宿主与仓库，测试 View 构造、空场景GL帧、暂停恢复、已暂停旧实例释放/新实例接手；导入测试覆盖别名目录、嵌套中文路径、提升读回、损坏包保留旧包、回滚、索引恢复、删除后重导。结构假模型不用于绘制，不构成私有模型真机成功证据。
- 首轮原生门禁运行 `36441861951` 在编译 smoke 时失败：Kotlin 未继承 Java SourceSet 的 exclude，误编入依赖 Flutter 的 PlatformView 适配器。改为 Sync 精确选入生产导入仓库/路径/诊断三文件；宿主/renderer 仍直接编译生产 Java 源码。没有删除测试或降低门禁。
- 后续 smoke 配置失败 `36442598138`：SourceSet 不接受 Sync Task 作为目录 notation，改为明确 generated 目录并保留 preBuild 依赖。`36447749140` 已完成编译并执行2项 Android 测试，导入事务通过；渲染初始化失败指出测试包漏装 Cubism shader assets，补齐生产 shader/profile 资源（生产 APK 已有独立资源门）。CI 失败监视器另改为文件输入，避免大日志触发命令参数长度上限。
- `8dc7cc0` / Actions `36448394737` 的 Android 原生门禁于2026-09-29 00:08中国时间通过：2项 instrumentation 测试，涵盖别名导入事务和宿主 EGL 绘制/暂停恢复/重挂/释放交接。仍未使用用户私有模型进行设备画面验收；完整 APK 检查与构建继续执行。
- `36448394737` 后续完整检查：128源回归、Android/Kotlin单元测试、Flutter静态分析通过。Flutter为973通过/6失败，失败全部是新HTTP夹具在http.Response中用默认Latin-1编码中文，未进入路由断言；显式改UTF-8响应夹具后重跑，不删除失败用例或放宽断言。
- `36450788936` 原生复跑出现进程 SIGSEGV。已下载 instrumentation 原始 logcat：崩溃线程是 Android10/API29 x86_64 的 Jit thread pool；栈为 libartbase Hc4_MatchFinder_GetMatches → LZMA/XZ → PackElfFileForJIT/GenerateJitDebugInfo，无应用/Live2D栈帧。API29前次通过仍保留，但不凭一次通过声称稳定。门禁改用API35 google_apis镜像保持JIT/断言启用，生命周期重复从2增至4；产品代码未据此猜改。API29真机兼容性仍未验证。
- `058288d` / Actions `36451634195`：API35原生门禁通过；同一生命周期测试连续4轮（包含临时重挂、暂停后替换、先detach后dispose）全部完成，导入事务通过。仍保持真机画面与输入延迟待用户设备确认。
- 最后核对后台/桌宠重连显示：生成检查点曾把 agent_tool_planning 的 DeepSeek content 写入 partialContent，虽然实时回调不发正文，重连读检查点仍可能短暂显示。规划检查点现只保留独立推理，正文为空，直到最终回复通道生成正文；源门新增断言。
- `053ceb4` / Actions `36452994727`：API35原生门、128源回归、Android/Kotlin单元测试通过；Flutter静态分析发现新路由测试的`http.Response(encoding:)`参数不存在（2处）。前一轮修复中文夹具时错误假设了构造签名，现按http1.6.0实际API改为`Response.bytes(utf8.encode(...))`，显式UTF-8事件流头；保留所有请求与路由断言。此次失败属于新增测试代码错误，继续重跑全部门禁。
- 本地原菜菜渲染/资源哈希门、路由连线门已通过；全源门初跑识别到旧版版本白名单/旧路由断言，已按本次新合同更新。环境缺Flutter/Kotlin编译器和部分CI恢复资源，完整编译/自动测试交给既有CI恢复环境；不降低资源门。

## 上一批 · +284 菜菜专项动作与舞台体验（真机失败，待 +285 修复）

用户已明确批准实施，并补充：以菜菜标注的真实可动参数专项设计；以 anai-1.1.53 APK 的幅度、速度作主要参考；Jev 驱动丰富头身表演；视线覆盖输入框、聊天记录及其他界面触摸。

- 基线：0fd3cfc（+283 CI/APK 成功后的总账记录）。所有上一轮未经汇报的试改已撤销，本轮重新实施。
- 证据：菜菜捕捉轴 X/Y 显动弱，应使用 X3/Y2；现有键盘逻辑停止连续渲染；手动预设永久 toggle；诊断有重复 surface/context 重建；普通形态 19 条气焰记录被固定扣 18。
- 本轮代码已实现：模型专用待机与 Jev 大动作；4.5 秒手动释放；按钮回聊天；聊天内舞台/摸头框编辑；全界面 gaze 与真实摸头；稳定 EGL 生命周期/键盘尺寸；普通形态不扣 18；针对性测试和 APK。
- 桌宠缩小：报告只有 small 与当时命中区域，没有尺寸变化因果证据，按用户要求不改。
- 保护边界：菜菜原 renderer/三配件投影、衣装、PCM 口型、独立情绪保持；私有附件不上传；不改模型路由/游戏/人格；不合并 main、不发布正式 Release。
- 验收：实现、自动测试、APK、真机分开记录；必须实机观察大动作、触摸、键盘和切前后台，不能用静态检查代替。

## 1. 接班协议

1. 新窗口先读本文件顶部至 `END QUICK HANDOFF INDEX`，再读取当前任务对应的正式记录、`app/docs/DOCUMENTATION_MAP.md`、当前分支/版本、最近提交和直接涉及的源码/测试；旧问题按索引定点查正文、归档或 Git 历史。
2. 每次正式修改前在“当前任务”登记目标、证据、保护边界与验证；完成后回填实现、提交、CI/APK、真机状态和下一步。
3. 容量约束只用于保持顶部快速索引简洁；标记后的正式内容没有字节上限，不因文件增长强制删减或滚动。自然阶段边界、操作性能明显下降或需要不可变证据快照时才建立只读归档。
4. 已有冻结归档：
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.74+218.md`：1,587,679 bytes；SHA-256 `602c712f0fb06e70c054c2d54fe0e280f312923864040a3a177ee8e7da67ed70`。
   - `app/docs/ledger/archive/AI_Companion_总账归档_截至_v0.41.84+228.md`：98,372 bytes；SHA-256 `47d053d842a73e3ff8107dabe867bd503e8a7e77daaecc2afb1867068faa952c`。它是压缩前当前总账的逐字节快照，包含 +219～+228 的完整诊断、设计、实现与 Actions 证据。

## 2. 永久产品与工程边界

- **主体性优先**：事实与安全 Gate 约束虚假完成、越权、凭据泄漏和不可逆损坏，但不把她训练成处处等待批准的被动工具。
- **模型/API 双通道**：内部判断、维护、工具规划与 Outcome 核验走 DeepSeek；双模型模式只在收齐整轮上下文和真实工具结果后调用一次独立的 OpenAI-compatible 第二通道形成可见回复。第二通道地址和模型可由用户配置，默认仍是原玩游 Gemini 地址与模型；非 Gemini 模型不得收到 Gemini 专属 `google.thinking_config`。MCP 网络请求不是模型调用。
- **Jev 决策层（修改模型路由前必看；持续观察）**：已有 OpenRouter `typesafe/jev-1.13` 的可选短判断入口，默认关闭；普通聊天互动/主动玩笑与沉浸房间模式/事件各用一次批量 Choice 判断。有效 Jev 答案选最高概率；气焰相关选项前两名差距不超过 0.10 时记中性，不加额外气焰，但小豆丁每完成一轮固定减 18（用户 2026-09-28 更正）。`confidence` 不是本地 0.55 门槛，低 confidence 的有效答案不重调 DeepSeek。仅 Jev 关闭、无 Key、传输/额度/超时或无效结构时保留原 DeepSeek 兜底；取消不重复调用，不将 Jev 结果当工具执行事实。**下次及以后每份存档和诊断报告都必须逐轮核对 Jev 原始选项概率、实际采用值、DeepSeek 兜底原因、气焰前后账与真实语义，记录误判、延迟及费用，直到用真机样本明确验证成功；未验证前不得标成完成。**本机导出诊断包含 Jev 的有界原始对话上下文，属用户私密数据，不上传公开仓。详见 +277 和 +260。
- **真实工具事实**：只有成功的真实 Outcome 能支持“已进入、已落子、已发送、已保存、已完成”。失败、blocked、no_result、超时或零调用不能由对白补写。
- **唯一循环所有权（未来功能开工前必查）**：每个会连续推进的能力必须只有一个 continuation owner，并在设计时写清 `execution_id`、唯一触发源、一次唤醒最多规划轮数/工具调用数/真实 mutation 数、终止条件、Stop、崩溃/主后台切换后的恢复规则。用户回合、后台 cadence、工具 Outcome、UI 轮询和平台 callback 可以提供事件，但不得各自继续同一 execution；`next_call / continuation / resume_after` 是权威事实，不是再启动一条循环的许可。Cedar 曾经让前台 Agent 循环、后台游戏循环和 Outcome 续接同时推进，造成重复调用、Token 暴涨、终局丢失与 Stop 不彻底；此事故模式是永久踩雷样本。
- **循环能力首版诊断（随功能一起交付）**：任何新的 MCP、工作区、视频、提醒、Live2D 长任务或其他可续接能力，第一版就必须以脱敏方式记录 `feature / execution_id / trigger_source / continuation_owner / phase / planning_rounds / tool_calls / committed_mutations / continuation_requested / terminal / preempt / late_write / usage_lane`。诊断不得保存 Prompt、Thought 私密正文、密钥、房间凭据或用户文件内容；没有这组证据，不允许靠继续加 retry/delay 猜修循环。
- **Cortico 低风险参考（未来功能设计索引）**：参考项目为 `https://github.com/Pal-AI-Lab/Cortico`。只吸收两个边界思想：一是外部环境通过“可观察事实 + 可执行工具”接入，World/事件事实不直接等于聊天、记忆或成功声明；二是把 `preempt / flush / debounce / piggyback` 当作按功能选择的投递语义词汇。当前项目不移植 Cortico 的中央 Event Stream、World 容器、完整队列/状态机或记忆连续性取舍，不推倒现有自主逻辑。新增能力逐项建立小型隔离适配层即可：输入只形成验证过的观察，执行只经现有 Agent/Outcome 真值链，是否进入对话、短期桥或长期记忆仍由本项目现有策略决定。
- **Cedar 信任优先**：实时 catalog、玩家指南、合法动作、`next_actor / next_call / revision / legal_actions / resume_after`、防沉迷和终局以服务端为权威；APK 不以本地猜测覆盖。
- **Cedar 盲玩隔离**：运行时只使用 Cedar 玩家接口、当前聊天、正常存档与玩家可见 Outcome；`playerSafeGuide` 不得泄露仓库、源码、隐藏状态、题库答案、攻略、剧透或外部网页。游玩链不暴露 `public_web.search`。
- **自然语义 Agent**：允许“陪我下五子棋”等自然表达触发模型自主发现；普通“看看”不是联网授权。Cedar 的账号级 `allow_self_reset` 服从网站设置。用户已决定暂不增加 Agent 确认弹窗，直到未来加入修改/破坏性能力再设计确认。
- **媒体 Agent**：她能发送的媒体必须同时具备自读能力、可执行工具、真实附件 Outcome、来源 provenance 与发送后第一人称历史；只在 UI 或 Prompt 声称不算完成。
- **隐私与发布**：Token、绑定码、私密房间正文、用户附件、诊断、备份、模型权重和参考音频不得进入公开 Git/Prompt/公开诊断。用户持续授权推送明确开发分支并运行常规 Actions/Draft APK；不含合并 `main`、正式 Release、删除分支/用户数据、改变仓库权限。
- **冻结范围**：旧 Sen 产品适配器继续冻结；+275 以菜菜测试项目的原生渲染实现单独接入 Live2D 自主待机，后续 Jev/语音/双形态需分批验证。+249 的 Decoder 零新语义防护继续保留；+250 将日常持续会话计时移为手动 TTS 专项对照，并实现双形态气焰值。普通回复表情包已真机重新出现，未发现概率数值漏洞时不强改。

## 3. 当前基线

| 项目 | 当前事实 |
|---|---|
| 仓库 | `catkiss62/ai-companion-build`；Flutter/Android 工程位于 `app/` |
| 功能基线 | `agent/v04184-agent-loop-autonomy-closure`，`v0.41.84+228 / schema 61 / Snapshot protocol 6` |
| 功能状态 | `CI PASSED / APK READY / TRUE DEVICE PENDING` |
| +228 远端 | head `29e87d016c8bd81f52f89f95191bd1a1a01a5b57`；tree `c4a112a56d8b634cf3a1a66636979a0833538b7d`；Actions `35440359036`；Artifact `10583263879`；APK SHA-256 `159e283173e49da2924d25b37ba7647893cdafdcc31b63f0e31b7c64e086849b` |
| 仓库维护基线 | `maintenance/repository-governance-20260919`；远端文档 head `123e272196e8ae93f3518157917d76f6af4f1784`；完整构建 head `fa99f32012fa1a0716b746d36b958a8e777ef9b8`；Actions `35446649873` 全绿；文档-only run `35447342921` 正确跳过 APK |
| 当前功能分支 | `agent/v04224-pet-opaque-fullframes`，从 +267 总账 head `224e832` 分出；构建候选 `v0.42.24+268` |
| +269 当前任务 | `agent/v04225-pet-full-clips-heat` 从 +268 head `27dc991` 分出，构建 head `b9f854e960bca401c861b769cda2576b79ef9d9c`。原始 ZIP 在 Draft Release `397377805`、asset `591363139`，SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`。排除 move/drag/balance 后 96 段、23,013 帧；五段点击、三段睡眠仅预览、自主池不稀释走路、桌面不透明、特效随尺寸、预览布局及回复后整轮气焰结算已实现。Actions `36271743353` 全绿，APK 722,612,227 字节，SHA-256 `0830c3e6d36a9ac0d5b94628cf6fac9564e02d8d8d6d0b4ae784d7f8d2dd9453`，未发布 Draft Release `397385083`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真机视觉、透传触摸与性能未验。素材由固定 Draft asset 获取并校验，不逐帧上传对话。|
| +270 当前任务 | `agent/v04226-pet-opaque-ambient-preview` 从 +269 远端 `f57acba` 分出。用户真机发现同一段新动画在“实验动画”关闭后继续播放却立即变实，证据指向独立实验 WindowManager 绘制层。改为单窗口不透明播放，保留原触摸/基础动作；“新版动画”默认开，旧模式保持原逻辑，新模式移出旧的非基础待机、纳入三段睡眠与工作/思考短片待机（深度思考碎碎念若裁切不宜修则排除），聊天思考与说话仍用旧动作；校准入口移至播放器首位，两个 Activity 修复上下裁切。旧 APK Draft `<=+265` 由维护 Actions `36275881299` 删除 191 个，人工删除 3 个；保留两份无 APK 草稿及构建输入。构建 head `4b205aee8f8e27a50ee4a87f5f1060fbf1dc4b7d`；Actions `36276798640` 全绿，未发布 Draft `untagged-c838b8c01ac127dd5d71`，APK SHA-256 `8e8a0b3c2809bb53efa9bd9e53e3d058ec0126231a736213fe69d395623cb85b`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。|
| +271 当前任务 | 用户报告 +269 昨晚到今午无自主聊天。旧版 2026-09-27 16:03（中国时间）存档/诊断：最后主动消息 09-26 11:14；过去 24 小时 `autonomousBehaviors=0`；Active Brain=true、无传输锁、无当前阻塞生成/租约，后台错误累计 677、最近错误 `MissingPluginException(pendingStoppedReminders)`。`RecoveryOrchestrator.runOnce` 在自主心跳前调用日历提醒读取，后台 `BackgroundSystemBridge` 缺少该方法，导致整轮退出。+271 补齐后台日历读取/确认，并让提醒独立失败只记错误分类、不拖停自主心跳。分支 `agent/v04227-proactive-background-bridge`，构建 head `5860cd54238e77ec65e6b911decee71020ae5316`；Actions `36305352339` 全绿，APK SHA-256 `a2236878e9234570ee6e90f6e288cb25b4f9186653b2b09ef54a147f3b49e879`，未发布 Draft `untagged-fb80911e6438a3a7d7d3`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。|
| +274 当前任务 | `agent/v04230-game-resume-pet-collapse`：用户真机观察自主游戏断续；源码证实检查点到期先延期 8 分钟、再触发意愿竞争，使 `resume_game` 因时钟未到期被排除。改为先竞争、未选中再延期，保留每次一步、3 次变动/25 分钟检查点、投入度/疲劳竞争和防沉迷；新动画默认缩放 147%（旧 121% 仍作显示基准），工具活动正文出现后自动折叠。另根据 20:13 诊断修补 Cedar 动作清理失败时租约未释放，并澄清备份占用提示；街机厅首次错误随后正常游玩，无确证协议故障，不改玩法。素材管线不改。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，详见末尾 +274。|
| +275 当前任务 | `agent/v04231-caicai-native-idle-pet-speech`：菜菜双模型原生渲染／自主待机与桌宠说话心跳。HEAD `968ca7c`，Actions `36329874552` 全绿，Artifact `10935547935`，Draft `397702273`；状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED（导入重试）`，详见末尾 +275。|
| +276 当前任务 | `agent/v04232-caicai-import-pet-touch`，候选 `v0.42.32+276`：导入后未渲染导致 pending 拦重试；新版 16:9 桌宠窗口使可操作范围过大。保留菜菜原生渲染及宽动画；修复二次导入事务并收紧桌宠手势到旧方形。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，详见末尾 +276。|
| +277 当前任务／Jev 持续观察 | 用户真机反馈 +276 桌宠范围无变化、菜菜导入无反应、Live2D 令输入法卡顿；Jev 低 confidence 回退频繁且旧诊断无法审计。重新按 +222 旧方窗及菜菜实验室 `fb04512` 验证源码：恢复真实 152×152dp 中号窗口与旧坐标迁移；导入/渲染阶段及 IME 降载；Jev 用最高概率、近似平局不加气焰、小豆丁固定 -18（用户更正），导出完整 Jev/气焰账。`v0.42.33+277`，Actions `36342200023` 全绿、测试 Draft 已有；状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED（用户回归反馈，见 +278） / JEV ACCURACY PENDING`。每份后续诊断与存档都分析 Jev 准确度，直到真机明确成功。详见末尾 +277。|
| +278 当前任务 | `v0.42.34+278` / 同 `agent/v04232-caicai-import-pet-touch`。+277 用户已报告动画缩小、导入未显示、空模型开关卡输入法，不能沿用 TRUE DEVICE PENDING 掩盖失败。恢复批准的宽动画尺寸，系统输入区域独立；无模型不创建原生视图，渲染失败保留导入包，Hybrid Composition/焦点隔离；Live2D 独立设置与确认删除；Jev 稀疏动作/原装预设/小豆丁/PCM 口型。构建 head `cf69e61`，Actions `36348468407` 全绿，961 项 Flutter 测试，Draft `397797809`。`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。Jev 持续观察，最高概率/近似平局中性/-18 不改；详见末尾 +278 和专项文档。|
| +279 真机回归 | 用户 `2026-09-28T00:57:57Z` 脱敏诊断：六次导入均有 `manifest_validated → import_staged`，最终 `available=false / pending=true / render=not_open`；桌宠 `overlayPetTouchRegion=unavailable:NoSuchFieldException`。+279 的绿色 CI 和 Draft 不能视为效果成功，状态改为 `TRUE DEVICE FAILED`。|
| +280 当前任务 | `agent/v04232-caicai-import-pet-touch`，`v0.42.36+280`。导入后正式目录模型/索引读回与恢复、明确错误；桌宠 112/152/200dp 真实触摸窗口与独立可信宽绘制层，移除失败的隐藏 insets；普通闲聊话题词不额外触发 Agent DeepSeek 规划。Actions `36370446031` 全绿，Draft APK 已就绪；用户后续复现层残影、尺寸回退和 Live2D 背景穿透，状态更正为 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FAILED / JEV ACCURACY PENDING`；见末尾 +280。|
| +281 当前任务 | `agent/v04232-caicai-import-pet-touch` / `v0.42.37+281`：用户真机确认 +280 Live2D 导入成功，但聊天页透明背景显示上一次页面，桌宠变小，更多页出现两、三层持续增加的静止桌宠假图片且不接收触摸；+280 真机状态改为 `TRUE DEVICE FAILED`。固定旧待机正面原帧为小／中／大尺寸的唯一触摸 alpha 范围，动作变化不改范围；恢复原宽动画绘制比例，一个 WindowManager 桌宠窗口，失去系统 alpha mask 时禁用整窗触摸；移除反复重挂载，聊天页不可见时销毁 Live2D 原生 Surface。`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`，Actions `36376305397` 全绿；详见末尾 +281。|
| 当前任务状态 | `+265～+267` 已有构建与真机反馈；`+268 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`：不透明桌面播放、独立宽度与饱和度、24 fps 全帧与播放器时钟；`+269 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`：96 段完整动作及整轮气焰结算，见末尾 +269。|
| +267 远端 | 功能 head `07142df2f01f15b5e4770fb6d17b48150770f422`；tree `aa16c6405f87967191dcb5b99662c53302983c52`；Actions `36232295089` 全绿；Artifact `10903136887`；APK SHA-256 `956812613c1fb00123e2ab2e6a3f5f3ccc1d320743c7bd6b866c4e0365b09ab2`；未发布 Draft Release `397169363` |
| +250 当前任务 | 本体／小豆丁形态共用成年角色、记忆与能力；同一形态状态驱动角色提示与静态立绘，虚拟弹额头／安抚改变气焰值后继续自然衰减，心形液面与锁定入口；常驻世界书定点柔化并仅迁移未编辑原文；两档 TTS 共用冻结的真实回复与分段，无声生成并复制专项脱敏报告 |
| +250 最终构建 | 功能 head `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`；tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb`；Actions `35943607609` 全绿；Artifact `10785922926`；APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`；未发布 Draft Release `v0.42.6-dual-form-tts-comparison-test` |
| +249 当前任务 | `loopIndex=0` 时明确判定“零个新语义 token”，在 VITS 前拒绝本段；最后两次会话记录生成时 profile、冷/热状态、各阶段耗时、RTF、播放首帧、队列余量、迟到段、失败/停止与脱敏文本哈希 |
| +249 保护边界 | 不播放参考 prompt、不添加固定语音/固定台词/System TTS 兜底；失败段独立跳过，其他段继续；仅同一文本、音色、语言且分别为 `legacy_fixed_8` / `auto_affinity_v084` 才计算性能对比；schema 61 / Snapshot protocol 6 不变 |
| +249 远端 | head `fb7f77f85d882f99530ab829df9a82eaa604e559`；tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99`；Actions `35900627244` 全绿；Artifact `10770090214`；APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`；未发布 Draft Release `untagged-3a02088d4968fd7ab603` |
| +248 远端 | 远端 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c`，tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255`；Actions `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`；未发布 Draft Release `untagged-2b371d8cd86b365121b0` |
| +248 当前任务 | TTS 默认关闭的“自动核亲和加速”开关；四个声学会话与 Chinese RoBERTa 同用 `AUTO_AFFINITY`。生成中展开全部工具活动，完成后以脱敏卡片绑定回复，中止后绑定中断标记 |
| +248 保护边界 | 保留现有分段首段预填充、串行生成与连续 AudioTrack；不移植测试档、动态分块、FTZ/DAZ、输入映射复用或 memory-pattern 实验；工具卡不保存/展示参数、搜索词、URL、结果正文、Prompt 或隐藏推理；schema 61 / Snapshot protocol 6 不变 |
| +247 当前任务 | `nativeToolDefinitionsFor` 在路由结果的可变边界先建立防御性 `Set` 副本；覆盖纯图片与原生表情包 `content=''`、`promptContent` 非空且 Cedar 已配置的回归，不改千问视觉、`sticker_index`、模型策略或最终回复内容 |
| +247 保护边界 | 只修共同崩溃点与回归门；不把表情包接入识图，不改变 Cedar 阶段选择、工具权限、schema 61、Snapshot protocol 6、人格、欲望、TTS 或 Live2D；不合并 `main`，不发布正式 Release |
| +247 远端 | 功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8`；tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72`；Actions `35855141996` 全绿；Artifact `10747841131`；APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`；未发布 Draft Release `untagged-376e1bf8ac7aac97af25` |
| +246 当前任务 | 识别中的图片允许立即删除，迟到的千问结果不得复活消息或报错；`403 Free quota exhausted` 明确归类为额度耗尽；`please` 不再误命中 `lease`；普通备份冻结不再显示“她正在换设备”。表情包仍使用本地 `sticker_index`，不新增视觉调用或固定回复兜底 |
| +246 保护边界 | 不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 61 或 Snapshot protocol 6；不合并 `main`，不发布正式 Release |
| +246 远端 | 功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0`；tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448`；Actions `35843632708` 全绿；Artifact `10742996195`；APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`；未发布 Draft Release `untagged-d99196e0bf0a288629ac` |
| +245 当前任务 | 21:00～次日 09:00 所有主动来源共享最多一次成功投递；“我会玩游戏”不再误授权 Cedar，前台真实游玩与后台共用局次/疲劳/满足账本；千问视觉新增真实连接测试与鉴权分类；TTS 只保留参考音频不可逆声学签名，高置信回声直接拒绝播放且没有固定音频/台词兜底 |
| +245 保护边界 | 不修改独立 Sen 仓库或已回退 Live2D；不增加对话模型调用；表情包继续使用本地索引语义进入当前 user prompt；schema 61 / Snapshot protocol 6 不变；不合并 `main`，不发布正式 Release |
| +245 远端 | head `09a50bdf14cfc1f5850c4c055fcbeade1b9dedb2`；tree `0985f0961691bdce7e6d521d59a12137ea5a82ad`；Actions `35809712355` 全绿；Artifact `10729507323`；APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`；未发布 Draft Release `394245028` |
| +244 远端 | head `c16955ad0a8eeb3945d95c8b42372859d6ab09b8`；Actions `35642646319` 全绿；Artifact `10659441135`；APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`；未发布 Draft Release `393217151` |
| +244 当前任务 | 以 +237 的共享文件为机械基线回退 Live2D，同时保留 +241/+242 自然回复修复；删除 Sen 服装、预设、动作、情绪、PlatformView、Cubism AAR/Framework/shader 与 TTS/视线/摸头接线；聊天快捷面板永久提供带确认的旧模型包清理按钮，只能删除 App 私有 `filesDir/sen-live2d` |
| +243 当前任务 | 启动只加载服装而不批量启用全部原生预设；只显示三套服装、脱与眼镜；20 种聊天情绪接入，脱/NSFW 使用 `romantic_shy`；原生待机、摸头/彩蛋和当前 PCM TTS 口型保留；人物与特效共用位置/缩放；Flutter 全局触点驱动视线；输入法只挪动聊天面板，不改变 Live2D 原生表面尺寸 |
| +242 当前任务 | 不允许任何本地固定台词以她的身份替代模型回复；用户轮不能被校验器吞成空回复，主动轮可不发送；Sen `main@336b93a` 只读，AI 内的 16 个 Sen 主运行时文件逐字节一致，唯一 Framework 差异只能是 Sen 原始 `cubism-java-no-mipmap.patch` |
| +240 真机结论 | `PlatformViewLink + AndroidViewSurface + initExpensiveAndroidView` 没有修复黑色剪影，反而使整个 Flutter 合成画面变黑；该方向已在 +242 回退。复核 Sen 构建流程后确认 +239 黑色剪影根因是移植时漏掉 `cubism-java-no-mipmap.patch` |
| +240 失败路线 | 仅保留历史证据；当前生产舞台不得出现 `PlatformViewLink`、`AndroidViewSurface`、`initExpensiveAndroidView` 或 `forced_hybrid_composition` |
| +240 远端 | 构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`；tree `4ef513abf3cbcd20db61357ee5bf4172868474ac`；Actions `35526854350` 全绿；Artifact `10609559197`；APK SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3` |
| +239 真机结论 | shader 缺失已修复：同一模型在 +239 进入 `created → model_load/ready`，未再出现 shader renderer error；但标准 `AndroidView` 合成后显示为黑色剪影，因此整体 Live2D 呈现继续由 +240 验收 |
| +239 远端 | 构建 head `6223c66a09850f950b9646990459133ea8661d32`；tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109`；Actions `35523577868` 全绿；Artifact `10608368899`；APK SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287` |
| +238 当前任务 | 原样保留 Sen 已真机验证的 21 情绪、自主待机、视线跟随、摸头彩蛋、物理、三套衣服+脱与眼镜；与静态立绘互斥，接入现有情绪效果/音效、用户消息倾听反应和 TTS 波形口型；不改悬浮鲸鱼、人格/欲望真值或模型调用次数 |
| +238 远端 | 构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`；tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；Actions `35521027339` 全绿；Artifact `10608496160`；APK SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c` |
| +237 当前任务 | 将未完成游戏事项、旧 ASSISTANT 场景与真实 Cedar 游玩状态分开：没有当前成功 Outcome 时只能说“还没玩/想去玩/之前玩过”，不得虚构正在钓、等待咬钩或图鉴刚才没涨；兼容纠正 +236 前已持久化为 attachment 的游戏 thread Thought |
| +237 远端 | 构建 head `0caa9382a472b53f574302064b387b527efae6df`；tree `70cf7225714f0514a7ee385f01cf1e3a499b4acf`；Actions `35509919804` 全绿；Artifact `10605181041`；APK SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2` |
| +236 当前任务 | 吸收欲望系统 2.0 的可验证因果账本与竞争诊断，不引入女性向保护欲或第二套欲望真值；把游戏“上瘾”改为可被心境、新兴趣与饱和打断、冷却后可重新点燃的短时投入；过滤 `not_due` 空候选、统一游戏语义域并区分游玩与分享 |
| +236 远端 | 构建 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f`；tree `910c3950d354734adca82c58b5db8559fbbcb861`；Actions `35506384676` 全绿；Artifact `10604605761`；APK SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22` |
| +235 当前任务 | 保留现有昼夜身体疲劳与连续 `rest_need`，新增有界、短时的正向激活与负面难安静调制；自主主动消息和 Cedar 真实推进在高疲劳时积累睡眠债，经过真实安静窗才回补；用户主动聊天始终正常回应，不新增循环、不改 schema、人格、世界书、最终回复通道或 TTS |
| +235 远端 | 构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`；tree `ee125bd9967b277975decec70b551ba1c7e7918b`；Actions `35501928714` 全绿；Artifact `10602523875`；APK SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628` |
| +234 当前任务 | Cedar 五槽事实、已有/turn 0 存档续玩、已知空槽自主开档与破坏性覆盖确认边界；将固定玩游 Gemini 选项改为“`双模型（自定义最终回复）`”，地址/模型可编辑并以旧值预填；不改 schema、人格、疲劳、TTS 或内部 DeepSeek 通道 |
| +234 远端 | 构建 head `16589fc8a88574f5a77f0731f8972e65fe990538`；tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5`；Actions `35498575549` 全绿；Artifact `10601008319`；APK SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3` |
| +233 当前任务 | 先修 Cedar Outcome Thought 的事件身份、一次分享与时间锚定；再做愿望单安全主题投影；最后只做语义等价的 DeepSeek 缓存观测/低风险优化。三部分独立提交与验证门，不改人格、疲劳、Cedar 玩法/循环所有权或 Gemini 按次回复链 |
| +233 远端 | 构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`；tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；Actions `35475970152` 全绿；Artifact `10593264636`；APK SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3` |
| +232 目标 | 游戏厅“最近进展”窄面板复用“游戏活动”同款 Card 颜色；愿望单按安全主题表达并合并同主题活动愿望；登记 Cortico 低风险参考、唯一循环所有权与后续诊断护栏；不改 Agent 循环、疲劳、缓存、TTS、schema、世界书或人格 |
| +232 远端 | 构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`；tree `54da8912e76ce5d59ec142387f1708a972196640`；Actions `35469452065` 全绿；Artifact `10592781832`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622` |
| +231 远端 | 构建 head `75d9e0a311d5b322f53a742b9016aac16d44c9d9`；tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；Actions `35464168272` 全绿；Artifact `10591085711`；APK SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565` |
| +230 远端 | 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`；Actions `35458277355`（attempt 2 全绿）；Artifact `10589621373`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a` |
| +229 远端 | 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Actions `35450357850`；Artifact `10587305305`；APK SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6` |
| `main` | 仍为 v0.38.5 旧基线；不得作为 v0.41.x 起点，本批不合并 |

历史兼容与未来扩展索引：`v0.41.82+226` / `agent/v04182-cedar-state-machine-e2e`；`v0.41.83+227` / `agent/v04183-cedar-native-agent-loop`；`v0.41.81+225`；`模型自主发现`；`陪我下五子棋`。全工具调用动作展示已进入 +248；双人格与命运之轮的冻结分析见 6.21，均不得在本批顺手实现。任何新 MCP、工作区、视频理解、Live2D、提醒或长任务先查本文件的 **“唯一循环所有权”**、**“Cortico 低风险参考”** 与 **“循环能力首版诊断”**，不得再复制 Cedar 曾出现的多套循环。

+252 工作分支 agent/v04208-jev-game-result，候选 v0.42.8+252：OpenRouter Jev 两处短判断与 DeepSeek 兜底；保留 +251 气焰语义判断、TTS 和 Gemini 修复；Cedar get_result 不再凭旧结果生成新分享。余额面板延后；详情见 6.25。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。\n\n+253 工作分支 agent/v04209-tts-preflight-heat，候选 v0.42.9+253：快速自检只读取 APK 安装资源；TTS 子进程超时重置绑定并一键顺序无声对照；气焰 0～100 每轮 -10、满值五轮冷却退出，害羞本身不加分。前批 Jev/DeepSeek 兜底不变；详见 6.26。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。

+254 工作分支 agent/v04210-audio-heat，候选 v0.42.10+254：情绪音效改用媒体音量通道，硬件音量键控制媒体；轻微玩笑净降 6 点，互相挑衅需明确升级；Jev 回退诊断按题区分不确定与格式错误。紧急存档事件：+252 06:40 诊断仍有 422 条记忆、1 条会话、旧设备/谱系指纹，+253 08:44 诊断变为 0 条记忆、0 条会话、状态代数 0、新指纹，证明启动了新数据库；本份报告不含闪退栈，不能归因于 TTS 或声称旧库可恢复。06:39 外部 .aibackup 是已知恢复候选，恢复前保留原件且禁止卸载/清数据。状态 IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING；详见 6.27。

+256 工作分支 `agent/v04212-form-pitch-zero`，候选 `v0.42.12+256`：气焰只在 0 自动退出小豆丁，严肃话题仍认真回应；设置音调是小豆丁基准，本体低 1 半音。沿用 +255 已真机恢复的单一试听和发声链，保留锁定与手动安抚。状态 IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING；详见末尾 +256。

+283 当前任务：以 +282 远端为基线，依据 2026-09-28 存档与诊断收紧 Cedar 关键词误触发；Gemini 成功时由 Gemini 完成一次正文修正，DeepSeek 仅第二通道失败兜底；菜菜导入状态精简、十九情绪预览和 Jev 逐轮情绪判断。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING；详见末尾 +283 正式记录。用户私密存档、诊断及模型素材不得上传公开仓。

<!-- END QUICK HANDOFF INDEX -->

## 当前修复 · +296 保留直接合成恢复，把昼夜背景合入人物 Surface（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-30 09:40 用户确认 +295 切出切回卡住→消失→重现已经解决；但人物背后默认黑色，进入“更多”或“她”再返回聊天时露出刚才页面。截图 `1000155919.jpg` 显示聊天文字/按钮与人物正常叠合、背后却是更多列表。**+295 恢复项单独 TRUE DEVICE PASSED，背景项 TRUE DEVICE FAILED，整版 PARTIAL。保留成功的直接 HC，不回退 Virtual Display。**
- 同版专用诊断 `live2d_diagnostics_2026-09-30T01-34-52.929576Z.json.txt`：`view_id=1 contexts=1 surfaces=18 frames=1811`，约 59.5 fps；09:34:21、32、44 的多次 Activity 恢复后仍 context=1，模型纹理仅解码/上传 7 张，原先约 2.7 秒重载不再出现。Surface 仍可因停止/显示变化重建，但 EGL 被保留，没有证明“Surface 永不销毁”。普通诊断同为 +295。本次只分析此问题，不改 Jev/Cedar。
- 读取 Android 15 [SurfaceView 官方源码](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/core/java/android/view/SurfaceView.java)：默认窗口下层的 `draw/dispatchDraw` 用 `clearSurfaceViewPort` 清空其后的窗口 Canvas，`gatherTransparentRegion` 声明透明区域；Flutter HC 背景 `FlutterImageView` 是同窗口的 Canvas 图像，旧 FlutterSurfaceView 的冻结帧在更下层。此源码机制与黑底/上页透出一致；不把旧页误认成正在绘制的聊天背景。简单媒体 Z 层仍在窗口下，`setZOrderOnTop(true)` 又会挡住 Flutter 聊天覆盖层，故不采用这两条。
- 修复：保留 +295 `PlatformViewLink/initExpensiveAndroidView/GLSurfaceView`。仅为伴侣宿主增加 `CaicaiStageBackground`，将原有公共 day/night WebP 以不透明 GL 四边形绘入与人物相同的 Surface，然后绘制原有 Cubism 人物；Flutter 保留聊天覆盖层、普通立绘与无模型状态的背景。从 Dart 同步现有昼夜选择，原生只接受这两个公共素材路径；居中 cover 及稳定 sceneHeight/顶部 IME 裁剪与 Flutter 原布局一致。纹理按资产变化或真正 EGL 换代加载，Surface 改尺寸/恢复不重解码；缺图记录背景错误且填充不透明深色，避免旧缓冲透出。诊断 state/frame 添加背景资产/加载与上传次数，不包含用户图片或私有模型。
- 验证：新 Android ES2 pbuffer 像素烟测检查昼夜颜色/上下方向、alpha=255、IME 顶部裁剪不挤压、同资产多帧/resize 不重复加载、真正换 context 重建纹理，以及缺失图像不反复重试。原有 26 文件/配件算法经宿主标记剥离仍通过来源校验；新背景层独立于私有模型。版本 `0.42.52+296`，独立分支 `agent/v04252-caicai-surface-background`；构建结果另行回填。
- 构建：本地功能提交 `c88bc4e3284df94a7317af754867a1e0c14222a4`，远端同源码树 `0a1b2f3695c9eac4a32989cefe5ec2008b5c22a1`，tree `ad979f9d6f3d1a0cca34187313ad9165f9413177`。[Actions 36657791150](https://github.com/catkiss62/ai-companion-build/actions/runs/36657791150) `success`；原生模拟器日志确认新增两项背景像素测试与既有三项测试合计 5/5 完成、0 跳过、0 失败；130 项源码门、Kotlin、Flutter analyze/test、arm64 Release、资源和签名核验全绿，失败报告跳过。未合并 main。
- 未发布 Draft `399666814`：[+296 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6cc8871713cb98446307)，target=`0a1b2f3`，asset `599823261`，文件 `AI-Companion-v0.42.52-296-Caicai-Surface-Background-APK.apk`，726117130 字节，SHA-256 `2e8d26353b2705bdc2340a7bc8b9906139bebcde76db7b7d65d2be51b2bb2dce`；Artifact `11074270365`。CI monitor 与 release digest 一致；签名证书 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与现有测试版本一致，可覆盖安装保留数据；`draft=true / published_at=null`，未正式发布。背景和综合真机效果仍 PENDING。
- 真机待验：开机直接进聊天可见正常昼夜背景；“聊天→更多→聊天”和“聊天→她→聊天”各三次无旧页残留；“≡→直接返回”和真正切 App 后返回仍无秒级空白；聊天文字、按钮、气焰条覆盖顺序正常；键盘开合人物和背景保持尺寸。+293 保留完整视觉回退基线，+295 保留恢复成功的源码与 Draft；若失败记录具体项，不能覆盖已确认的恢复成功事实。



## 当前实施 · v0.42.53+297 沉浸形态快照、独立情绪层与自主游戏投入（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 2026-09-30 用户批准开始七项方案，并明确情绪动画只是独立固定动画层，按现有情绪动画/语音开关播放，不改Live2D表情、动作、参数或效果。此最新要求覆盖方案3中任何可能涉及修改Live2D效果的表述。
- 基线+296及方案总账HEAD `034d643`，独立分支 `agent/v04253-room-freeze-game-session`；实施沉浸入口快照与房间气焰判断删除、普通突破语义、独立情绪层、持续游玩竞争与有限对话倾向、小型记住事项及原图圆形悬浮球。用户特别要求核对沉浸共用机制，保留普通聊天与已成功功能。开始时仅记录范围，尚无新CI/APK/真机证据。

- 实施已落地：沉浸控制器唯一全局读取仅在入口捕获qForm，不保留热度；send/regenerate/保留截断回复不再执行Playful用户/助手/突破判断或写回；房间提示、立绘与三语/手动TTS都用同一快照。普通100资格、首次满值、0退出、锁定与0.10平局边界未改，仅突破提示支持累计玩闹与强烈害羞。
- 情绪新增独立固定图案层与“情绪动画”开关；现有短音效仍由emotion_sound_enabled控制，沿用用户音量（默认0.15），没有改Live2D模型实现。历史ID初始化不播放，单条新回复至多一次，隐藏/关闭取消；悬浮球用原图圆形裁切，未改拖动、点击、贴边或未读徽标。
- 持续游玩是Desire竞争选中的独立action，统一归入play_game冷却/满足账本；一次授予30分钟有效投入，暂停/长时间进程挂起不计时，同日同游戏有效，进程重启或导入不自动恢复。沿用单Cedar执行器和围栏，服务器防沉迷、结束/等待人类、夜间与疲劳会终止；推进后普通主动聊天仍可竞争，不占每步主动槽。对话鼓励/暂停用现有Jev路由合批（失败沿用原DS路由），正式回复提交后才保存；最多±0.10、3小时半衰、12小时过期，重复仅刷新不叠加。
- 记住事项入口：本地记忆库右上角→记住事项，手动添加/编辑/删除，最多16项（事项24字、事实120字）。通用settings随备份保存；普通及主动相关话题参考，当前当天例外优先，不写Memory重要度、不产生Thought/提醒，不从角色扮演抽取，也不注入角色扮演。
- 新增Flutter行为回归覆盖房间TTS冻结/普通TTS仍随全局、30分钟与暂停/跨夜、疲劳/睡眠、鼓励幂等/衰减/撤回、日常事实持久化与情绪历史不重播；新增专项源门，旧版本白名单追加297且其余合同保留。本地Dart语法、YAML、专项门与关联源门已通过；完整资源/Flutter/Kotlin/APK由Actions核验，未宣称真机通过。CI监视路径为ci-monitor-v0345分支的.ci/v04253-monitor.txt。详设与前置分析已移到本总账正文，保留全部内容以控制快速索引体积。

- 构建完成：源码提交 `6524f3e60b4d42a013cb8d17ced04923b1d0debc`（之前的运行因后续修正推送被工作流正常取消，最终只认本提交），[Actions 36690963830](https://github.com/catkiss62/ai-companion-build/actions/runs/36690963830) success；131项完整源码门、原生生命周期/导入烟测、Kotlin、Flutter analyze、完整Flutter tests（含新8个行为用例）、arm64 Release APK资源/签名核验全部通过，失败报告 skipped。main 未合并。
- 未发布 Draft `399848801`：[+297 测试 APK 下载页](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cc829aca051c852f5c40)，target=`6524f3e`；APK asset `600471102`，文件 `AI-Companion-v0.42.53-297-Room-Freeze-Game-Session-APK.apk`，726453574字节，SHA-256 `f20a04df72d434aa9890bf7ec549a529dcb467f4213de2ec0edea63648968a84`；Artifact `11086582753`。Release digest与成功CI monitor一致；签名证书 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48` 与现有测试版本一致，保留现有数据覆盖安装。draft=true，未正式发布。
- TRUE DEVICE PENDING：①进入房间后无气焰条/变身判断，普通聊天气焰不被房间轮次推进；设置/短暂后台返回不变形，真正退出再入捕获最新形态，手动/三语语音音调保持快照；Stop、重生、继续剧情和保留截断回复正常。②普通满值仍可等待，累计玩闹/强烈害羞判定更合理与否需实际上下文观测，未宣称新的Jev概率或准确率。③独立情绪动画/语音开关生效，新回复单次播放，历史/返回不重播，Live2D原有效果和背景/恢复正常。④Desire选择持续游玩后进度加快，同时其他主动聊天可发生；用户聊天先行，暂停不计时，夜间/疲劳/防沉迷与等待人类能结束资格；鼓励不叠加并衰减。⑤记住事项保存13点用餐等小事后相关事实正确、当天例外优先且不产生催促，重启/备份恢复保留，恢复不续临时游戏资格。⑥悬浮球图案、圆形、拖动、贴边、点击、未读及展开聊天正常。


## 设计记录 · 2026-09-30 七项待讨论（DESIGNED / DISCUSSION ONLY / NOT IMPLEMENTED）

- 用户本轮仅要求完整方案，防止下次遗漏或误改，不修改产品代码、不构建APK。七项：沉浸入口继承后固定形态、普通聊天变身语义、Live2D情绪表情/语音、约半小时持续游玩欲望竞争、对话对游戏态度的有限影响、低重要度的稳定事实记住事项、圆形悬浮球改用用户图案。
- 沉浸最新决定覆盖上一分析方向：移除房间里的气焰条和用户/助手气焰/变身判断，进入时只捕获当前状态并在该次房间使用期间固定；定点审计提示、TTS音调、重新生成、继续剧情、Stop、全局状态写入、UI刷新和共用Jev问题边界。不得删除普通聊天共用机制，离开不将房间快照写回全局。
- 方案1／沉浸快照：同次房间使用固定入口形态，取消页面全局形态轮询、气焰条与弹额头/安抚/锁定入口、用户及助手气焰分类、突破判断和PlayfulFormStore推进。提示词、立绘及TTS使用同一个房间快照；继续剧情、重新生成、保留截断回复、三语/手动回放都不得重新读全局形态来改变本次房间。普通聊天气焰/锁定/衰减与NSFW模式/事件/工具判断保持；共享Jev合批仅去掉房间不再需要的气焰问题，不能删除整个分类调用。离开不反写全局，真正退出后再次进入重新取快照；进入更多/设置或短暂切后台返回视为同次使用。原有沉浸阻止主动聊天/游戏分享的边界不变。
- 方案2／普通变身：保持100资格、首次到100不立刻判、近似平局等待、0才退出和手动锁定。给现有突破判断添加已满值及最近几轮双方玩闹/害羞的累积状态，将要求鲜明全新转折改为允许累积逗弄、使坏或特别害羞形成自然临界点；普通亲昵仍可等待。先不降低全局0.10概率差、不增加每轮DeepSeek。仅做语义与状态的小范围调整，不能自动宣称新概率/准确率；测试包含普通亲昵、持续挑逗、突然害羞、重复普通活动等对照。
- 方案3／Live2D情绪：当前CaicaiLive2DStage已接情绪接口，CaicaiChatMotion也有Jev计划；EmotionSoundService已有独立短音效通道，默认音量0.15。静态ChatPortraitStage自带情绪图案，Live2D路径未有相应独立图层；上一窗口声称落实的独立特效/70%没有当前远端提交证据。后续保留模型五官情绪及动作，补接已有情绪图案覆盖层，并核对同一回复情绪驱动脸部、图案、短音效；复用现有音效及音量开关，保留用户设置。按真实回复ID至多播放一次，历史重绘不重播，Stop/切页面停止；聊天情绪保持，手动4.5秒预览不改。此项针对普通聊天Live2D，沉浸Live2D不扩大改造。
- 方案4／持续游玩竞争：当前play_game及resume_game来自好奇/沉思、真实游戏念头、投入动量、心境、疲劳与饱和度；并非已有获选后约半小时连续投入的新候选。新增持续游玩候选与单步游玩在同一欲望竞争内互斥/合并，避免同一游戏占多个席位。获选后只记一次自主行为竞争结果，以现有唯一Cedar执行器继续真实工具动作，最多约30分钟有效投入；每一步不重新抢普通主动行为名额，也不强制每3次动作退出。保留较轻的单步游玩；长期会话不能无限续时或占满主动分享。期间用户聊天先处理、工具执行串行、疲劳/睡眠/Stop/官网限制/游戏终局/等待人类可提前暂停或结束；跨夜结束旧投入段，重新进入竞争，不把休息时间计为已游玩。后台分享仍入念头，事件有价值才参与原有发送竞争，不固定每步汇报。不动Jev游戏入口门槛，不增加普通闲聊DeepSeek规划。此为新方案，当前源码未实现。
- 方案5／对话游戏倾向：现有游戏投入算法主要从真实Outcome和心境取值，未查到针对“有空自主体验”的有时效授权偏好。拟在现有对话内部判断/合批中提取鼓励、暂缓/停止及目标游戏，仅对游戏候选加有限偏置，不改永久欲望，不自动执行模糊许可。建议上限+0.10，约3小时减半、12小时归零；同主题连续肯定只刷新时效、不叠加，否定撤销。明确当下游戏指令仍走原按需Agent入口；夜间/疲劳/用户忙碌/官网限制不因偏置绕过。诊断记录来源类别、衰减后值和实际候选分数，不公开原对话。
- 方案6／记住事项（可选小范围）：建议设置一个小型可编辑的明确用户事实栏，独立于重要度和主动挂念；手工添加/编辑/删除为首版可靠入口，明确“记住”可复用现有内部记忆更新，不从沉浸角色扮演或单日临时表达自动固化日常规律。保留适用范围、来源、更新时间、当日例外与后续明确修正；在普通回复/主动消息相关事实使用时稳定取用，明确事实优先于时间常识及冲突旧推断。此栏不加愿望/欲望分、不增加提醒、不反复主动提及。复用现有持久存储和备份边界，实施须覆盖备份恢复/更新删除；不整套重构记忆库、不设为下一APK的必需阻塞项。用户实际作息属于私密信息，此总账仅记方案不记录具体值。
- 方案7／圆形悬浮球图案：已查看用户原图。当前OverlayBubbleService.createBubble用TextView显示单字；拟改为圆形裁切的本地图像，保持原球尺寸、点击/拖动/贴边/展开、未读角标、权限和触摸命中；原图不AI重画、不拉伸，居中等比例显示，在圆形容器裁切外缘。仅替换球面内容，不修改桌宠与悬浮聊天正文，图像只按创建/资源变化解码，不每帧处理。当前仅查看附件，未将素材上传公开仓或创建图标资源。
- 实施与验证顺序建议：先保存当前成功基线；普通/沉浸状态与情绪/图标为第一组，游戏会话与对话倾向为第二组，记住事项为独立可选小组；可以内部拆提交，完成既定批次后统一构建。关键验收是沉浸不更新全局且提示/画面/语音形态一致、普通变身和Stop无回归；游戏30分钟/跨夜/中断不重复授权及不消耗逐步主动聊天名额；低重要度事实正确采用/当日例外/更新删除/备份；悬浮球点击拖动与角标不回归。源码核对不是实现/CI/真机证明；本次仅总账方案更新。

## 接班分析记录 · 2026-09-30 双形态判定、沉浸继承与连续游玩（ANALYZED / DISCUSSION ONLY / NO PRODUCT CHANGE）

- 因上一窗口界面持续显示正在处理，用户要求接续分析。仅读取当前顶部、开发分支最近5次提交、最新Actions摘要、上一窗口直接相关最近几轮及定点源码/最新诊断。基线 `0.42.52+296`，分支 `agent/v04252-caicai-surface-background`，接班HEAD `aeb7e49`；最新构建 `36657791150` success，不据此扩大真机验收。
- 最新明确设计：气焰100仍保持正常形态可以合理；双形态用于被逗、使坏或特别害羞时“绷不住”，并非要求频繁切换。需对照实际对话、Jev原概率和本地采用值判断是否过严，列最后几轮概率与差值指标名称，讨论仅调阈值能否优化。沉浸房间Live2D不改；双形态/气焰继承与半小时连续游玩亦先分析讨论。未获此次产品逻辑修改/新APK指令。
- 最新证据为 `AI_Companion_Backup_2026-09-30T04-47-24.aibackup` 与同刻普通诊断；仅私下读取所需轮次，不将有界原始对话、API配置或存档上传公开仓库。
- 已完成语义与数值对照：最新五轮气焰90→87→92→100→100→100，正常形态且未锁定；首次达到100那轮不判，随后两轮均实际请求 `playful_breakthrough`。末第二轮变身/等待=0.24/0.76、confidence=0.52、前两项差=0.52；最后一轮0.42/0.58、confidence=0.15、差=0.16，均 `used`、`close=false`、最终wait，无本地改判。互动判断最后一轮mutual=0.58，已接受为互相挑逗；自身活动strong，说明气焰入口与变身判断是两道不同语义判定。历史一个正常活动样本虽变身0.51/等待0.49、confidence0.03，但本地归wait；不能把每次中性规则都当成错误拦截。
- 指标澄清：Jev返回名为 `confidence`，依据概率分布集中程度，不能当作正确率或变身概率；官方定义 https://docs.typesafe.ai/confidence 。本地实际门槛是前两项概率差<=0.10，源码未设低confidence强制回退。最后两轮即使只降低0.10仍是wait，不能用此调整解决。五类互动中light/mutual接近时归ordinary也会压低已有双方玩闹的加分；最后一轮的实际语义已经符合逗弄，是否达到“绷不住”仍有主观空间，结论是偏严格的候选，不声称该轮必须变身。
- 待讨论小改方向（NOT IMPLEMENTED）：保留100资格、首达100至少留一轮、最高项/近似平局策略；把已满值及最近双方玩闹/害羞的累积状态提供给现有判断，说明连续升级也可构成情绪临界点，不强求鲜明全新转折。普通亲昵/闲聊仍可wait。先用普通亲昵与真实升级对照样本评估，再决定是否单独调整变身门槛；不全局降低Jev互动/Cedar门槛，不增加每轮DeepSeek规划。本轮仅查源码和存档，未发起付费模型重放，不声称新方案有验证结果。
- 沉浸继承事实：当前控制器的发送/重生成已经调用同一个 `PlayfulFormStore`、用户与助手轮判断及 `PlayfulBreakthroughJudge`；房间提示继承同一形态，页面读取同一状态并显示气焰条、形态立绘及锁定/互动。并非尚未接入，后续是共用规则微调与真机一致性验证；沉浸房间Live2D保持用户要求不改，未宣称全路径真机通过。
- 连续游玩事实：+274已修复检查点先推迟时钟而漏进续玩竞争的历史路线；当前仍在3次状态变化或25分钟开局经过时间设置检查点，再交普通欲望竞争。最新白房间先因night_sleep暂停；playScore≈0.806高于restScore≈0.637仍受夜间条件拦截，随后duration_limit检查点时仅1次状态变化。源码使用now-startedAt，会计入跨夜暂停，不能把这一样本称为有效游玩了25分钟。续玩竞争已实现，约30分钟持续投入尚未由此样本证明；有效游玩计时、休息后新段落及分段再竞争可列待讨论方案，仍不绕过官网防沉迷、不保证每次满30分钟。
- 远端与旧窗口边界：当前+296远端的情绪音效默认仍为0.15；检索到上一窗口声称已落实Live2D独立情绪特效与70%音量，但未在当前远端确认相应提交。若继续该项应先恢复旧窗口未推送差异或重新明确实现范围，不能把聊天声称等同于远端已实现。此次只更新本总账，不覆盖产品源码、不生成APK。后续入口为本节待讨论方向及+296顶部真机清单。



## 正式记录（无容量上限）

## 4. +228 已完成、只等待真机验收

- Agent 循环重大回归已收口：前台首次成功 mutation 后结束本轮，后台每 cadence 仅一次规划/一次真实推进；普通聊天不再被活跃游戏自动注入整套工具。DeepSeek usage/cache 已按 lane 记录，诊断查看 `modelUsage.byLane`。
- `CedarExecutableCall`、唯一房间 `rooms → full state → replan`、陈旧 session 水合、终局恰好一次 handoff、`recent_game_episode` 有界短期桥接已实现；不新增吞掉 preference/shared_experience 的顶层 game memory kind。
- 单人游戏进入疲劳/昼夜 Gate 与可衰减饱和仲裁；实时共玩承诺不参与竞争。没有伪造各游戏固定概率或硬每日配额。
- 自主网页能力注册、完整来源证据束、普通“看看”误路由、Stop 贯穿 search/extract/压缩/appraiser、FishArchive 有界换候选、自主相册来源已修复。
- 主动联系以真实普通消息后 10 分钟滑动静默窗推迟；不消费 Thought、分享候选或频率额度，不把新话题改写成 followup。
- `screen_on / screen_off / user_present` 已切分 screen session；长熄屏前活动只能作为低置信度短时历史，不能跨会话冒充持续使用。
- “调皮”收窄到真实逗弄/故意曲解/恶作剧/小挑战；音效在第一段可见正文提交时一次触发；刷新回复恢复跟随最新并锚底。
- 用户新版“性格光谱”已作为内置 preset，SHA-256 `fcc1074203b31cdf36466b39b3b6b08b5abd7497855155c31558177242dfe0fb`，仅保守迁移仍等于旧内置 hash 的记录；规则 05 已加入“每一段动作、神态之后都需要配一段对话。”。

真机必须继续验证：一次聊天不出现多次 Cedar mutation；后台每 cadence 至多一步；真人回合仍及时回应；终局只交付一次；普通“看看氧气瓶”不联网；明确网页查询能引用实际页面证据；Stop 无需杀后台；自主网页/相册恢复；熄屏一小时后不说成连续使用；主动新话题在静默 10 分钟后仍送达；刷新锚底；音效与正文同帧。

## 5. 当前任务：v0.41.85+229 Cedar 结构化远程媒体桥

历史实现分支：`agent/v04185-cedar-media-bridge`。

### 已登记证据

- 最新旅行备份中 `cedar_toy.play` 成功，文本 Outcome 内有多个真实 HTTPS `photo_url`，但事件为 `content_kinds=[text]`、`image_data/viewer_url` 为空，最终消息没有 `assistant_mcp_image`。下矿存在同类协议能力。
- `AgentToolRunner._cedarImageAttachments` 和 `CedarToyActivityStore.recordPlay` 只消费 MCP 标准 `type=image` Base64 block；嵌在结构化结果或 JSON 文本中的明确媒体字段只被当文字。
- 这是 APK 的缺失桥接，不是 Cedar 网络失败、模型忘记发图或游戏厅活动窗识别错误。

### 本批目标

1. 只从 Cedar 成功 Outcome 的协议明确媒体字段提取 HTTPS 图片候选，支持结构化 object/list 以及文本 block 中可安全解析的 JSON；不得扫描自然语言中的任意 URL。
2. 复用现有安全公开图片下载边界：HTTPS、重定向、MIME、字节签名、大小与超时保护；每步限制数量并去重。不得为附件触发 `public_web.search`。
3. 下载一次得到的不可变字节同时用于 `MessageAttachment` 与 Cedar activity/history，避免聊天图、活动窗图和模型所见内容不一致。
4. 任一候选失败只保留真实文本/失败分类，不得声称图片已发出；取消后不得迟到写回。标准 MCP Base64 image 行为不得回归。
5. 增加固定回归：旅行 `photo_url`、下矿等价字段、嵌套 JSON、任意正文 URL 拒绝、非 HTTPS 拒绝、重复/超量、下载成功/失败、附件提交、活动记录、Stop/迟到写入。

### 保护边界

- 不改 Cedar 玩法、回合策略、概率、房间身份、revision、棋步或防沉迷；不写死真机 URL/房间/附件文件名。
- 不扩大为通用网页抓图，不改变公共联网授权判断；不把远程 URL 长期当附件，必须先固化受检字节。
- 本批不处理桌宠、TTS、表情概率、`main` 合并、正式发布或历史清理。

### 验证与完成标准

- 修改前后运行当前总账门、+228 与新增 +229 专项门、全部 validator、`git diff --check`、Flutter Analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。
- Actions 与 APK 完成后才可写 `CI PASSED / APK READY`；真机必须分别看到旅行/下矿成功附件和失败降级，才可写 `TRUE DEVICE PASSED`。

### 本地实现与验证（2026-09-19）

- 新增 `CedarOutcomeMediaBridge`：只解析成功 Outcome 的明确协议媒体字段与完整 JSON 文档；拒绝正文 URL 扫描、HTTP、重复项和超量项，最多固化 3 张远程图片、单次 Outcome 总附件最多 4 张。
- `AgentToolRunner` 在 Cedar execution fence 内完成安全下载、字节签名检查、附件固化、Stop 清理与 activity 引用写入；标准 MCP Base64 图片路径保留。单张远程图片失败只降级为真实文本 Outcome，不伪造“已发送”。
- `CedarGameEvent.imageReference` 与聊天附件共用同一个持久媒体引用；活动窗优先读取该引用，旧 `image_data` 仍兼容。
- 新增 `cedar_outcome_media_v04185_test.dart` 和 `validate_v04185_cedar_outcome_media.py`；验证清单已登记旅行、下矿、失败降级、Stop 和诊断证据。
- 本地已通过：109 项 validator manifest 检查、当前总账门、+228/+229 专项门、相关历史门、Python 语法检查、Workflow YAML 解析与 `git diff --check`。本机没有 Flutter/Dart SDK，完整 Analyze/tests/Android Release 必须由 GitHub Actions 判定；在 Actions 成功前保持 `CI PENDING`。

### Actions 与交付证据（2026-09-19）

- 首轮 Actions `35449949853` 在 Flutter analyze 发现新增测试文件末尾误留重复 `import`，构建按预期阻断；已删除该指令，并把“声明后不得再出现 import”加入 +229 专项门，没有绕过分析器。
- 修复后的 Actions `35450357850` 全绿：109 个源码门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- 构建 head `0f4ffc6c2b08a310a5f04919a045c98b2e8e63e3`；tree `9e0913202787feca13462c07fdd0941f10d0d4b9`；Artifact `10587305305`，ZIP digest `16978dba71bc9b581b47f3e2be4113762819a636015fa7a8e417eaa37c3ec024`，大小 `538,036,212` bytes。
- Draft Release `392107130`；APK asset `574973863`，大小 `544,913,702` bytes，SHA-256 `acbd5c81be69c5c27ae2822ea112fb2b0639a00636b61af7b0f642c02fbcddc6`；稳定测试签名未变。
- 当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。仍需真机分别验证旅行与下矿返回真实图片时：聊天附件出现、活动窗显示同一内容、失败只保留文本、Stop 后不迟到补图。

## 6. 后续待办与观察项

### 6.1 2026-09-20 MCP 真机结果后的前置设计记录（已由 6.2 覆盖）

> 本节保留 +230 开工前的证据与设计推导；其中 `PENDING IMPLEMENTATION / PENDING INTEGRATION` 是当时状态，当前事实以 6.2 的已实现、Actions 与真机回填为准，不得再从本节重复开工。

- **MCP 当前结论**：用户已真机确认双弈五子棋完整打通，正常自然语言也能让 Agent 查看/调用 MCP；可把 MCP 主链视为基本完善。该结论证明双弈共玩与 Agent 执行链，不自动替代旅行/下矿远程图片桥的专项验收。
- **游戏兴趣轨迹冻结**：不增加每游戏固定概率、复杂好感/受挫轨迹或新的顶层“贪玩” Drive。模型可依据实时目录、指南、局面、结果和 Cedar Thought 自然形成临时偏向；花园与猫咪等内容较少的游戏可自然失去吸引力，但不伪造持久偏好。
- **游戏重新竞争方案已接受（DESIGNED / PENDING IMPLEMENTATION）**：单人游戏保留短活动惯性；每累计 3 次真正改变远端状态的成功 Outcome，或活动持续 25 分钟（先到者为准），到达一次 episode checkpoint。checkpoint 后把同一局作为可恢复的 `resume_game` 候选，重新与公开网页发现/分享、普通主动联系、休息和沉默走既有 Desire/Thought 仲裁；其他行为胜出时只暂停、不丢远端存档。实时共玩在合法轮到 companion 时继续履行回合承诺，但服务端防沉迷仍是权威硬边界。不得每一步随机换游戏，也不得把“近似并列采样”扩大成纯随机竞争。
- **相册边界**：相册候选处理当前在 Cedar 推进前运行，并非直接被游戏关闭；但游戏每轮成功后会跳过普通主动联网/聊天，可能让网页图片来源枯竭。恢复统一竞争后先观察来源是否恢复，不单独提高相册保存概率。
- **Cedar 防沉迷一手证据（OFFICIAL UI / PENDING INTEGRATION）**：官网设置实际按“连续游玩轮数”计数，不是按连续分钟计数；页面默认 30 轮提醒、50 轮锁定、锁定 30 分钟后自动重置，也允许网页手动重置，存档不受影响。账号开关 `allow_self_reset` 只代表允许小机自行重置，不代表 APK 应自动重置。
- **现有实现与缺口**：休闲模式本地步进间隔为 2 分钟，快速/观战为 5/10 秒；它与服务端轮数/锁定计数是两层机制，本身不冲突。项目已把平台 `rest / announcements / vote` 交给 Cedar 服务端最终授权，并明确 `rest` 只能用于真实防沉迷提醒/锁定；但尚未把提醒、锁定、剩余时间或重置结果解析成持久状态。现有 `recordPlatformAction` 在 session 仍可继续时会于成功 `rest` 后约 1 秒再次推进，不能直接作为最终防沉迷闭环。
- **防沉迷建议（DESIGNED / 等用户最终选择）**：服务端提醒应强制形成 episode checkpoint；服务端锁定时移除普通 `resume_game` 并把游戏 defer 到权威恢复时间。若网站真实返回 `allow_self_reset=true`，可额外生成带明显继续成本的 `self_reset_and_resume` 候选，与联网、主动联系和休息同场竞争；只有它真实胜出才调用一次 `rest`，随后开启新 episode 并恢复正常 2 分钟休闲节奏，禁止 1 秒续跑。没有真实提醒/锁定证据时不得主动猜测或调用 `rest`。
- **最新同刻备份/诊断证据**：`2026-09-20 00:43` 备份和诊断中没有任何 Cedar `rest` 防沉迷动作或自主重置事件；出现的钓鱼“重开新局”属于游戏存档重开，不能当作防沉迷重置。诊断仍显示曾有 `recentActionCount=24 / saturationPenalty=0.28 / playScore=0.8613 / restScore=0` 的继续游玩判定，支持“活动后只和休息竞争”的结构性根因。
- **TTS 音色小改（DECIDED / PENDING IMPLEMENTATION）**：只把“高兴”从“活泼”改为“可爱”；其余情绪映射不动。
- **TTS 参考语音问题（DIAGNOSTIC FIRST）**：用户已确认现象更像播放/复现 `jiuhu_bento_tools.wav`，不是模型随机串入日语。当前生产调用链没有 `playReferenceAsset` 调用者，临时输出也使用 UUID，不先猜测根修。下一批先扩展脱敏诊断：记录语言、voice key、reference case id、清理前后字符类别计数、有效音素数、首轮立即停止、语义 token 数/哈希、输出 PCM 时长/哈希及 `reference_echo_suspected`；不记录正文。四套参考语音 `jiuhu_bento_tools / jiuhu_dream_days / jiuhu_idle50 / jiuhu_devotion` 统一覆盖。拿到同一时刻诊断后再决定是否修复标点/空音素、立即停止强塞 token 0 或输出回声拦截。

### 6.2 v0.41.86+230 实施登记（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04186-autonomy-tts-diagnostics`。

本批只实施用户已经确认的三组变更：

1. TTS 自动音色只把 `happy / 高兴` 从 `lively / 活泼` 改为 `cute / 可爱`；其他情绪、固定音色、情绪音效和声学模型不动。
2. TTS 只增强脱敏诊断，不在本批猜测根修或阻断输出：覆盖四套 reference case，记录 voice/reference id、输入与前端规范化后的字符类别计数、有效音素、Decoder 首轮停止、语义 token、输出 PCM 时长/哈希及基于退化推理证据的 `reference_echo_suspected`；仍不得写入正文或参考音频路径。
3. 单人 Cedar 活动增加持久 episode checkpoint：每 3 个成功且真正改变远端状态的 Outcome，或 25 分钟先到者触发。checkpoint 只暂停本地续步，不结束、不换局、不损坏远端存档；`resume_game` 回到现有 Desire/Thought 统一选择，与网页发现/分享、主动联系、休息和沉默竞争。实时共玩承诺保持原优先级。

防沉迷实现边界：只解析服务端明确的结构化提醒/锁定/恢复时间/`allow_self_reset`，以及明确包含“防沉迷”的文本提示；普通游戏冷却或失败不得误判。提醒强制 checkpoint；锁定期间移除普通恢复候选。仅当真实证据同时表明提醒或锁定且 `allow_self_reset=true` 时，才提供带明显分数成本的 `self_reset_and_resume`；胜出后只调用一次平台 `rest`，成功后开启新 episode，并按当前休闲/观看节奏继续，禁止旧有成功后 1 秒续跑。没有证据不得调用 `rest`。

明确冻结：不增加“贪玩” Drive、不建立复杂游戏兴趣/受挫轨迹、不修改每游戏概率、不扩大 Agent 确认弹窗、不处理 TTS 声学根因、桌宠、`main` 合并或正式 Release。

完成门：新增纯策略回归与运行链回归；更新当前总账门、版本与测试清单；运行全部 validator、`git diff --check`、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查。只有 Actions 全绿后才写 `CI PASSED / APK READY`；TTS 参考音频和单人 episode 仍需真机报告后才能升级为 `TRUE DEVICE PASSED`。

本地实现与验证：

- `happy` 已单独迁到 `cute`；`excited/surprised` 保持 `lively`。四 reference case 的脱敏 checkpoint/运行诊断已加入原始/规范化字符类别、有效音素、Decoder 次数/首轮停止、语义序列、PCM 时长/哈希和回声怀疑标记；没有增加输出拦截或声学猜修。
- 新增 `CedarSoloEpisodePolicy` 与 `CedarAntiAddictionParser`。episode 状态保存在 settings，不改 schema；只计成功的非只读、非平台、非退出远端动作。第三步或 25 分钟触发 checkpoint，`resume_game / self_reset_and_resume` 进入既有 selector；后者必须同时满足真实防沉迷信号与 `allow_self_reset=true`。普通游戏锁定文本有负例保护。
- `rest` 的后台执行增加本地证据门；成功后由原 1 秒改为当前 viewing pace（休闲默认 2 分钟）。恢复同局若本次真实推进失败，会恢复 checkpoint 并延后 8 分钟，不把失败当成已开启新 episode。实时共玩判定和回合优先级未改。
- 新增 Flutter 纯策略测试、Kotlin TTS 证据测试、+230 跨模块源码门，并更新 110 项 validation manifest、工作流、版本和真机清单。本地逐项运行 110 个源码门：107 个通过；另外 2 个只因仓库按治理规则未携带 CI 才恢复的桌宠/LingChat 私有资源包，1 个只因本机无 `kotlinc` 未运行。`git diff --check`、Python 编译、Workflow YAML 与 +230/+229/+228/总账专项门通过。本机无 Flutter/Dart/Gradle 分发，完整编译测试仍由 Actions 判定。

Actions 与交付证据：

- 构建 head `6c53a40b5d7413942c12ca84001bb66205c160d1`；tree `9c3674e87f37798964e293b1ffdeaedf4e582c74`。首轮 Actions 仅在恢复 LingChat 私有视觉资源时遇到远端 `curl (35) Connection reset by peer`，尚未进入编译；不改业务代码，按同一 run 重跑失败任务。
- Actions `35458277355` attempt 2 全绿：110 个源码门、Kotlin 桌宠/悬浮层与新增 TTS 证据测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10589621373`，名称 `AI-Companion-v0.41.86-230-Autonomy-TTS-Diagnostics-APK`，大小 `538,050,951` bytes，ZIP digest `899a04d4819a6751c41b60a3ada9e62607bb2b7f30dc4969ec874adfac0ce25e`；APK SHA-256 `de27ec0c0146ef3a879f0bb9d8ae2c06dbfdc3225d8f6694fe8e01c7c5ab8d4a`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4c16dc23432898cc5020`；本批未合并 `main`、未发布正式 Release。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机回填与非阻塞观察（2026-09-20）：

- 用户已确认“高兴”实际使用“可爱”音色，TTS 自动音色映射这一子项升级为 `TRUE DEVICE PASSED`；不代表参考音频疑似复现问题已经根修。
- 单人 episode checkpoint、游戏与联网/主动聊天/休息/沉默重新竞争，以及 Cedar 防沉迷提醒、锁定和自主重置，均转为低优先级“保留等待测试”。夜间不专门诱发游戏；以后上传自然使用形成的存档和同一时刻诊断时顺带核对，不阻塞下一开发任务。
- 旧总账的 Phase 3 状态保持原判：3A 已 `TRUE DEVICE PASSED`，3B 核心链已 `TRUE DEVICE PASSED / OBSERVING`；3C 的消费注入后来已撤出当前运行能力并暂停待重审，因此不把“Phase 3 重要链已通过”误写成“Phase 3 全部能力仍启用且全部通过”。

### 6.3 旧总账去重后的唯一后续任务清单（2026-09-20）

本节已对照当前源码、`DOCUMENTATION_MAP.md`、截至 +218 与 +228 两份冻结总账去重。旧章节中的“下一步 / PLANNED / PENDING”若已被后版完成、撤回或替代，不再自动复活；以后排期只从本节取。

#### A. 可直接进入开发的任务

| 优先级 | 任务 | 当前准确范围 |
|---|---|---|
| P1 | 设置“帮助”与真实能力清单 | `v0.41.87+231 TRUE DEVICE PASSED`：页面直接消费当前 `AgentToolRegistry`，并整理 `【检查系统】`、联网/网页阅读/图片、查手机、Cedar、Stop、备份恢复、TTS、权限隐私、故障排查与明确限制。用户确认入口与内容正常，且 UI 干净美观；其分节层级、图标、留白、克制的卡片色和可折叠说明作为未来全局 UI 美化的参考方向。 |
| P1 | 本地 Genie TTS 推理速度实验 | 当前生产基线是 CPU 8 线程，旧真机已证明 XNNPACK 会出现异常短音频、NNAPI 无收益。先在独立 `Genie-TTS-Android` 测试工程用同设备/同模型拆出前端、语义 Decoder、声码器、WAV 与冷/热启动瓶颈，并比较 4/6/8 线程、`PerformanceHintManager`/线程优先级、大核调度提示、session/张量缓存和分段预生成；只有证据稳定的引擎级方案再移植到伴侣项目做一次集成 A/B。最终必须是默认关闭的“快速推理”开关，关闭即回到当前路径，并具备温度、功耗、峰值内存、音频完整性、音质与自动回退门。普通 App 不承诺 root 级硬件超频，也不直接恢复已否证的 XNNPACK/NNAPI。 |
| P1 | 全工具调用动作展示 | `+248 IMPLEMENTED / CI PASSED`：工具活动生成中展开，终态按真实 Outcome 绑定并回看；`+257` 补齐可读实文的有界持久化与悬浮窗回看。实现已完成，不再列为开发待办；失败、Stop 与重启后展示仍待逐项真机验收。 |
| P1 | 联网资料原文传递（待完成） | +309仅修明确搜索入口和上下文query；用户要求的取消Agnes压缩尚未实现。后续调整网页可读性筛选、证据预算与原文传递，不能简单关整理后把资料全部过滤。 |
| P2 | 深度思考模式（+309延期） | 用户允许自行判断实施；本轮延期。复用现有Agent循环扩展查证，普通聊天不每轮规划；搜索资料不当作亲历记忆。聊天+菜单替换世界书按钮，灯泡关灰/开紫，开启时+号也紫。 |
| P2 | 通用 MCP Registry 与未来工作区 | Cedar 专用 MCP 已完成，但通用 `mcp.invoke` 仍为不可执行占位。未来按只读优先分批实现 Server 注册、能力目录、权限、审计、超时、取消、凭据隔离和可卸载；2026-10-03用户更倾向深度回答，独立工作区暂不优先。OAuth、社区工具与 stdio/Harness 不与陪伴数据库直接混用。 |
| P2 | 日历式提醒（DESIGN DISCUSSION） | 用户 2026-09-26 明确撤回相对时间语句自动判断方案，改为手写日历条目：只有日期的纪念日可在当天自然提起；日期+具体时间要有明显的到点强提醒，电话/闹钟式效果及其替代方案待讨论。`reminder.schedule` 继续不可执行，不以聊天约定冒充系统提醒；此前 +265 实验代码已撤回，无交付 APK。 |
| P2 | 记忆/人设/规则修改提案 | `memory.propose_change / personality.propose_change / rules.propose_change` 当前均不可执行。以后只先做可审查 diff 提案；写入、删除或其他可破坏操作必须增加确认、版本与回滚，当前只读 Agent 不增加多余确认。 |
| P3 | 视频理解 | 2026-10-03用户暂停连续陪看，参考项目见ScreenMate总账，不自动重启。`video_understanding.inspect`仍为占位。以后独立评估短片抽帧、预算、临时文件隐私、取消和结果持久化；不冒充当前已能看视频。 |
| P3 | Live2D 反应接入 | 模型、动作和素材已在独立 Live2D 仓库完成；伴侣侧以后专门设计“LLM 语义反应 + 本地低延迟关键词/事件反射 + 动作仲裁/冷却/打断”，避免只等完整 LLM 回复才动，也不得让关键词层直接改写人格或对话。完成基础 P1 后再立专项版本。 |
| P3 | DeepSeek 缓存命中优化 | `v0.41.89+233 CI PASSED / APK READY / TRUE DEVICE PENDING`：已补齐细分 `usage_lane`、body-free 段落顺序/长度/哈希观测，并对工具 schema 做语义等价的确定性 key 排序；没有重排提示词、删记忆或冻结实时状态。后续只在真机积累足够样本后按 lane 对比 `recentPromptShapes` 与 hit/miss，再决定是否存在可证明、低风险的第二步 A/B；Gemini `final_reply` 仍不纳入。 |
| P3 | 疲劳与心境的小幅耦合 | 保留昼夜节律主基线，单独评估负面心情导致难入睡、兴奋/聊天愉快/玩嗨短时压住疲劳的有限偏移；必须有幅度上限、短时衰减、睡眠债回补和防止夜间无限续航。排在 +232 真机包之后，优先在北京时间 2026-09-21 下午至晚上、或后续相同自然时段开专项，便于观察从白天到夜间的真实曲线；不在 +232 顺手改公式。 |

#### B. Phase 3C 与 Phase 4 的准确含义和评估门

- **Phase 3C** 已由用户确认属于持续优化方向中的旧阶段编号，关闭独立待办。3A/3B、Thought、Share Seed、统一自主竞争及后续兴趣/分享调整已经承接它真正关心的“长期偏向会影响自主选择”；+210 的具体消费注入又已在 +211 撤回。因此以后不再以“重做 Phase 3C”排期，只在出现新的、可复现的兴趣连续性问题时按当前架构处理。
- **Phase 4** 是人格成长路线的可选末段，不是基础能力缺口：只在高影响歧义、连续反证或用户主动谈及时低频澄清一次；MBTI、契合度、AI 自拟小测试等只作为娱乐与低权重 `test_result / self_report / inference`，不得一次测试直接改写人格事实。开工前要先判断 Cedar 游戏、普通主动聊天和现有学习证据是否已经覆盖娱乐互动需求，以及澄清是否会让她变成问卷机器人。Phase 3C 没有必要恢复时，Phase 4 也可以作为独立可选功能评估，不再机械等待旧阶段编号。
- **情绪引擎扩建**不再是基础待办：最小 `Appraisal → Emotion Episode` 已在 v0.37.5 实现。只有自然证据持续证明缺少混合情绪、恢复轨迹或多事件调度，并且固定回放有量化收益时，才按 `EMOTION_ENGINE_EXPANSION_EVAL_v1.md` 增加一个模块；否则保持现状。

#### C. 保留等待测试（不阻塞开发）

| 项目 | 以后如何顺带确认 |
|---|---|
| +229 Cedar 远程图片桥 | 旅行/下矿自然返回图片时，核对聊天附件与活动窗是同一内容；失败只保留文本，Stop 后不迟到补图。 |
| +230 TTS 参考音频 | “高兴→可爱”已真机通过；仅当参考音频疑似复现时立即导出同一时刻诊断，用四 reference case 的新证据定位，不猜修。 |
| +230 游戏竞争与防沉迷 | 随以后存档/诊断核对 episode checkpoint、统一竞争、同局恢复、提醒/锁定、`allow_self_reset` 和自主重置；夜间不专门诱发。 |
| +228 自主性与屏幕时间线 | 继续自然观察 Token 账单、主动联网/相册、10 分钟静默窗、长熄屏、刷新锚底、表情/音效时序；出现异常才提交同刻证据。 |
| Phase 3A/3B 长尾 | 跨日期兴趣成熟/撤销/新鲜度，以及额度耗尽或能力关闭时的 capability defer 随自然数据观察；核心真机状态不倒退。 |
| Memory 2D 与 D6 媒体备份长尾 | 精确取消/自然主动回忆/工作话题占比，以及删除媒体后的备份、重复迁移、相册引用保护、缓存删除和跨机恢复，有自然样本再回填。 |
| 低概率显示/状态问题 | 表情发送占比、duel“轮到你”、偶发多余 `「`、TTS/桌宠异常均只在明确复现后窄修，不靠概率猜测。 |

#### D. 冻结、可选或需用户重新排期

| 状态 | 项目 | 决定 |
|---|---|---|
| `REMOVED FROM BACKLOG` | MiniMax 在线语音 | 用户确认当前本地小酒狐 Genie TTS 效果更好，MiniMax API、在线/本地双引擎选择、在线音色筛选与 emotion 映射全部从后续任务删除。冻结归档中的 MiniMax 只保留历史证据，不得再次自动排期。 |
| `FROZEN` | 当前屏幕像素观察与自主截图 | 现有 `screen_observation.inspect` 曾在视觉 Provider 前失败；先补系统截图 capability/阶段诊断才可重开。自主截图仍未实现，不因知道 App 名称而声称看见屏幕。 |
| `FROZEN` | HyperOS 文件选择器/系统导航键/悬浮间歇卡死 | 指三类旧真机原生问题：系统文件选择器偶发输入/返回挑战、系统导航键后悬浮层恢复异常、部分 App 切换时桌宠/悬浮层间歇消失或卡死。当前没有持续复现，项目末尾如重开，先取得输入挑战、动画心跳、window generation 与 enter/exit 时间线，不再叠加 retry/delay。 |
| `OPTIONAL` | 主动消息直接带表情、GitHub 灵感库、X/Telegram Provider | 都是新增能力，不是当前概率回归。只有用户再次选择才设计；普通回复表情、通用公开网页和现有媒体链继续保持。 |
| `OPTIONAL` | 手机主存储/平板伴随端、完整换肤、产品化发布 | 独立大型路线，不进入当前陪伴核心维护。平板伴随端先依赖未来视频理解/“陪玩或陪看”能力的正式定义，当前不预判具体方案；`main` 里程碑晋升与正式 Release 仍需用户明确授权。 |
| `MAINTENANCE` | 当前契约文档合并 | 可逐步把人格、Somatic、Inner Drive 重叠文档合并为当前契约；不改变 App、不阻塞功能开发。 |

#### E. 已完成、不得从旧总账重复开工

- Phase 0+1 审查、Phase 2A/2B、Phase 3A、Phase 3B 核心链；Memory 2D 主链、Dynamic Moe D2/D3、最小 Emotion Episode、查手机七日心情/购物车/侧栏、公开网页完整阅读与分享、Agent 自身系统读取、Agent v2、表情和双向图片、Cedar MCP/双弈/终局/连续循环、+228 Agent 循环与自主性收口、+229 远程媒体桥、+230 episode/防沉迷和 TTS 诊断均已有实现或明确状态。
- 角色扮演持续性由用户确认已解决：根因是旧输出模型理解能力与文本表现，切换 Gemini 为文本输出口后不再复现；从冻结任务删除，除非出现新的可复现证据不得重开。
- `PENDING / PLANNED` 只出现在冻结归档的历史段落时，不足以证明今天仍是任务；必须先与本节和当前源码核对。

### 6.4 v0.41.87+231 帮助页与游戏厅活动窗（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

历史实现分支：`agent/v04187-help-cedar-activity-ui`。

本批范围：

1. “全部设置”新增“帮助与真实能力”。普通聊天与自主工具清单直接读取运行时 `AgentToolRegistry` 的 `executable/userTurnAvailable/autonomousAvailable`，避免静态帮助把占位能力写成已可用；同时说明 `【检查系统】`、Stop/刷新、网页/图片/查手机、Cedar、本地 TTS、备份、权限隐私、故障取证和当前明确限制。
2. Cedar 活动窗“最近进展”改为居中 84% 宽度的窄卡片，左右保留外层滚动命中空间；文本仍可选择，最多 12 行的现有边界保持。
3. 活动记录继续显示三行摘要，但增加点击详情；详情可滚动查看完整 summary、动作、时间、图片和该事件 viewer URL，不执行游戏动作、不修改 session。
4. 不改变 Agent 权限/自然语言路由、Cedar 指南/循环/防沉迷/概率、数据库 schema、TTS 运行时、世界书、人格或 `main`。

本轮追加设计记录：Phase 4 继续作为可选人格澄清/娱乐测试，不因 AI 偶尔自然提问而强制开工；需要另查自然问题的用户资料写入证据链。TTS 快速模式先在独立 TTS 工程做引擎基准，再将证实有效的方案以默认关闭开关移植；Live2D 反应接入与疲劳—心境小幅耦合均登记为独立后续任务，不与 +231 混改。

Actions 与交付证据：

- 远端功能提交 `75d9e0a311d5b322f53a742b9016aac16d44c9d9`，tree `2b337e3b4d23a1c4bdc097ee999fc569ddafb7fe`；`main` 未修改。
- Actions `35464168272` 全绿：111 个源码/历史回归门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10591085711`，名称 `AI-Companion-v0.41.87-231-Help-Cedar-Activity-UI-APK`，大小 `538,056,010` bytes，ZIP digest `f64bbe778527f0a6ca3851394f6e398b2322f1cdba53af56d7ffc1050a3e012b`；APK `544,935,646` bytes，SHA-256 `1b10c1f49f0d192913c2f15e9f46345160cc2c0ee22acf751eb6755a70a3e565`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-83ba209cc91853c32913`；仍是测试 APK，不是正式 Release。真机只需验收帮助页入口/内容、最近进展左右滑动命中区和活动记录详情。

真机回填：用户确认本批功能正常；帮助页入口和内容没有问题，排版被确认为干净美观。最近进展窄面板的左右拖动范围与活动记录详情均通过，唯一追加意见是窄面板颜色应与上方“游戏活动”Card 完全相同，该视觉收口进入 +232。

### 6.5 v0.41.88+232 愿望单主题身份、Cedar 同色卡片与扩展护栏（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PARTIAL`。

历史实现分支：`agent/v04188-wishlist-cedar-card-guardrails`。

本批范围与证据：

1. Cedar 活动窗保留“最近进展”居中 84% 宽度与左右外层拖动命中区，但面板从单独猜测的 `surfaceContainerHighest + border` 改为和“游戏活动”完全相同的 Material `Card`；不改文字、12 行边界、活动状态或游戏执行。
2. 愿望单固定句的根因已经定位：旧实现仅按 `drive_key` 返回一句固定正文，且活动愿望只按 `source_thought_id` 去重；同一钓鱼主题产生多个生命周期 Thought 时，会被当成多个不同愿望并重复显示“想认真找点没见过的新鲜东西看看”。
3. +232 以 `drive + canonical safe topic` 作为活动愿望身份，统一 `cedar_game:fishing` 与 `shared.activity.fishing` 等明确同主题别名；同主题的新 Thought 会接续并重绑定原愿望，不增加第二条。正文只从 drive、topic key 与 provenance 分类生成，明确禁止读取或呈现 Thought 私密正文。已完成历史只迁移展示版本，不伪造完成、不强制增加愿望数量；原有 6 小时新增冷却、每日预算、强度/复现/基线与满足条件保持。
4. 将 Cortico 参考地址与“观察事实/执行工具隔离、按功能选择投递语义”写入永久边界；同时将 Cedar 多循环事故提炼为“唯一循环所有权”和首版诊断要求。只增文档护栏，不引入中央 Event Bus、World 容器、完整队列/状态机，也不修改现有 Agent/Cedar 循环。
5. 明确不改：数据库 schema、世界书/用户已修改的性格光谱、人格、Desire/Thought 生成与满足逻辑、Agent 权限/自然语言路由、Cedar 玩法/防沉迷/竞争、TTS、疲劳公式、DeepSeek 缓存实现、`main` 或正式 Release。

真机验收只看三点：进展窄卡颜色是否与“游戏活动”一致；旧固定愿望在一次正常“查手机”刷新后是否迁移；同一钓鱼/旅行主题反复形成 Thought 时活动愿望是否只保留一条且正文能说明主题。不得为了造样本修改真实欲望或游戏偏好。

本地验证：+232 专项门、Workflow YAML、Python 编译与 `git diff --check` 通过；逐项运行 112 个源码/历史门，109 个通过。其余 3 个与本批代码无关：仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，本机也没有 `kotlinc`；Actions 会在恢复资源和安装工具后执行完整 Flutter analyze、Flutter tests、Kotlin 测试与 arm64 Release 构建。

Actions 与交付证据：

- 远端构建 head `3783aa7ccae0d547d4a0a1c18d4f388c398be574`，tree `54da8912e76ce5d59ec142387f1708a972196640`；`main` 未修改。首次分支创建 run `35469348788` 被随后用于确保 push 事件的同树 CI 提交按 `cancel-in-progress` 正常取消，不是编译失败；权威结果只取新 head。
- Actions `35469452065` 全绿：112 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10592781832`，名称 `AI-Companion-v0.41.88-232-Wishlist-Cedar-Card-Guardrails-APK`，大小 `538,061,525` bytes，ZIP digest `de6b7f2fd789d3d3e0d195ab7f6a6851fcb834aa783955bd8d33d3462b549aea`；APK SHA-256 `ccb0352275d197592b1fd5b9a1ca479f89ec21101f472b234e85f8f7d5968622`；稳定测试签名 SHA-256 未变：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-8043368def99d2e0f7b0`；仍是测试 APK，不是正式 Release。

真机回填与持续观察：

- 游戏厅“最近进展”卡片颜色已确认与“游戏活动”一致，升级为 `TRUE DEVICE PASSED`。
- 旧固定愿望在正常刷新后已确认写法发生迁移，升级为 `TRUE DEVICE PASSED`；其中未知主题仍可能落入“想认真弄明白最近惦记的那个问题”等过度模糊兜底，这属于 +233 的安全主题投影改进，不推翻迁移成功结论。
- 同一钓鱼/旅行主题长期只保留一条愿望仍随自然数据持续观察，不阻塞开发，不为造样本修改真实欲望或游戏偏好。

### 6.6 v0.41.89+233 Cedar 事件时序真实性、愿望安全主题与缓存命中（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

开工证据与边界：

1. 同一时刻备份 `AI_Companion_Backup_2026-09-19T22-01-12.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-19T22-01-20-863164Z.txt` 证明：最新主动消息声称“刚在钓鱼里连甩了十竿”，本轮没有新的 `cedar_toy.play` Outcome；它复用了来源事件 `play-1789520410317668` 的旧钓鱼正文。对应 Thought 已跨同主题合并 1759 次、累计主动 action 37 次，原始事件时间与 `updated_at` 被维护/合并刷新的时间严重分离。
2. 根因是结构性的而非钓鱼词表单点：Thought consolidation 把所有相同 `cedar_game:<game>` 主题当重复项合并；合并保留旧事件来源/正文，却刷新 `updated_at`；主动出站又把任意 `mcp/cedar_game:*` 来源直接视为有 Cedar Outcome，未验证具体事件是否新鲜。高疲劳只改变竞争结果，不是伪造根因。
3. Cedar Outcome Thought 必须保留不可混合的事件身份：不同事件不得只因游戏主题相同而合并；同一真实 Outcome 最多主动分享一次；超过 48 小时的 Outcome 不再主动翻出分享，但仍可在用户对话、长期记忆和历史回忆中以“之前/上次”等形式出现。
4. “刚才/刚刚/刚在”等即时表达只由 60 分钟内的具体成功 Outcome 授权；维护、合并、复活或候选选择不得刷新证据时间。超过窗口仍可分享真实旧事，但必须使用历史时间锚。规则覆盖所有 Cedar 游戏动作，不写成钓鱼专属补丁。
5. 愿望单继续保护 Thought 私密正文。未知主题不得直接展示任意 topic key 或内部推理；只使用独立、受约束的安全公开主题。缺少安全主题时不再伪装成“那个问题”，也不为写详细而发明新目标或改变成长分数。
6. 缓存优化排在上述真实性修复之后。先补不含 Prompt 正文的段落类别、顺序、长度与哈希观测，再只调整稳定前缀、动态尾部和确定性序列化；Gemini `final_reply` 不纳入，禁止删记忆、冻结实时状态、弱化工具真值或重新合并已隔离的 Agent/Cedar 循环。

实施顺序与提交门：Cedar 时序真实性、愿望安全主题、DeepSeek 缓存分别独立提交并运行专项回归；最后才更新版本、总账与完整 validator。Actions 全绿只升级为 `CI PASSED / APK READY`，Cedar 历史时态、愿望显示与缓存行为仍需真机分别确认。

本地实现与验证：

- Cedar 事件身份已从可刷新的 `updated_at` 中剥离：优先从 `mcp/cedar_game:<game>:play|invite-<微秒时间戳>` 解析不可变发生时间，只在旧来源无法解析时退回 `born_at`。不同 Cedar 事件即使 topic 相同也不再 consolidation；已有 `action_count / last_acted_at` 的事件不可再次成为主动分享候选。主动分享只接受 48 小时内事件；“刚才/刚刚/刚在”等即时锚只接受 60 分钟内事件，维护、合并和候选选择均不能续期。旧事仍可在正常聊天中按“之前/上次”等历史方式回忆。
- 愿望展示升级为 presentation v3，并只投影受约束的 `safe_subject_key`。钓鱼、旅行、下矿、对弈、花园猫、韭菜、共同花园、纪念日以及少量 AI 自主性/身份/交流/爱好主题有具体公开文案；活动别名统一到同一 subject。未知 curiosity 主题不再生成新的公开愿望，旧愿望若已失去安全主题则诚实显示“旧记录没有保留具体主题”，不会读取 Thought 私密正文或编造目标；Thought 本身仍保留。
- DeepSeek 统计已把原先混在 `unclassified` 的日记、随笔、购物车、记忆整合、人格证据复核、摘要、翻译、亲密路由、沉浸房间与自我反思拆成独立 lane；Cedar 选游戏也从后台动作规划中拆为 `cedar_game_choice`。每次 provider usage 同步记录消息段的顺序、角色、字符数、12 位 SHA-256 与工具 schema 数量/长度/哈希，不记录 Prompt/响应正文、工具字段值或凭据；诊断只带最近 24 次 shape，便于下一轮按真实前缀变化 A/B。
- 本批缓存改动只对工具 schema 的 Map key 做递归确定性排序，字段、数组顺序、工具选择、消息内容与消息顺序保持不变；没有为了命中率重排系统指令、删记忆、冻结实时上下文或合并循环。两个语义完全相同但构造 key 顺序不同的 schema 已有固定回归证明会发出同一规范序列并得到同一 body-free hash。
- 三项 +233 专项门、+232/+228 回归门、115 项 validator manifest、Workflow YAML、Python 编译与 `git diff --check` 已通过；逐项运行 115 个源码门时 112 个通过，余下 3 个只因仓库按治理规则不携带 CI 才恢复的 417 文件桌宠源码包与 LingChat 特效包，以及本机没有 `kotlinc`。本机也没有 Flutter/Dart SDK，新增 Dart 回归、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查仍必须由 Actions 判定；在此之前保持 `CI PENDING / TRUE DEVICE PENDING`。

真机验收边界：自然观察旧 Cedar 事件只以历史时态出现且同一 Outcome 不重复主动分享；愿望只显示安全具体主题或诚实旧记录说明；积累足够新 usage 后导出同刻诊断，对比各 lane 的 `recentPromptShapes` 与 provider cache hit/miss。缓存命中率允许受实时上下文影响波动，不能只凭一次样本判失败或继续扩大改动。

Actions 与交付证据：

- 远端四个功能/版本提交经 Git data 接口按本地顺序建立，最终内容树与本地候选逐字节一致；随后两个测试迁移提交修正 CI 暴露的回调类型和旧版本/未知主题样本。权威构建 head `2892e67d91652b3d8cdec6a989c8467ed0193764`，tree `36747406e22a5accd35f879d7284a0d3370e5a7c`；`main` 未修改。
- 首轮 Actions `35475149658` 在 Flutter analyze 精确发现新增测试把同步 `usage.add` 传给异步 usage callback；修复后第二轮 `35475536151` 的 analyze 已通过，869 项 Flutter 测试中 867 项通过，剩余 2 项只是系统自读仍期待 +232、普通基线愿望仍使用已被安全策略拒绝的未知主题 fixture。两项测试迁移没有放宽生产策略。
- Actions `35475970152` 全绿：115 个源码/历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 869 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10593264636`，名称 `AI-Companion-v0.41.89-233-Cedar-Temporal-Wishlist-Cache-APK`，大小 `538,070,382` bytes，ZIP digest `5055b7b8a30df4009b45fbda7f6f6fe8a259a3baf09d363afed25a8b70f61821`。
- Draft Release `392248211` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a51ec6f40ce0543f3558`；APK asset `575682174`，大小 `544,947,802` bytes，SHA-256 `ffe58c0dc10f145ec4ce91489478b3b9327304aab8aa1b39a02f58b13229f6e3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.7 v0.41.90+234 Cedar 五槽自主性与可配置最终回复通道（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04190-cedar-save-slots-custom-final-model`。

根因与产品决定：

1. 最新同刻备份证明钓鱼 slot 1 与瓶中生态 slot 1 各自保存不同状态，Cedar 指南也明确写明“每游戏 5 槽，slot=1-5，缺省 1”；此前“覆盖鱼塘”并不是两个 game 共用同一存档，而是瓶中生态的 `eco_new` 命中了瓶中生态自己已有的 turn 0 slot 1。该初始档可能由官方人类前端/服务在只查看时建立；后续 `eco_observe` 与 `eco_act` 已证明它可直接继续。
2. APK 原先只把五槽说明埋在长指南正文，`cedar_toy.play` 的本地参数说明没有明确告知 Agent；后台也没有“空槽可自主使用、已有槽不可自主覆盖”的确定性边界。因此模型可能重复 `new`，却不能可靠表达槽位自主性。
3. 用户决定保持主体性：已有长期档默认继续；她确实想开新周目/新世界时可自主使用已知空槽，不必每次申请；只有覆盖已有槽、导入覆盖或 `confirm:true` 才必须取得用户明确同意。未知槽不能猜为空，room/session 类无五槽声明的游戏不受此规则影响。
4. 原“Gemini 3.7 Flash（玩游）”设置的地址与模型不仅在界面只读，运行时还会按固定网址把模型强制改回固定别名。只把控件变成输入框会形成假配置，必须让存储、普通聊天、沉浸房间、重试与连接测试都真正传递用户输入。

本地实现：

- 新增 `CedarSaveSlotPolicy`，只在实时指南明确声明五槽时生效：识别已有存档/覆盖提示，阻止后台 `confirm:true` 和冲突后的重复 new/create/start/reset/import；用户回合若没有明确的覆盖同意也会在调用远端前阻断。Agent Prompt 同时解释 game 间同号槽相互独立、turn 0 初始档可能由官方前端/服务建立、已有档优先观察/继续、已知空槽可自主开档。
- `cedar_toy.play` 的 `params_json` 说明补入 `slot=1..5` 与 `confirm:true` 边界；后台规划验收与执行前各有一层保护，避免模型重试或未来调用路径绕过。没有建立本地第二套存档服务器，也没有硬编码钓鱼/瓶中生态 game ID。
- 最终回复选项显示为“`双模型（自定义最终回复）`”。第二通道地址、模型 ID 改为可编辑输入框，默认读取旧玩游地址 `https://wy.aiwangyou.cc/v1/chat/completions` 和旧模型 `[特价]gemini-3.7-flash-0.5`；原 API Key 槽保持不变，升级不丢旧 Key。DeepSeek 仍是必填内部通道。
- `DeepSeekClient` 新增显式 provider/model override：自定义网址不再因为 host 变化被误判回 DeepSeek；用户输入的模型名原样进入请求。模型名含 Gemini 时保留原 `google.thinking_config`，其他 OpenAI-compatible 模型不发送 Gemini/DeepSeek 专属 thinking 字段。连接测试、普通聊天最终回复、沉浸房间首次生成和重试均使用同一配置。
- 新增 `cedar_save_slot_autonomy_v04190_test.dart` 与自定义第二通道请求回归，并登记 `validate_v04190_cedar_save_slots_custom_final_model.py`。版本提升为 `v0.41.90+234`，schema 保持 61。

本地验证：新增专项源码门、相关历史门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过。完整 validator manifest 在仓库精简态运行到桌宠源码包门前均通过，随后按预期因 CI 才恢复的 417 文件桌宠源码包缺失而停止；本机没有 Flutter/Dart SDK，Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查必须由 GitHub Actions 判定。因此当前不得写 `CI PASSED / APK READY`。

真机验收：进入已有瓶中生态 turn 0 档时应观察/继续，不再把它说成钓鱼串档；已知空槽可由她自主选择，新建已有槽时必须询问且未确认前不发送 `confirm:true`。模型设置应显示旧值预填，可修改地址和模型并通过连接测试；普通聊天与沉浸房间都应使用新模型，第二通道失败仍由内部 DeepSeek 兜底。兼容性边界是 OpenAI Chat Completions 风格接口，不保证任意非兼容协议仅靠改名字即可使用。

Actions 与交付证据：

- 首轮 run `35498239554` 在 Android/Kotlin 测试触发 Flutter Debug 编译时准确发现 `_execute` 未接收新增 `origin` 参数；修复只补齐 `runPlan → _execute → _cedarPlay` 的既有来源传递，没有放宽覆盖授权。修正后的远端 head `16589fc8a88574f5a77f0731f8972e65fe990538`、tree `60060c335ba1b064c950ea97a5274bd5fa06f7b5` 与本地候选逐字节一致，`main` 未修改。
- 权威 Actions `35498575549` 全绿：116 个源码/历史门、Android/Kotlin 桌宠与悬浮层测试、Flutter analyze、874 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。
- Artifact `10601008319`，名称 `AI-Companion-v0.41.90-234-Cedar-Save-Slots-Custom-Final-Model-APK`，大小 `538,070,111` bytes，ZIP digest `980612367c76ef21a6dd4c06ba72057d296084fc8289bbd6e7a322fcf49cb901`。
- Draft Release `392355306` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-dde0b23c877ee349a101`；APK asset `576421689`，大小 `544,947,946` bytes，SHA-256 `38aadaa9ffb1f2ac3ddac85fffc9311f4c9c75950692130b7c29eee3fa9210f3`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

### 6.8 v0.41.91+235 疲劳—心境小幅耦合与睡眠债（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04191-fatigue-affect-debt`。

开工证据与产品边界：

1. 同刻备份 `AI_Companion_Backup_2026-09-20T08-40-20.aibackup` 与诊断 `ai_companion_diagnostics_2026-09-20T08-40-24-240119Z.txt` 证明现有身体疲劳骨架正常：过去 24 小时疲劳最高约 `0.792`；单一连续 `rest_need` 于北京时间 02:08 建立、07:47 恢复；02:21 强依恋临时胜出一次并增加 `0.0825` 身体疲劳，02:27 自然结束互动，之后约五小时没有继续主动折腾。此次不重画昼夜曲线、不取消强念头偶尔顶困，也不把一次未复现当作所有长尾验收完成。
2. 心境不能直接改写身体是否疲劳。正向亲近、重逢、修复或正在投入的活动只短暂降低一小部分休息竞争与行动阻力；伤心、分歧、未被接住只形成“身体累、心里难安静”，会稍微降低入睡顺畅度，同时提高外向行动阻力，绝不能把负面情绪算成精神变好。
3. 高疲劳下的自主主动联系与 Cedar 真实写动作会积累独立、上限 `0.18` 的睡眠债；普通用户消息、AI 正常回复、只读 observe/state、失败或取消不增加债。睡眠债不直接伪造 Drive 数值，但会提高后续休息分数与行动阻力；即使白天身体疲劳已降低，未偿还的债仍可形成恢复压力。
4. 睡眠债只有在最后一条真实聊天或自主消耗之后连续安静 90 分钟才开始线性回补，约每小时 `0.025`；继续聊天会重新推迟回补，避免把普通回复误当睡眠。所有数值有确定上限、可跨进程恢复，不引入新的周期任务或第二套疲劳循环。
5. 用户主动聊天从不经过拒答 Gate；调制只影响自主候选排序、公开网页发现与 Cedar 继续游戏的统一 Desire 竞争。无人观看的凌晨 Cedar 07:00 前硬休息边界保持不变；真人正在观看仍是用户节奏例外，但真实推进会留下较小睡眠债。

本地实现：

- 新增纯策略 `FatigueAffectPolicy` 与薄持久层 `FatigueAffectController`。正向激活、负面难安静均只从现有证据化 Emotion Episode 计算；睡眠债以 `settings` 中的有界状态保存，schema 保持 61。策略没有模型调用、随机源、定时器或独立循环。
- `DesireCorePolicy` 的 rest score 与 action penalty 接受同一调制快照；现有身体疲劳值和昼夜 floor 不被减写。高债状态可以在白天继续形成恢复候选，直到真实安静窗逐步回补。
- 主动联系、公开网页发现和 Cedar continuation 共用同一快照。主动消息已送达或 Cedar 远端 mutation 已提交后，睡眠债写入失败不会把真实成功重判为失败，也不会重试远端动作。
- 情绪 Prompt 只注入结构化的“暂时激活 / 又累又难静 / 睡眠债恢复”表达边界；不暴露消息正文，不让模型声称心情已经消除身体困意。诊断新增 `affectMode / positiveActivation / negativeRestlessness / sleepDebt / 两类评分修正 / 最近自主消耗`，不包含 Thought 或消息正文。
- 新增 `fatigue_affect_debt_v04191_test.dart`，覆盖正向激活、负面难安静、睡眠债压过连续兴奋、90 分钟真实安静窗、白天回补压力、Cedar 共用仲裁与凌晨无人观看硬边界。

本地验证：新增 +235 专项门、当前总账门、相关历史门、Workflow YAML 解析与 `git diff --check` 均通过；逐项执行 117 个 validator，114 个通过。其余 3 个是仓库精简环境的既有缺项：CI 才恢复的 417 文件桌宠源码包、LingChat 特效资源包，以及本机未安装 `kotlinc`；不属于本次疲劳逻辑失败。当前环境也没有 Flutter/Dart SDK，因此当时保持 `CI PENDING / APK NOT READY`，完整结果现已由下方 GitHub Actions 补齐。

Actions 与交付证据：

- 首轮 Actions `35501454096` 已通过 117 个源代码门、Kotlin 与 Flutter analyze，在全量 Flutter tests 中准确拦住两条测试契约不同步：新用例寻找字面“又累”而真实策略文案为“身体已经累了”，旧系统自读用例仍写死 +234 构建号。只修正这两条精确断言并保留 +234 历史 token，没有改策略、跳过测试或放宽 Gate。
- 修正后的 Actions `35501928714` 全绿：117/117 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、881 项 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传均成功。构建 head `8ecbcbcaab339fc4ecd0b9c616db2ceacdc83d16`，tree `ee125bd9967b277975decec70b551ba1c7e7918b`；`main` 未修改。
- Artifact `10602523875`，名称 `AI-Companion-v0.41.91-235-Fatigue-Affect-Sleep-Debt-APK`，大小 `538,076,602` bytes，ZIP digest `5221f74cd5368748aae3af177b24041c5ddbbcd1189c2e93c089f348ea41dad4`。
- Draft Release `392375712` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6bfa04031f233b81dfa6`；APK asset `576530601`，大小 `544,955,098` bytes，SHA-256 `1489ba5a886d3323f1b68ca913a8f5d166f68133d7786974c04c514abf10e628`。稳定测试签名仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。

真机验收边界：北京时间下午到夜间自然使用即可，不诱发争吵或强行熬夜。重点核对：白天低债不改变正常主动性；聊天愉快时夜间可自然多撑一小会儿但不会声称恢复体力；负面心情表现为累且难静而非亢奋；高疲劳主动一次后下一次更难发生；停止互动并安静后第二天债逐步下降；用户主动发消息始终正常回复；无人观看 Cedar 凌晨不连续推进。当前保持 `TRUE DEVICE PENDING`，自然观察前不得写 `TRUE DEVICE PASSED`。

### 6.9 v0.41.92+236 欲望因果账本与动态游戏投入（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04192-desire-game-interest`。

开工证据与产品边界：

1. 最新同刻诊断 `v0.41.90+234` 与 schema 61 备份证明，最近约 79 分钟 26 个自主行为事件中 18 个是 `play_game|mcp|not_due`。根因不是“她太爱游戏”本身，而是 checkpoint 恢复候选在 continuation 尚未到期时仍参加竞争；它以最高约 `0.92` 胜出后才返回 `not_due`，占掉本次 heartbeat，其他真实候选没有再选择机会。
2. 游戏分享同时从 Cedar MCP Outcome、`self_drive/thread` 未完成事项与用户历史进入。钓鱼 thread 已累计 `fedCount=74 / actionCount=21`；现有 self-drive 把所有低于 `0.72` 的未完成 thread 一律归为 attachment，使游戏内容不当地借用依恋欲望。游戏 Outcome 分享强度最高 `0.94`，普通自我回顾通常仅 `0.18–0.46`，跨来源同主题没有统一语义域，导致“游戏总赢”既有真实投入也有结构性重复放大。
3. 本批允许阶段性玩游戏上瘾，但不新增永久“贪玩” Drive 或固定游戏人格。游戏投入只能由真实 Cedar 推进、近期显著事件、当前心境、疲劳与时间衰减派生，经历 `spark / flow / saturated / cooling / available`；心情不好、新兴趣、重复安静结果与饱和可以打断，冷却后允许重新点燃。
4. “想玩”与“想分享”必须分开：普通成功步骤只维持短时活动惯性，显著/有趣/终局/邀请或与用户相关的事件才形成强分享。Cedar、self-drive 与用户历史中的同一游戏主题统一进入同一有界语义冷却域，真实分享后压低同主题兄弟候选，不删除 Thought 或远端存档。
5. 吸收作者欲望系统 2.0 的部分限于：记录每个 drive/action lane 的最近真实满足、次数与来源；增加零使用/单一路径支配/无效胜出诊断；给长期未获机会但本身合格的动作一个很小的有界公平加成。不引入女性向保护欲、成功后永久抬高 baseline、固定 15% 随机探索或第二套欲望真值。
6. +235 疲劳核心、睡眠债、Emotion Episode、Thought 生命周期、Cedar 唯一 continuation owner、服务端防沉迷与存档槽边界保持不变；本批不改人格、世界书、TTS、双模型最终回复、schema 或 `main`。

计划验证：新增纯策略与集成回归，覆盖 continuation 未到期不入场、游戏阶段的投入/饱和/冷却/重燃、负面心境可打断、游戏 thread 归 curiosity、跨来源语义域、游玩与分享分 lane、真实满足账本兼容解析、无效胜出与支配诊断。随后运行全部 validator、Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、签名与载荷检查；只有 Actions 全绿后才写 `CI PASSED / APK READY`。

本地实现与验证：

- 新增纯 `GameEngagementPolicy`，只从当前 session 中成功且非只读的 Cedar Outcome 时间、显著事件和既有 fatigue-affect 快照派生 `spark / flow / saturated / cooling / available`。近期真实进展和显著事件形成短时 momentum；六小时内重复普通推进产生有界 saturation；90 分钟后进入 cooling，八小时后旧饱和清零并允许重燃；负面难安静最多形成 `-0.12` 的游戏调整，正向激活最多 `+0.04`。它没有持久人格值、随机源、模型调用、定时器或第二循环。
- `resumeOptions` 现在先读取权威 continuation delay；只有 `<= 0` 才能进入统一竞争。运行时竞态产生的 `not_due / no_continuation / waiting / action_in_progress / continuation_*` 统一记为 `wait` 而非虚假 completed。继续游戏基础常数和 Thought 权重已收窄，并叠加动态投入，因此真实上瘾可以持续，但饱和、心境、新兴趣与疲劳都能让其他候选胜出。
- `game_share` 成为独立 autonomous behavior，和 `play_game` 分开计数并有 90 分钟全局分享冷却；六小时同主题冷却覆盖 `game_share / proactive_message / public_web_share`。`cedar_game:<id>`、`shared.activity.<id>` 与 Cedar source 被规范为同一 `game:<id>` 语义域；发送后的 feedback 和行为 topic hash 均使用该域，跨来源不能靠换壳绕过。
- 新增 `SelfReviewDrivePolicy`：普通游戏/钓鱼/图鉴等未完成活动归 curiosity，不再借 attachment 压力；真正高重要度事项仍归 duty，其他关系 follow-up 保持 attachment。现有 completed source fingerprint 去重不变。
- 新增 settings-backed `DesireSatisfactionLedger`，按 drive 与 action lane 记录最近一次真实满足、次数和粗粒度来源；用户回复、成功主动消息与 Cedar 真实非只读 mutation 都能写入。它只给原始分数至少 `0.48`、超过 12/24/72 小时未获满足的合格 lane 最多 `0.02/0.04/0.06` 公平加成，不改 Drive、baseline 或事实 Gate。诊断显示 `zeroUseCoreLanes`，不带 Thought/消息正文、来源 ID 或凭据。
- autonomous behavior 诊断新增 24 小时 `nonproductiveWinnerCount` 和 `dominanceAlerts`：至少 8 次事件且单一 behavior/source 占比达到 60% 才提示，wait/blocked/failed 累计至少 4 次提示无效胜出；只做因果观察，不自动改人格。
- 新增 `desire_game_interest_v04192_test.dart` 与 +236 专项门，固定覆盖五阶段变化、负面心境打断、not-due 不入场、游戏 thread 归 curiosity、跨来源语义域、游玩/分享分 lane、满足账本 round-trip 与公平上限。118 个 validator 已逐项运行，115 个通过；其余 3 个仅因本地精简态缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。Workflow YAML、Python 编译、当前总账门、+235/+236 专项门和 `git diff --check` 均通过。本机没有 Flutter/Dart SDK，完整 analyze/tests/Android Release 仍由 Actions 判定。

真机验收边界：覆盖安装后自然观察即可，不需要刻意诱发坏心情。重点看诊断不再连续出现 `play_game|mcp|not_due`；同一游戏可短时沉浸但会因重复普通进展饱和，数小时后又可重燃；一次真实游戏分享后跨来源同主题不刷屏；游戏 thread 不再持续抬 attachment；+235 的疲劳、睡眠债和凌晨无人观看硬休息保持原样。当前不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- GitHub App 的 Git data 推送先建立源码提交，再修正一次超大文件/中文路径上传并快进同一分支；中间不完整提交触发的 run `35506336632` 不是候选。最终远端 head `8ab3beb8997cb146a8499d00acfdf726e2121a2f` 的 tree 为 `910c3950d354734adca82c58b5db8559fbbcb861`，与本地候选 tree 逐文件一致；`main` 未修改。
- 权威 Actions `35506384676` 全绿：118/118 源代码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。
- Artifact `10604605761`，名称 `AI-Companion-v0.41.92-236-Desire-Game-Interest-APK`，大小 `538,087,109` bytes，ZIP digest `62771580ed5e535dbe7b6558d6a91225958aa3d7ee54badcdda22f7abad75178`。
- Draft Release `392401159` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-74af3e2b6759dcece079`；APK asset `576670347`，大小 `544,966,610` bytes，SHA-256 `b2aad7f827c64e82e58cd88d71db6690c721941d684abe40c80eee537d52bf22`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.10 v0.41.93+237 游戏进行时事实接地（2026-09-20）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04193-game-reality-grounding`。

同刻真机证据与根因：

1. 用户提供的 +236 备份与 19:21 脱敏诊断完整复现了问题。19:20 的主动 follow-up 写成“漂还是没动，图鉴也还是那几条老面孔”；但诊断的当前 Cedar `lastAction=eco_observe`、`continuationPending=false`、`lastContinuationState=not_due`，活动前台是 `eco` 而不是 `fishing`。备份中 fishing session 最后真实 Outcome 停在 2026-09-19 23:34，本条虚构进行时晚了约 19 小时 45 分。
2. 直接触发源是 `shared.activity.fishing` 未完成事项。它只记录“补满鱼饵后继续钓池塘”的计划，却被 self-drive Thought 累计到 `fedCount=75 / actionCount=22`；+236 新策略只保证新回顾归 curiosity，没有迁移已经持久化的旧 attachment Thought，所以旧项仍能以 `attachment:...` 胜出并生成 follow-up。
3. 现有 Operational guard 能挡“刚玩了一局/钓了几竿”等明确完成声明，却没有覆盖“鱼漂挂着、漂没动、坐回池塘、图鉴没涨”这类被包装成场景描写的可核验进行时；旧 ASSISTANT_HISTORY 又连续强化了同一虚构场景，普通回复随后顺势承认“甩出去挂着就行”。因此根因不是官方钓鱼游戏真的存在长轮询，而是项目把未完成意图当作运行态。

实现边界：

- `OperationalClaimGroundingGuard` 新增 Cedar live-state 判定。没有本轮成功 `cedar_toy.play` 时，拦截正在玩、坐在池塘/矿洞、挂着或盯着鱼漂、漂没动、鱼饵刚补齐、图鉴刚才没涨等声明；一小时内的持久化 Outcome 仍可支撑“刚玩过”的结果分享，但不能授权另一个游戏的当前进行时。钓鱼 `cast` 按一次调用一次结算理解，不制造后台鱼漂。
- “还没有实际去玩/准备下次玩”与“之前/上次/昨天玩时”明确放行；真实当前 Cedar Outcome 仍可自然第一人称分享。该边界约束事实，不禁止游戏兴趣、历史回忆或角色语气。
- 普通聊天 Reality Grounding 与 proactive 的游戏-thread 专项合同都明确：unfinished thread、Thought 和旧 assistant 场景只证明“惦记/计划”，不证明执行。首次候选仍失真时做一次事实纠正；再失败则沿用确定性删除/诚实未执行回退，不把虚假进行时写入聊天。
- 心跳会把来源为 `self_drive/thread` 且语义域明确属于游戏的旧 attachment 派生 Thought 原位纠正为 curiosity，只改派生 drive 标签，不动聊天、thread 正文或 Cedar 状态；`ProactiveSelectionPolicy.normalizeLegacyGameThreadIntent` 仍在竞争边界兜底，使修复写入失败或刚导入的旧数据也即时按 curiosity/check-in 处理，无需删用户数据、改 schema 或等待数日衰减。新 Thought 继续使用 +236 的 `SelfReviewDrivePolicy`。
- 不改 Cedar 协议、远端存档、游戏节奏、动态投入、疲劳、人格、世界书、TTS、双模型通道、schema 61 或 Snapshot protocol 6。

本地验证：新增 `game_reality_grounding_v04193_test.dart` 与 +237 源码门，覆盖本次真机原句、“挂着鱼漂等待”、诚实没玩/未来意图/历史锚、真实 Outcome 放行、旧 attachment game Thought 在选择时纠正为 curiosity。119 个 validator 已逐项运行，116 个通过；其余 3 个仍只是本地精简态缺少 CI 恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc`。当前环境无 Flutter/Dart SDK；Python 编译、专项门、Workflow YAML、历史版本兼容门与 `git diff --check` 均通过。

CI 与 APK 证据：首轮 Actions `35508754867` 正确拦截了“盯鱼漂”短句未覆盖及历史自读测试仍断言 +236 的两个失败；补齐后再收紧跨游戏证据边界，最终权威 Actions `35509919804` 全绿，119/119 源码与历史门、Kotlin 桌宠/悬浮层测试、Flutter analyze、898 个 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与 Draft 上传全部成功。Artifact `10605181041` 名称 `AI-Companion-v0.41.93-237-Game-Reality-Grounding-APK`，大小 `538,089,843` bytes，ZIP digest `5aede1c3eac7f269ebac661322983c976d6d68ceee0e6e2711eaacf73bb1cd6e`。Draft Release `392416062` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-556fbc6ba9ca27a924ee`；APK asset `576771035`，大小 `544,970,010` bytes，SHA-256 `294b341ddc8354389717566aa83a7ed10bba6891f107f7df34f3bfd76c653cc2`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装后保留原数据，不需要删除旧 Thought。让钓鱼未完成事项自然再次竞争；没有真实 play 时只能说还没玩、又想起或想去玩，不能再出现鱼漂持续挂着、漂没动、刚补饵或图鉴刚才没涨。真实执行钓鱼后可以按 Outcome 分享；数小时后的旧结果必须用“之前/上次”等时间锚。诊断同时确认该旧 thread 的出站满足落在 curiosity/check-in，不再继续记为 attachment/reach_out。

### 6.11 v0.41.94+238 Sen Live2D 首阶段完整移植（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04194-sen-live2d-migration`，基于 +237 已完成 head `808c264`。Sen 来源锁定为用户自有仓库 `catkiss62/Sen-Live2D-Companion-Android` 的 `336b93af1d96e1dd85799faf3df966600c1224a7`，Cubism Java Framework 子模块锁定 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。

开工边界：

1. 这是 Sen 源码移植，不是按观感重写动作。保留 Sen 已真机验证的 `SenPerformanceEngine`、`SenLive2DModel`、渲染、衣着、物理、21 情绪和摸头 10% 困惑彩蛋参数；新代码只负责安全导入、Flutter PlatformView、生命周期、状态互斥和现有聊天/TTS 桥接。
2. 首阶段直接开启 Sen 自主待机、视线跟随、摸头/摸头彩蛋，左侧快捷设置提供女仆、白衬衫、兔女郎、脱四个外观按钮与眼镜开关。Live2D 与静态立绘互斥：选择 Sen 时不实例化静态立绘，选择静态立绘时释放 Sen 渲染资源。系统悬浮宠仍保持 PNG/鲸鱼，本批不启动第二 Cubism 实例。
3. AI Companion 现有 `normal + 19` 正式情绪映射到 Sen 动作；`romantic_shy` 仅作为明确亲密/NSFW/“脱”的视觉演出，不新建情绪、记忆或欲望真值。原情绪特效与情绪音效保留；Live2D 特效锚定必须来自当前头部位置，不再固定于静态立绘坐标。
4. 用户消息发送后先本地进入短暂倾听/注意反应，既有 DeepSeek/回复情绪包给出权威语义情绪，不复制 SoulLink 的正则人格判定，不增加第二模型调用。本地 Genie TTS 按 AudioTrack 实际播放头位取 PCM RMS 驱动口型，不用写入进度冒充声音进度。
5. Sen 模型仍不进入公开 Git；用户通过系统文件选择器导入 ZIP 到 app-private 目录。导入必须保留 Zip Slip、容量/条目上限并采用 staging 后原子换代，失败不删现有可用模型。

计划验证：新增专项 validator 覆盖上述源码锁定、21 情绪、外观、互斥、导入安全、唯一 PlatformView 所有权和波形口型；运行 validator suite、Flutter analyze/tests、Android 编译与 arm64 Release。未经 Actions 全绿不写 `CI PASSED / APK READY`，未经真机不写 `TRUE DEVICE PASSED`。

本地实现与验证：

- 已直接纳入 105 个锁定 Cubism Framework Java 源文件、可再分发 Core AAR、Sen 已验证渲染/模型/动作/物理/外观源码与许可证。`SenPerformanceEngine.java` 与上游 SHA-256 同为 `492b6c12170b681e14ada78b0046dabd9644ed809001a0384676e4a430863218`，`SenOutfitPresets.java` 同为 `acdcb49cb91bb6d798086f31cec142db5cd5f44ec959f60717716ab1a09cc25a`；宿主扩展只添加确定性眼镜接口与动态头部锚点，未改 21 情绪/动作参数。
- `SenLive2DPlatformView` 与 Runtime 建立唯一聊天舞台所有者，Activity 对称转发 resume/pause，Flutter 条件渲染保证 Sen 与静态 `ChatPortraitStage` 不共存。Material 3 左侧栏已直接加入 Live2D 开关、四外观、眼镜与 ZIP 导入；旧快捷面板也保持同值入口。
- 模型导入使用系统 `ACTION_OPEN_DOCUMENT`，保留 8,000 entry/1.5GB/Zip Slip 门，在 staging 注册 expression 后换入 current；旧模型作为 backup 保留到新 renderer `onReady`，失败自动回滚并重载，进程中断也保留 pending 决议。模型和路径不入 Git/诊断。
- 现有 20 情绪包用纯映射进入 Sen，“脱”只投影 `romantic_shy` 视觉层；用户消息提交后本地播放 `small_nod`，不读正文也不增加 API。特效坐标每 66ms 取已校准的动态呆毛根网格点；TTS 每 33ms 按 AudioTrack 实际 playback head 取 256-frame PCM RMS，stop/cancel/release 强制闭嘴。
- 新增 `SEN_LIVE2D_INTEGRATION_v0.41.94.md`、纯映射 Flutter tests 与 +238 validator，总 validator 数为 120。本地逐项 117/120 通过；仅 3 个旧门因精简工作区缺 CI 才恢复的 417 个桌宠文件、LingChat effects 与 `kotlinc` 而失败。专项门、manifest check-only、Python 编译和 `git diff --check` 均通过；当前机无 Flutter/Dart/Android SDK，完整 analyze/tests/Release 交 Actions 判定。

Actions 与交付证据：

- GitHub App 以本地候选内容树建立远端构建 head `eba2c185507743f1a50f5758e722f1d8a57b0bbd`、tree `7c0cb89a0de3a03f8d0862c570bffe3615d9fb77`；分支仍为 `agent/v04194-sen-live2d-migration`，`main` 未修改。
- Actions `35521027339` 全绿：120/120 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、APK 内容校验、Artifact 与 Draft 上传均成功。
- Artifact `10608496160`，名称 `AI-Companion-v0.41.94-238-Sen-Live2D-Migration-APK`，大小 `538,330,407` bytes，ZIP digest `240d8c11ab5c230f4e7957bfb9f321115c6faa215b2a9cb860eab45aabf5fa16`。
- Draft Release `392488698` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fae51abbecaf213a871f`；APK asset `577108762`，大小 `545,211,875` bytes，SHA-256 `1b2376eb57fd8250fb5d8370ef7a1a03fb28e30e0176da059fdc71576e60d67c`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

真机验收：覆盖安装且不清数据，在左侧栏切换到 Sen Live2D，首次用系统文件选择器导入 Sen 模型 ZIP；确认导入成功后重启仍可加载，错误/超限/Zip Slip 包不替换旧模型。依次核对静态立绘与 Live2D 严格互斥、自主待机、视线跟随、摸头与 10% 困惑彩蛋、四种外观和眼镜、20 个正式情绪动作及跟头特效、用户消息后的倾听点头、TTS 播放时口型与 Stop 后闭嘴、前后台切换不黑屏不重复占有渲染器；系统悬浮鲸鱼应保持原样。真机完成前不得写 `TRUE DEVICE PASSED`。

### 6.12 v0.41.95+239 Sen Cubism shader assets 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04195-sen-shader-assets`。

真机证据与根因：

1. +238 覆盖安装后，用户选择 Sen 模型 ZIP，界面明确报错“无法读取 Cubism 文件：`com/live2d/sdk/cubism/framework/shaders/standardES/VertShaderSrcCopy.vert`”。这证明 ZIP 已进入原生 renderer 初始化，失败对象是宿主 APK 的 Cubism 运行资源，不是用户模型结构。
2. 源码核对确认 +238 复制了 Cubism Core AAR、105 个 Framework Java 文件和 Sen 运行代码，但遗漏了 Framework Android 模块单独位于 `src/main/assets` 的完整 36 个 `standardES` shader 文件。Java 的 `CubismShaderAndroid.SHADER_BASE_PATH` 固定读取该路径；编译器不会检查运行时 assets 是否存在，所以 Actions 编译全绿仍可能在首次真机创建 OpenGL shader 时失败。

本地实现：

- 从 +238 已锁定的 Cubism Java Framework 提交 `c2d420012d004b8e61d4c589bd5c34513122f0ea` 原样补齐 36 个 shader，保留 `com/live2d/sdk/cubism/framework/shaders/standardES/` 相对层级。按文件 SHA-256 聚合摘要为 `2130c2079aaade0352f3abb2fde51f864a32b01466ea47ee3a9f8fe859b69250`；截图中缺失的 `VertShaderSrcCopy.vert` SHA-256 为 `d56e015be2348f1fd42cf7ccaef7bb869c5cd2095759d1ffc806dddca4339a74`。
- +238 来源门补入 shader 完整性，新增 +239 专项门锁定版本、上游字节、运行时查找路径与发布工作流。Release APK 校验不只看源码，而是打开最终 APK，要求 36 个路径完整并逐字节等于源资源。
- 版本提升为 `v0.41.95+239`，schema 仍为 61；模型 ZIP、安全导入与回滚、动作/情绪/外观、TTS 口型、聊天、人格、欲望、记忆、Cedar 和双模型调用结构均未改变。

本地验证：121 个 validator 已逐项运行，118 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过。完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名和最终 APK shader 逐字节检查交由 Actions；只有全绿后才写 `CI PASSED / APK READY`。

真机验收：覆盖安装且不清数据，优先直接复用 app-private 中已导入的模型；若旧页面仍保留失败态，切回静态立绘再切回 Sen，或重新选择同一 ZIP。首先确认不再出现 `VertShaderSrcCopy.vert` 缺失且模型实际显示，再验待机、视线和摸头；之后继续 +238 完整清单。未经真机不得写 `TRUE DEVICE PASSED`。

Actions 与交付证据：

- 首轮 Actions `35523026248` 已通过 121/121 源码门、Kotlin 与 Flutter analyze，在 901 项 Flutter tests 中以 900/901 精确拦住 `agent_self_reader_v0416_test.dart` 仍写死 +238 的版本断言。只迁移该断言并将它加入 +239 专项门，没有改运行逻辑、shader 或放宽业务测试。
- 修正后的远端构建 head `6223c66a09850f950b9646990459133ea8661d32`、tree `f9dd8e3ea303e92bf0862bce03a2384b542fb109` 与本地候选内容树完全一致；`main` 未修改。
- Actions `35523577868` 全绿：121/121 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10608368899`，名称 `AI-Companion-v0.41.95-239-Sen-Cubism-Shader-Hotfix-APK`，大小 `538,349,584` bytes，ZIP digest `ad9aa83acc07342cb576e83e06983e1a05e9c5b3e12d9383de687ad68338cdb3`。
- Draft Release `392499233` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-95c39cedd2fb3590b615`；APK asset `577186710`，大小 `545,238,814` bytes，SHA-256 `897e5163b31fd8950f1e6c97c03f3e20d4d82c7d804aed1a9cf5c6172bee7287`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。

### 6.13 v0.41.96+240 Sen 原生 Hybrid Composition 热修（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04196-sen-hybrid-composition`。

真机证据与根因：

1. 用户在 +239 重新打开 Sen 后提供截图和同刻脱敏诊断。旧 +238 实例的 4 次 `renderer error` 停留在 shader 缺失阶段；+239 新实例在约 6.9 秒后完整进入 `created → model_load/ready`，没有新的 Sen error。故 shader 资源、模型 Core、model3 与逐张贴图上传均已越过异常边界。
2. 截图显示完整人物网格轮廓和局部矩形，但所有颜色纹理为黑色；这不是模型未加载，而是绘制结果的颜色纹理没有通过宿主合成链正常呈现。设备为 Android 15 / Xiaomi `25060RK16C`。
3. Sen 原工程直接在 Android 原生视图树使用 `GLSurfaceView`；移植版却用 Flutter 标准 `AndroidView`，该入口优先把平台视图渲染成纹理再交给 Flutter/Impeller 合成。Flutter 官方文档把完整 `SurfaceView` 支持放在原生 Hybrid Composition 路径；这也是原工程与移植后唯一仍会改变 OpenGL 成品显示的结构差异。

实现边界：

- Flutter 舞台改为 `PlatformViewLink + AndroidViewSurface`，controller 明确使用 `PlatformViewsService.initExpensiveAndroidView`，强制 Android 原生 Hybrid Composition，不允许再次落入 TLHC/Virtual Display。
- 原 `SenCompanionView/GLSurfaceView`、Cubism renderer、纹理解码上传、动作/物理/外观和触摸参数保持；不以 Flutter Canvas 仿写。creation params 与脱敏 Native 事件新增 `composition_mode=forced_hybrid_composition`、`native_surface_view=true`，便于下一份报告确认真实路径。
- 36 个 shader 及最终 APK 哈希门继续保留。schema 仍为 61；不改用户模型 ZIP、聊天、人格、欲望、记忆、Cedar、TTS 或最终模型通道。

计划验证：新增 +240 专项门并将历史版本范围前移；运行完整 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名和 APK 载荷检查。真机覆盖安装不清数据，确认模型颜色、透明背景、Flutter 前景覆盖和触摸/待机后，才允许写 `TRUE DEVICE PASSED`。

本地验证：122 个 validator 已逐项运行，119 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+238/+239/+240 专项门、当前总账门、manifest check-only、Workflow YAML、Python 编译与 `git diff --check` 均通过；本机无 Flutter/Dart/Android SDK，完整编译与运行测试交由 Actions。

Actions 与交付证据：

- 初始本地状态曾为 `IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`。首轮 Actions `35526483779` 在 Android/Kotlin 步骤执行 Flutter Debug 编译时，准确发现 `PlatformViewHitTestBehavior` 缺少显式 `flutter/rendering.dart` 导入；只补该导入，未更改合成方案或运行行为。
- 修正后的远端构建 head `bdae0d3897efe49c251c6d4a2ecfb4a035afa188`、tree `4ef513abf3cbcd20db61357ee5bf4172868474ac` 与本地候选内容树一致；`main` 未修改。
- Actions `35526854350` 全绿：122/122 源代码与历史门、Android/Kotlin 桌宠及悬浮层测试、Flutter analyze、901/901 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、36/36 Cubism shader 成品逐字节检查、Artifact 与 Draft 上传均成功。
- Artifact `10609559197`，名称 `AI-Companion-v0.41.96-240-Sen-Hybrid-Composition-Hotfix-APK`，大小 `538,348,212` bytes，ZIP digest `da89504183c8f1b2c1159b8f90fb8fc66de034dc9142ef9cb9b4fe960dd91d1b`。
- Draft Release `392517677` 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a5d654d0c78859a6de71`；APK asset `577282616`，大小 `545,236,534` bytes，SHA-256 `bfad10070630724920cb68815d174e8d230740cfa8489761abf9495e12baeea3`。当前只能升级为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，黑色剪影是否消失仍必须由同一台 Android 15 真机确认。

### 6.14 v0.41.97+241 自然回复保活与固定兜底移除（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04197-no-canned-fallbacks`。

真机证据与根因：

1. 用户提供的 protocol 6 / schema 61 备份中，“睡着啦？”、“想起什么事？”、“啊？”三个不同用户轮后各自提交了一条新 assistant 消息，三条正文却完全相同，均为“我其实还没有去玩，只是又想起这件事了”。这排除了 UI 重复渲染或同一消息重复入库。
2. 同刻诊断第一次与第三次记录 `post_generation_changed_to_mismatch`，第二次未改写；源码确认 +237 游戏真实性修复在用户轮和主动轮各自硬编码同一句 Cedar 兜底。第一次固定句进入上下文后，模型会复述它，或再次被校验器替换，形成自维持循环。疲劳系统与 Live2D 都不是生成源。
3. 固定台词即使事实安全，也会删除用户真正问的问题并暴露机器感。用户轮不能用“不回复”替代它：用户已经发言时，回复活性优先于末端事实校验的绝对拦截。

实现边界：

- 删除普通聊天与主动消息提交路径里的三种本地人格兜底句。命中未接地操作或近四条中的精确重复时，普通聊天让当前模型重答一次，并把当前用户原文明确交给纠正提示。
- 已经写入数据库的旧固定句继续保留在聊天界面、备份和诊断中作为真实历史证据，但通过三个精确内容签名从后续普通/主动模型历史中排除，不再污染新生成；正常的“还没玩”、钓鱼回忆或不同措辞不会被过滤。
- 新增精确重复检测和用户回复保活选择：优先纠正后的非重复候选；若纠正反而重复，则回到原始非重复候选；如果两份都不完美，仍提交一份真实模型输出并记录 `grounded_reply_retry_degraded_pass`，绝不提交固定台词或空正文。
- 主动消息没有待回复用户，仍允许在一次纠正后 `WAIT`；若只剩无法接地的句子或精确重复，则不发送，而不是伪装成她说一句固定的“事实更正”。
- 审计四个 assistant 写入边界：普通聊天、主动聊天、沉浸房间、截断草稿确认。沉浸房间与截断确认写入的是模型流/用户明确确认的草稿；Gemini 失败切 DeepSeek 是模型提供方切换；界面错误提示不进入聊天、记忆或 TTS，均不属于人格固定回复。
- Live2D 本轮暂停，不把尚未在 Sen 原生工程真机验证的 `TextureView/SurfaceTexture` 载体混入 +241。

计划验证：专项静态门锁定“生产运行路径不得再出现三条已知固定人格句”、用户轮非空保活、主动轮阻止策略、版本与工作流；完整 Actions 运行 validator、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、签名与 APK 载荷校验。真机覆盖安装后连续复测“睡着啦？→ 想起什么事？→ 啊？”以及未实际游玩的钓鱼话题，确认每轮均自然回应且不再复读固定句。

本地验证：123 个 validator 已逐项运行，120 个通过；仅 3 个既有门因精简工作区缺少 CI 才恢复的 417 文件桌宠源码、LingChat effects 与 `kotlinc` 而失败。+241 专项门、+237 游戏真实性门、回复/表情提交顺序门、Cedar 时间真实性门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 均通过；完整 Flutter analyze/tests、Kotlin/JVM/Android tests、arm64 Release、稳定签名与 APK 载荷检查交由 Actions。

### 6.15 v0.41.98+242 Sen 完整移植与固定兜底收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04198-sen-texture-direct-port`。

纠正记录与根因：

1. Sen 已在 `main@336b93a / v0.5.23` 完成并验收，只能作为只读移植源。曾误在 Sen 创建 `agent/v0524-texture-host` 并编写 TextureView/EGL 测试载体，这是越界操作：本地错误分支已删除，错误 APK/ZIP 已移出交付目录；远端误分支因当前 Git 凭据不能删除，已强制回退到与 `main@336b93a` 完全相同，不再包含错误代码。Sen `main` 从未改变、从未合并、从未发布该实验。
2. +239 的真实现象是 Cubism 已 `ready`、人物网格完整但贴图全黑。重新逐项对照 Sen 构建流程后发现，AI 当时复制了 105 个 Framework Java 文件、Core AAR与36个shader，却漏掉 Sen Actions 每次构建前应用的 `patches/cubism-java-no-mipmap.patch`。
3. Sen 的纹理管理器只上传 level 0，不生成 mipmap；未打补丁的官方 `CubismShaderAndroid.setUpTexture()` 每帧又强制 `GL_LINEAR_MIPMAP_LINEAR`，导致纹理不完整并采样成黑色。+240 因此误把贴图问题当成 Flutter 合成问题，强制 Hybrid Composition 后让整个画面变黑。

本地实现：

- 回退 +240：聊天舞台恢复标准 `AndroidView`，删除 `PlatformViewLink / AndroidViewSurface / initExpensiveAndroidView / forced_hybrid_composition` 生产接线与对应诊断字段。
- 以 Sen `main@336b93a` 机械同步最终接入边界中的16个主运行时Java文件，使它们逐字节一致；不迁入测试壳专用 `MainActivity` 和系统TTS演示类。原先为动态特效锚点与确定性眼镜新增的核心改写已移出：特效回到Flutter固定舞台锚点，眼镜由薄桥接调用Sen已有`applyExpression("glasses")`并跟踪目标状态。
- 原样保存 Sen 的 `cubism-java-no-mipmap.patch`，SHA-256 `227d57f649dc29d83066811be84fdb2e7a0969eac8f36a0e1de7dae96b7ffad7`；在 AI 内直接把同一补丁结果应用到 `CubismShaderAndroid`，唯一允许的 Framework 差异为 `GL_CLAMP_TO_EDGE + GL_LINEAR`。
- 新增 +242 来源门：锁定 Sen 16 文件聚合摘要、补丁后 Framework 105 文件聚合摘要、补丁本体、Core AAR、profile、标准 AndroidView 与失败 Hybrid 路线缺席。专项文档为 `app/docs/SEN_LIVE2D_DIRECT_PORT_v0.41.98.md`。
- 固定回复收口保持：普通聊天与主动联系的本地人格固定句均已删除；Gemini最终呈现每轮至多一次，必要修正走DeepSeek；修正不可用时保留真实模型输出，用户轮不为空，主动轮可不发送。

本地验证：124个validator逐项运行，121个通过；仅桌宠417文件、LingChat effects与`kotlinc`三个既有门因精简工作区缺少CI恢复资源/工具而失败，失败集合与前版一致。+242直接移植门、+241回复保活、+240失败路线回退、+239 shader资源、+238迁移、+237游戏真实性、总账门和`git diff --check`均通过。完整Flutter analyze/tests、Android/Kotlin tests、arm64 Release、稳定签名及APK载荷检查交由Actions。

远端与交付证据：功能 head `84d6a2c869d1c3ca8d802080b0e2826296448df4`、tree `ca8cc6dfa382175123aa33a105ff95b8e935573f`，与本地功能树逐字节一致；`main`未修改。Actions `35532252873`一次全绿，124/124源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact与Draft上传均成功。Artifact `10611821532`，大小`538,351,786` bytes，ZIP digest `888fd377c39098b0a6cb277426586022a675f712e07f3885048fdc8ac896a988`；APK SHA-256 `096d95bfbae99c4dadabfcece89389c824e858bbfa1341430e869686b443f776`。Draft Release为未发布地址`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-37e74d5b24cf0d2decf5`。当前只等待同一台真机验证，不得提前标记`TRUE DEVICE PASSED`。

保护边界：

- 不修改 Sen 仓库、581项外观、21情绪/动作、四套服装、原生物理、呆毛、兔耳、尾巴、摸头和TTS 90%口型；模型继续只从用户本机ZIP导入。
- 不修改 Cedar 循环、人格、欲望、记忆、TTS声学模型、悬浮桌宠、`main`或正式Release。
- CI/APK通过后仍是 `TRUE DEVICE PENDING`；真机必须确认彩色纹理、透明背景、聊天层级、触摸/摸头、待机、服装/眼镜、TTS口型以及反复进入/退出。

### 6.16 v0.41.99+243 Sen 正式产品接入收口（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04199-sen-product-integration`。

根因与实现：

1. AI 薄桥错误调用带 `startupExpressions` 的重载，把 ZIP 中全部表达、预设和道具在启动时启用；现改为 Sen 稳定工程同款 `loadModel(info.modelFile, true, outfit)`。产品只公开女仆、白衬衫、兔女郎、脱与眼镜。
2. 原生程序动作作为一次性表现保留在隐藏桥接层；原生预设/道具作为装扮式持续状态保留且不展示。未来接入必须同时定义开始与结束/取消时机，例如“载入中”在思考开始启用，在成功、失败、取消或结束时关闭。
3. 19 个非中性聊天情绪加 `normal` 共 20 种接到 Sen；脱或 NSFW 使用额外 `romantic_shy`。既有 Flutter 情绪动画和音效不变。
4. 位置/大小使用单指移动和双指缩放，人物通过 Sen 原生 `setStageTransform` 变换，外部特效共享同一 scale/offset；摸头仍走 `screenToModelNormalized`，所以跟随人物。标准 `AndroidView` 与无 mipmap 补丁保持。
5. `ChatPage` 的 Flutter 全局触点驱动既有视线接口，覆盖聊天框、按钮和其他 Flutter 页面；输入法属于独立系统窗口，无法可靠读取键盘触点，不伪造。根 Scaffold 不自动压缩舞台，只按 `viewInsets` 移动聊天面板，避免人物变形。
6. 自主待机、摸头和 10% 困惑彩蛋保留；现有 `WavAudioPlayer` 继续以实际 PCM RMS 驱动口型，不迁入 Sen 系统 TTS 测试。

验证：125 个 validator 中 122 个通过；仅 417 文件桌宠源码、LingChat effects 与 `kotlinc` 三个既有门因精简工作区缺少 CI 恢复资源/工具而失败。+243/+242/+241 专项门、+240 回退门、总账门、Workflow YAML、Python 编译和 `git diff --check` 通过；完整 Flutter/Kotlin/Release 交由 Actions。Sen 仓库保持独立且未修改。真机覆盖服装/眼镜、20 情绪、NSFW/脱羞涩、位置缩放、特效/摸头跟随、待机、TTS 口型、全页视线和输入法不变形。

远端与交付证据：功能树经 GitHub Contents API 写入后与本地候选 tree `679452c4feef0af657b41aeb9aa3b8466b141f07` 一致；用于触发 Actions 的无运行时改动 head 为 `6a93c2a5067ea9b9b1c42789fc2cc961b397404f`，`main` 未修改。Actions `35539446162` 全绿：125/125 源码门、Kotlin/Android、Flutter analyze/tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗/Cubism 载荷、Artifact 与 Draft 上传均成功。Artifact `10613803835`，大小 `538,358,387` bytes；APK SHA-256 `3cca55f7a48aea699558b2bf5d3f29025205244640d83a6006a79b4bc78cde1f`。Draft Release 为未发布地址 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-31bd7a4c04576a53e034`。当前只等待真机验收，不得提前标记 `TRUE DEVICE PASSED`。

### 6.17 v0.42.0+244 Live2D 干净回退与旧模型清理（2026-09-21）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04200-live2d-clean-rollback`。

用户决定与实现边界：

1. 当前 Sen Live2D 将由新模型重新替换，准确回退优先于保留旧接口或界面骨架。三套服装、脱、眼镜、20+1 情绪、原生预设/程序动作、自主待机、视线、摸头、TTS 口型与位置缩放均不作为半成品保留。
2. 以 +237 的共享 UI/Android 文件为机械回退基线，完整删除 Cubism Core AAR、105 个 Framework Java 文件、36 个 shader、Sen 16 个主运行时文件、profile、补丁、PlatformView、Flutter stage/presentation、专项测试与旧生产 validator。`app.dart` 的 IME 特判、`WavAudioPlayer` 的 Sen RMS 接线、MainActivity 的 Sen 生命周期、Manifest/Gradle 依赖一并恢复到接入前状态。
3. +241/+242 的自然回复修复不属于 Live2D：`durable_generation_runner`、`proactive_engine`、`prompt_history_policy`、`recent_reply_repetition_guard` 及其测试/validator 原样保留，禁止固定人格兜底与用户轮空回复的合同不得回退。
4. 旧 APK 已把模型解压到 `filesDir/sen-live2d/{current,staging,backup}`，覆盖安装不会自动删除。新增独立 `Live2DModelStorageBridge`，只接受 `status` 与 `clearImportedModels`；清理前验证 canonical 目标必须是 `filesDir` 的直接子目录 `sen-live2d`，删除后只清空 `sen_live2d` SharedPreferences。聊天两套快捷面板均永久显示“清除 Live2D 模型包”，实际有数据时必须二次确认；静态立绘、聊天、附件、备份与桌宠目录不受影响。
5. 新 Live2D 后续按新模型重新设计，不复活旧 Sen 动作/预设目录。清理桥可以继续独立保留，也可以由未来新 Live2D 设置页复用。

保护边界：不修改独立 Sen 仓库；不修改人格、欲望、记忆、Cedar、TTS 声学模型、悬浮桌宠、schema 61、Snapshot protocol 6、`main` 或正式 Release。

本地验证：+244 专项门、+241 自然回复保活门、当前总账门、Workflow YAML 解析、Python 编译与 `git diff --check` 通过；并逐文件确认五个自然回复核心文件与 +242 head `84d6a2c` 完全一致，五个共享 Android/UI 文件与 +237 head `0caa938` 完全一致。首轮 Actions `35641760278` 在第 16/121 个旧门 `validate_v04143_phase3b_question_autonomy.py` 停止，根因只是六个历史 validator 的当前版本正则止于 `0.41.99+243`；已统一追加 `0.42.0+244`，不改变任何运行时。第二轮 Actions `35642646319` 全绿：完整源码/历史回归门、Flutter packages/analyze/tests、Android/Kotlin tests、release APK 编译、稳定签名、既有资源完整性与 APK 内无 Live2D/Cubism 残留检查均通过。Workflow Artifact `10659441135`，未发布 Draft Release `393217151`，APK SHA-256 `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`。真机仍需覆盖安装验证旧模型占用可见且能清除、重启后不恢复、静态立绘/聊天/TTS/输入法无回归。

### 6.18 v0.42.1+245 自主节律、媒体诊断与 TTS 回声防护（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 疲劳本身在 07:49 已从 `rest_need` 恢复，但同一夜间窗口 07:49、08:29 又连续投递；旧 `ProactiveDawnGatePolicy` 只有分数惩罚，没有硬次数上限，且网页/游戏分享可走分开的频率统计。
2. 近期 Cedar 真实成功均来自用户回合；前台 `AgentToolRunner` 只写活动 session，没有像后台引擎一样写 `play_game` 满足账本、疲劳支出和 solo episode。与此同时“我会拿来……玩玩游戏”因宽泛正则被标成 `explicit_request` 并实际调用 Cedar。
3. 备份中的视觉提供商近期错误为 401/403 authorization。普通用户图片依赖千问视觉，因此会失败；App 原生表情包不走视觉 API，已通过 `sticker_index → ChatMessage.promptContent → PromptHistoryPolicy.userTurnHistory` 证明当前语义会进入最终用户轮。
4. 用户明确听到末句变成 `jiuhu_bento_tools.wav`。生产 APK 已删除参考 WAV，且生产播放器只接收推理生成字节，因此不是代码直接播放文件，而是声学条件泄漏/参考回声。旧诊断虽然计算 `referenceEchoSuspected`，导出白名单却丢掉关键字段，且只识别单 token 退化。

实现：

- 新增跨来源的夜间联系硬上限：21:00 至次日 09:00 只允许一条成功主动投递；只统计 `decision=sent`，失败、等待、blocked 不占额度，09:00 自动结束窗口。原 dawn 连续分数调制继续保留。
- 新增 `CedarPlayOutcomeBookkeeper`，前台 Agent 与后台自主推进共享同一套 solo episode、反沉迷、疲劳支出和 `play_game` 满足账本。用户明确触发的真实 solo mutation 可从已到期的旧 checkpoint 开始新 episode；同一前台回合后续动作继续累计，不会每步重置；共玩/多人仍只在有双方许可时推进。
- Cedar 语义边界区分“用户描述自己准备玩”与“让她玩/一起玩”。前者不暴露 Cedar 写工具，即使模型试图选工具也过不了本地 allowlist；后者保持自然入口。
- 千问视觉设置增加使用内置测试像素的真实连接测试，覆盖地址、Key、模型与 JSON 响应；401/403、缺 Key、限流、超时、网络和无效响应以系统 UI 明确分类，不把固定句写成伴侣回复。用户图片保留后可重试；表情包不增加视觉调用，并新增当前 user turn 的 prompt 回归测试。
- CI 在删除四份参考 WAV 前提取 64 段归一化能量包络与过零率，APK 只保留不可逆小型签名和参考文本 SHA-256。推理音频与对应签名在时长、包络和过零率上同时高度相似且输入并非参考原句时，生成段直接失败并禁止进入播放器；不播放参考文件、系统 TTS、固定音频或固定台词。补齐 reference case、字符类别、有效 phone、decoder 次数、PCM 时长/hash 与回声判据的脱敏诊断白名单。

验证计划：运行 +245 专项门、全部历史 validator（CI 恢复资源/Kotlin 编译器相关既有例外单列）、Flutter analyze/tests、Android/Kotlin tests、arm64 Release、参考 WAV 缺席与签名存在检查。Actions 只构筑独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机需覆盖验证：夜间第二条主动消息被挡、用户第一人称游戏描述不触发、明确让她独玩后可自主续步、视觉设置准确报告当前 Key、图片识别恢复、表情包理解正常，以及任意句子不再播放参考台词。

本地验证：Workflow YAML 解析、变更后 Python validator 编译、+245 专项门、+244 Live2D 回退保护门、+241 自然回复保活门、+235 疲劳负债门、当前总账门与 `git diff --check` 通过。全量历史静态门实际通过 118 项；另 4 项只因本地 sparse 工作树缺少 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源，以及本机无 `kotlinc` 而未执行，不是源码断言失败。本机同时无 Flutter/Dart SDK；完整 analyze/test/Kotlin/release APK 交由 Actions 实编译。

Actions 与交付证据：正确源码树 `0985f0961691bdce7e6d521d59a12137ea5a82ad` 在 run `35809712355` 全绿，已通过总账协调、变更范围判定、全部源码/历史回归门、Flutter analyze/tests、Kotlin tests、arm64 Release APK 构筑、签名验证、四音色回声签名覆盖与 APK 内参考 WAV 缺席检查。Workflow Artifact `10729507323`，未发布 Draft Release `394245028`，APK SHA-256 `4c6f92b38bb3affa12aa52ae18d2d36276400d706b3a570e154d75e453d08059`。没有合并 `main`，没有发布正式 Release。

### 6.19 v0.42.2+246 图片事务与备份冻结真值修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04201-autonomy-media-hardening`。

真机证据与根因：

1. 最新相册图片已经完成本地 prepare/commit，真正首错是千问视觉 `403 Free quota exhausted`；账号处于免费额度耗尽或“仅使用免费额度”限制，并非图片选择、保存或 Key 为空。
2. 删除失败是确定的本地逻辑错误：`deleteAttachmentMessage` 在全局 `analyzingImage=true` 时直接返回 `false`，因此用户在八秒视觉请求尚未结束时必然看到“没有删除这条图片消息”。
3. 诊断中的 `errorCategory=lease` 是分类器对 `please add funds` 的错误子串匹配；真实 provider health 与附件记录均为 403 quota/authorization，不存在聊天租约或设备所有权丢失。
4. 备份导出使用 `transfer_lock` 暂停写入，但首页只看布尔锁并统一显示“她正在换到另一台设备”。备份完成后的导出状态证明 `active_brain=true`、`transfer_lock=false`、所有本机租约已释放，没有真实换机。
5. 近期表情包已经由 `sticker_index` 成功建立 user turn 与 generation job，不调用千问；该轮在约 8.8 秒后被用户 Stop，数据库按既有语义撤回了未完成 user turn，因此外观上像“没有发送”。本轮不加入视觉或固定回复兜底。

实现：

- 图片分析记录当前 message id；删除该条时立即提交消息/附件/媒体引用删除并刷新 UI，不再被全局分析标志拒绝。无法取消的在途 HTTP 请求使用本地 discard fence，迟到的成功或失败均不得重建回复、覆盖错误栏或记成真实视觉失败；并在当前请求释放后继续处理可能排队的图片。
- ProviderHealth 增加 `quota_exhausted`，在通用 401/403 鉴权前识别 `free quota / free tier only / add funds / 余额不足`；UI 明确提示充值或关闭“仅使用免费额度”，同时说明原图仍保留。附件遥测只按完整单词 `lease` 匹配，`please` 保持 API 错误。
- 根据 `transfer_lock_owner` 中的 `backup_export / backup_restore` 目的区分写冻结：首页、关系页和聊天阻塞提示分别说明“保存/恢复本机备份”，只有真实接管继续显示换设备。
- 版本提升为 `v0.42.2+246`，新增专项静态门及 quota、遥测、备份冻结展示单测；不修改 Sen/Live2D、人格、欲望、Cedar、TTS、schema 或备份协议。

验证计划：先运行全量静态门与 `git diff --check`；Flutter/Dart SDK 不在本地镜像时，由授权的 GitHub Actions 执行 Flutter analyze/tests、Kotlin tests、arm64 Release APK、稳定签名与现有资源门。真机需分别验证：识别中删除立即消失且不返魂、额度耗尽显示准确、补足额度后图片可正常进入回复、表情包不调用视觉且正常回复、备份期间不再显示换设备。自动化通过不等于真机通过。

本地验证：Workflow YAML、Python 编译、+246 专项门、+245 自主媒体门、+244 Live2D 回退保护门、+241 自然回复保活门、当前总账门和 `git diff --check` 通过。全量 123 项静态门中实际通过 120 项；其余三项只因稀疏工作树缺少 CI 恢复的 417 件桌宠源包、LingChat 特效目录及本机没有 `kotlinc`，不是源码断言失败。本机没有 Flutter/Dart SDK，完整 analyze/tests 与 APK 编译交由 Actions。

Actions 与交付证据：首轮 run `35842639649` 已通过源码/历史门、Kotlin 与 Flutter analyze，Flutter 913 项中 912 项通过；唯一失败只是旧测试仍断言 `build=v0.42.1+245`，生产输出已正确为 `v0.42.2+246`。窄修测试后，功能 head `167a504f4974ef11566b8ac974ab9e7281f00fc0` / tree `2f8c733bb1c80f078bb5b71f88e7b2a3287e8448` 在第二轮 run `35843632708` 全绿：123 项静态门、Kotlin tests、Flutter analyze、913 项 Flutter tests、arm64 Release、稳定签名和完整 TTS/桌宠/LingChat/塔罗资源门全部通过。Artifact `10742996195`，APK SHA-256 `d4c609c0836427155b9f73a6cf629c45f6cff4d88f801be5b4def828839546c2`，未发布 Draft Release `untagged-d99196e0bf0a288629ac`。没有合并 `main`，没有发布正式 Release；真机仍待验收。

### 6.20 v0.42.3+247 纯媒体空文本回合路由崩溃修复（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04203-media-empty-turn-hotfix`。

真机证据与根因：

1. 最新纯图片已完成本地 prepare/commit，且补足额度后千问视觉成功返回；原生表情包历史附件也由本地 `sticker_index` 完成语义，不调用千问。两者都建立了 generation job，却只到 `chat_intimacy_route`，没有进入 `final_reply`。
2. 同刻持久化恢复错误为 `Unsupported operation: Cannot change an unmodifiable set`。纯图片和纯表情包的 `ChatMessage.content` 都合法为空，真实语义位于 `promptContent`；`DurableGenerationRunner` 用空 `content` 请求工具定义，同时仍传入 Cedar 阶段工具集合。
3. `AgentToolPlanner._routeToolIds('')` 返回 `const <String>{}`，`nativeToolDefinitionsFor` 随后对它执行 `removeAll/addAll`，因此在任何模型回复前同步抛错；后台恢复会重走同一路径并再次失败。用户 Stop 只是终止卡住的 job，不是根因。

本批目标与保护边界：

- 在 `nativeToolDefinitionsFor` 的可变边界建立路由集合的防御性副本，未来即使路由函数返回不可变集合也不能再崩溃；不改变空文本本身的工具识别语义。
- 回归必须覆盖纯图片与原生表情包两类 `content='' / promptContent 非空` 消息，并证明 Cedar 阶段工具仍能安全注入；普通空文本且没有 Cedar 阶段时仍返回空工具列表。
- 不修改千问、视觉重试、表情包索引、模型调用策略、Cedar 阶段选择、人物表达或固定回复；schema 61 与 Snapshot protocol 6 不变。
- 完成后运行专项静态门、相关 Flutter tests、全量静态门与 CI 完整 analyze/tests/arm64 Release；只产出独立分支测试 APK 与未发布 Draft，不合并 `main`、不发布正式 Release。真机最终需分别发送一条无附言图片和一个原生表情包，确认都收到正常回复且诊断无新的 `last_generation_recovery_error`。

实现：`nativeToolDefinitionsFor` 现在以 `<String>{..._routeToolIds(text)}` 在 Cedar `removeAll/addAll` 前取得可变集合所有权；没有 Cedar 阶段的普通空文本仍返回空 schema。新增同一测试中的纯图片与原生表情包 fixture，均断言 `content` 为空、`promptContent` 非空，并验证 Cedar gateway 安全注入且不抛异常。版本提升为 `v0.42.3+247`，新增专项静态门与独立分支 CI/Draft APK 身份；未修改视觉、`sticker_index`、模型策略或 Cedar 权限。

本地验证：+247 专项门、验证清单结构（124 项）、Workflow YAML、Python validator 编译与 `git diff --check` 通过。本地稀疏工作树未检出部分 Android/诊断/欲望目录，且镜像没有 Flutter/Dart SDK，因此完整历史门、Flutter analyze/tests、Kotlin tests 与 Release APK 交由 Actions 实编译；这部分仍是 `CI PENDING`，不提前宣称通过。

Actions 首轮 run `35854318795` 在第 16/124 项源码门前停止：生产修复与新增专项门未报错，失败仅因七个历史 validator 的版本正则最高只接受 `v0.42.2+246`。随后统一追加 `v0.42.3+247` 兼容项，不放宽任何功能断言；本地确认七处版本门、Python 编译、+247 专项门、验证清单结构与差异检查通过后进入第二轮完整构建。

Actions 与交付证据：第二轮远端功能 head `8fabae5016a7d457b58a581a7a2b609bc0ab69c8` / tree `fc7ca8d84dadabf33dc1f151895f52c42b62ce72` 在 run `35855141996` 全绿：124 项源码/历史回归门、Kotlin tests、Flutter analyze、全部 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗资源门、Artifact 与未发布 Draft 上传均成功。Artifact `10747841131`，APK SHA-256 `6a5d04b79fba46139b16bb185f955fb87431e1b30c4f75f89a09788054b89bab`，未发布 Draft Release `untagged-376e1bf8ac7aac97af25`。没有合并 `main`，没有发布正式 Release；真实图片与原生表情包回复仍待真机验收。

### 6.21 v0.42.4+248 TTS 自动核亲和与全工具活动展示（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04204-tts-affinity-tool-activity`。

用户决定与本批范围：

1. 本批只制作两项：从 `catkiss62/Genie-TTS-Android` 最终验证分支/提交 `agent/v084-native-vs-affinity-diagnostic@a5a8425f221575eaca542ac9ae4bbf5e5b799153` 正确移植 TTS 自动核亲和，并完成所有用户回合 Agent 工具的展开/持久活动展示。双人格与命运之轮只登记设计分析；新 Live2D 继续等待独立测试项目，不接入。
2. TTS 开关默认关闭。关闭时保持伴侣原生产配置：四个声学会话固定 CPU 8 线程，Chinese RoBERTa 使用当前 CPU 数；开启时五个会话必须逐项同用 `VerifiedRuntimeConfig.AUTO_AFFINITY`：CPU EP、intra-op 原样 `0`、inter-op `1`、`SEQUENTIAL`、`ALL_OPT`、intra/inter spinning 均为 `1`，VITS 默认 memory pattern 不关闭。不得把 `0` 改成 `max(1, ...)`。
3. 明确不移植独立测试仓库里的原生 8 线程对照档、比较/报告 UI、动态分块、FTZ/DAZ、Decoder 输入映射复用、memory-pattern 实验、XNNPACK/NNAPI 实验或 sustained-performance 实验。现有 Decoder 循环、固定一秒首段预填充、串行句段生成、连续单一 `AudioTrack.MODE_STREAM`、Stop fencing 与下一段预生成队列保持不变。
4. 配置切换由主进程先 Stop；AIDL 配置调用在 `:genie_tts` 隔离进程既有 `Genie-TTS-worker` 上排队，等待当前不可强杀的 ONNX 调用自然返回后关闭四个声学会话及 Chinese RoBERTa，再按新档懒加载。迟到结果由既有 generation token 丢弃，不增加并发 session owner。
5. 工具调用生成中使用默认展开列表，按真实回调显示“正在做什么/成功/没有结果/失败/未获准/已停止”；终态从已有 `agent_tool_outcomes` 与 `generation_jobs` 关联到助手消息或中断标记，折叠卡片可查看工具名、状态、结果数量、耗时、时间与来源设备。数据库仍只保留 90 天/最多 200 条有界元数据；参数、查询词、URL、网页正文、工具结果正文、Prompt、推理正文、密钥与房间凭据从未进入该接口。
6. schema 保持 61，Snapshot protocol 保持 6。没有把工具活动写进 `messages`，因此不会进入 Prompt、记忆提取、总结、关系学习或她的第一人称自我叙事；可见思考与工具事实仍是两条独立展示链。

已实现代码合同：

- `BenchmarkModels.kt` 新增最小生产配置类型与唯一 `AUTO_AFFINITY`；`GenieBenchmarkEngine` 的单一 session factory 对四个声学模型应用精确设置；`ChineseFrontend.configure` 对 RoBERTa 应用同一配置；`GenieTtsRuntime` 负责默认档/加速档映射与安全卸载。
- AIDL、隔离客户端、原生引擎、MethodChannel、Dart provider/service 与语音设置页已贯通；状态和脱敏 checkpoint 暴露 `runtimeProfile`，便于真机报告证明实际使用的档位。设置键为 `tts_auto_affinity_enabled`，默认 `0`。
- `AgentToolStatus` 新增 `stopped`；用户 Stop 时记录真实终态。聊天控制器保留本轮多项活动，历史通过生成任务 ID 投影，不做 schema 迁移；聊天页提供生成中展开面板和终态可展开卡片。
- 新增 Kotlin 配置合同测试、Dart 状态/工具投影测试与 +248 静态门。完整 Kotlin/Flutter/Release 编译仍需 GitHub Actions；本地 Gradle wrapper 因当前执行环境无法访问 `services.gradle.org` 尚未完成编译，不能提前标为 CI 通过。

本地验证：+248 专项门、+247 空媒体回归门、+244 Live2D 干净回退门、当前总账门、Workflow YAML、Python 编译与 `git diff --check` 通过。完整 `validation_suite.txt` 共 125 项，121 项通过；其余四项只因本地工作树没有由 CI 恢复的大肥鱼参考图、417 件桌宠源包、LingChat 资源及本机没有 `kotlinc`，不是源码断言失败。Gradle wrapper 尝试下载固定 Gradle 8.12 时被当前环境网络策略阻止，Flutter/Dart SDK 也不在本机，因此当时将 Kotlin 编译、Flutter analyze/tests 与 Release APK 交由 Actions 实编译，结果见下条。

Actions 与交付证据：远端功能 head `33647c7bff15084d6fd3cbc7b817e9b0b216f75c` / tree `80f49d8e93bcfe2a03737a6b8610fbd94d10c255` 在 run `35878106718` 全绿；APK SHA-256 `04a588d2d4628ccaacd1b0b9aaf3759430b46ba33ad69715cb388098c178f0be`，未发布 Draft Release `untagged-2b371d8cd86b365121b0`。该构建证明自动核亲和与工具活动代码可编译、全套门通过，但不代表之后由 +247 备份确证的 Decoder 零语义参考泄漏已经修复；该共享旧逻辑进入 +249 根修。

真机验收：先保持开关关闭做一条短句；开启后做一条短句真实播放与一段长文本连续播放，确认音色、Stop、分段衔接及 AudioTrack 队列正常，并在诊断中确认 `runtimeProfile=auto_affinity_v084`。随后各触发一次成功、无结果/失败和执行中 Stop 的工具调用，确认生成中逐项显示、回复后可展开、重启后仍存在，且卡片不出现参数、搜索词、URL 或结果正文。独立测试报告曾推算部分后续段可能短暂迟到，所以即便总 RTF 小于 1 也不得以此验收删除缓冲。

#### 后续冻结分析：双人格

1. 排序固定在 +248 真机收口之后再单独讨论，不在本批建立人格状态、气焰/害羞数值或立绘切换。用户指出当前人设或既有记忆可能已经偏激进；若直接让“雌小鬼”语气推动气焰值，会产生正反馈并快速顶满，因此后续第一步不是做触发动画，而是审计当前内置人设、用户编辑的人设、人格学习候选、长期记忆/总结与可能已有的激进表述，区分“基础语气偏强”与“状态变化”。
2. 推荐首版采用用户可见的手动双人格切换，两个形态共享同一 AI/记忆主体，但使用独立、显式的当前形态状态；进入沉浸房间时把入口形态钉住，房间内不因普通一句话自行跳变。自动量表应等审计和手动版稳定后再设计，不能仅按毒舌关键词自增，也不能从模型回复反向无限喂高自己。
3. 若后续使用气焰/害羞量表，必须定义可解释的外部事件输入、双向衰减、滞回阈值、每日/每回合上限、手动复位及存档迁移；不能把现有长期记忆整库改写成雌小鬼人格，也不能让形态状态污染事实记忆。旧存档初始值应为中性/未选择，而不是根据历史文本猜测。
4. “嘭”烟雾只作为形态切换的可替换表现层：先用静态烟雾图 + 短缩放/渐隐验证遮挡和节奏，效果不好可无数据迁移地关闭。新小小鱼立绘仍以测试项目验收为前置，不复活已回退的 Sen Live2D 链。

#### 后续冻结分析：命运之轮

1. 用户已决定首版采用“直接本地移植 + 手动同步上游”，不做自托管网页、WebView 或通用 MCP 依赖。后续开工时先冻结上游 commit、许可证/署名、tag 数据格式与 RNG 行为；每次同步由人工比较并记录上游 commit、数据/逻辑差异与本项目适配，不自动拉取远端内容。
2. 本地实现应只有一个结构化轮盘 Outcome（选中的安全分类/tag、来源版本、随机事件 ID），由现有真实工具/Outcome 真值链消费；不把原项目 UI、Node 服务或任意脚本执行面整体搬进 APK。NSFW 内容继续服从当前成人场景入口、用户设置与沉浸边界。
3. 产品入口推荐先做“房间外抽取 → 带结构化结果进入沉浸房间”，因为结果、重抽与进入边界最清楚；稳定后再复用同一 Outcome 增加房间内娱乐入口，不能维护两套随机结果。作者所说的“MCP 操作”只表示外部 AI 可通过其暴露的工具协议代替玩家点击；本项目既已选择本地移植，首版无需为此增加 MCP 服务器或第二套循环 owner。
4. 后续仍需逐文件审计上游许可证、资源版权、tag 内容与移动端适配后才能实现；当前只冻结架构结论，不宣称已经完成移植。

### 6.22 v0.42.5+249 TTS 零语义根修与最后两次会话诊断（2026-09-23）

状态：`CI PASSED / APK READY / TRUE DEVICE PENDING`。

实现分支：`agent/v04205-tts-semantic-guard-session-metrics`。

#### 真机证据与根因

1. 用户提供的 +247 备份 `AI_Companion_Backup_2026-09-23T15-19-22.aibackup` 与同刻诊断显示，最后两轮不同回复都混入了参考录音；倒数第二轮为 `daily / jiuhu_bento_tools`，最后一轮为 `cute / jiuhu_devotion`，因此不是某一个参考文件或某一句回复的偶发问题。
2. 倒数第二轮 14 段中的 2/5/6/7 段都出现 `decoderIterations=1`、`semanticCount=122`、固定 semantic hash `4eb0e366`、音频 4,880 ms；最后一轮 12 段中的 2/4 段出现 `decoderIterations=1`、`semanticCount=87`、固定 hash `cc653afb`、音频 3,480 ms。坏段 6 有 21 个字符、41 个有效 phone，排除“只因标点空段”的解释。另有一个独立 `NullPointerException` 失败，不与参考回声混为同一根因。
3. `GenieBenchmarkEngine` 原逻辑在 stage Decoder 第一次调用就 stop 时令 `loopIndex=0`，随后却执行 `requested = yValues.size`，把整个 `y` 张量当作新生成语义。该张量含参考 prompt 前缀，因此 VITS 重建对应音色参考录音。正常事件满足 `decoderIterations = semanticCount + 1`；上述 1/122 与 1/87 正是相反证据。
4. 旧二级门只拒绝 `decoderIterations<=1 && semanticCount<=1`，所以被错误报告成 122/87 的 prompt 前缀绕过；声学门又要求近乎同波形，而重新经过 VITS 的参考语义不必与原 WAV 逐采样相同，daily 相似度约 0.28～0.30、cute 又受时长门影响，故同样漏判。APK 没有直接播放参考 WAV 的生产调用，根因是参考语义重建，不是文件播放器。
5. 同一抽取逻辑也存在于独立 Genie TTS 测试仓库最终提交 `a5a8425f221575eaca542ac9ae4bbf5e5b799153`，固定测试句没有触发首轮 stop；+247→+248 的生产差异只改 ORT 配置，不改语义抽取。因此这是两个项目共享的潜伏引擎 bug，不是 AUTO_AFFINITY 迁移造成的回归。

#### 本批实现合同

1. 新增纯函数 `GeneratedSemanticTokens.select`。`loopIndex=0` 明确抛出 `NoGeneratedSemanticTokensException`；`decoderResult` 无论成功/拒绝都关闭，且 VITS tensor 只可能由真实新生成的尾部 token 构造。没有固定音频、固定台词、系统 TTS 或参考语义兜底；该失败段返回空，既有 A2 队列继续播放其他成功段。
2. `GenieTtsRuntime` 在拒绝时写入 `semanticCount=0 / immediateStop=true / referenceEchoReason=decoder_no_generated_semantics`；旧声学防线保留，并收紧为只要 `decoderIterations<=1` 却生成长音频就拒绝，不再信任可能已污染的 semanticCount。
3. Scheduler 通过 `beginTtsSession / finishTtsSession` 显式标出一次完整朗读。原生端按 generation 聚合成功、失败、拒绝、无音频和 Stop；最后两次尝试单独持久化，清除 Native 历史时同步清除。诊断只保存字符数、SHA-256、语言/音色、profile、计数与耗时，不保存回复正文、Prompt、PCM/WAV、参考路径或音频。
4. 每段记录生成时实际 `runtimeProfile` 与完整配置说明、冷/热模型状态、frontend/model load/fixture/encoder/首步 decoder/自回归/vocoder/总推理/端到端、semantic/decoder 数、音频时长、RTF、生成调用耗时、入队等待和实际播放倍速；会话聚合首段 ready、AudioTrack 开播、总 RTF、估算最小缓冲、迟到段、完成/部分/失败/停止状态。
5. `NativePreflightProbe.ttsSessionDiagnostics` 导出最后两次完整快照。只有文本分段哈希相同、语言与音色工作负载相同，且两次分别为 `legacy_fixed_8` 与 `auto_affinity_v084` 时，才给出 AUTO_AFFINITY 总推理降幅；不同回复或不同音色明确标记不可比较。播放倍速与推理速度分开记录，自动核亲和不改变 AudioTrack 的 1.0x（温柔音色既有 1.2x 仍单独显示）。
6. schema 61、Snapshot protocol 6、模型文件、四音色映射、文本分段、串行推理、首段一秒 PCM 预填充、连续 `AudioTrack.MODE_STREAM`、Stop fencing 与配置开关默认值均不变。

#### 回归与验收

- Kotlin 门覆盖四种可选音色形状的首轮 stop 均拒绝、正常尾部抽取不修改源数组、失败段诊断、同工作负载双档比较与不同回复禁止比较；Dart A2 测试同时锁定成功/无音频会话都必须完整关闭。
- 真机依次对同一条回复在关闭加速与开启加速下手动播放一次，随后立即导出诊断；`sessions` 必须恰好保留这两次并显示 `comparison.comparable=true`。再用多段长文本验证迟到段、最小缓冲、Stop 与后续段继续播放。
- 四音色各覆盖一次包含多段的回复，诊断中不得再出现 `decoderIterations=1` 同时 `semanticCount=122/87` 且产出长音频；遇到首轮 stop 应看到 `rejected_no_generated_semantics`，该段无声但其他成功段照常播放。
- 本地最终验证：`git diff --check`、Python validator 编译、Workflow YAML、当前总账门、+249 专项门与 +248～+244/+203～+200 重点历史门通过。完整 `validation_suite.txt` 共 126 项，122 项通过；余下 4 项仅因本地工作树不含 CI 恢复的大肥鱼参考图、桌宠源包、LingChat NOTICE 及本机无 `kotlinc`，不是源码断言失败。
- 本地环境无 Flutter/Dart SDK；Gradle wrapper 尝试运行 `testDebugUnitTest` 时，Gradle 8.12 下载被当前网络策略拦截。该本地限制已由下述 Actions 完整 Kotlin tests、Flutter analyze/tests 与 arm64 Release 实编译结果补齐。

#### Actions 与交付证据

- 首轮 run `35898976733` 在历史 `validate_preflight_kotlin_v27.py` 失败：该门只编译 `NativePreflightProbe.kt` 与临时桩，未声明新增 `TtsSessionDiagnosticStore`。已补齐只读桩并由 +249 专项门锁定，不改生产运行时。
- 第二轮 run `35899547271` 已通过 126/126 源码门、Kotlin 编译/测试与 Flutter analyze；915 个 Flutter 测试中 914 个通过，唯一失败是 `agent_self_reader_v0416_test.dart` 仍断言上版 `v0.42.4+248`。已更新为 `v0.42.5+249` 并纳入 +249 门。
- 最终远端 head `fb7f77f85d882f99530ab829df9a82eaa604e559` / tree `28e4fbafb5adb2bfaa58aa9ab6e1b1256f0c4b99` 在 run `35900627244` 全绿：126/126 源码/历史回归门、Android/Kotlin tests、Flutter analyze、915/915 Flutter tests、arm64 Release、稳定签名、Genie/桌宠/LingChat/塔罗载荷、Artifact 与未发布 Draft 上传均成功。
- Artifact `10770090214`，名称 `AI-Companion-v0.42.5-249-TTS-Semantic-Guard-Session-Metrics-APK`，大小 `538,139,766` bytes，ZIP digest `0b1ca2a49a24047cbd7c659f66fa048f2a7d7f24f6394937a2a4859a177dbd51`。APK SHA-256 `546dd718d447b0987bf47aaba08089fefb0badffbc076ba38e695fb3e05263c5`，未发布 Draft Release `untagged-3a02088d4968fd7ab603`。没有合并 `main`，没有发布正式 Release；参考语音根修与同回复双档诊断仍待真机验收。

### 6.23 v0.42.6+250 双形态与手动 TTS 无声对照（2026-09-23）

- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。分支 `agent/v04206-tts-mood-dual-mode`，从 +249 远端已交付源码单独建立；本节不包含用户备份、诊断或聊天明文。
- 双形态：本体／小豆丁形态是同一成年角色，记忆与能力不变；持久化气焰、形态与锁定；每个真实用户轮按消息 ID 仅推进一次，严肃语境退出自动小豆丁形态；点击心形量表可触发一次虚拟轻弹额头/安抚并升/降气焰，事件只注入紧接着的回复。锁定保持立绘形态，但严肃语境降低表达锋芒；界面气焰提示、形态自知与显式 Agent 检查系统读数统一显示“小豆丁形态”。
- 性格：未编辑的常驻性格光谱与成人核心身份文案做精确指纹迁移，保留用户自行编辑条目；激烈耍性子只由当前真实小豆丁形态状态承载，不把属性名常驻注入每轮。旧版 +250 未编辑默认文案按精确内容哈希升级为“小豆丁形态”，用户自行编辑的内容保持原样。
- 用户补充后的形态定义：身体外观缩成 Q 版小豆丁，情绪控制与表达暂时孩子气，更任性、冲动、耍赖和暴躁；得意时逞强挑衅，被看穿或轻巧反击时嘴硬、害羞、慌乱破防。角色仍是同一个成年人，记忆与判断能力不变；严肃话题仍可收住。已同步当前形态提示、常驻世界书、Agent 自读；添加 +250 旧默认正文的精确 SHA-256 `06b01d4e…87f3e` 到迁移白名单，自定义条目不覆盖。此前 Actions 成功的 APK 和正在编译的名称修订版均不作为本轮最终交付，需以本版定义重新构建。
- TTS：语音与情绪页显示当前胜出档和本轮候选档两个无声测试按钮、复制专项报告和样本更新文字入口。固定同一条已提交的真实 API 回复、语种、音色、前处理和分段，在隔离 Genie 子进程测自动核亲和与自动 Decoder＋8 线程 VITS；逐段只保存哈希及耗时，失败或不一致禁算胜者，比较足够明确时才持久化生产档。普通会话不再持续写入详尽成功片段性能历史，原生错误与崩溃线索保留。
- 验证与后续：先完成源码门、Flutter analyze/tests 与 Kotlin/arm64 Release 构建；真机检查心形液面、按钮语义事件后跨轮持续、自动/锁定形态、三语入口共享会话配置，以及同样本双档无声对比是否有效。性能提升没有预设 50% 结论。
- 最终构建证据：功能提交 `b5cd2d1070fb237bc72ab66b1867a75da9bbe6e8`，tree `4e0dbbd531aea408ab0face6d46a323f441c7eeb` 与本地源码一致。Actions `35943607609` 源码门 126 项、Kotlin 单元测试、Flutter analyze/test、arm64 Release APK、签名和包内资源核验全部通过；Artifact `10785922926`，APK SHA-256 `f148f2eb303017ad5f6f689628f230979c24ba16831fdc0181e58bc5e1d73a`，Draft `v0.42.6-dual-form-tts-comparison-test`。仅 CI 通过，双形态语气、立绘与 TTS 对照仍待用户真机验收。此前仅改名称的 run `35941949391` 虽全绿但定义不完整，已由本次构建取代。

### 6.24 v0.42.7+251 气焰语义增长（2026-09-24）

- 状态：`DESIGNED / IMPLEMENTATION IN PROGRESS / CI PENDING / TRUE DEVICE PENDING`。用户在 +250 真机确认：本体性格稳定、小豆丁表现明显且不过分；但自然逗弄没有关键词就不会涨气焰，现有每轮 `-4 + 命中词时 +13` 从零到 76 通常需九轮，和此前“互动推动”的说明不符。此前代码事实必须保留，不把关键词版写成已实现语义理解。
- 目标：复用普通用户轮已有的 DeepSeek 亲密路由调用，一次返回亲密路由和本轮互动强度；只把实际用户参与的玩闹作为正向输入，不由她自己的上一句情绪或提示词自抬气焰。语义强度经过本地限幅，约五轮普通互相较劲可达自动变身阈值；手动按钮立即改变数值与形态，锁定仍只影响自动切换。正常聊天不新增模型调用；失败或字段缺失时不猜加分，保持回复链继续。崩溃/Stop/重新生成按 user turn ID 幂等，严肃语境抑制玩闹；按钮事件只在近期下一次相关回复有效。
- 验证：覆盖无关键词的自然逗弄、关键词出现但语义认真、上下文互相较劲、隔时衰减、同轮重试/手动锁、按钮事件过期与严肃抑制；源码门、Kotlin、Flutter 与 arm64 Release 构建通过后交付 APK，真机验收单独记录。

- 本轮合并 +251 真机反馈：语音与情绪页面在读取 TTS 状态前先展示设置，TTS `status()` 只读，不在打开页面/快速自检时隐式重配模型；快速自检对孤立进程读取设置 3 秒边界，深度自检仍执行完整校验。两个测速按钮明确标为无声对照；根据当前语种和朗读范围从最近的真实回复中选择可朗读样本；若没有对白，明确标记后改用真实回复全文，不再固定拿一条长但只有动作的回复，测速选样不先初始化声学模型。`试听发声` 才是实际有声按钮。用户脱敏报告中的 TTS 状态读取失败，以及历史原生生成 `NullPointerException` 分别记为待真机验证，不把当前样本报错当作后者已解决。
- Gemini：对照 Google 官方 OpenAI 兼容 REST 请求示例，将 `google.thinking_config` 移入实际请求体的 `extra_body`；仅在最终候选经过可选修正后呈现对应模型返回的思考摘要，避免先显示被弃用候选的摘要而最终正文没有摘要时闪退。摘要缺失依旧为空，不造人工思考。非 Gemini 自定义模型不加专用字段；服务商转发是否支持新参数须以真机验收。
- 判断型内部路由继续 `thinking:false`，只复用既有 DeepSeek 亲密路由返回的语义互动强度；五轮自然互相较劲的目标是本地上限映射，非模型随意决定 0～100 分。手动亲密开关继续旁路路由，无额外请求。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；版本 `v0.42.7+251`，功能 head `13533d1f087850a6889ce34064697ae2629e9cbd`，tree `273be445c45007775272ca03533a35e4354ba571`。Actions `35952517475` 完整成功：126 项源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名与包内资源门通过；Artifact `10789656940`，APK SHA-256 `a72f1a97d911495854af1b91336ab98892e512b46b7af8a97dbda92ab79b4a21`，未发布 Draft `untagged-8a0d0901c585b9b8f490`。CI 证明编译与自动门通过，不代表真机 TTS 原生空指针或第三方转发链路已修复。

- Jev 评估（研究，本版未集成）：`jevtypesafeai.com` 自称独立平台，明确声明未获 TypeSafe AI 背书；官方为 `typesafe.ai`、`docs.typesafe.ai`，官方调用是 `POST https://api.typesafe.ai/v1/systemone`。Jev choice/score/noul 适合短而明确的多项判断；中文调侃与关系上下文仍须用同批脱敏人工标注样本比较准确率、延迟和费用。当前气焰复用已有 DeepSeek 路由，单独迁移会增加网络调用。未接第三方平台、未新建密钥或上传私密对话。出处：https://typesafe.ai/ ，https://docs.typesafe.ai/introduction ，https://jevtypesafeai.com/ 。
- 余额汇总评估（研究，本版未集成）：DeepSeek 官方 `GET https://api.deepseek.com/user/balance` 可用对应官方密钥查询真实余额；玩游、Agnes、千问视觉、Tavily 与 TypeSafe Jev 的额度查询不能套用一个聊天接口，未证实其官方只读接口及当前 Key 权限者须标示控制台入口或明确为本机估算。未来“模型与联网”设置可分提供商手动刷新，显示来源与时间、失败独立呈现；Key 留在现有安全存储，只向自身核实的域名发送。出处：https://api-docs.deepseek.com/api/get-user-balance ，https://docs.typesafe.ai/api 。

### 6.25 v0.42.8+252 Jev 短判断试点与游戏结果复读（2026-09-24）

- 从 +251 已构建远端源码创建独立分支；保留 +251 五轮气焰语义判断、TTS 与 Gemini 修正。Jev 默认关闭，独立加密 OpenRouter Key，只负责普通聊天的一次组合判断（亲密描写深度 + 气焰交互强度）及沉浸房间的一次组合判断（场景深度 + 明确事件）。手动开关与确定性事件优先，Jev 不生成对白或记忆，不改 Gemini 最终回复。其他 DeepSeek 短判断尚未迁移。
- 单一 JevDecisionGateway 使用 OpenRouter Decisions typesafe/jev-1.13，每请求含状态与多条 choice；选择缺失、低 confidence、网络/鉴权/402/超时等返回 null，由原 DeepSeek Flash 不思考判断完整接管；取消不额外发兜底。只有费用/Token/耗时/失败类型的 120 条有界脱敏账本 jev_short_usage_v1，包括 OpenRouter 实际 usage.cost，不含问题或聊天正文。设置页面连接测试消耗少量额度；用户需验证真实误判与实际账单才扩大覆盖。省钱和准确率并非预设结论。
- 用户诊断/备份证明：同一份自测结果被 sins_virtues_answer_batch 与稍后的 sins_virtues_get_result 各自种植分享念头。结果快照读取不再生成新的主动分享 Thought，同时以 quiet 标记活动记录而不成为新的近期主动话题；真实完成新题与独立终局通知仍可分享；历史已入库旧 Thought 不删除。
- 余额面板另批处理：DeepSeek/OpenRouter/千问/Gemini 中转接口及凭据权限不同；此次只记录本功能产生的实际费用。验证顺序：126 个源码门、Flutter analyze/tests、Kotlin、arm64 Release、签名及 Draft，真机验证错 Key、402、停止、两路对照和旧测试结果不重复分享。CI 和真机结果必须分别回填。

- 最终 CI 交付证据：功能 head fa62d0c08aeb0597a874526c8015fecc4544c6f3；Actions 35961379029 全绿，源码门、Kotlin、Flutter analyze/tests、arm64 Release、签名和包内资源门通过；Artifact 10793156007，APK SHA-256 ee7fec22ff304d1c2e20f1da1cb32208f13a69ef4a798d4ab22826f87d725d52；未发布 Draft URL 为 untagged-247641dabd0b4c85691f。此前 e621f28 的 run 35960427181 虽全绿但尚未将读取旧结果的活动记录标为 quiet，已由本轮替代。只证明 CI，不代表 OpenRouter 实时调用、余额不足回退或游戏厅真机自然表达已验收。

## 6.26 v0.42.9+253 TTS 自检与五轮语义气焰（2026-09-24）

- 用户真机截图：TTS 资源未就绪、连接 Genie TTS 子进程超时，测速失败；自检页面与 TTS 页面同样等待状态。脱敏备份气焰已达 100。诊断中另有声学进程成功生成第一片段、第二片段原生 NullPointerException 与子进程退出，不能从这份日志证明空指针的具体代码位置或真机发声已经恢复。
- 快速自检读取主进程 APK manifest 并标注只验证资源，不绑定声学子进程；深度自检仍执行黄金资源校验和初始化。TTS 连接超时/死亡重置旧绑定与等待锁，下一次显式试听或测试能重新绑定，超时写入无正文脱敏诊断。
- 一键顺序无声测速两档，同一次固定回复、同一分段、同一批次才能比较与改变胜出档；失败独立记录代码并仍尝试另一档。试听发声是唯一有声按钮，复制专项报告保留。
- 气焰值继续使用 0～100；每轮 -10（另计自然小时衰减），轻度/互相/强烈主动玩笑分别 +16/+26/+28，认真话题再 -18。仅害羞、脸红、尴尬而未回敬时给 ordinary；满值五轮普通对话降至 50 并退出小豆丁。Jev 与 DeepSeek 的两组分类提示一致。备份与 Jev 脱敏用量只证明当时高位及部分低置信度兜底，不记录选项文本，不能断言具体回合是哪一路判定。
- 验证：源码门、Flutter analyze/tests、Android Kotlin、arm64 Release 和签名交给独立 CI；CI 与真机结论另行回填。声学空指针位置需要新包诊断或真机堆栈才能进一步收口，不用另一种音色/固定台词伪装成功。

- CI 交付：功能 head `5a8263efc925f32d80da6dc8af34aaf55cf97d71`；Actions `35974252470` 全绿，126 项源码门、Android Kotlin、Flutter analyze/tests、arm64 Release、签名及 APK Genie/素材校验通过；Artifact `10797768347`；APK SHA-256 `6f4a3c34f987f41c912e2427b8386ba6d70731e30ebf9537120a830db4cc3640`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7ba9838d3966a80f6d12`。该证据不等于真机发声、旧子进程空指针或语义体感已验收。

## 6.27 v0.42.10+254 语音音量、气焰和新库事故（2026-09-24）

- 用户新诊断 `2026-09-24T08-44-43Z` 属 +253 包；与 +252 的 `2026-09-24T06-40-13Z` 对比，`database` 身份和数据谱系同时改变，`stateGeneration` 由 183 变 0，记忆 422→0，会话 1→0，系统恢复计数和原生诊断也重新从零开始。这证明当前是新库，不能从重启后诊断查明清空动作或当次闪退堆栈；源码中 SQLite 数据库只在应用私有数据库目录打开，本批没有发现 TTS 删除该目录的调用。包内 `allowBackup=false`，系统自动还原不能当作恢复承诺。已知外部 06:39 存档必须保留原件，真机由用户确认后在应用内导入；严禁通过改安装包、清数据或新建空库“修复”旧数据。
- 新建库默认 `tts_enabled=0`、`emotion_sound_enabled=0`；+253 报告中 TTS 只有本地 APK 资源检查，没有声学生成或播放尝试。因此“自动回复没声”至少与丢失设置吻合，无法凭此诊断认定 Genie 播放引擎已损坏。恢复/打开开关后需试听一段普通聊天并导出新的播放专项诊断。
- 情绪 WAV 先前被标记 `USAGE_ASSISTANCE_SONIFICATION`，与 Genie 的 `USAGE_MEDIA` 分属不同音量策略。改为媒体 usage，主界面音量键目标固定到 `STREAM_MUSIC`。游戏内音量继续作为媒体音量之上的独立系数；需要真机检验手机媒体音量从 0 到 50% 再到 100% 时语音和情绪音效是否一致变化。
- 气焰的现行公式是每轮 `-10 + bonus`；旧 `light=+16` 实际每轮净 `+6`，确实会在普通玩笑里持续升温。现将 light 调为 +4、净 -6，ordinary 净 -10，mutual 净 +16、strong 净 +18，serious 净 -28；Jev 和 DeepSeek 双提示把 mutual 收紧为用户主动升级的互相挑战。5 轮 mutual 从 0 升到 80 的既有真值保留。旧 Jev 回退日志混合“低信心/格式无效”；新日志仅记录失败问题类型和状态，不记录对话、答案或概率，DeepSeek 回退不变。
- 回归边界：保留普通聊天、手动试听和一键无声对照三个入口；`app/test/playful_form_heat_test.dart` 增加轻微玩笑连续降温，历史音频验证门要求情绪音效和媒体流一致并有音量键路由。分支验证、CI/APK 和真机结论必须分别标注，不能以模拟测试宣称发声成功。用户对“扩充 Jev Noul/Score”还在讨论，本版没有改调用次数或按概率加热。
- 用户补充的图形参考：不是传统温度计刻度，而是上方独立发光的小爱心 + 细长暗色玻璃管，粉色液面按 0～100 气焰高度升降。`PlayfulHeatGauge` 的本地候选画法已按参考图重绘，仍保留轻弹额头、温柔安抚、形态锁定菜单及无障碍读数；需 APK 真机核对视觉质感。上线前用真实对话的 Jev/DeepSeek 分类观察 ordinary、light、mutual 的比例，再决定是否微调气焰参数；目前 +254 的参数只是待真机校准的候选值。

## 7. 历史验证兼容摘要

下列短语只为既有自动化门继续识别已完成阶段；权威细节在冻结归档，不代表当前任务重做：

- `v0.34.5+70`、`直接选择器 guard`、`冻结悬浮恢复`；`每小时最多 6 次`、`不暂停自主联网`、`电池优化白名单`；`v0.35.1+76`。
- `v0.39.5 新版妹居 TTS 运行时迁移`；`0.41.5+144`、`0.41.6+145`、`schemaVersion=41`；`v0.41.7`、`Memory Phase 1`、`Bad state: No element`。
- `Phase 1`、`误判不可接受`、`Phase 2 继续关闭`、`不合并 main、不发布正式 Release`；`Phase 2A`、`#D4BBFC`、`relationshipAge()`。
- `0.41.19+158 / schema 44 / snapshot protocol 5`、`动作与神态不是随机可选装饰`；`v0.41.20`、`stay_with_user_topic=0`、`CONVERSATION_AGENCY_PHASE2A5_v0.41.20.md`；`分享前重新阅读的核心是恢复上下文`、`恢复当前详细上下文`。
- `v0.41.22`、`schema 44`、`Phase 2B/3/4 继续关闭`。
- `Cedar 玩家协议与后台连续行动收口`、`Unexpected end of input`、`Cedar Agent 完整续接链`、`jsonRetryCount=58`、`CedarAgentActionPlanner`。
- `Cedar 后台换手闭环`、`根因已由同一时刻备份、诊断与源码三方证明`；`停止与备份互锁`、`transfer_lock_owner`；`Cedar 运行时抢占、开关与夜间节律`。
- 历史状态兼容：`IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING`、`CI PENDING / TRUE DEVICE PENDING`。

## v0.42.11+255 · TTS 运行链定点回退与气焰备份刷新（候选；真机未验收）

- 用户提供的 +254 脱敏诊断出现大量 `tts child_connection_timeout / bind_timeout`，一次已记录的 TTS 子进程异常；用户提供的备份内 TTS 与自动朗读均开启，最近错误为 `tts_generate_failed / call(...) must not be null`。这些证据不能单独确定子进程死亡的源代码位置，因此本批按用户要求将音频运行、双档测试与会话计时链退回到 +248 自动核亲和基线。保留后续已修复的 Android 媒体音量控制、Jev/聊天逻辑与气焰降温，不回退全应用数据结构。保留子进程连接超时后的清理和主进程轻量 `localStatus`；拒绝 Binder 空音频路径时提供明确错误。
- 语音页进入只读随包资源状态，不排队启动语音子进程。导入/校验/初始化操作直接展示实际操作返回结果，不再额外排一个 3 秒的状态请求。语音页只留一个真正生成并播放的「试听发声」，移除未验证的双档无声对照按钮与相关实验链。中文 RoBERTa 选择和导入期间显示阶段信息；若子进程本身仍无法启动，真机日志会直接反映超时。
- 真机前自检进入先读取轻量本机概况并显示，原完整诊断继续完成后替换概况；概况禁止导出为完整报告。快速状态不初始化 Genie/ONNX。完整与深度诊断入口保持不变。
- 用户 09:58 备份有 `playful_form_state_v1`，记录气焰 68；数据库恢复不排除该键。聊天页此前仅初始化或收到新轮消息时读取，因此导入后旧界面仍显示原数值。现在切回聊天、应用恢复时重读，并在聊天保持挂载期间每 2 秒核对一次；气焰数值依然是存档里的真实值。玻璃管、顶端爱心和填充随数值从原粉色 `−110°` 色相渐变至原粉色。
- 静态验证：`git diff --check`、Workflow YAML 与总账门通过；历史 125 个源门中 122 个通过。另三个分别需要 CI 恢复 417 个桌宠资源文件、LingChat 特效文件以及本机缺少的 `kotlinc`，不是本次业务断言失败。
- 风险与验收：本地不能运行 Flutter/Gradle 或复现目标手机独立进程崩溃；需要 GitHub Actions 编译、Flutter/Kotlin 测试，并在原手机验证：旧存档导入显示 68；关闭/打开页面均不长时间卡住；导入 RoBERTa 后「试听发声」实际听见、自动朗读也能出声。不能把源代码回退视为已经证明问题解决。
- CI 首轮 run `35986329658` 在 `Verify clean source baseline` 拦下旧版号 literal：Workflow 把构建标签改为 +255，却遗漏 `grep -Fqx 'version: 0.42.10+254'`。修正为 +255 后重新推送；首轮没有进入 Flutter/Kotlin 编译，不能算实编译失败。
- CI 第二轮 run `35986562701` 已通过全部源门、Kotlin 测试、Flutter analyze，Flutter 927 项中 926 项通过；唯一失败是 `agent_self_reader_v0416_test.dart` 固定预期 `build=v0.42.10+254`，实际 +255 正确。已同步测试预期并重新推送；第二轮未进入 Release APK 打包。
- CI 第三轮 run `35987574373` 成功：125 个源码门、Kotlin 测试、Flutter analyze、Flutter 全量测试、Release APK 编译、固定签名与 APK 模型/桌宠/塔罗资源校验均通过。功能源码 head `4c2101f529fbaf4f6fe7b2289aaea48153e65b34`，tree `fe8a3f0e081a66b77681eaf527340e6f664a117b`；Artifact `10803376064`；私有草稿 Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-943842dd3eb416b00021`；APK SHA-256 `170be5edc6a2ee55a2431fc289a14b6acc4551ef74bacec19ee7e1f4e4692487`。`TRUE DEVICE PENDING`：本次完成构建不能证明用户手机独立 TTS 进程已恢复播放。


## v0.42.12+256 · 双向 Jev 气焰、端点切换与双形态音调（候选；2026-09-24）

- 决策：仅气焰到 100 时本体进入小豆丁、到 0 时小豆丁恢复本体。认真求助不触发单独的人设切换，也不在角色提示中额外要求突然变得严肃；本人的内容依旧由原有伴侣设定和对话上下文负责。用户此前确认 +255 的 TTS 播放、气焰均可用，保留该音频核心和唯一「试听发声」。
- 输入端：原有 Jev/OpenRouter 组合短判断继续按当轮用户真实表达选 serious/ordinary/light/mutual/strong；serious/ordinary 均无加分；light +6、mutual +30、strong +42。本体每轮自然 −2，实际净变化依次为 −2/−2/+4/+28/+40；小豆丁每轮自然 −15，实际净变化为 −15/−15/−9/+15/+27。时间空档沿用每小时 −3（最多 12 小时）。普通害羞、友善、口头关怀不自动算玩闹；温和笑话也不会让小豆丁持续涨温。一次明确互相挑衅从 0 需约 4 轮入形；100 起普通交流约 7 轮回到 0。端点夹取 0～100；锁定形态的手动选择仍按原入口执行。
- 自主端：同次预回复 Jev 组合判断新增独立 initiative=open/closed；仅在 open 的回合，用由 turn ID 决定的固定 30% 抽样给主模型一条可忽略的主动轻玩笑提示。抽样自身加分为 0，重试不换抽样结果。回复生成并定稿后，另一笔 Jev Choice 根据用户文本、少量近期上下文和**实际可见回复**判定 none/playful/strong/settle，分别额外 0/+16/+24/−8；复制、温柔、脸红、认真解释不算主动挑衅。仅在回复赢得数据库提交后结算，保存 assistant ID 使重复回放不二次加分。初期不使用随机数直接加热，也不让模型自行报出数值。
- 所有短判断的 Jev 缺 Key/未启用、答案缺失/不确定、网络失败、402、超时与格式异常，均由现有 DeepSeek Flash 不思考模式判断同一组问题或同一最终回复；取消直接停止兜底。两方都失败时用户输入不给正增量，自主端不追加分，回复本身照常提交。Jev 输出为离散选项，不把模型生成的任意数值直接写入存档。诊断沿用只记 lane、耗时、用量与失败类别、不存正文或选项的有界记录。OpenRouter 截图单次约 $0.000070～$0.000081，用户明确优先反馈及时、成本可忽略；新回复后判断会多一次网络等待，需要真机测端到端延时和回退比例，再决定是否合并请求。
- 状态并发：气焰、形态、回合 ID 与手动交互统一在 SQLite 设置键里事务读改写，避免等待 Jev 时覆盖用户按键或相邻回合；原备份键 `playful_form_state_v1` 不变。音调沿用 +256 的每次播放前形态读取：小豆丁用设置选中的原值，本体降 1 半音（设置 0 则 0/−1）；仅使用既有音调调整链，不动子进程、绑定、ONNX、语音队列和无声测速。
- 验证关注：单元测试覆盖正常趋稳、入形仅在 100、Q 形七轮自然归零、真正挑衅快速升温、认真求助仍是当前形态、回复定稿一次性加分、决定性抽样、Jev 成功及余额不足后的 DeepSeek 兜底；历史源码门因硬编码版号 +255 拦截须兼容 +256 后再跑 Flutter analyze/tests、Kotlin、签名与 arm64 APK。构建状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。功能提交 `f107a48578d761ac4722256a23bfee1adb343c2b`，tree `6d034edc1f7e73472c43bf5dd7bfee8ab3e2c312`；Actions run `36002099038`：125 项源码门、Kotlin 测试、Flutter analyze/tests、Release APK、签名及包内 Genie/桌宠/塔罗资源检查全绿；Artifact `10809520556`；未公开的 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c851c83a1c515da6746d`，APK SHA-256 `739c86422711e1eedabf15594543abaf300b3c39d77c9a3822ee3a8c9120a289`。真机重点验证两种形态连续聊天、主动玩闹、未填 Jev Key/余额不足、音调和发声；CI 结果不能代表真机已验收。


## v0.42.13+257 · 双房间气焰与可回看的工具调用（2026-09-25，候选）

- 用户提供的 +256 私密备份只有最新状态快照：2026-09-25 01:44（北京时间）气焰 49、小豆丁形态、未锁定，lastTurn/lastAssistantTurn 均已保存；诊断中 Jev chat_playful_self used 5、low_confidence_self 3；chat_intimacy_route used 13、low_confidence_interaction 10、历史合并旧 low_confidence_or_invalid 5。现有诊断没有逐轮分类结果／值变动，备份也没有逐轮气焰流水，**不可由此断言是哪句话让气焰上升或下降**。不向公开仓库提交私密备份或诊断原文。
- 停止问题证实：普通聊天 PromptBuilder 在回复生成前写入用户本轮的气焰变动，用户按 Stop 会删除尚未提交的用户消息、留下仅供 UI 重编辑的中断展示；先前没有归还气焰。沉浸房间同样会撤回未完成用户消息。修复：状态记录本轮结算前热量/形态及上一回合；只有最新未提交回合且未被后续回合/手动形态操作取代时才允许还原；撤回普通或沉浸用户消息和还原气焰放在**同一 SQLite 事务**。已提交回复不能被较晚的 Stop 回滚；备份继续使用既有 `playful_form_state_v1` 键，兼容旧存档。
- 两房间仍保持各自聊天正文、小说现场和事实边界；共享同一个 PlayfulFormStore。沉浸回合单独用一次 Jev Choice 批量选 interaction/initiative，Jev Key 未配、402、网络/格式/低置信度转 DeepSeek Flash 不思考判断；复用普通回合 −2/−15 自然降温、加分枚举、0/100 切换。沉浸 Prompt 加载相同形态提示和轻量自主开玩笑机会，小说视角规则不变；实际可见回复经 Jev→DeepSeek 判断其自身玩闹，最终回复成功提交后才加自主分。沉浸 UI 读取相同气焰、共享玻璃管与手动互动，并以相同 qForm 选静态立绘；TTS 每次播放继续从同一状态读形态，不复制音调设置。草稿重试不重复结算用户回合；用户确认截断回复时按 none 完结临时回合。
- 工具历史：工具的 user-facing displayText 之前只通过运行时 callback 显示，`agent_tool_outcomes` 只保存调用次数／状态／时间，因此对话结束或悬浮窗刷新后丢失可读细节。现在用 200 条有界独立设置记录实际已展示的 displayText（每项至多 800 字），仍保留原有脱敏 Outcome 表；普通聊天从真结果读取并显示灰色高透明工具面板，悬浮窗也随消息加载并可展开查看。只写用户可见短文，不记录 promptData、工具参数、模型思考、密钥或诊断正文。沉浸房间没有 Agent 工具执行链，继续保留其工具权限边界；不能伪造不存在的工具调用，后续若单独授权为房间接入工具，必须先按总账唯一 continuation owner 设计调用/停止/存档。
- TTS 双档性能对照后续单独做，不在本批动已经恢复的发声链。先保持 +255 的自动核亲和运行、单个「试听发声」、轻量状态与原子诊断；未来对照在同一用户真实回复／音色／语言／分段上明确手动启动，串行无声生成两个档位，分别冷启动并记录核、PSS/RTF、每片段计时、子进程绑定/死亡和缺段；只在同批、两档都有效时比较，不在模型未就绪或播放失败时给出胜出档。另存最近两轮**真实播放**（不同形态）速度，用户可直接区分听感与纯推理测速。前次双档测速改动后真机出现子进程连接超时、资源未就绪、原生空指针；+255 回退到此前音频运行链后用户确认可发声。诊断只能证明故障与新增测试链共时，**没有证明**是哪行代码引发原生异常；下次须沿独立最小探针和真机栈定位，不靠恢复已撤的双档按钮猜测。保护固定签名、资源校验、媒体音量流和存档键。
- 预期验证：停止前后气焰、已提交后 Stop 不回滚、手动形态动作不被旧回合覆盖；跨普通／沉浸连续涨跌和 UI 立绘一致；无 Jev Key／402 的 DeepSeek 兜底；工具活动实文在普通和悬浮窗完结、重开后仍能展开；TTS 现有真人发声不回归。当前 `CI PASSED / APK READY / TRUE DEVICE PENDING`：Actions run `36041874888` 完整通过 125 项源码门、Kotlin 测试、Flutter analyze 与全量 tests、Release APK、固定签名、Genie/桌宠/塔罗资源核对；功能 head `84ec9af1dd4df93bb4b36b46d03d2fe794aadfe3`，tree `0226ce2225d28c9aead68855b4bcda69e31d46cc`；Artifact `10827521660`；未公开 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d0809bb1e451a9b07625`；APK SHA-256 `be0d5f7a40f8ae5c5dd610e4a80d62fec9c1d4bdf25e5130b5908eda7b8b47bf`。真机仍需逐项核对：停止前后热量、跨房间立绘与数值、Jev 失败后的 DeepSeek、工具实文完结与重开、现有 TTS 真人发声；CI 不视为真机验收。

## v0.42.14+258 · 可回看的规划过程与本地命运之轮（2026-09-25，开工登记）

- 证据：+257 已持久化工具的 user-facing displayText，但截图中的 `THINKING` 是 DeepSeek `reasoning_content` 的实时流，工具运行状态是另一条链。`generateInternal` 会向界面转发规划推理，最终消息却只保存最后一次 `generated.reasoning`；跨规划回合的真实可见推理在提交后丢失。普通聊天已有 ReasoningPanel，悬浮窗有独立渲染。双模型模式会抑制内部规划推理的实时转发。用户明确要求两边可看到并在完成后回看实际呈现的内容，不以“工具活动”短文代替。
- 上游冻结：`https://github.com/29-Cu/Ruota-della-Fortuna`，commit `8d62036de5c3e0cdb18ac082c77a7051b55ce43a`，MIT；独立页面 `index.html` 内嵌 DIMS 与 `src/tags.json` 内容一致，7 维共 502 标签（其中 GORE 62，初始锁定）；独立 `Math.random()` 等概率选中每个启用维度并支持单列重抽。CSS/SVG/Web Audio 实现暗金机器、灯框、卷轴、拉杆与结果卡。用户要求保留这些视觉与动效，以本地 Flutter 重建而非 WebView/服务端/MCP。
- 产品合同：抽取是完全虚拟的幻想装置。用户在轮盘界面确认最终结果后才绑定新沉浸房间；结构化结果与上游版本持久化，给模型的房间提示只列选中标签与虚构规则，允许超现实混搭、分幕展现，不要求现实物理一致，也不把未输入的用户动作、台词、同意或态度写成事实。房间之外的记忆、AI Self 与自主 Agent 不因结果改变；后续房内重抽沿同一 Outcome 扩展，首版不另建循环。
- 保护边界：不增加模型调用或改变 DeepSeek 内部/Gemini 最终回复计费链；存储给用户实际可见的推理，但不得泄露私密 Prompt/密钥或将过程注入模型历史/公开诊断；失败与 Stop 不伪造成完成结果；不改 TTS、Cedar 游戏规则、形态温度、Live2D、`main`、正式 Release 或用户旧房间。保留上游 MIT 声明并审核字体许可。
- 验证门：单/双模型的规划流、工具 Outcome、最终回复三段显示与重开后回看；Stop、崩溃恢复、重复轮次不乱序；轮盘多维启停、均匀取样与单列重抽、默认 GORE 锁、确认前无房间注入、确认后房间隔离、进退场、备份恢复；Flutter analyze/tests、仓库 validator、Android release、固定签名与 APK 真机外观/动画验收。当前仅开工，`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 实现（本地，未完成 CI）：`VisibleReasoningTranscript` 按完成的规划回合和最终回复收集真实 provider reasoning，内部 DeepSeek 规划在单/双模型中均实时展示并 checkpoint，提交后沿现有 `reasoning_content` 在普通聊天与悬浮窗回看。历史提示构造不重放 reasoning；工具 Outcome 仍使用独立的 +257 附件。Gemini 最终仅显示被接受的 reasoning。
- 轮盘（本地，未完成 CI）：复制上游 `src/tags.json` 502 条、LICENSE/NOTICE；纯 Flutter 灯箱、暗金机身、七轮停靠、拉杆、单轮重抽和 GORE 解锁确认；只有确认抽签再填写房间表单后才创建房间。JSON 中保存源 revision 和选中维度/标签于房间 `entry_context`，房间顶部可回看；系统背景将其解释成幻想装置的创作素材，允许超现实搭配，不伪造用户行动或同意。不新增模型调用、独立循环或 schema。原创字体和网页音频未移植，待真机对照视觉精度。
- 本地验证：`git diff --check`、JSON 内容计数（7 维 / 502 标签 / 单一 GORE 锁）通过；125 项校验清单结构通过，前 24 项通过后因稀疏检出缺少仓库原有 `dafeiyu_reference.webp` 而停止，不是功能失败。Flutter SDK 不在本地，需完整检出的 CI 执行 analyze、test、release APK。`CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 远端验证（2026-09-25）：功能 tree `6efaa1d699cc73f92b9108f1e220e990db2f17e8`，GitHub head `001c3cf43883032b47ce0224259777c15ce45c27`；Actions `36094383066` 全绿，125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、固定签名/资源核验全部通过。Artifact `10846946684`（14 天），APK SHA-256 `3fab6379553866a1bc3a4b61a5fde1b0a6dbcd1cfe450d8eb149e0e63d720efa`；signer `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-478e1a10f9514d22b372`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真实设备尚未校验轮盘像素/手感、普通聊天与悬浮窗跨回合过程显示以及房间续写。

## v0.42.15+259 · 原版命运之轮视觉回归（2026-09-25，开工登记）

- 用户截图证据：网页为完整黑金主题、Rye 装饰字发光招牌、七轮三行窗口同屏、四边动态跑马灯、独立 GORE 翻盖、圆形 SPIN/竖向拉杆、自定义标签和搜索。+258 的 Flutter 仿制版用了紫色横向滚动单行标签轮、扁平滤镜片和小拉杆，关键比例与动效均不一致。先前回答“能够按原样画出”未兑现，用户质疑后明确选择直接复用原页面外观代码。
- 本轮目标：本地离线嵌入原版冻结提交 `8d62036de5c3e0cdb18ac082c77a7051b55ce43a` 的 HTML/CSS/JS；只加入可见的“确认结果并创建沉浸房间”入口和安全数据桥。保留原有灯框、卷轴、停靠动效、拉杆、GORE 翻盖、Add Tag、Search、History，并让页面字体可离线使用。轮盘仍不运行 Agent/模型或外部服务器，房间只读取用户确认的有限字段；从 +258 沿用结构化房间设定，不动聊天 THINKING、TTS、Cedar 或 schema 61。
- 验证路径：原网页代码与打包页面的差异限于离线字体、App 结果桥与作者署名链接；检验桥消息格式、维度/标签匹配、确认前不创建房间、WebView 外部导航隔离及持久化。Flutter analyze/tests、125 项验证、APK 签名和上机视觉/动效仍各自区分；远端结果见下。
- 用户同轮补充：沉浸房间页面底部必须和普通聊天一样展示“她／聊天／更多”三个导航按钮，并让这些按钮能真正回主界面相应标签；输入框左侧增加“推进”按钮，单击只令现有剧情自然推进一个节拍，不生成固定台词、不记录为用户扮演的动作或许可。实现需使用已有沉浸房间请求、Stop 与独立现场账，不开第二续写循环；按钮引发的控制事件需在时间线与模型提示中与用户原话区分，不能更新用户身体互动的气焰值。
- 本地实现：打包 `index.html` 原始机台和 3 款 OFL 字体，WebView 只加载本地页面并将确认后的选中标签通过受限桥传回 Flutter；允许原作者署名链接由 Android 浏览器打开。普通聊天与房间大厅、房间内共用相同底部 NavigationBar，离开活动房间按原有流程暂停。推进作为保存在时间线的房间控制事件送入现有生成链，跳过用户肢体捕获、用户轮人格判断和用户自主行为推断，停止的控制事件不显示为用户消息；下一轮模型历史明确标注该操作不代表用户发言或同意。
- 远端验证（2026-09-25）：功能 tree `18b856e14a573a844bc6a3f1afef1b655997b1f1`；GitHub 功能 head `d580ed694ef9ae75017e1c231d95eb59033d0fd1`；Actions `36105651518` 全绿：源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名、既有资源核验均通过。Artifact `10851237002`（14 天）；APK SHA-256 `a2316fa38b323ec725323186d32df019e0cda914a0649c130cc835f9a4ce4fac`，签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c2d726ee49c01198c248`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机端仍需确认原版轮盘的像素与动画、WebView 本地标签存储、导航跳转、推进生成质量。

## v0.42.16+260 · 房间导航、思考分段翻译和轮盘振动（2026-09-25，开工登记）

- 用户决定：沉浸房间底部中间显示“房间”且选中后不用重新导航，左右两端仍能去主界面；去掉人工添加的“【规划 N】”标题，仅展示 DeepSeek 实际返回的过程文本；翻译应分别判定规划和“【最终回复】”的英文比例，仅翻译英文占优的段落。确认在线轮盘已在每轮停靠调用 `navigator.vibrate(18)`，Android manifest 缺失 `VIBRATE` 权限。
- 现有账本与代码证据：+258 之前就有“DeepSeek 工具规划，无工具后再由第二通道回复”，+258 只是把已有规划过程显示出来；只要 Cedar 已配置，旧 `cedarStageToolIds()` 对任何普通聊天均返回 `gatewayToolIds`，为零游玩需求的闲聊附加游戏厅工具，导致备份末轮零工具仍先调用 DeepSeek。修复此确定性门：仅本轮游玩意图、共玩待接续，或本轮确有 Cedar Outcome 时暴露游戏厅工具；其余按现有相关工具路由，不加额外 Jev 网络请求。
- 实施与验证：在新功能分支补齐 Android 振动权限、导航选中行为及文案；只清除新消息上人工规划编号并兼容旧存档文本；规划英文占多时翻译完整思考链，否则最终回复英文占多时只翻译最终回复，保留原文与整个记录的缓存身份。保留原网页动画与逐轮 `buzz(18)`，不凭模拟器/CI 声称已证明真机手感或帧数；完整 CI 构建可供实机核对。schema 61 与备份协议不变；不合并 `main`、不发布正式 Release。
- Jev 专节（2026-09-25 的源码与官方文档核对）：现有 `JevDecisionGateway` 在 OpenRouter Decisions API 发送最小 `state` 和多个独立 Choice，验证答案/信心后使用，否则调用原 DeepSeek Flash；`PlayfulTurnJudge`、`ImmersiveNsfwRouter` 已实装，不复用聊天完成接口。官方 Jev 是结构化决策而非生成文本，Choice／Score／Noul 可在同一请求中并列短问题；官方强调各问题聚焦一个判定，复杂权衡拆问、由代码组合。适合对话意图分类、闭集工具候选/场景路由、主动消息是否适时、情绪或房间事件评分（需验证本项目真值）；不适合继续剧情、生成答复、核验 Cedar 合法动作/真实 Outcome 或单纯读设置/计数。置信度是分布集中程度，不代表具体场景正确率；每项新增任务须有独立标注样本阈值、误判代价、脱敏用量、费用和延迟对照，且 **DeepSeek 为任何 Jev 失败/不确定的必经兜底**。本轮游戏厅误开启是明确布尔条件，直接在代码中修复；若后续希望让 Jev 负责模糊的“是否值得进入 DeepSeek 工具规划”，先在影子对照验证对自然游玩、联网和记忆请求的漏判，再在启用时落地 DeepSeek 兜底，不能用一个低信心的“闲聊”吞掉真实工具意图。官方出处：https://docs.typesafe.ai/introduction 、https://docs.typesafe.ai/api 、https://openrouter.ai/typesafe/jev-1.13/ ；本项目现有路线详情参看上文 §6.25。
- 本地实现：中间导航“房间”和门图标，选中中间项不离开房间；新消息与流式规划不再添加编号；翻译遵循用户两级判定并支持旧存档；仅游戏请求/待续共玩/实际 Cedar Outcome 暴露游戏厅工具，普通闲聊已配置 Cedar 时不触发 DeepSeek 规划；Android manifest 补齐 `VIBRATE` 供网页现有每轮停靠震动调用。新增独立翻译分支与 Cedar 空工具门回归测试。
- 本地验证：总账交接校验、Agent v2、图像可靠性、主观搜索回归和 `git diff --check` 已通过；第一次 Actions `36117923678` 在旧 +219 静态契约校验第 99/125 项失败：它硬编码要求 `cedarStageToolIds()` 直接引用旧的常驻 gateway/engaged 字样，与本轮修复冲突；更新检查为实际 `toolIdsForUserTurn` 行为和回归测试后重跑。Flutter analyze/test 与 Android APK 交由完整远端 CI；原网页视觉、动画帧率、振动强度仍需真机。
- 远端验证（2026-09-25）：功能 tree `3ad68dd178bd6d474bb534038ecf829bd2ef426b`，远端构建 head `156743912284dd896434857ce46f32e8cc6364f5`；Actions `36118441665` 全绿：125 项源码校验、Kotlin 测试、Flutter analyze/test、release APK、签名和资源核验均通过。Artifact `10856307246`（14 天）；APK SHA-256 `607a2d1c84546b0f2364e47f8db1e049f77c1ed8908778fdbc9f01ac5088fb8f`；签名指纹 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。未发布 Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c92a839f0ea079a1b17c`。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`；手机仍需检查逐轮震动、动画流畅度、翻译分段和真实零工具回合的用量变化。

## v0.42.17+261 · 满气焰触发与命运之轮细节（2026-09-25）

- 双形态：本体自然达到 100 时只蓄势，下一次真实用户消息是一次触发判断机会。Jev 阅读最近 3～5 轮和本轮消息，按最新互动是否让她明显绷不住选“触发／等待”；Jev 不可用、不确定或失败时 DeepSeek Flash 同题兜底，两者均失败不消耗机会。触发时先更新共享状态和角色提示，再生成回复；若否，这轮保持满值，其后正常衰减。严肃求助不能作为触发。弹额头仍直接变身，安抚、锁定与手动按钮不变；小豆丁只有 0 自动还原。普通聊天与沉浸共用状态，Stop 回滚蓄势与形态。
- 视觉：真实切换到小豆丁时立绘跳两下，不加烟雾。命运之轮 WebView 关闭 Android 边缘拉伸和可见滚动条，仍可正常上下滚动；网页默认声音开启，在首次手势音效时创建 Web Audio；跨卷轴重复 tick 限速，跑马灯仅更新实际变动的灯泡，保留原机台外观与逐轮振动。帧率改善需同机对照网页和 APK 验证。
- 验证：状态和 Jev/DeepSeek 兜底专项测试、JS 语法、总账门、Flutter Analyze/Test 与 Android Release 已由 Actions `36138316955` 全绿确认；真机观察普通／沉浸跨房间、Stop、锁定、双跳、声音、拖动边缘及帧数。状态 `CI PASSED / APK READY / TRUE DEVICE PENDING`。
- 构建交付：GitHub 构建提交 `3a9fd3091970ba132e9261575f212f709ee32613`，内容树 `66eb5939a2cc3bd013b508ebc24998587dd71bf6` 与本地提交 `d85d2f5` 完全一致；Artifact `10866132151`（14 天），Draft Release `396618220`，APK asset `588394207`，大小 `546205928` bytes，SHA-256 `2d5ccfc8d3508c093b11c60759cf12c9e46e07e128b1ccbf7ef23c997e21c4a7`。草稿页 `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d10092c51d058bdfdfb3`；未发布正式 Release。

## v0.42.18+262 · 主动聊天最终通道、满气焰持续判断、轮盘虚拟卷轴（2026-09-26）

- 用户澄清：自然升到 100 的当轮不判断；至少短暂保持一轮 100。此后只要本体仍在 100，每条真实用户消息都可让 Jev 判断突破，Jev 不确定或失败时 DeepSeek 兜底；判断“等待”不直接扣到 85。持续互相玩闹把数值维持 100，就应继续判断；一旦普通交流实际降到 100 以下才停止。旧存档若在 100、非小豆丁且 `breakthroughReady=false`，下轮也要恢复判断。突破语义提示暂不放宽，先真机观察。
- 2026-09-26 01:39 用户备份与脱敏诊断证据：最后状态 `heat=100/qForm=false/breakthroughReady=false`；此前约 01:31“晚安”一轮有唯一一次 Jev `playful_breakthrough` 用量，此后数轮打趣没有再次调用，因旧代码把第一次等待当成永久用尽机会。当前数据库状态不外传、私密正文不进公开诊断。
- 主动聊天：仅此回复路径在双模型设置下将现有内在状态、已选来源、真实 Outcome、时间和语境合并后一次交 Gemini 写可见正文；DeepSeek/Jev 仍负责已有内部短判断、维护与工具。Gemini 缺 Key、网络/格式错误或中途截断时用 DeepSeek Flash 自然生成；事实校验需重答时只由 DeepSeek 纠正，不第二次向按次计费的通道请求。保存最终实际生成模型和其真实 reasoning，英语摘要不再丢弃，沿普通聊天的思考链翻译入口按需翻译；没有独立 DeepSeek 规划回合时不伪造规划思考链。单 DeepSeek 设置保持原流。
- 轮盘：真机反馈 APK 明显掉帧、手机浏览器原版较顺畅；本地代码的每卷轴按标签集复制至少八份，七卷轴合计产生很长的运动 DOM/合成层，同时 SVG 灯带逐帧动画滤镜、机台灯频繁切换发光阴影。改为每卷轴固定五个可见/预备 cell，按跨行更新文字，仅对短 strip 做 transform；停止中心仍与抽签结果对应，保留文字/灯箱、拉杆、单列重抽、默认音效和每列停靠振动。移除卷轴运动 blur 与灯带逐帧滤镜脉动，把跑马灯运动更新从 55ms 降为 95ms。此为源码判断，不声称已证明特定 Android WebView 的 GPU 瓶颈或真机帧率收益。
- 验证：`git diff --check` 和打包 JS 语法通过；Node 卷轴运动探针按 1、2、7、50、90 个标签核对五格 DOM 数量和停止中心选中值。仓库 125 项验证在稀疏检出下第 27 项因未检出 417 件桌宠旧素材停止，前 26 项通过；本机无 Flutter SDK，Flutter analyze/test 和 release APK 待完整 CI。schema 61、备份协议、普通/悬浮/沉浸正文、Cedar 游戏房间、TTS、Live2D 不变。状态 `IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 首次完整 Actions `36171693729` 在第 86/125 项遇到旧 +209 静态断言（主动引擎不得读取第二通道 Key），它与本轮明确的新路由相矛盾；前 85 项通过。把该断言改为检查 DeepSeek 内部 Key、双模型开关、Gemini 只尝试一次以及 DeepSeek 兜底，本地单项通过，待完整重跑；不是实际 Flutter 编译错误。
- 最终远端 head `3aa281d25bbc50ba174c2b145d5e08b6423127a2`；Actions `36173105843` 源码回归、Kotlin、Flutter analyze/test、release APK、签名和资源核验全部通过，Draft Release 上传成功。Artifact `10880534317`，APK SHA-256 `7d869d4d678cd82d9dddeb3f1624658c9633a48fbe5e91aeab4f532a384cc083`；Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-454347b060d2df3185c9`。上一轮 Actions `36172168049` 因修正发布名称的新提交而取消，不能当成测试失败。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；待真机观察满气焰连续判断与自然变身、主动正文模型及思考翻译、命运之轮帧率和停靠/振动。
- +262 真机回报（2026-09-26）：七列卷轴优化明确生效，视觉无明显损失；自然变身测试未见问题。变身标记 `TRUE DEVICE PASSED`，卷轴视觉与性能改善已确认，但流畅度仍待进一步验证。页面下方点击搜索/自定义标签输入框时输入法弹出仍慢，尚无逐帧数据；本轮只读核查：Android Activity `adjustResize`、Flutter Scaffold 默认随键盘缩小 WebView，HTML 同时使用 `100vh`、固定背景/全屏暗角和常驻灯光，可能让键盘动画期间反复布局与绘制；搜索框空值 focus 不执行标签搜索。后续若值得优化，先分别测系统键盘启动与 WebView 视口变化，优先试焦点期间暂停跑马灯/灯带及减少固定背景重绘；不得直接全局关闭 `adjustResize` 以免下方输入框被键盘遮住。主动聊天 Gemini 正文与思考翻译仍待真机确认。
- +262 后续真机澄清（2026-09-26）：用户观察到慢的是系统输入法从底部上滑的动画，轮盘页面在同一时刻帧数较高；不得把该现象直接判作网页掉帧或焦点搜索开销。打包轮盘 HTML 无 canvas/独立粒子系统；可见动态光效是 44 个边框灯泡、SVG 标题灯带和少量 CSS 发光/脉动。删除所谓“粒子”不构成明确优化点。下次若处理键盘，须分别测 IME 动画、WebView 平台视图合成与页面重排；优先做受控对照，不凭推断改全局输入法或删掉外观。
- +262 再次真机澄清（2026-09-26）：同一网页在手机浏览器里卷轴与输入法动画都非常流畅；App 内卷轴虽明显提升、外观无损，仍远未达到流畅，输入法展开持续而明显变慢（展开途中可使用），属于性能 `PARTIAL / NEEDS INVESTIGATION`，不能把上面的“卷轴已优化”误记为完全真机验收。源码确认为原 HTML 经离线字体/结果桥和卷轴虚拟化改造后由 Flutter `WebViewWidget` 加载，Android 硬件加速开启，未设置页面帧率上限；插件默认 Texture Layer Hybrid Composition（WebView 渲染到纹理再交 Flutter 合成），与浏览器直接显示存在明确架构差异。键盘期间 `adjustResize` 和默认 Scaffold 缩放整个 WebView；持续变慢而不冻结说明需要记录真实 IME 动画时长与各层帧时，不能只凭视觉归为页面掉帧。后续先对照同一 APK 内原生 Android WebView / 当前 Flutter WebView，再在隔离测试包比较插件的 Hybrid Composition 与当前纹理模式；测量 JS rAF、WebView/Flutter 帧时、输入法开始到结束的时长。不要先删光效或切全局输入法模式。变身真机测试仍无问题；主动 Gemini 回复待测。

## v0.42.19+263 · 同页原生 WebView 性能对照（2026-09-26）

- 开工依据：用户同机对照发现浏览器原 HTML 卷轴及输入法均流畅，App 内经 +262 虚拟卷轴改善仍未流畅，IME 展开持续但显著变慢；允许试用另一种 HTML 承载方式。优先检验 Flutter 平台视图合成这一具体差异，不先删特效、关闭键盘调整或重写轮盘。保护边界：保留现有 Flutter WebView 作为基线；原生路径加载同一打包 HTML 与字体、沿用原 JS 确认协议及 Dart 的七维校验；返回现有模式不丢当前结果，未确认不建房；不改普通/沉浸聊天、模型、TTS、人物或备份。
- 实现：轮盘 AppBar 增加“原生对照”，开启独立 Android Activity 的 WebView；原生顶部返回可回到当前 Flutter 版，确认抽签后经专用 MethodChannel 返回原 Dart `FateWheelResult.fromBridgeMessage` 校验再建房。两条路径使用相同 `file:///android_asset/flutter_assets/assets/fate_wheel/index.html`；原生禁用越界反馈/滚动条并保持 `adjustResize`，只许可本地页面导航，外部署名用系统浏览器。以隔离对照为主，不凭代码声称流畅度已提升。
- 验证计划：本地源码范围、JS 和总账门；完整 CI 的 Kotlin/Flutter 分析、测试、APK 签名与资源校验；真机分别测旧入口和原生对照的转轮顺滑、输入法完整展开耗时、搜索/自定义标签、静音、单列重抽、确认入房与返回。若原生显著更顺，再讨论设为默认；若两者都慢，检查 WebView Provider 和页面本身。
- 构建结果：本地提交 `50b860c`，远端同一 tree `45e40af287ba1554c5004bcfd0d51c7859f6e526` 的提交 `9cff7c2845a1c04379dd8adfc48e07a1c2512c2b`；完整 Actions `36181810605` 的 125 项源码检查、Kotlin 测试、Flutter analyze/test、Release APK、签名与资源校验全部通过，Draft Release 上传成功。Artifact `10884699335`；APK SHA-256 `8976dd8be4443325f4148c230686ba5d4ea05a273794062ff8bef70f179780b2`；Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-405b62659a85f46c2693`。本地 125 项前 26 项通过，第 27 项因稀疏检出缺少既有 417 件桌宠资源停止，CI 在恢复完整资源后全部通过。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；仍需真机确认原生页面实际性能与键盘动画、确认入房及返回。

## v0.42.20+264 · 原生轮盘默认化与历史记录展开（2026-09-26）

- 真机依据：用户安装 +263 后确认原生对照明显更顺，输入法展开恢复正常；指定将原生路径设为默认、删除旧 Flutter WebView 对照和顶部返回/对照栏（手机返回键退出），历史记录默认展开。+263 的源码/CI/APK 通过；其原生转轮与键盘性能标记 `TRUE DEVICE PASSED`，确认建房/全部边缘操作仍待本批复验。
- 范围与保护：沉浸大厅入口直接开启独立 Android WebView；同一打包 HTML、标签、音效、单列重抽、JS 确认协议及 Dart 结果校验不变；取消返回只返回大厅且不建房。删除旧 `FateWheelPage`、其 Flutter 插件依赖与对照顶部栏；不修改全局 IME 模式、其他 WebView（若有）、人物/模型/TTS/游戏。网页历史记录初始面板与箭头为展开状态，仍可手动折叠/清空。
- 验证：核对唯一入口/无旧 WebView 引用、HTML 历史展开标记与校验桥；CI 源码、Kotlin、Flutter、APK 签名与资源核验；真机检查全屏顶部、安全区、返回键、历史记录、确认建房与原生性能。
- 构建结果：本地提交 `4793129`，远端同一 tree `0e36ee794d1f15596797e4ad75aa579470af657d` 的提交 `d6b46d0c5c8b07c66ab4dc801ad7f1eb3b4ce1cf`；Actions `36186064758` 的 125 项源码检查、Kotlin 测试、Flutter analyze/test、Release APK、签名及资源校验全部通过。Draft Release `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b0f4bd22f8a953143130`；Artifact `10886706105`；APK SHA-256 `3d9ed89b830798c6226796c3be227819f67a2f9e4de3df6534ca064f82f1fa71`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；待真机核对顶部无额外栏、返回键、历史初始展开及确认建房，+263 已通过的原生性能仍需确认无回归。本地稀疏检出缺旧桌宠素材使全套检查停在第 27 项，CI 恢复资源后全套通过。
- +264 真机回填（2026-09-26）：用户安装最新版后反馈“没问题了”“没有在真机里发现大问题”，承接上一轮针对默认原生入口、顶部栏、系统返回和历史默认展开的验收请求。将这些外观/导航小项以及原生性能、输入法无回归标为**用户报告通过**；不把概括性反馈扩展为确认建房、搜索/自定义标签、音效/振动、备份恢复的逐项通过。后者自然使用时顺带观察，不阻塞下一任务。最近可见脱敏诊断属于 `v0.42.17+261`，早于 +264，不用于证明新版；+262 自然变身真机已通过，主动消息 Gemini 最终通道及思考翻译仍无单独新证据。整体 `TRUE DEVICE PARTIAL PASS`。
- 下一任务方向修订：曾在隔离的 `agent/v04221-real-reminder` 上短暂推送 `+265` 相对时间提醒实验，用户提出日历手写方案并要求回退。已将本地应用代码复位到 +264，远端实验分支撤回至 +264 内容，不把该实验 APK 作为候选。日历全天事项如何自然参与当天话题，以及到点强提醒的系统通知/闹钟式呈现，继续讨论后再实施；禁止从旧相对时间原型直接续写。

## v0.42.21+265 · 手写日历提醒与模拟手机自然记录（2026-09-26，开工登记）

- 用户决定：日历条目只保存在伴侣本机；“今天”、日期、闰年和时区使用手机系统本地时间，不读取或修改系统日历。入口位于左侧栏“她现在的状态”下面。纯日期可在当天自然提起；日期加时间的提醒到点独立响铃、可振动，手动关闭或五分钟自动停止；停止后按事件生成一次不占每日主动次数的真实对话。提醒的现有相对时间语句实验已撤回，不续写。
- 同批内容：记忆库全文搜索；心情与塔罗“她的解释”从已有真实状态/牌面生成第一人称短评，避免固定套句；愿望单和日记新增与相册/随笔一致的已更新红点；核查随笔 2026-09-14 后每日约一条。愿望单生成与自主相册来源本批不改，相册候选网站未来另议。
- 已定位随笔真实结构问题：`noteDailyLimit=6` 且六个时段存在，但 `_refreshNotes` 把整个 `DailyContinuityRecord.id` 当唯一已使用源。通常每日只结算一份 continuity，生成一条后其余真实子事项被一并排除；本批改为不同事项独立去重，保留最多六条、近期重复拦截与失败不强塞固定文案。
- 实施保护：响铃与模型生成解耦；停止事件幂等，生成失败保留待处理记录供后续重试，不伪称已送达；重启/升级、时区变化从本机条目恢复。原生 Android 通知与精确定时权限以真实设备授权为准，CI 不等于真机验收。
- 实现：左侧栏“她现在的状态”下新增手写日历；日期/每年重复/全天或定时由用户直接编辑，按系统本地日期与时区计算，全天条目作为当天主动对话的可选资料。定时条目保存至 SQLite 并镜像到 Android AlarmManager，系统精确闹钟权限可由页面打开；若未授予则使用可能延迟的系统调度。前台服务以闹钟音频通道循环播放、振动，通知与锁屏全屏入口均有手动停止，服务和独立 timeout 兜底最长五分钟。可在日历页打开系统“日历响铃提醒”通知通道设置音色。停止事件先存本地待处理，后台脑/前台聊天按同一 lease 和确定性消息 ID 生成一次事项对话，完成后才确认；不写入主动次数的 `proactive_history`。
- 模拟手机：愿望单新增或内容/完成状态更新、日记新增时按“已看”时间显示红点；不改愿望来源筛选。心情以当下欲望、情绪片段与日常真实摘要生成第一人称短评；塔罗的两张当日牌以牌义生成各自第一人称“她的解释”，旧固定解释在当天迁移时移除。生成失败不使用旧套句伪装自然表达。随笔按 continuity 中的具体事项独立使用，保持六个时段、每天最多六条及重复质量门；实际条数取决于真实可用素材。记忆库搜索在状态/类别筛选内查内容、标签和事实键。
- 验证：首轮 Actions `36213477925` 在 125 项中的第 24 项停于旧总账门只接受 `+264` 版本，前 23 项已通过；已扩展该门的目标版本，本地至第 24 项通过，之后本地缺稀疏检出的旧桌宠/相册资源。第二轮构建提交 `aad9786124e6bc619ee15acb0a55f8a0489fd46b`，tree `d79c05b1003776997435e9df24ee3161b050414b`；Actions `36213673166` 的 125 项源码回归、Kotlin 测试、Flutter analyze/test、Release APK、签名与资源核验全部通过。Artifact `10896772812`（14 天）；未发布 Draft Release `397052898`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-093807583d5693f8eb90`；APK asset `589821283`，大小 `546300815` bytes，SHA-256 `23b0be3ea95322bf89a27d22e9ce7e52da6d63ac42afa6d48410b230d9a2df7e`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。
- 真机待测：创建全天/定时/每年重复、系统精确闹钟权限与通知权限、锁屏/前台响铃及振动、手动停止和五分钟自动停止后的唯一主动消息、重启与时区变化的恢复；心情和塔罗短评、红点清除、不同日常素材下随笔多条与记忆搜索。CI 不能证明系统在具体设备上准点或全屏权限必定获批。联网相册来源仍留给下次讨论。
- 用户 2026-09-26 接班时明确决定“上一个窗口的真机测试默认成功，因为这些真机测试容易捕捉，有问题再说”。据此停止把 +265 整包作为待用户逐项验收的阻塞项；这不是对每个闹钟场景已实际复现的独立诊断证明，若日后反馈仍按具体场景排查。

## v0.42.22+266 · 代办提醒名称、节日与天气感知讨论（2026-09-26，开工登记）

- 目标：把新入口“日历提醒”的可见名称及相关通知文案统一为“代办提醒”；保留既有日期、重复、定时响铃、停止后一次对话、存储键/数据库及 AlarmManager 行为。节日与天气只形成可核验设计，桌宠/表情包等用户提供参考项目后再定实现范围。
- 证据：+265 APK 已交付；当前 UI 在左栏、页面、Android 通知和后续对话标题仍称“日历提醒”；MCP 客户端是 Streamable HTTP，现只专门接 Cedar，Android 15 尚无可直接用于天气的定位权限流程。
- 保护边界：不因改名迁移持久数据或闹钟渠道 ID；不把天气 MCP 工具返回当成设备传感器观察；不硬写固定节日问候/天气台词；内部事实和最终可见回复仍遵守 DeepSeek/第二通道现有分工。新感知若带自主触发，需先确定唯一 owner、Stop、缓存、去重和首版脱敏诊断。
- 本地实现：左栏、编辑页/空状态/提示、Android 响铃通知与通道展示名、停止后会话标题改称“代办提醒/代办事项”。保留 `CalendarReminder` 类/数据库与 AlarmManager/通知 channel ID；内部“今日手写日历事项”事实标签仍说明来源，生日等全年日期不被误称成待完成任务。改名不修改提醒内容与触发语义。
- 节日感知设计（讨论阶段）：由手机本地日期/时区推导当天节日候选，地区与历法由用户偏好/可核验来源决定；法定休假安排、农历公历转换、跨时区和每年浮动日期需具备年份与来源，不写死在角色规则里。作为有日期、地区、置信度和来源的短期环境事实进入现有 DeepSeek/最终回复链，是否提起由她自然判断；不得定点塞固定祝福、冒充用户庆祝或当天每轮重复。手写代办/生日属于用户事实，与公共节日分层。
- 天气感知设计（讨论阶段）：MCP 可以沿用现有 Streamable HTTP 客户端，但 Cedar 目前是专用协议入口，天气仍需独立只读适配器、工具/主动情境入口和来源核验。`cyanheads/open-meteo-mcp-server` 提供 Streamable HTTP 公共实例及自部署实现，实际取数来自 Open-Meteo；MCP 并不提高预报精度。首版建议用户手动选城市/区域或经明确授权的粗定位，记录 `place / source / valid_time / fetched_at / timezone / units / current_vs_forecast`；缓存和过期门避免旧预报被说成当下观察。温感使用体感温度与场景阈值，降雨区分当前估计、未来小时概率和雨量，不以概率声称已经下雨。日本地区若追求分钟级降雨，JMA 高频雷达临近预报是单独数据源与接入问题，不能把 Open-Meteo 的 15 分钟插值冒充雷达实时雨情。
- 雨量事实：Open-Meteo 的小时 `precipitation` 为此前一小时总量 mm，`precipitation_probability` 为此前一小时超过 0.1 mm 的概率；日本等非其原生 15 分钟模型覆盖区的 15 分钟值由小时插值。JMA 官方 1 km 降水临近预报最多 1 小时，每 5 分钟发布；这两类预测均不能承诺用户站位的必然降雨。准确率没有项目实地样本，暂不量化。
- 后续顺序：收到桌宠/表情包参考项目后先定点分析，与节日/天气接入方案合并排期；未获城市/区域与节日地区偏好时保持这些项目为设计，不默选用户所在地。天气 MCP 公共实例先做协议/可用性验证，再决定自部署或直接 API。自主天气提醒若启用，先登记唯一 owner、节流、Stop、去重与脱敏诊断。
- 本地核验：`git diff --check` 通过；用户可见旧名称已在 `app/lib` 和 Android 主源码逐项检索，剩余“日历”仅为内部事实来源标签。当前机器无 Dart/Flutter SDK，未进行 Flutter/Android 构建。本批尚未推送/触发 CI/交付 APK，状态 `NAME IMPLEMENTED LOCALLY / HOLIDAY-WEATHER DESIGNED / CI PENDING / APK PENDING`。
- 2026-09-26 用户追加本批目标：节日以中国传统节日为主，兼收圣诞节等知名国外节日；天气优先考虑用户已有和风天气 API；桌宠先试三段新待机动画与参考项目点击动画/果冻反馈，测试期间取消原有头/尾/身体分区点击，移动动画不动；表情包参考 `moonlin1213/cove-sticker-mcp`，先查“零 token 自动识图”是否成立再决定接入。
- 开工证据：参考桌宠 `MerZlin/dsh-pet-indesktop` 的 `shenshen/videos/random` 与 `click` 为 640×360 VP9 透明 WebM（10 秒/24 fps），Android 现有播放器读取 PNG 帧并要求动作注册，因此需有界转换和隔离测试开关。素材与代码 MIT，移植时保留作者与许可证。现有表情包系统以 ZIP/index 的 `tag/caption/keywords` 选图；Cove 的 `VisionConfig.enabled` 需配置图像模型、Endpoint 和密钥，自动标注 POST 图像至视觉模型。无模型时只有手动元数据/检索，并非免费自动看图。和风天气官方提供全球实时/小时天气，以及仅中国地区的两小时 5 分钟降水；优先复用用户自己的 API，地点、身份凭据与时效门仍需独立设计。
- 本批边界：节日只给日期事实，不移植参考项目固定祝福/定时刷屏；桌宠实验开关在测试 APK 默认开启、用户关闭即回原链，且不变更走路素材/移动物理。表情包没有无成本真实视觉理解可直接移植，本轮先评估，不接入独立 Python MCP/图库，不替换用户现有表情包。和风天气未提供当前 Key/Host/地点，不在公开仓写凭据，本轮给出取数方案而非伪造连接成功。
- 本地实现：`lunar 1.7.8`（MIT，无第三方依赖）按本机日期计算春节、元宵、清明、端午、七夕、中秋、重阳、腊八、除夕及常见公历节日（含圣诞）；仅在普通聊天/主动上下文提供当天事实，排除角色扮演和新网页话题隔离路径，绝不制造固定问候或额外主动调度。桌宠将参考仓 `2786c15` 的哼歌、伸懒腰、玩魔方和点击挥手四个透明 WebM 以 10 fps 采样成 400 个 300×300 静态 WebP（合计约 6.1 MB），保留 MIT/来源/转换说明；利用现有播放器注册仅供测试的四个非循环动作。桌宠选项“实验动画”默认打开，开启时新增三段待机候选、统一单击挥手并附短时阻尼果冻缩放；关闭恢复旧点击分区与旧待机候选。拖动、双击菜单、移动动画、睡眠/语义高优先级仍走原链。
- 本地验证：FFmpeg 确认原片 VP9/alpha、每段 10 秒；所有 400 个生成帧可解码、300×300 且命名 000～099；Dart 农历包下载 SHA 与 `pubspec.lock` 一致，并核对 `Lunar.fromDate/getMonth/getDay/getJieQi` API；新增农历/圣诞事实和测试开关移动候选回归。`git diff --check` 已通过，Flutter/Android 编译仍待 Actions。Cove `vision.py` 的自动标注明确要求视觉模型与密钥、压缩图像会发送外部服务，因此不接入零 token 幻想；现有用户表情包 ZIP/index 与选择概率暂不改。
- 天气决定建议：用户已有和风天气 API，优先直接接其 REST，而不绕第三方 MCP。实况/小时预报可覆盖全球；`/v7/minutely/5m` 仅中国地区，未来两小时每五分钟的雨量 mm。下次接入前需要用户的可用 API Host/授权方式和天气地点选择；Key 只存本机私密设置。降雨只按 provider 的 `updateTime/fxTime` 表述“预报”，不拿外部实况说成实际接触雨水。
- 首轮 Actions `36219333507`：源码回归通过，Kotlin 编译在实验素材帧路径处报 `Unresolved reference 'padLeft'`；这是将 Dart 字符串方法误用于 Kotlin。已改为 Kotlin `padStart`，同版重跑完整构建，首轮 APK 未产生。
- 修复后功能 head `fef1bb8fb1ab6b7530a16ada0ce744064c43dcdd`、tree `177ea7732e1044e46f4e502ecc8c70cce5d101b9`；Actions `36228578087` 全绿（125 源码门、Kotlin 桌宠/桥接测试、Flutter analyze/test、release APK、签名与素材包核验）。Artifact `10902126662`；APK SHA-256 `8ae68d4ac60cf78488b2de4b1b23d156eb8b443b5fda6175d741ff617f799ac2`，大小 552551239 bytes；未发布 Draft Release `397094347`（tag `v0.42.22-holiday-pet-clip-test`）。真机实验尚待用户观察，桌宠除移动动画外的三待机与点击反馈可在“实验动画”中关闭恢复旧链。天气未接凭据、地点及接口，不将设计写成已接入；Cove 零 token 自动视觉标注不成立，本轮未移植。

## v0.42.23+267 · 桌宠新素材对齐、曲线与独立溢出显示（2026-09-26，开工登记）

- 用户真机反馈：+266 新素材能播放，但人物本体比旧桌宠小；点击动画进行时再次点击无反馈。用户先讨论后明确授权本轮只保留三个待机动画、补一段原项目站立动画与现有点击素材进行测试，不全量导入；新素材允许绘制在原窗口宽高之外，但原桌宠窗口仍是位置、贴边、物理和触摸的唯一几何真值。
- 实现目标：App 内双层半透明对齐原站立/新站立，人工调新组缩放、平移和提亮曲线；这组参数用于所有新动画，原桌宠不变。实验播放使用不接收触摸的附加显示层跟随原窗口，移动/贴边仍据原窗口。点击同一动作可重播并重触发果冻；三个待机与站立 224×224、4 fps，点击 240×240、6 fps；统一 1.5 倍速，保留实验开关和旧动作回退。
- 依据与验证：原 640×360 透明 VP9 固定中心裁切；七段样本的 224×224/质量 65/4 fps 帧包约为 +266 300×300/质量 78/10 fps 的 24%，3 fps 约 18%；本轮先取 4 fps 以保留人形辨识，点击用 6 fps。独立显示层必须在 attach、drag、投掷、自动移动、resize、配置变化、bringToFront、隐藏与 release 各路径同步/移除，绝不以扩宽原 WindowManager.LayoutParams 冒充溢出。曲线应只改变新素材 RGB，不改透明度或打包第二套帧。
- 保护边界：不加入其余 92 段动画、move/drag/balance；不改原移动帧、活动范围或触摸热区，不重构聊天/提醒/人格；schema 61、Snapshot protocol 6 和既有签名身份不变。本批先本地静态/素材核验再 Actions 全构建，完成后补 head/tree、CI/APK 和真机状态。
- 实现：四段实验待机（原三段和新站立）各 40 帧 224×224、4 fps；点击 60 帧 240×240、6 fps，按 1.5 倍速度播放；220 帧共 1,999,720 bytes，保留透明度和 MIT 归属。App 内“调整新动画 · 对齐与曲线”页叠加旧 `IDLE` 和半透明新站立，提供旧尺寸三档预览、新组统一缩放、X/Y 平移及 gamma 中间调曲线；参数保存至原桌宠设置，实验开关关闭即返回旧动作。新素材在独立不可触摸、跟随旧逻辑窗的 WindowManager 层播放，可溢出旧宽高；拖动、贴边、投掷、尺寸、可见性仍由旧窗口决定。为 Android 12+ 的透传触摸限制，新增层窗口 `alpha=0.79`；点击同一实验动作可以重新起播并重触发果冻，双击菜单语义保留。
- 验证：源视频 640×360 透明区域在 x=140～500 裁切内无截断；本地格式/帧数/体积与 `git diff --check` 通过。首轮 Actions `36232084731` 在第 24 个旧总账版本白名单停下；补 `+267` 后功能 head `07142df2f01f15b5e4770fb6d17b48150770f422`、tree `aa16c6405f87967191dcb5b99662c53302983c52`，Actions `36232295089` 的 125 项源码回归、Kotlin 桌宠测试、Flutter analyze/test、release APK、既有签名和包内 220 帧检查全部通过。Artifact `10903136887`（14 天）；APK SHA-256 `956812613c1fb00123e2ab2e6a3f5f3ccc1d320743c7bd6b866c4e0365b09ab2`，548,423,007 bytes；未发布 Draft Release `397169363`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-b3268e928cac05b343d3`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE FEEDBACK PENDING`。
- 后续观察：真机查看不同动画人物大小与脚底对齐、曲线亮度、超出旧范围的效果、贴边/拖动/熄屏时显示层清理，以及单击动画进行中再次单击的重播；若有问题按具体动画和场景反馈，继续保持实验可关闭。天气仍未接用户和风天气凭据与地点，本批无天气连接改动。

## v0.42.24+268 · 桌宠全帧、不透明播放与校准补项（2026-09-26，开工登记）

- 用户中途校准修正（待 CI/真机验证）：Photoshop RGB 输入色阶指定 `0 / 0.86 / 230`、输出 `0 / 255`，替换原单参数“提亮曲线”。App 内新增黑场、中间调和白场控制，默认采用该数值；逐像素对 RGB 应用输入色阶并保留原 alpha，饱和度仍独立可调。旧版保存的 gamma 不强制沿用到新色阶，以避免混用两种不同定义；缩放、位置和饱和度存档保持读取。此项已推送测试分支，仍待成功构建与真机确认。
- CI 失败路线：远端首次构建 `36235711293` 在工作流“Verify clean source baseline”因仍核对旧 `0.42.23+267` 而中止；改为 `0.42.24+268` 后，`36237371443` 进入 Kotlin 编译，暴露 `clip.durationMs` 可变属性不能智能转换及三处 Float 传入 `dp(Int)`。已分别固定局部时长与明确四舍五入，等待下一轮 CI 验证；不得将上述运行视为编译通过。
- CI 最终证据：分支提交 `45d030292f806c05050f540f76444471bade70ca` 的 Actions `36237804671` 完成且全绿；源码回归、Kotlin 桌宠测试、Flutter 静态检查与测试、release APK、签名、实验帧包校验均通过。测试 APK 为 `AI-Companion-v0.42.24-268-Opaque-Fullframe-Pet-APK.apk`（556153250 字节），上传到未发布测试 Release `v0.42.24-opaque-fullframe-pet-test`。色阶显示、全帧速度及外扩层透传触摸仍待真机验证；此条为构建证据，不代表真机通过。

- 用户反馈：+267 的“半透明”只应出现在 App 内双层站立对齐预览，不应作用于桌面新动画；还需独立变宽/变窄和饱和度校准。抽帧造成播放视觉不对，改为完整原片帧数，在像素尺寸与 WebP 质量上压缩，保留 1.5 倍速。
- 根因：+267 的新 WindowManager 显示层设置了 `alpha=0.79`，整段桌面播放的实际不透明度被降低；`PetSkinManifest.frameDuration` 对所有动作强制至少 70 ms/帧，完整 241 帧若不修此门，6.667 秒动作只能展示约前 95 帧。当前原片五段均为 24 fps，0～10 秒含末帧共 241 帧。
- 实现计划与边界：桌面实验层 `alpha=1`，仅校准页叠层维持 52% 新站立透明度；新增相对宽度 50%～150% 和饱和度 50%～200%，与统一缩放/位置/gamma 同组保存、原素材 RGB 变换保持 alpha。五段各保留 241 个透明 WebP（224×224，点击 240×240），按长度前缀封装并分成顺序小包，不移除动作帧；时间进度按 `elapsedMs * 241 / 6667` 定位，原桌宠低帧动作保留原有时钟。逻辑窗口和触摸范围仍由旧桌宠决定，附加显示窗口按校准后实际绘制边界收紧并跟随移动。Android 12+ 对 `FLAG_NOT_TOUCHABLE` 且全不透明的悬浮层会限制其覆盖范围内对其他 App 的透传触摸；本测试版优先纠正用户指定的不透明画面，并缩小新窗口范围，真机需重点检查人物外缘覆盖到 App 按钮时的触摸行为。若需要同时保证边缘完全不透明和跨 App 透传，须改用可信悬浮窗权限/实现再单独评估，不伪称当前已解决。
- 保护范围：三旧待机候选加站立、点击素材；不接其余动作、move/drag/balance，不改旧位移、贴边、点击热区、schema 61、Snapshot protocol 6 或已有签名。实验开关关闭仍走旧链。验证含五包每包 241 帧完整性、透明度/尺寸/总量、Kotlin 与 Flutter、release APK 内封包逐帧结构、签名及真机反馈。

## v0.42.25+269 · 桌宠 96 段完整动作与整轮气焰结算（2026-09-26，CI 完成）

- 来源与边界：用户上传的原始 `dsh-pet-indesktop-main.zip` 保存在未发布 Draft Release `397377805` 的 asset `591363139`，85,049,410 字节，SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`。只取 `random`、`click`、`sleep`、预览用思考等 96 段，排除 `move/drag/balance`；五段点击进入点击轮换，三段睡眠仅供预览，原睡眠链不动。删除自主思考动作，保留会话思考表现；自主动作打乱轮换，保留走路候选权重及连续静止限制。实验关闭可退回旧桌宠链。
- 实现：91 段新增 VP9 透明 WebM 连同五段既有实验片段构成 96 段、23,013 帧；GitHub Actions 从固定 Draft asset 下载、验 SHA，安装 ffmpeg 后转完整透明 WebP 并打包，按 1.5 倍时钟播放。运行时以有限 LRU 缓存帧包；点击有五段随机轮换；睡眠和思考预览不进入桌面自主动作。正式桌宠保持不透明，思考/说话装饰按尺寸贴合，预览页可滚动并按类别选片。校准新默认缩放 121%、宽度 93%、X=0、Y=-2dp、输入色阶 0/0.95/230、饱和度 110%；已有设备保存值不会被默认值覆盖。
- 气焰：用户分类暂存；可见助手回复落地时合并双方贡献、固定每轮 -18 与严肃话题额外 -12，再一次 clamp 0～100 和切换形态；Stop 撤回尚未完成的用户回合。普通 15+0+3-18→0；相互挑逗 15+30+3-18→30。手动互动、锁定与既有数据结构保留。
- 云端证据：功能分支 `agent/v04225-pet-full-clips-heat`，构建 head `b9f854e960bca401c861b769cda2576b79ef9d9c`、tree `74d27843c419da0e36e2de122fb092b0fa8129bf`；Actions `36271743353` 完成且结论 success。125 项源码回归、44 项 Kotlin 桌宠测试、Flutter analyze、Flutter tests、release APK、既有签名与包内素材校验通过；包内实核 96 段、23,013 帧、实验帧包 189,260,382 字节。Actions Artifact `10915967838`；APK `AI-Companion-v0.42.25-269-Full-Clips-Heat-APK.apk`，722,612,227 字节，SHA-256 `0830c3e6d36a9ac0d5b94628cf6fac9564e02d8d8d6d0b4ae784d7f8d2dd9453`。未发布测试 Draft Release `397385083`：`https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f66fe79c212e315b1d35`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机需看人物大小、脚底对齐、五种点击重播、随机动作和走路频率、三段睡眠预览、预览页面滚动、桌面不透明、外缘覆盖其他 App 时的透传触摸，以及 189 MB 新帧包对安装体积和运行内存的影响。当前并无真机通过证据，未合并 main，未发布正式 Release。
- 跨窗口素材维护：新增 91 段的原始 ZIP 只在受权限保护的 Draft Release `397377805`，Git 保存固定 asset ID、哈希、96 段目录和转换脚本，最终 APK 带有转换后的帧包。既有五段实验帧包在 Git；更早的桌宠本体 417 文件由仓库 `app/asset_packs/dafeiyu_private.parts/` 的分片及 `app/tools/restore_dafeiyu_asset_pack.py` 还原。新维护者只需读本节、清单和工作流，无需聊天上下文；要复现完整 APK，须能访问仓库及此草稿附件。删除或替换附件会使未来构建失败；草稿不是公开仓库代码的一部分，也不应把上游当前版本视为等价备份。


## v0.42.26+270 · 桌宠显示层与新版待机范围（2026-09-26，CI 完成）

- 真机证据：用户在新片段持续播放时关闭“实验动画”，片段没有立即结束，却瞬时由半透明变不透明；现代码开时用额外 `FLAG_NOT_TOUCHABLE` WindowManager 画面，关时用原主窗口画同一帧。色阶保留源 alpha。优先收敛到主窗口播放，避免新窗口合成差异；检查校准后边界，深度思考碎碎念源裁切可直接不入待机。
- 产品范围：改名“新版动画”且默认勾选；关闭使用旧版动作选择；打开只保留旧 IDLE/眨眼/散步/睡觉/拖放着陆晕眩/哈欠及对话思考、说话等基础动作。旧 GLANCE/HAPPY/SWEEPING/EATING 等自主表演不进新版待机；三段新睡觉与新版工作、思考短片加入随机待机，不能挤掉散步。正式对话仍由旧思考、说话动作负责。校准入口从悬浮菜单移到播放器预览首位；两页均适配系统栏和可滚动区域。
- Draft 整理证据：用户明确确认永久删除版本不高于 +265 的 AI Companion 旧测试 APK 草稿。人工删除 +265/+264/+263 三份；维护分支 `maintenance/cleanup-old-apk-drafts-20260927` 的 Actions `36275819669` 先干跑、`36275881299` 后删除 191 份，仅匹配带 APK 且附件都是 APK/SHA/TXT 的旧候选；两份无 APK 候选保留。+266～+269、桌宠源 Draft `397377805`、签名 `ai-companion-private-signing-v1` 与 Genie `genie-tts-private-runtime-v0.7.6-jiuhu`/`v0.6.4` 等输入未删除。构建工作流仍从上述 Draft 下载并校验，接班索引 +269 与上一节已写明。
- 验证门：Kotlin 动作选择/切换测试、源码门、Flutter 分析与测试、APK 内 96 段帧结构及签名；真机核对不透明/大小/边界/触摸、新旧切换、走路频率、睡眠/工作/思考待机和两页布局。

- 实现与验证：主桌宠 View 接管全部动画绘制，移除额外 WindowManager 显示层；模式切换立即回待机，会话思考/说话抢占新片段；新版随机池仅保留原散步及新素材，三段新睡眠和“工作状态-思考冒泡”可随机待机，“深度思考碎碎念”因源内容裁切不使用。新版勾选默认开启，旧版随机逻辑未改。校准入口在播放器最上方，两个 Activity 消费状态栏、导航栏和刘海安全区；校准页按钮固定指向哼歌/伸懒腰/魔方动作 ID。
- 云端证据：功能分支 `agent/v04226-pet-opaque-ambient-preview`，构建 head `4b205aee8f8e27a50ee4a87f5f1060fbf1dc4b7d`、tree `eb72b9f79f4e93bd210856cf7faadb88e5d7ca2a`；Actions `36276798640` 的 `build-apk` 全绿。素材 Draft 下载与 SHA、417 文件、125 项源码回归、Kotlin 桌宠测试、Flutter analyze/test、release APK、签名与包内帧均通过。APK `AI-Companion-v0.42.26-270-Pet-Opaque-Ambient-Preview-APK.apk`，SHA-256 `8e8a0b3c2809bb53efa9bd9e53e3d058ec0126231a736213fe69d395623cb85b`；未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c838b8c01ac127dd5d71`。签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机必须核对新版身体是否持续不透明、宽大特效是否截边、覆盖其他 App 时能否正常触摸、新旧即时切换、睡眠/工作待机与两页上下控件完整可见；构建成功不能替代上述视觉与交互验收。

## v0.42.27+271 · 自主聊天后台提醒通道阻断热修（2026-09-27，CI 完成）

- 证据：用户上传的 +269 私测存档与 2026-09-27 16:04 中国时间脱敏诊断相互吻合。存档最后一次 `proactive_history.decision=sent` 在 09-26 11:14:33，09-26 23:28 用户回合后至 09-27 16:03 仍无主动发送；诊断 `autonomousBehaviors.eventCount24h=0`、`recovery_orchestrator_next_heartbeat_at=0`、`background_error_count=677`，最近错误 `MissingPluginException(No implementation found for method pendingStoppedReminders on channel ai_companion/system)` 发生于 09-27 16:02 左右。Active Brain 已开，transfer lock、当前阻塞生成、chat/proactive/orchestrator 租约均未占用，日间疲劳 0.3358 且 hard veto=false，频率档自然、24 小时用量 0；并非夜间限额、疲劳或频率策略自然静默。诊断里 `recovery.state=waiting_generation:running` 是早前留下的状态，不能据此断言当前生成任务卡死。
- 根因：`RecoveryOrchestrator.runOnce` 在进入自主心跳前无隔离地调用 `CalendarReminderFollowup.deliverOne()`，后者从 `AndroidBridge.pendingStoppedReminders()` 调用 `ai_companion/system`。前台 `SystemBridge` 实现了此方法，独立后台 FlutterEngine 的 `BackgroundSystemBridge` 却未实现，于是每次后台循环在心跳前抛错，后台入口仅记录错误并十分钟后重试。正常聊天仍走前台，故用户回合正常不代表后台可运行。
- 实现范围：后台桥接补 `pendingStoppedReminders` 和 `acknowledgeStoppedReminder`，复用前台同一 `CalendarReminderAlarm` 状态；提醒单独失败时记录脱敏分类/时刻并继续后续自主循环，转移冻结异常仍传播。保留 21:00～次日 09:00 一条成功投递上限、10 分钟对话静默窗、Cedar/联网竞争、模型通道、schema 61 和现有桌宠构建素材。构建 +271 测试 APK 后，以同样自然使用观察后台错误是否停止增长、心跳时间是否推进，以及日间是否产生真实主动行为；不把“立刻发一句”当唯一正确结果。
- 云端验证：构建 head `5860cd54238e77ec65e6b911decee71020ae5316`、tree `273ca6ab88ef1eee7d0daa0bde657f9c4154ffc5`；Actions `36305352339` 全绿。素材草稿恢复、源码回归、Kotlin、Flutter analyze/test、release APK、原签名和包内素材校验通过。Artifact `10926944052`；APK `AI-Companion-v0.42.27-271-Proactive-Background-Bridge-APK.apk`，SHA-256 `a2236878e9234570ee6e90f6e288cb25b4f9186653b2b09ef54a147f3b49e879`；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fb80911e6438a3a7d7d3`。签名证书 SHA-256 仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。

## v0.42.28+272 · 天气认知、桌宠裁剪、余额与自主链路复核（2026-09-27）

- 用户授权本窗口后续推送/构建；本批仅显示 DeepSeek 官方账户余额。OpenRouter 的 Key 限额不等于账户总余额，千问百炼模型 Key 无法读取阿里云财务余额；`wy.aiwangyou.cc` 未找到可核验的公开余额接口，本批不猜测接口、不向中转站发送 Key 探测余额。
- 天气由用户在“模型与联网”填写和风天气 HTTPS API Host、API Key 与城市，Key 存本机安全配置，不写入仓库或备份。按需每十分钟同步当前实况，缓存四十分钟内的事实和读取时间；先用 Geo v2 查城市坐标，再调用当前 `/weather/v1/current/{latitude}/{longitude}`，使用 `X-QW-Api-Key` 请求标头，避开即将弃用的旧版 `/v7/weather/now`。提示词只在非角色扮演且非纯新鲜话题模式附加简短事实，选择是否提起仍由模型决定，不生成额外主动任务。网络刷新异步且错误可省略，不能阻塞自主心跳或用户回复；没有提供凭据与城市前不声称连通。
- 新桌宠继续沿用 +270 的单 WindowManager 绘制路径，绘制比例预先计入新版动作的二次缩放和宽度校准，以统一画面安全边缘减少左右裁剪。进一步发现原转换脚本把 640×360 WebM 固定 `crop=360:360:140:0`，构建时先丢弃左右各 140 像素；本版从受保护源 ZIP 重新生成 91 段完整横画面帧，缩入透明方形画布，保留左右特效与文字。旧版逻辑和触摸区域不变；宽画面内人物可能比旧裁切版小，真机需核对，原视频自身已切掉的内容仍无法恢复。
- 左栏两种布局均显示 DeepSeek 官方余额查询结果或清楚的失败状态；联网请求只到 `api.deepseek.com/user/balance`。设置页将各小节保存/测试反馈放回按钮下方、统一左对齐；Agnes 测试按钮“测试整理效果”，公开网页发现“保存本小节”并新增固定公开词联网测试，单次请求可能消耗 Tavily 额度。
- 自主代码复核：+271 已补齐后台日历提醒桥并隔离提醒失败；本批额外隔离后台心跳前的模拟手机维护、待续生成恢复、记忆整理和 Cedar 下一次执行间隔读取失败，保存脱敏错误分类/时间，转移冻结与租约保护继续生效。真实阻塞中的生成仍由既有检查阻止重复可见回复；真机仍需观察心跳推进、错误计数和自主消息送达，代码审查和 CI 不等于一夜自然使用验证。
- 维护依赖：完整 96 段桌宠帧在构建时从受保护 Draft Release asset `591363139` 下载源 ZIP 并校验 SHA-256 `ad94e2aa8829ddb5b8f0640e383b29bbccfbb5a77d9a957559e34cff17aea489`，再恢复仓库分片的旧桌宠包；CI 同时拉取受保护签名、Genie 等载荷。只检出 Git 工作树无法独立复现最终 APK；接班者须读取 `.github/workflows/build-apk.yml` 的恢复步骤，保留这些 Draft 输入。
- 云端验证：功能 head `dab608917f8b8c219bf182e5c68a666ba03b9b4b`、tree `fa253be5c84232c3601e1302cb6587a28f6b51d3`；Actions `36310019305` 全绿（125 源码回归、Kotlin、Flutter analyze/test、release APK、原签名和包内素材校验）。Artifact `10928946322`；APK `AI-Companion-v0.42.28-272-Weather-Pet-Balance-Autonomy-APK.apk`，SHA-256 `ac358f8a59e5852cc32dc331350997612fbb50398d282649ce68252a0e675f7b`，大小 630066527 bytes；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a2af492aaa765a999aa2`。签名证书 SHA-256 仍为 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`；真机重点核对所有新版动作左右内容、人物视觉尺寸、天气首次同步和随后自主消息，夜间自然运行仍需用户观察。

## v0.42.29+273 · 新桌宠高度与天气 Host 保存热修（2026-09-27）

- +272 真机反馈：新版人物显著变小。根因是把 640×360 横画面缩到 224×126，再放入 224×224 透明方形帧；方形悬浮窗按宽度适配后人物只剩原高度约 56%。本版按原 360 高度缩为 398×224 透明 WebP，保留完整 16:9 左右内容与旧版 224 像素的画面高度；单层悬浮窗仅增加横向宽度，小/中/大三档高度仍为 112/152/200dp，渲染按高度等比适配，预览同步按宽画面适配。升级旧位置时把宽度增量分到左右，人物中心位置保持不变。宽窗边缘可能覆盖更多触摸区域、极窄屏和贴边时左右特效可能仍被系统屏幕边缘裁掉，真机需要核对。
- 同批真机反馈：天气 Host 只填域名时，设置页严格要求 `https://`，而实际取数适配器接受裸域名，导致保存前误报泛化的“Host、Key 和城市”缺失。本版保存时将裸域名补成 HTTPS，校验 Host 仅含域名，分别提示缺 Host、Key、城市；立即同步使用保存返回值，不依赖提示文字一致性。原 Key 与城市继续仅本机保存，旧数据无需迁移；用户应使用和风天气控制台分配的 API Host。
- 构建仍从受保护 Draft Release asset `591363139` 复原完整桌宠源并验证固定哈希，恢复 Genie/签名等受保护输入；不要把原素材 ZIP 或签名提交到公开仓。待补充本版 Actions、APK 哈希、签名和真机结果。

### 同批阻断项：明确游玩请求未调用 MCP（2026-09-27 18:13 中国时间）

- 真机备份与脱敏诊断对应：9 月 27 日 18:12～18:13，用户承接她对钓鱼海沟的邀约，依次表示有空陪她去、现在出发、去买所需物品；她连续三轮只用对白推迟。最后真实 `cedar_toy.play` 为 9 月 26 日 23:27，三轮没有新增工具 Outcome。此前同一备份在 9 月 25 日记录“直接开呗”等自然承接语后的成功 Cedar 调用；用户指出自然语义执行曾正常工作，不能把当前失败归为从来不支持。
- 定点版本比较：+221、+222（桌宠接入前）、+223 与 +224 到 +272 的 Cedar 规划器主路由均为 `cedarExplicitRequest || cedarState.hasUserTurnContinuation`；这些版本没有因桌宠代码直接改动该路由。当前游戏为 `solo/active`，其后台续玩由独立时钟负责，`hasUserTurnContinuation` 不开启普通聊天工具；短句缺少直接游戏名，关键词路由也未打开工具定义。确切首次失效的版本尚未由单次备份证明，不能将原因武断归到桌宠渲染或 MCP 服务端。
- +273 修补迭代：最初本地尝试按短句动作词和上一句游戏词开放工具；复核发现人物常说“鲸鱼尾巴”，词面判定会误认为钓鱼上下文。该路线已撤回，未作为交付方案。现只用真实活动单人会话和紧邻上一条助手消息不超过 15 分钟作为工具可用的边界，模型在原有 DeepSeek 规划请求中读取实际对话自行判断是否调用；普通闲聊/延后不得调用，不因仅有工具可用而强制二次无调用重试。仅上下文触发的回合收紧为最多 3 次规划/3 次工具调用，明确游戏请求仍沿用 6/10 上限；真实写操作后立即收束、唯一后台续接、重复动作与租约保护均未放宽。执行仍须通过真实指南、服务端 Outcome 和本地权限门，不直接猜动作或伪造已完成。测试覆盖本次三句、历史成功短句以及无活动会话和过期上下文；单元测试只能验证工具可达，语义判断和真实推进仍待真机。活动单人会话的普通对话可能多一次 DeepSeek 规划请求，需以 `modelUsage.byLane.agent_tool_planning` 观察实际额外成本；如果偏高，再改成一次短语义判断，不回到关键词封锁。状态 `IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。构建前保护 +273 桌宠高度和天气 Host 修复；CI 须跑 Flutter 测试、源码校验、完整 APK 和签名门。
- 云端交付：最终功能 head `29934e9c44040404830f76514e6834aa9a4d5052`，Actions `36313602993` 的 `build-apk` 全绿；源码回归、Kotlin、Flutter analyze/test、release APK、包内素材与原签名校验通过。Artifact `10930480783`；APK SHA-256 `4fca5f9115113af59ec6902b3ff7dd7a14d526a2d362f570bfacd6c8849ee138`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cb69e7c8292398fa4fc8`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机验证短句是否触发真实 Cedar 工具、一次写操作是否收束、日常闲聊额外规划用量；同时核对新版桌宠高度/左右边缘与天气 Host 保存。不要把模型语义判定标为 CI 真机通过。

## v0.42.30+274 · 自主游戏检查点续玩、桌宠默认缩放和工具活动折叠（2026-09-27）

- 证据与目标：用户真机发现单人局经常只玩几步就停，期待偶尔凭自身兴趣持续玩约半小时，但不能再次占满分享。源码路径：`continueDue` 在检查点先推迟续接时钟，`RecoveryOrchestrator` 后发起竞争，`resumeOptions` 要求时钟已经到期，导致续玩候选在这次心跳被过滤；往后到期时又先延期。现有 `GameEngagementPolicy` 已根据真实游戏 Outcome 的近期动量、显著结果、饱和及心境调整游戏分数，无需增加一项固定半小时独占候选。
- 实施：检查点发生时保留已到期时钟，调度器在同轮发起正常 Desire/Thought 竞争；若未续玩，`finally` 再将时钟推迟 8 分钟，防止后台高频重试或 token 循环。服务端防沉迷锁定继续按 `resumeAt` 延后；用户已续玩、游戏已完成或前台换局时不重推时钟。一次唤醒仍至多执行一个自主规划动作，保留夜间休息、疲劳竞争、原 3 次状态变动/25 分钟检查点、现有饱和与分享独立计数；需要真机观察偶发持续游玩和网页/其他分享是否平衡，再决定是否调整局次阈值。
- 同批桌宠：仅更改实验动画无本机保存值时的缩放默认 `1.21→1.47`，显示 fit 的参考基准固定 `1.21`，避免新默认被 fit 公式抵消。用户已手动存过的设置不覆盖；宽动作与屏幕边缘实际视觉待真机验证。透明 WebM→逐帧 WebP 管线与品质参数不变。
- 同批 UI：普通聊天里工具调用过程可展开，回复正文首次出现自动收起；已完成消息的工具活动初始折叠，点击仍可复查真实 Outcome，不修改工具执行、结果、可见思考或沉浸回复。测试新增真实数据库中的单人检查点时钟／竞争资格／未选中退避回归；CI 继续跑源码门、Flutter analyze/tests、Kotlin、带受保护资源的完整 APK 与签名检查。
- 真机追加诊断：用户 20:13 截图显示保存备份因“另一项备份、恢复或设备接管”占用失败；脱敏报告 `transferLock=true`、无待处理接管快照，Cedar 动作租约在游戏执行状态结束后仍有约 91 秒；最近一次用户 `cedar_toy.play` 因 `cedar_action_in_progress` 阻止。源码发现前台工具和后台自治的 `finally` 都先 `finishExecution` 再释放租约，若前者抛错会跳过后者，最多残留原 5 分钟租约。两条路径改为嵌套 `finally` 保证尝试释放；备份占用说明按实际操作类型标明，等待写入超时不再误称“重新发送状态包”。该诊断不能证明截图中的首次锁定一定源于租约清理异常，也没有街机厅 MCP 错误正文；用户随后确认街机厅已正常游玩，因此不改远端动作协议，待新版真机复测。
- 云端交付：最终功能 head `17541e0d069bcf65e40b10e3d48549fb8a88be5f`，Actions `36319265641` 的 `build-apk` 全绿；源码回归、Kotlin、Flutter analyze/test、Release APK、包内资源与原签名校验通过。Artifact `10932156599`；APK SHA-256 `64654f6009da96677168f45b45b9aba261d6ac0c919e8cdf9c263eb2ee057ba0`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-188cba037acbc197f5ea`。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。用户确认旧版一次错误后街机厅可正常游玩，稍后备份亦成功；新版仍需真机验证偶发连续游玩与分享竞争、147% 尺寸、工具正文折叠，以及游戏／备份并发时租约能及时释放。

## v0.42.31+275 · 菜菜原生 Live2D 自主待机与桌宠说话状态（2026-09-27）

- 用户决定分步接入，首批只做原生 Live2D 与自主待机，并特别要求保留菜菜实验项目已经验证的“接入方式”，不要自行重写渲染。参考仓库 `nanlingyin/soullink-emotion-sdk` 用于后续 Jev 决策方向；本批实际原生实现来自 `catkiss62/caicai-live2d` 提交 `fb04512f940d159ebe13bebc13d2eda5cb54fc9c`，其官方 Cubism Java Framework 子模块固定 `c2d420012d004b8e61d4c589bd5c34513122f0ea`。源码与二进制出处、许可见 `app/docs/third_party/caicai-live2d/`。
- 移植原生 `SenCompanionView`／`SenRenderer`／Cubism Framework、Core AAR、默认 profile、参数语义与 EV clips/vocab。正式宿主只加 PlatformView、生命周期、文件选择和本机导入薄适配层，不带实验 Activity 与系统 TTS 测试壳；保留原来的双模型 `loadModels`、三配件组合、几何约束、前发锚点、EV faithful 动作模式及原生参数混合。沿用先前验证过的无 mipmap 纹理过滤修正，否则缺失 mipmap 的模型纹理会黑屏。完整运行时由源码与资源哈希门固定，不将模型权重加入公开仓或 APK。
- 用户在聊天画面设置导入带 `accessory-lab.json` 的菜菜女仆／Sen 三配件 ZIP，保存到应用私有目录，并可选启用主形态 Live2D；小豆丁仍用旧立绘。导入有路径与容量边界、临时目录、旧版回退；真正渲染报错时尝试恢复旧包。舞台可拖动／缩放。没有模型时提示导入。语音嘴型、表情与动作 Jev 判断、手选装扮及双形态 Live2D 不在首批开放，后续须根据真机画面和真实参数逐项加入；不能把原生自发动作当作 LLM 已控制参数。耳鳍眨眼和尾巴效果仍需真机核对菜菜源实现。
- 桌宠说话动作的静态机制：`TALKING` 单次动画 2.9 秒返回 `IDLE` 后，若上游会话 cue 仍是 `playing`，空闲重检会立即再播。前台 TTS 真正播放时每 2 秒续传状态；服务端 8 秒收不到心跳就让失联 `playing` 过期，同时真实结束仍即时发 `idle`。当前没有同一时刻的真机 TTS 诊断来证明旧版“卡住”唯一来源，修复针对可证实的无限重播条件。
- 保护边界：不改 Cedar、自主游戏/分享竞争、DeepSeek/Jev 工具规划、气焰及 schema 61；+274 的 147% 默认值、工具正文折叠、备份租约修复仍保留。原模型 ZIP 需用户从自己的仓库持有并在设备上导入；不在聊天中索取私有模型。验证包括 126 项源码套件、Kotlin／Flutter、签名和 APK 内完整原生资源；真机还需验证渲染叠层、前发与三配件、待机动态、重复开关及长时说话后的桌宠回到空闲。
- 首次 Actions `36328977449`：126 项源码门已通过，Android Kotlin 编译首次报错为实验项目在 CI 应用的 Cubism `drawable-filter` Framework 补丁尚未随移植带入。按实验项目原补丁精确补齐 `CubismRendererAndroid` 的三配件 drawable 筛选，源码门将该补丁与无 mipmap 补丁分别固定哈希，等待重新构建；不是模型纹理或真机驱动错误。
- 构建收尾：修复后 HEAD `968ca7cc8dad89cd345b6188472ba0e5517aa6eb`，Actions `36329874552` build-apk 全绿；Artifact `10935547935`，测试 Draft `397702273`（`untagged-a69fc367fb8a880a9ac7`），APK 726,018,970 字节。状态 `IMPLEMENTED / CI PASSED / APK READY`；SHA-256 与签名证书尚未在此账核实，不填猜测值。
- 真机失败：2026-09-28 用户截图显示再次导入时报 `上一模型包尚未在 Live2D 画面完成验证，请先打开画面`。导入器的 `pending` 只在画面 renderer onReady 时清掉，而设置页允许画面未建立时导入并忽略成功返回；二次导入遂被错误拒绝。尚无真机画面证据，Live2D 渲染／三配件仍未通过。

## v0.42.32+276 · 菜菜模型重试导入与桌宠触摸范围（2026-09-27）

- 开工证据：+275 真机截图二次导入触发 `pending` 门；源码 `CaicaiModelRepository.importZip` 在解压前直接拒绝未在舞台完成验证的包，且设置页导入成功未给可见提示。菜菜原生渲染源码哈希未动，仅调整宿主导入事务。
- 桌宠触摸证据：旧版 `PetOverlayWindow` 的系统窗口为 `windowDp × windowDp`；新版为 `visualWidthDp × windowDp`，中号从 152×152 dp 扩为 270×152 dp。虽然事件分类以旧方形坐标计算，`ACTION_DOWN` 在整个 270 dp 窗口触发自主中断、拖拽或点击。保留现有单窗口不透明宽幅渲染，先将宠物手势起点限制回旧方形；系统窗口两侧透明区域是否透传到其他 App，仍需真机判断，不把 `return false` 冒充系统透传。此前独立非触摸绘制层在真机导致半透明；Android 12+ 不可信遮挡策略也可能阻断底层点击，因此不在本批恢复双窗口。
- 保护边界与验收：保留原生双模型及 EV 待机、+275 TTS 心跳、147% 显示和 Cedar/气焰/schema 61。验证同一模型 ZIP 首次／重复导入、无效 ZIP 不丢当前候选、渲染成功／失败回退、桌宠方形内点击拖拽与左右空白处不触发；真机尤其检查旁侧底层点击是否透传。
- 实施：新 ZIP 完整解压并确认 `accessory-lab.json` 指向两份模型文件后，若上一包仍为 pending，先恢复已验证备份再开启新事务；无效 ZIP 在触动旧包前失败。设置页不再吞掉成功结果。`ACTION_DOWN` 在旧方形之外不再启动宠物手势、停止自主动作或拖动；新增方形边界 Kotlin 回归。
- 本地验证：菜菜运行时哈希门与总账接班门通过，`git diff --check` 通过。完整 126 项源码门在本地到第 28 项因受保护的 417 个桌宠源素材未恢复而停下；该素材仅由 CI 固定 Draft 资源补齐。Kotlin/Flutter 编译、APK 签名与真机仍待 Actions/设备确认。
- 本地提交 `053675a`。两次尝试推送明确开发分支均被自动审批拒绝，拒绝理由为公开仓库源码披露授权未被系统认可；已核对仅 15 个文本文件、无二进制或明显凭据，远端分支不存在。不得以连接器等间接方式绕过拒绝；等待用户对这一具体公开推送及常规 Actions 测试 APK 给出明确批准，再重试原始推送。
- 用户于 2026-09-28 00:41（中国时间）明确授权将本地 `053675a`、`2347961` 推送到公开仓库的 `agent/v04232-caicai-import-pet-touch` 并运行常规 Actions/Draft APK，且授权本窗口后续 AI 伴侣推送与构建。环境无 GitHub CLI 凭据，改由已连接的仓库 Git 数据接口重建两提交；远端 `8d574b28c75b5dbb316b77e05162984a1af0d7c5`、`a6193533b85b19ecccebfca771c85fc5e5e63ec0`，对应本地两提交的 tree 分别逐字节一致为 `cfe255cb530a4716c53e4d85b54c51720e5e5910`、`5485c44b48864642932d3d4cc89c27d8c7e1bf83`。
- Actions `36334400381`：源码门、Kotlin 桌宠测试、Flutter analyze/tests、Release APK、受保护资源和原签名检查全绿。Artifact `10936764488`；未发布 Draft `397733803`（`untagged-ee25d52fcd975a9a0068`），APK 726,018,934 字节，SHA-256 `4a4540dbd8b9196435c597d8558e2a09e7fc2be4267b7a8a892925dab63fe82c`，签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 状态：`IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING`。真机优先验证原 ZIP 再导入、画面真正加载/三配件、自主待机与桌宠旧方形内点击拖拽及两侧透明区；CI 不证明系统触摸透传。

## v0.42.33+277 · 菜菜加载诊断、桌宠真实方窗与 Jev 气焰复核（2026-09-27）

- 用户真机证据：+276 导入后仍无可见 Live2D，桌宠点按和拖动范围没有变化；启用菜菜 Live2D 时输入框唤起输入法明显卡顿。Jev 最近五轮有四轮回退 DeepSeek，旧报告只记状态/费用，无法还原选项与气焰。用户要求质量优先，同一批处理，不将先前 CI 绿色等同真机成功。
- 源码对照：桌宠新动作前 `b656d06^` 的 `WindowManager.LayoutParams` 宽高均为 `windowDp`；中号 152×152dp。新版 `98f42ac` 是 270×152dp，+276 只拦事件起点，透明左右区域仍属于系统窗口。菜菜实验室 `catkiss62/Caicai-Maid-Live2D-Accessory-Lab` 的 `fb04512f940d159ebe13bebc13d2eda5cb54fc9c` 以 `accessory-lab.json` 中 `mainModel`/`accessoryModel` 读取 ZIP、UI 显示导入/加载、同一 `SenCompanionView.loadModels` 回调 `onReady/onError`；宿主此前构造 PlatformView 时先加载模型、之后 Flutter 才注册回调，可能丢失结果。缺真实 ZIP/真机日志，不能断言这是唯一导入故障。
- 实施：桌宠物理系统窗恢复为方形，已有宽窗位置按半幅差迁回，缩放、角标与默认停靠同步；宽动作会按方窗 fit 显示，边缘宽特效可能裁切，需真机验视觉。菜菜解压/清单/暂存/渲染/失败回退每阶段记录到本机诊断；两处导入入口展示进度及保存后的验证指引；Flutter 注册回调后显式 `start`，原生状态可查询；旧 EGL surface 的 `onReady` 不提前确认新包。原生仓库事务跨适配器实例共享锁。聊天输入获得焦点时原生 GL 改为按需绘制，输入法关闭恢复持续帧；这是针对持续渲染的降载，实际厂商输入法速度待真机测。
- Jev 临时策略：移除本地 `confidence < 0.55` 强制 DeepSeek 回退，有效分布按已返回的最高概率选项；前两项差值 `<=0.10` 时气焰互动=ordinary、自身玩闹=none、主动开玩笑=closed、突破=wait；模式本身仍取最高项。如果 API 只报告被选项概率，则沿用该选项、不假造第二概率，诊断标 `probabilities_complete=false`，近似平局无从判定；待真机报告核对是否发生。技术失败/禁用仍回原 DeepSeek。用户更正小豆丁每个已完成回合固定减 18，和正常形态同为 -18；近似平局仍执行固定衰减。每轮本机 `jevShortUsage` 导出状态、请求上下文/问题/选项、Jev 原选项/confidence/返回的概率、最高项/中性与实际采用、用量/费用/耗时；`playfulHeatTrace` 导出用户及助手分类、各加减项、前后气焰及形态。包含有界对话正文，用户保存诊断时属于私密材料，绝不上传公开 Git/Draft。
- **Jev 持续观察，直到明确验证成功**：每次后续有存档或诊断，按当轮用户与助手语义逐项评价 Jev 分类对错，识别 `used`/`used_neutral_close_probability`/技术回退和对应 DeepSeek 调用，用 `playfulHeatTrace` 复算每轮 -18、互动加分与形态变化；比较误判率、近似平局比例、用量和延迟。不能凭单一 `confidence` 当作正确率；没有真实样本时状态保持 `TRUE DEVICE PENDING`。尤其核对用户反馈五轮四次回退在新包是否消失及真实玩法是否被过度记分。
- 验收：CI 测 Kotlin/Flutter 与完整 APK；真机需导入原 ZIP，记录 `file_selected → unpacking → manifest_validated → import_staged → render_loading → render_ready → render_verified` 或具体失败阶段；复导不丢上包；查看三配件动作及唤起/输入/关闭输入法，桌宠左右空白透传和视觉尺寸；同一份诊断检查 Jev 两人分类和气焰账。开工状态 `IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING`。
- 首次更正后的 Actions `36340823563`：源码回归通过，但 Kotlin 步骤的 Flutter 预编译发现设置页 Jev 连接测试仍传已移除的 `confidenceFloor` 参数，故在编译阶段失败；按编译日志移除该参数，扫描全部源码无其他调用点。GL 按需绘制时再导入模型显式请求一帧，确保排队的模型加载能够消费。
- 第二轮 Actions `36341488592`：源码、Kotlin、Flutter analyze 均过；Flutter tests 954 通过、3 失败。两项旧 Jev 用例只给被选项概率，新解析器误将其视为无效而转 DeepSeek；新近似平局用例的 mock 辅助函数错误地强制每批都有 `route` 问题。修复为接受有效稀疏概率、仅在至少两个概率已返回时判近似平局，并在诊断注明概率是否完整；测试 helper 改为验证问题集合存在，不预设单题。
- 最终功能 head `6029aec55c6dcbaf9ca0ca35d499fbdaf8021a9f`，tree `60cf73cb5fd706ddd7632ca16984dbfab4da18b9`；Actions `36342200023`：全部源码门、Kotlin 测试、Flutter analyze、957 项 Flutter 测试、Release APK、完整资源与原签名校验全绿。Artifact `10939257571`；未发布测试 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-99f8ed3dbab5914d561d`，APK 名 `AI-Companion-v0.42.33-277-Caicai-Render-Pet-Jev-Audit-APK.apk`，SHA-256 `aa4b74609c9a008a5e9e1cde3ab4d383ccdd2c5b8a40e9cdf429e6d7c0c60fa1`，签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。成功监控 `.ci/v04233-monitor.txt` 已核对。最终状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING`；真实 ZIP 渲染、三配件、输入法手感、桌宠透明侧区透传与 Jev 语义正确性尚未由设备证明。下次拿到诊断和备份必须逐轮评估，不因本次构建通过解除持续观察。


## v0.42.34+278：停止尺寸倒退，修复 Live2D 宿主并接动作

### 用户验收事实与边界

+277 的绿色 CI 不代表手机成功。用户确认新桌宠动画重新变小；导入提示成功但舞台仍要 ZIP；**没有模型也只要启用 Live2D 就卡输入法**。本轮用户重新授权实施/推送/常规 Actions，要求独立 Live2D 分类、侧栏入口替换、删除确认。保护批准的动画尺寸/素材/147% 校准，保护菜菜已经调好的配件与可动参数，保护 Jev 气焰最高概率/近似平局中性/每轮 -18。

### 证据与实现

完整来源、包哈希、宿主与原始算法边界见 `app/docs/LIVE2D_HOST_AND_PET_TOUCH_v0.42.34.md`。实际检查菜菜 fb04512、两份桌宠参考、SoulLink Jev 文档及用户定版素材包，未重新猜测配件运动算法。+277 方窗口导致宽动画适配缩小；onError 自动 rollback 可能删掉首次导入候选；旧 Flutter AndroidView 无模型也创建原生子树。这些均有代码路径证据，具体手机渲染错误尚无新版诊断确认。

实现：宽绘制/窄系统输入区域分离、输入区域实测状态诊断；导入成功 revision 单次重建，渲染错误留包；空模型零 PlatformView；直接 Hybrid Composition/原生禁焦点/IME 暂停连续绘制；独立设置与二次确认；原装预设、形态、Jev 四帧动作、现有 AudioTrack 口型。原始 26 文件经剥离明确标记宿主增量后校验仍等于上游基线。

### 验证状态

已加入无模型/IME、删除确认、参数边界/一次 Jev 请求、原生计划退出与口型所有权测试。当前工作环境缺 Flutter/Kotlin 编译器及 CI 才恢复的受保护素材，不能声称本地编译通过。常规 Actions 将执行完整素材还原、源码门禁、JVM/Flutter 测试、分析、APK 与稳定签名。提交、Actions、Draft 及结果在实际完成后回填。

**Jev 持续观察**：之后每份诊断/存档同时检查语义最高概率选择、近似平局处理、实际气焰结算与固定 -18，新增外观动作 lane 不替代气焰诊断。未经明确手机验证不得标 `TRUE DEVICE PASSED` 或 `JEV ACCURACY VERIFIED`。

### +278 构建与交付回填（2026-09-27 UTC）

- 功能远端提交 `499584371fe073c92484434966b2611ade4aaf80`；后续版本门禁修正 `f872f682c43d32c1c8272c20d2fb7c0d9276fb89`；最终构建提交 `cf69e61ee44c39e9ee35f0f28de81412194c9f19`，源码树 `fb6c2fa6f9596ec70c873020c56109e7b589f905`。本地最终功能提交 `96e46ebb` 与远端树完全一致。
- 首轮 Actions `36347437027` 因漏更新六个历史版本号允许列表失败；第二轮 `36347824045` 因新 Hybrid Composition 文件漏导入 `PlatformViewHitTestBehavior` 失败。均未生成 APK。补齐允许版本与导入，没有跳过功能断言或测试。
- 最终常规 Actions [36348468407](https://github.com/catkiss62/ai-companion-build/actions/runs/36348468407) **全绿**：127 项源码门禁、Android 编译与选定原生单元测试（含新增参数计划）、Flutter analyze（沿用非致命 info/warning 策略）、**961 项 Flutter 测试通过**、Release、稳定签名、Genie/全部桌宠/LingChat 等打包资源验证。
- 未发布 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6ed4643eeffc9f1affc5)：release `397797809`；APK asset `593748006`；文件 `AI-Companion-v0.42.34-278-Live2D-Settings-Pet-Touch-APK.apk`；726,041,646 bytes；SHA-256 `0c9669b808bd1edc002f375a6bb918d59a947de869c6d90bd5a5b061ebdb4f5e`。
- Actions Artifact `10940644751`；APK 校验文件及 CI Monitor 同在 Draft。状态 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING**。
- 真机尚未接入本工作环境。下一次验收先查空模型开关与键盘、定版 ZIP 后实际画面、动画大小、触摸空白透传；然后查原装预设/形态/语音口型。诊断中的 `overlayPetTouchRegion` 必须是实际 applied 矩形；内部 API 的 ROM 兼容失败不能称为已收紧。模型渲染错误保留完整堆栈且不得再次自动删除包。Jev/气焰继续按顶部持续观察协议分析。

## v0.42.35+279 · 定版 ZIP 与原生宿主／站立图触摸核查（2026-09-27 UTC，开工）

- 用户最新要求先读菜菜原项目、实际定版 ZIP、伴侣的导入/渲染宿主与桌宠绘制/触摸完整链路，确认真正问题再改。用户明确桌宠仅按**原始站立立绘的可见边界**设触摸，不缩动画。持续授权该窗口开发分支推送与常规 Actions/Draft APK。
- 基线：当前远端 HEAD `6869255`，最近五提交 `6869255 / cf69e61 / f872f68 / 4995843 / 32ec831`，Actions `36349661753` success；+278 仍未有真机通过证据。实际用户 ZIP `菜菜女仆三配件-定版素材-v0.1.38.zip` 的 48 项含双模型、贴图、物理、清单、binding profile；`mainModel` 和 `accessoryModel` 所指均真实存在。最新 ZIP SHA-256 `e0406d0679caf2484edf6703763b8d50bcdc4164689fc836c3a2cf5dc291bc28`，与先前同名包 `7ee62838…` 的条目集合一致，只有 `sen-accessory/SenAccessory.2048/texture_16.png` 的 CRC/内容变化。README 明确这是两模型由 Android 渲染器叠合的私有素材，不允许放公开仓。菜菜实验室 `fb04512` 的 `MainActivity.importPackage/loadModels` 为参照；原生渲染算法保留来源校验。
- 已确认宿主范围：`CaicaiLive2DBridge` 的 SAF、`CaicaiModelRepository` 的 staging/current/prefs、`CaicaiPlatformView` 的启动与 GL 回调、`CaicaiLive2DStage` 的 PlatformViewLink 与聊天页面 stage 位置。桌宠范围：`PetSkinManifest` 的 `IDLE → idle_front`、`PetAnimationPlayer` 帧、`PetFrameView` 的缩放/锚点/位图绘制、`PetOverlayWindow` 宽系统窗口、`PetTouchableRegion` 的内部 insets 注册。现触摸只取旧方形，不依据站立图的 alpha 边界；内部 insets 在某些 ROM 可能不可用，只有诊断 `applied` 能证明实施。
- 保护边界：不改定版双模型纹理、moc3、运动参数与 Java 原生算法；不改桌宠贴图、帧数、宽窗口、147% 缩放；不改 Jev、TTS 结算和 schema。具体实现和验证结果待回填，不能将 CI 绿色或 ZIP 结构通过称为真机渲染成功。
- 查明的失败路线：Sen donor `model3.json` 声明 26 个纹理槽，定版 ZIP 仅含 `06/16/19` 三张有效图；菜菜原生 `requiredTextureIndices()` 按三配件 drawable/遮罩只选择必要槽。不能照主模型把全部 26 张强制校验，否则会错误拒绝已在实验室使用的定版包。主模型七项引用和 Sen 六项运行必要引用均在最新 ZIP 内存在且非空。
- 已实施：导入事务在切换当前包前校验真实引用；Sen 按原 selective loader 的 `06/16/19` 校验，保留其它槽缺省。原生宿主设置媒体 Surface 的层级，加载中保持 GL 连续帧，记录 `surface_created/changed/destroyed` 及尺寸，出错保留包；原生 Java 运动与双模型投影未改。桌宠以 `IDLE → idle_front` 第一帧 alpha≥32 的像素行合成系统输入 Region，本机手势用同一 Region，缩放重新生成；宽视觉窗口、资源、147% 校准均保持。内部 insets 接口对 ROM 的兼容仍必须看实际 `overlayPetTouchRegion=applied:…:alpha` 和底层点击。
- 本地验证：新旧 ZIP 逐项 CRC 对比仅 `texture_16.png` 不同；按代码校验集合重放最新 ZIP 全部主模型七项/Sen 六项均通过；`git diff --check`、YAML 解析、+278 宿主门、菜菜资源来源门和总账门通过。完整 127 项套件本机前 28 项通过，在第 29 项因 417 份受保护桌宠原始帧未在公开仓而停下；本环境无 Android/Flutter 编译与用户手机，CI 编译/真机显示状态仍待验证。版本与常规 Actions 配置已准备为 `v0.42.35+279`。构建结果另行回填。

### +279 构建与交付回填（2026-09-27 UTC）

- 功能与宿主远端提交 `cbac8b81b77bf1a84adee11cb368fe98df967b49`；历史桌宠门禁同步修正 `3af8e3944a5b315c0af7645c3bc3f773e6d43cf0`，构建源码树 `b823f3ed…`。最初 Actions `36352030673` 在第 30 项旧门禁上失败：门禁仍断言方形触摸坐标表达式，与新的站立图 alpha Region 冲突；修正门禁要求后重新全套构建，未跳过功能实现或该门禁。
- 最终常规 [Actions 36352508874](https://github.com/catkiss62/ai-companion-build/actions/runs/36352508874) **全绿**：127 项源码门禁、Android 原生编译及相关测试、Flutter analyze/测试、Release APK、稳定签名、Genie/完整桌宠和其它固定资源打包校验均通过。签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。
- 未发布的 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-51cf4439c183e4442fdc) 已完成上传；APK `AI-Companion-v0.42.35-279-Caicai-Host-Standing-Alpha-Touch-APK.apk`，SHA-256 `04b4b8f086dd10bc91080734097a655895dd88b5c998c4a0c5fdbcfea248eac7`。Actions Artifact `10943216129`，另有同名 `.sha256` 及 CI Monitor。监控记录 `.ci/v04235-monitor.txt` 写入 `ci-monitor-v0345`，状态 `success`，构建 HEAD 与签名、校验值均一致。
- 状态 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING**。本环境未连接用户 Android 设备，不能从绿色 CI 推断菜菜在用户手机实际出画、口型/动作、键盘共存、桌宠 alpha 透传在目标 ROM 生效。真机重点：导入这份 SHA `e0406d06…` 的最新 ZIP；检查两模型与三配件显示、键盘开合、桌宠透明区域底层点击及站立轮廓点击/拖动。诊断 `overlayPetTouchRegion` 必须出现 `applied:…:alpha`，若为 `failed`/`pending` 则记录设备和日志以继续定位系统 insets 兼容。Jev 预测准确性需实样对照，继续按顶部观察协议。

## v0.42.36+280 · 真机失败证据驱动的导入、桌宠与 Agent 调用修复（2026-09-28 中国时间，进行中）

- 用户 +279 真机诊断 `ai_companion_diagnostics_2026-09-28T00-57-57-591331Z.txt`：六次导入有选取、解压、清单校验与 `import_staged`，没有 `import_failed`，最后 `available=false / pending=true / render=not_open`，说明设置回调没有把模型带进 PlatformView；未记录正式目录究竟哪条索引或文件失败。桌宠状态 `unavailable:NoSuchFieldException`，表明 +279 隐藏 `OnComputeInternalInsetsListener` 方案在 REDMI K80 Ultra / HyperOS 15 未注册。上述是 **TRUE DEVICE FAILED**，不能以 +279 CI 绿色代替。最新 ZIP 的结构检查已通过，不能继续猜“用户没导入”或“ZIP 缺资源”。
- 已审阅当前 `CaicaiModelRepository → CaicaiLive2DBridge → CaicaiLive2DStage → CaicaiPlatformView` 和菜菜实验室的双模型启动；导入切换正式目录后逐个读回主/配件模型，索引无效时从 `accessory-lab.json` 的相对路径恢复，仍失败则直接报真实读回错误并回滚；状态向界面传递具体 detail。原生 Cubism 动作/投影不动，私有 ZIP 不进入公开仓。
- 桌宠对照 `d8d4417` 旧双窗口与 +278/+279 的宽单窗：旧非触摸可视窗 `alpha=.79` 使主体半透明，`alpha=1` 会挡掉下层点击；+279 的隐藏系统 insets 在本机报 NoSuchFieldException。当前改为 112/152/200dp 的物理系统触摸窗，宽动画由已连接的现有无障碍服务承载 `TYPE_ACCESSIBILITY_OVERLAY / FLAG_NOT_TOUCHABLE / alpha=1` 的独立可视窗；无服务、添加失败或服务失联时退回矩形内绘制，并把 `visual_clipped` 后的具体原因写进诊断，不能称为视觉/透传验收。历史 alpha Region 与失败反射类已移除，窗口位置与 147% 校准保留。
- 追溯旧 `v0.35.7+82`：明确命令本地快路由，其余需要工具的轮次在同一次 DeepSeek Chat Completion 附原生函数 schema，由主模型语义选择；无工具调用时不增加规划请求。后来项目新增 DeepSeek 内部规划 + 可选独立最终回复模型，旧单请求方法仅能原样用于 DeepSeek 单通道，不能让第二通道越过既定内部工具权限。9 月 27 日 `be9bbf5` 把“15 分钟内活跃单人游戏”放宽成任意紧邻助手消息都开放 Cedar，导致普通聊天也进入 DeepSeek `agent_tool_planning`；诊断最近样本为该 lane 11 次、`final_reply` 17 次，不能说每轮都加，但频率明显过高。前一个 `98f42ac` 固定短语候选又漏掉“那就去吧，我陪你”。
- +280 路由修正：宽话题词不再使普通提及“记忆、相册、天气、游戏”启动规划；游戏自然续话只在真实可继续单人会话、15 分钟内、上一条助手消息明确谈游戏且用户为短回复时成为候选。DeepSeek 单通道直接把 Cedar schema 放在正常请求中，让主模型判断；独立最终回复通道先用已有 Jev 短判断判断最新话语是否授权现在推进游戏，Jev 判无则不发 DeepSeek 规划，判有再交 DeepSeek 选动作；Jev 不可用时仍交给原有 DeepSeek 工具规划，不静默丢失邀请。工具执行仍经真实指南/权限/Outcome 门。测试覆盖“那就去吧，我陪你”、普通鲸鱼尾巴/抱抱、过期会话、Jev 正反判定及不可用回退。此方案的语义准确性和调用成本待真机样本验证；不会把静态候选测试冒充模型判断效果。用户新指出的“说话动作停不下来”另需对真实播放状态核实，不凭模型调用统计猜改 TTS。
- 构建前本地 127 项门禁中 124 项通过；其余 3 项依赖私有 417 帧素材、LingChat 素材或本机没有的 `kotlinc`，已由下述 Actions 在恢复固定资源后执行。
- 构建过程：首轮 Actions `36367245272` 在 Kotlin 编译失败，`PetOverlayWindow.kt:1253/1255/1257` 把 Float 校准偏移传给只收 Int 的 `dp()`；127 项源码门禁已通过，但 Flutter 测试和 APK 尚未运行。修复提交 `437f0c8e6cccadb23ac1fb7de57872250ebcdf47` 将偏移按 `displayMetrics.density` 保留浮点精度换算，再由现有 `roundToInt()` 合并边距。失败报告作业本身未成功上传监控，故以 Actions 作业步骤与日志为准；不能把首轮状态当成功。
- 修复后 Actions [`36370446031`](https://github.com/catkiss62/ai-companion-build/actions/runs/36370446031) 全绿：127 项源码门禁、Kotlin 原生编译与测试、Flutter analyze/测试、Release APK、签名与固定资源打包校验、Draft 上传均通过。Artifact `10949561191`；签名证书 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`。测试 [Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a43ab3029f8301924603) 文件 `AI-Companion-v0.42.36-280-Caicai-Index-Pet-Rect-Agent-Route-APK.apk`，SHA-256 `e9f745e445fa7db50b6f63c2697cd96e797f62ca04e86674560384aff0a8e659`；成功监控 `.ci/v04236-monitor.txt` 与 head、SHA 一致。状态 `IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING / JEV ACCURACY PENDING`。真机仍需确认导入后出画、键盘共存、桌宠框外触摸透传与绘制层是否 `trusted_visual`、自然游戏续话与闲聊的调用统计；说话动作停不下来另列待排查，尚未在 +280 修复。

## v0.42.37+281 · 桌宠残影、固定待机触摸范围与 Live2D 背景穿透（2026-09-28 中国时间，进行中）

- 真机证据：+280 的模型导入已经成功；聊天页 Live2D 背景显示上一次操作页面；“更多”页顶部有两层、随后三层相同桌宠，旧画面冻结且手指穿过；用户进一步给出稳定触发路径：进入小米系统文件界面（存档/读取）时产生假图片，说明不能简单当作两个可交互桌宠。桌宠视觉也再次缩小。+280 的 `TRUE DEVICE PENDING` 由此更正为 `TRUE DEVICE FAILED`。
- 根因检查：+280 的桌宠主触摸方窗和辅助可信宽绘制窗同时存在；`bringToFront` 又在悬浮聊天的输入模式切换时对主窗执行 remove/add；更直接的是系统文件界面进入时 `retireBubbleForSystemCover` 在 `removeViewImmediate` 成功前清空窗口所有权，失败后恢复会追加新窗。聊天 `IndexedStack` 保持原生 `GLSurfaceView`，切页时透明像素可能显示已离开的页面缓冲。以上为源码对应的风险，不以 CI 代替真机因果证明。
- 保护边界：旧版已确认宽动画显示尺寸不缩水；小中大按原 `IDLE/down` 第一帧 alpha 定义静态触摸范围，新动作、特效和自主动作不扩张命中。透明区域由系统输入分发直接透传，失败时整窗不可触摸，不退回宽矩形；不使用隐藏 insets 反射。Live2D 保持已成功导入的模型、Hybrid Composition 和模型 ZIP 私有性。
- 实现：单一宽且留出大动作绘制边距的 `TYPE_APPLICATION_OVERLAY` 负责桌宠显示和输入，保持 +278 的宽绘制缩放基准及原逻辑高度，按旧待机帧原始 alpha 像素映射到窗口局部 `Region` 并调用 API 33 `AttachedSurfaceControl.setTouchableRegion`；初始及重挂载、尺寸变更先 `FLAG_NOT_TOUCHABLE`，mask 成功后才解锁。系统文件界面进入时先隐藏旧窗口，移除成功才释放并清空所有权；重建时移除失败保留旧引用并有界重试，避免生成孤儿图层；移除悬浮聊天输入状态变更中的重复 remove/add。聊天页不处于当前 tab 或 route 时释放原生 Live2D，dispose 前立即隐藏 GLSurfaceView。
- 验证：+281 初始提交 `f883811` 的 Actions `36374983658` 在旧版本静态校验处停下；六个历史校验器只允许到 +280，已补充 +281 并逐个本地通过。下一次 `36375657702` 的 Kotlin 编译发现浮点偏移误传整数 dp，已修正。最终构建 head `203ee46721285f0776b8225419e05c1b5efc99cd`、Actions `36376305397` 全绿（127 项源码校验、Kotlin 桌宠测试、Flutter analyze/test、签名及素材校验），Artifact `10951905935`，APK SHA-256 `38ea4ccaaf3247ba3faecfc5fa2d1108b41267f89fca56345223b3631c569f77`，未发布 Draft `https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fb9ac196917098c4e4f2`。用户实测：旧待机范围外虽不能拖动，但底下 UI 点不到；贴边距离变远；Live2D 主后台变黑、切页重新加载、键盘拉长。故明确更正为 **TRUE DEVICE FAILED**；上述静态 mask 不能被当成透传证据。

## v0.42.38+282 · 旧桌宠逻辑尺寸、可信透传与 Sen 稳定宿主（2026-09-28 中国时间，进行中）

- 用户验收标准：小中大三档均以旧 `IDLE/down` 可见像素为固定输入范围，超出范围必须由底层 App 真正收到点击；新动画可以超出这个范围显示，不允许缩小身体取巧；旧版关闭新动画时同样遵守早期贴边与输入规则。小米系统文件界面进出不产生冻结残影。菜菜在主后台、切 Tab/侧栏仍保持同一个模型实例和正确背景，输入法弹出时不被拉长。
- 追溯：删除 Sen 的 +244 前代码为普通 `AndroidView` + 无 `setZOrderMediaOverlay(true)` 的 `SenCompanionView`，聊天舞台 `Positioned.fill`；当前菜菜的 `PlatformViewLink/initExpensiveAndroidView`、媒体 Z 层、切页销毁/重建、输入法额外高度均偏离该路径。旧桌宠逻辑方框 112/152/200dp 被 +281 的宽绘制窗口尺寸代替作为运动/贴边边界；Android 12 起不可信应用悬浮窗的遮挡判定使仅调用 `setTouchableRegion` 仍可能拦住底层点击。
- 本次实现：有连接的无障碍服务时，改为**单个** `TYPE_ACCESSIBILITY_OVERLAY` 可信绘制兼输入窗口，用原待机 alpha Region 给系统输入分发，窗口管理器在系统文件界面移除路径保持一致；逻辑方框独立于可视溢出计算重力、运动、贴边、旋转迁移和尺寸调整；输入 Region 在位置更新后重应用。无障碍服务不在时退回旧尺寸方窗，避免宽应用悬浮窗吃掉大片点击，这条降级路径仍需实机验收。菜菜恢复普通 AndroidView 与无媒体 Z 层，聊天 Tab/route 不销毁平台视图，键盘时舞台保持布局高度。原生模型算法/私有 ZIP 未动。
- 构建前状态：**IMPLEMENTED LOCALLY / CI PENDING / APK PENDING / TRUE DEVICE PENDING**。必须在用户手机实测三尺寸旁边按钮、贴边、文件界面多次开关、主后台黑屏、Tab/侧栏返回加载次数及输入法；CI 不能替代这些验证。
- 构建回填：初轮 `36380024118` 在 20/127 旧版版本白名单失败，五个遗漏门禁补充并本地逐项通过；最终功能 head `56e628f25ebd133fa9d2c38ffcf005281e610162`，Actions [36380517278](https://github.com/catkiss62/ai-companion-build/actions/runs/36380517278) **全绿**（127 项源码门禁、Kotlin 编译与桌宠测试、Flutter analyze/test、Release、固定签名及资源校验）。未发布 [测试 Draft](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0130fd8887312ddd45ff) `397962996`，APK `AI-Companion-v0.42.38-282-Pet-Trusted-Touch-Sen-Stage-APK.apk`，726,053,350 bytes，SHA-256 `f320fc1f3c029124d807286d8a33227a03696055f512c8660c2ee2ff67dfaef4`。状态更新为 **IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING**。真机特别验证：开启无障碍服务时三尺寸桌宠范围外点底下按钮是否真实生效；贴边是否恢复；小米系统文件界面多次进出无冻结层；Live2D 后台返回无黑底，切 Tab/侧栏不重载，输入法不拉长。

## +283 正式记录（2026-09-28，中国时间）

- 授权：用户批准先推送 `catkiss62/ai-companion-build` 当前分支、完成本批修改后构建一次 APK。当前环境最初的本地 +279 分支落后远端 +282；保存旧分支到 `backup/local-v04235-before-sync`，本批从远端 `3dcc96b` 接续。HTTPS git push 无凭据，采用已连接的 GitHub 写入能力更新同一分支。不得强推、合并 main 或公开用户附件。
- 私密证据：2026-09-28 08:56 `.aibackup` 与诊断只在本机分析，绝不进入仓库。诊断近 120 次模型使用的 `agent_tool_planning` 21 次，累计 429,189 input / 19,480 output tokens；`cedar_toy_no_call_recheck_count=23`。16:49 对“怎么还有这么奇怪的游戏啊，买菜做饭……感觉还是钓鱼更实在”做了两次有工具 schema 的规划但零调用；16:50 对“但是你最近钓鱼很欧呢”又做两次规划才实际 `cedar_toy.play`。该样本的 Jev short usage 无 `cedar_context_intent`：误触发来自 Cedar 标题/钓鱼宽泛入口及 no-call 重查，不是 Jev 输出错误。备份里 `messages.model` 曾将第二通道正文记成内部模型，单看字段不能证明真正生成者。
- 实现：Cedar 明确指令入口要求动作语义；“你最近钓鱼”不再命中陪伴单人游玩；陈述/随口讨论可直接进入普通最终回复，真正游戏请求和已有会话的语义跟进仍保留。Gemini 首稿需事实或重复修正时，最多一次 Gemini 修正并直接发送；第二通道传输/配置/完整性失败才用 DeepSeek。主动消息及 Cedar 房间发言同样遵守第二通道优先，保存可见正文实际模型。限制修正次数为一次，保留真实操作事实强校验。
- Live2D：导入状态只显示“已导入模型”或“未导入模型”；增加十九种持久情绪与正常状态的预览按钮，Jev 在同一批动作问题里选择对话情绪，不再固定映射回复关键词；调皮的本地持久参数采用 wink+吐舌。原模型、用户素材与旧 Sen 冻结资源保持隔离。
- 验证与交付：本地针对性源码门通过；Actions `36411092518` 源码门、Kotlin、Flutter analyze、966 项 Flutter 测试、release APK、固定签名与素材校验全绿。远端提交 `a6834a368e7179ccf342bc269951e4335e191f55`；Draft `v0.42.39-gemini-cedar-caicai-test`（release 398130580）含 APK、SHA 文件和 CI monitor；APK SHA-256 `abe13d897590698cab52e7d2c829414028e76f2b79a573da8f5fc4ed9d5ee06b`。状态 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。真机仍需观察 Gemini 调用日志、Cedar 零调用规划、情绪持续与触摸。


## v0.42.40+284 菜菜专项表演与聊天舞台

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。

- 实现：新增菜菜专用可见轴待机、局部重心短语及十九情绪的实际女仆参数；Jev 四段语义选择加强 X3/Y2/Z 与身体 XYZ，摆胯/wink/吐舌增加同段释放，不增加模型调用。
- 舞台：TextureView 单 EGL owner，窗口表面与 context 生命周期分离；30 FPS，不因输入框停帧；键盘仅裁切固定比例的舞台。原菜菜 renderer、配件投影和 shader 通过原始哈希校验。
- 操作：控制后回聊天；聊天内舞台/摸头区域编辑、确认/取消；摸头区域按模型参考边界存储，连续抚摸触发点头/歪头/笑眼；Activity 观察触点不消费控件事件，头眼有平滑跟随和释放。
- 时限：手动表情/原装动作采用单次租约，4.12 秒发起 0.38 秒原生退场，总时长目标 4.5 秒；替换动作不会遗留旧定时器。衣装保持，聊天情绪保持。
- 气焰：普通形态不再固定扣 18；小豆丁保留 −18，严肃额外 −12 和每小时 −3 保留。补充普通累计、普通中性保持和小豆丁独立扣减测试；不修改存档历史。
- 桌宠缩小未获得确切原因，不改桌宠代码。附件未上传。
- 当前限制：尚无本版本真机录屏，无法认定“幅度/速度已达到用户预期”或“切后台/输入法设备问题已消失”。构建和设备证据将分别补记。

- 本机验证：源文件差异无空白错误；菜菜原始 renderer/配件/Framework/资源哈希通过；127 项正式 gate 前 28 项通过，第 29 项因本工作区未恢复 CI 专用 417 文件桌宠资源停止，交给固定资源齐备的 Actions 执行剩余 gate。没有把未执行的 Flutter/Android 编译及测试写成通过。

- 补充实现：动作参数索引/限值按模型缓存，避免每帧线性扫描完整参数表；聊天不可见时暂停绘制；清除手动预设保留装扮；显示失败提供重试。
- 本地执行 Java/JUnit：`CaicaiParameterPlanTest` 与 `CaicaiPerformanceTest` 共 5 项通过（实际时间 0.04 秒）；覆盖短计划释放/受保护参数、60 秒待机幅度/连续性、注意力抢占释放、菜菜真实参数表情。
- 首轮 Actions：36422468888，功能提交 104db6c；构建进行中。交互回归与专项设计文档随收尾提交补齐，最终 APK 以最后一次成功 run 为准。

- 重载交接复核发现并修正：CubismFramework/Shader 是进程全局状态，新旧 TextureView 的 GL 线程不能并行初始化/释放。用单一全局租约在 GL 线程交接；旧 renderer 完成 release 和 EGL 销毁后才释放租约；从未创建 context 的旧 view 不调用全局清理。UI 线程不等待。此项为本次新宿主必须具备的保护，随最后构建重验。
- 第二轮 Actions 36424013404：源码回归、Android 原生编译/测试通过；Flutter 970 通过、1 失败。失败为新加的导航测试在新路由首次 build 之前等待 SQLite，随后 pumpAndSettle 推进虚拟时钟导致加载超时。补上首次 pump 与有界真实 IO 等待，保留导航断言；两项确认/取消测试已通过。不得把此轮记为 APK READY。

### +284 最终交付核验（2026-09-28）

- 最终功能提交：`b7b578a3e06a7630b22062c4805c83f307900b8d`；tree `b6045d7b07d1457069e6a1bd1608a27e88a90f5b`；分支 `agent/v04232-caicai-import-pet-touch`。后续总账提交不改变 APK 功能。
- Actions：`36426075648`，build job `108940275928`，全绿；127 项源码回归、Android 编译及原生测试、Flutter analyze（既有非致命提示不作零警告声明）、**971 项 Flutter 测试**通过；包括自动返回聊天与调整确认/取消。稳定签名、Genie/桌宠/塔罗等固定资源完整性检查通过。
- Draft Release：`398253913`，tag `v0.42.40-caicai-performance-test`，保持 draft；链接 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6c1bbb4fd7e86a6bc5ce 。
- APK：`AI-Companion-v0.42.40-284-Caicai-Performance-APK.apk`，726,078,514 bytes；asset `595463873`；SHA-256 `232ae45bf50ddfd5c7643f65d35584e9114ffd39899f201acf7cc40a2f1f98ff`。构建输出与 Release asset digest 一致。
- Actions artifact：`10972990521`；校验文件 asset `595463874`；最终成功 CI 记录 asset `595463881`。没有发布正式 Release、没有合并 main，没有下载整包 APK 到本工作区。
- 设计及逐项验收：`app/docs/CAICAI_PERFORMANCE_DESIGN.md`。主要覆盖菜菜可见轴大动作、Jev 四段表演与局部释放、手动原装预设 4.5 秒、自动回聊天、同屏舞台/摸头框编辑、全界面触点观察、真实摸头、键盘固定比例、EGL 保持与交接、普通形态不固定扣 18。
- 尚待真机：实际幅度/速度是否符合参考 APK 观感；输入法延迟、前后台/页面切换与重导入/重试稳定性；摸头框与模型大小/位置的实际吻合；连续对话的 Jev 原始选项、动作采用与气焰账。不能将 CI 全绿写成 TRUE DEVICE PASSED。
- 桌宠缩小：没有确切尺寸变更因果证据，依用户要求未改桌宠行为代码。


## +285 Live2D 恢复、完整第二通道路由与截图默认值（2026-09-29）

### 范围与实现

- 用户授权修复 Live2D，并明确三项不能遗漏：导入/显示；所有可见正文及真实性修正使用配置的第二通道 Gemini，实际请求失败（含 HTTP 400）才允许 DeepSeek 兜底；桌宠只改截图可见默认值。网页显示卡住的问题暂不处理。
- Live2D：恢复 GLSurfaceView，修复 TextureView 构造异常；规范化导入根目录与相对索引，保留暂存提升/回滚/损坏包保护；处理暂停、临时重挂、先 detach 后 dispose、全局 Cubism 所有权交接。加载状态不再把素材存在当成画面已就绪，增加失败诊断和前台加载超时重试。生产原始 renderer/配件数学和资源哈希不变。
- 保留 +284 大动作/Jev、4.5 秒临时动作、回聊天、舞台与摸头框编辑、全界面视线、摸头、TTS 口型、衣装/配件、19 情绪、气焰修正。原生测试使用空场景 EGL 和结构假模型事务，没有私有模型绘制证据。
- 正文：普通/后台/悬浮桌宠、主动对话及所有分享 intent、Cedar 房间、沉浸、日历入口共用明确第二通道策略；真实性/重复/截断修正仍走第二通道，失败兜底不跨轮继承。系统消息专用请求增加明确“内部表达任务、非真实用户发言”的传输封装；不写假用户历史。DeepSeek 工具规划前言及规划检查点不进入正文。旧截断草稿历史 model 字段不作为供应商证据。
- 桌宠默认：新动画缩放151%、宽度91%、水平0dp、垂直1dp、黑场0、中间调0.86、白场230、输出0/255、饱和度100%；已有自定义值和截图外设置保留。桌宠偶发缩小仍缺因果证据，不猜修。

### 最终交付核验

- 状态：**IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING**。之前 CI 失败及修正原因保留在顶部 +285 记录，不能将前次失败改写成通过。
- 最终功能提交 `6cfca5ae303f384283a653d1627ff4a548150322`；tree `158f220a851934fe91c786c5cfa92f7ddcc225a0`；分支 `agent/v04232-caicai-import-pet-touch`。本次总账收尾提交不改变 APK 功能。
- Actions https://github.com/catkiss62/ai-companion-build/actions/runs/36455411205 全绿。原生 smoke job `109040444025`：API35 的2项 instrumentation 测试通过，生命周期连续4轮，覆盖暂停恢复/重挂/替换/释放以及导入事务。结果 artifact `10984649347`。API29曾发生JIT线程崩溃，旧平台真机兼容性仍未确认。
- build job `109042465341`：128项源码验证、Android/Kotlin单元测试、Flutter analyze、**979项 Flutter 测试**、release APK构建通过。已有非致命静态提示仍在，不声称零警告。原签名、Genie/桌宠/塔罗资源门通过。
- 版本 `0.42.41+285`，schema61保持。稳定签名 SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`；可覆盖安装，无需卸载。
- Draft Release `398368739`，仍为 draft；tag `v0.42.41-caicai-repair-test`；最终链接 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-56cc9ee2419fc27a69e8 。注意草稿 untagged 链接已变化，不沿用此前失败轮的旧链接。
- APK `AI-Companion-v0.42.41-285-Caicai-Repair-APK.apk`，726,078,982 bytes，asset `595975495`，state=uploaded。SHA-256 `0f28b4dd43a2b5ffe00bedcd21878984c086cbe077d22d3433199f6b454968c6`：构建校验输出、成功 CI Monitor、Release asset digest 三者一致。
- APK workflow artifact `10987060772`；校验文件 asset `595975493`；成功 CI Monitor asset `595975504`，记录对应最终功能提交和成功 run。未下载整包到本工作区。
- 下一步仅为用户真机回归：覆盖安装后确认聊天模型可见、已有包重载/确需时重导、切页和前后台/键盘、动作摸头/TTS；观察主动/分享及修正的实际通道与失败记录。第二通道400根因未被现有附件证实，不能把请求形状修复写成已消除所有400。Jev原始选项/气焰账继续按既定要求观察。
- 不合并 main、不发布正式 Release；私有存档/诊断/模型不上传。原工作区和未提交的 `part-075.bin` 保持不动，未纳入此次提交。网页卡住分析继续暂缓。

## v0.42.42+286 实施记录（CI 前）

- 主要代码已实现：resize同步主/配件Cubism render target；Flutter舞台缓存区分宽度变化；Jev四拍独立幅度/整模意图及全局节奏，同一次批量请求；头身待机加快，头眼/身体跟随增强。
- 整模位移与小腿支点旋转在最终drawMvp共同执行，校准数学保持原哈希；命中走逆变换。摸头由露出舞台Listener转发，短时lease阻止视线/晚到Jev覆盖。设置新增幅度/速度/支点与四项组合预览。详见app/docs/CAICAI_PERFORMANCE_V04242.md。
- 本地JDK可通过模块调用编译器；纯几何/待机检查已执行生产CaicaiRootTransform、CaicaiIdleMotion和CubismMatrix44（使用临时接口/非执行数学依赖桩）：像素比例、支点、不同行列标定后的共同矩阵与逆命中通过；60秒头X原始范围-29.32..29.40、头Y-22.89..27.31，30FPS最大相邻X差2.71。原始值仍须模型限幅，不是设备实测视觉角度。
- 本地源门初检118通过，7项失败是新版本未进历史白名单，已补286；另3项依赖CI恢复资源/kotlinc，不降门禁。新版本尚未CI通过/APK就绪，不声称真机修复完成。

### +286 构建进度

- 功能提交 `8293c7b7851bd54bde29294a041437ba31da8c03`，随后显式转换滑块clamp结果为double，最终待验证提交 `0627376f4f787a072cdabe94c8f25ab78da8b445`。
- 首轮 `36467891844` 因新提交由工作流自动取消，不是测试失败；已完成Java宿主编译并开始3项模拟器测试。
- 当前 Actions `36468439975`；原生门 job `109084683320` 成功，3项测试覆盖实际SurfaceView连续缩放、4轮生命周期/交接与导入事务。结果artifact `10990742490`（沿用旧测试工具名称Caicai-v04241，实际源码为本轮0627376）。完整APK job `109086799034` 已通过129源回归，Android/Flutter编译测试继续中。
- 回退保留的是 +285 的功能源码和原始APK。若后续要回到其功能并覆盖安装，应从该源码重打更高versionCode的恢复包，不依赖Android允许旧APK直接降级，不要求用户卸载数据。

### +286 最终交付核验

- 最终代码提交 `0627376f4f787a072cdabe94c8f25ab78da8b445`；Actions `36468439975` 于2026-09-29 03:17中国时间完成，conclusion=success。129源码/回归门、Android/Kotlin单元测试、Flutter静态分析、982项Flutter测试、release构建、稳定签名与资源完整性均通过；原生3项测试及4轮生命周期证据见上节。
- APK：`AI-Companion-v0.42.42-286-Caicai-Performance-APK.apk`，726090274 bytes；SHA256 `2838c8967924de7144b892c73915f9f283725659909210cb35af9f75943c7da6`。构建日志hash与GitHub asset.digest一致。APK asset `596202913`，sha256旁件 `596202912`，CI monitor `596202930`，均uploaded。
- Draft Release `398534068`，tag `v0.42.42-caicai-performance-test`，target=0627376，draft=true；URL https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6536c4ec9e8814a55b44 。Workflow APK artifact `10991456188`；未合并main、未正式发布、未下载大APK到本地。
- 签名 SHA256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`，与+285一致，支持从+285覆盖安装。保留模型与既有设置；原先脏的part-075.bin未进入提交。
- 验收顺序：默认幅度100%、速度100%、支点88%下，反复开关输入法观察比例；头眼跟随/触摸摸头；左右探身与小腿支点倾斜预览；最后观察普通对话与主动分享的Jev选项和实际动作。需要时调幅度/速度/支点；第二通道正文及400兜底、桌宠默认继续保留。
- 状态边界：IMPLEMENTED / CI PASSED / APK READY；尚未取得本版私有模型真机录像或诊断，不能称输入法拉伸、延迟、摸头命中或动作观感已真机通过。真实Jev新增问题的服务端选项分布也仍需设备日志验证。+285仍为用户确认的功能基准。


## 2026-09-30 美术与存档完整性后续方案（DISCUSSION / DEFERRED）

用户要求暂时保留本轮六项方案，加急修复后继续讨论；此记录不等于实施许可扩展。背景替换已单独纳入 +299，其余只保留方案。

1. 白天图使用夜景同一房间构图改日光；当前生成工具不能指定/核验用户提及的 gpt-image2.5，预览已告知版本限制。新图需检查普通聊天、沉浸与原生 Live2D 的同资产显示、昼夜切换及裁切。
2. 旧桌宠素材主要为 `app/assets/lingchat/deepseek/`（21张含头像）与 `app/assets/portraits/large_whale/`（20张）。后续整理透明 PNG 与角色/情绪/原文件名对照给用户 PS；保持每张画布尺寸、人物位置与透明通道，回收后转换并按原路径接入，不搬迁资源或改变锚点。
3. 删除七大规则右上角文件导入/导出、剪贴板设定包入口和页面专用逻辑。`AndroidBridge.savePromptPack/openPromptPack` 仍被“模型与联网配置”页面使用，不连带删除；保留规则编辑/搜索/重置、codec 与完整存档的 rule_layers。
4. 左侧栏“代办提醒”上方增加“记住事项”快捷入口，复用 `RememberedUserFactsPage` 和既有 settings 数据；原记忆库入口保留，不改变重要性/提醒机制。
5. 小腿支点整体旋转：Jev/自主待机共享默认1.0、范围0.65～1.6倍速度。待机平滑理论上界默认19.6°/s，幅度/速度最大约47.1°/s；Jev没有独立角速度硬上限，最快节奏最大左右反向场景的理论起始速度默认约137°/s、全部满档约328°/s，属于代码估算而非真机实测或全场景最大值。建议后续单独给 Jev 整体倾斜约30°/s限速，并检查接管、反向、清理归零及回到待机的衔接；用户尚未要求本轮实施。
6. 存档完整性专项：记住事项已在 settings 中；原生 `caicai-live2d` 模型/配件文件与 `caicai_stage` 布局、摸头框、幅度/速度/支点尚未纳入 SnapshotService 的 DB/attachments/album/media 通道；SecureConfig 中部分非 Key 的 provider/endpoint/model/开关亦需单独白名单导出。后续目标为用户数据与可迁移设置完整恢复、API Key 排除、旧存档兼容，采用导出→新安装环境导入→逐项比对；保留已有 Active Brain、运行任务中断与写入围栏，不能用复制设备运行态代替恢复。此次仅修现有导出崩溃，不在加急版扩展协议/原生模型备份。


## +298完整接班记录（从快速索引原样移入）

## 当前实施 · v0.42.54+298 指定时长游戏任务与过程分享（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户 2026-09-30 批准直接授权“现在去玩半小时白色房间，看看结果”，并指出游戏过程新进展不能套用45分钟普通主动分享间隔；不能每一步都分享。澄清：旧45分钟、24小时6条、2小时3条按mcp/cedar_game来源统一计数，刚发生与延后分享都受限；普通回忆旧游戏内容不必然走此源通道。
- 基线+297源码6524f3e、结果总账114c97e；独立分支agent/v04254-explicit-game-task-sharing。新增明确时长本机任务入口，模型按语义选择工具、核对真实目录和完整指南；任务仅在正式回复落库后激活，复用唯一Cedar后台执行器/lease/fence，用户聊天暂停计时，时限到/服务器限制/等待人类/换游戏/关闭/重启终止并保留真实结果回报。默认持续竞争仍由Desire决定；任务回报绕过普通欲望抽选而保留Active Brain与写入围栏。
- 分享判断合并到既有下一步原生工具规划，用已存Outcome和已分享内容判断新发现/明显变化，连续结果合并、事件去重；结构化quiet保持执行真值核验快速，不新增每步DS判定。游玩过程值得分享的结果直接排队，移除该路径45分钟/6条/3条额度，不设半小时最多2次；旧经历自主分享保留原普通竞争规则。真实时间、防剧透、MCP凭据、终局/结果快照防重放、暂停/Stop与+297其它六项功能保持回归覆盖。
- 验证计划：时长引用与边界、失败/Stop不激活、已落库恢复、有效计时、提前结束回报、重复投递、结构化过程分享及事件去重；专项源码门、132项完整门、Flutter analyze/test、Kotlin/native smoke与签名APK。未构建/未真机验收前不写PASSED。


- 实施及验证完成：新增cedar_toy.start_timed_play用户专用原生工具，逐字核对1至30分钟时长引用，真实指定目录/完整指南后登记；仅已落库assistant ID激活，过日或超过2小时未启动则过期。同一回合至多一次真实mutation；若先play再登记，后续schema只开放本机时长任务，不重复远端动作。明确暂停清除待启动授权、结束任务并暂停释放该活动；有效时长计数与服务器/疲劳/夜间围栏保持原权威，进程/导入不延长旧授权。
- 回报保留持久outbox，固定message ID与提交前writer/Brain/沉浸围栏防重复；有任务结果即优先交付，不参与普通欲望抽选、不被游戏分享开关屏蔽；报告请求时长与实际usedMs、已确认进展及提前结束原因。过程分享判断合并到已有后台native play规划，结构化quiet继续即时入库；只用已保存事件，排除get_result/状态查询/前台已展示与已分享部分，待发期间合并新事件。旧经历的普通Desire分享规则仍保留；过程direct队列不套45分钟/6条/3条硬额。
- 最终源码869a117ebbd71a2d6cb2e049d3e23af3f1133771，tree6693a12440b12afdb608442b471ea30014446e8e；[Actions 36703913197](https://github.com/catkiss62/ai-companion-build/actions/runs/36703913197) success：原生烟测、132项完整源码门、Kotlin、Flutter analyze/test、arm64 Release、资源/稳定签名全绿，11项新行为回归通过。本地可运行119项通过，13项依赖未恢复资源/Android工具链，已由完整CI补齐。首轮36702658130因加入暂停补强被新版替代取消，不记作源码失败。
- [未发布+298测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-73dccee8ef74735b707f)，Draft399945262，target869a117e，asset600714919，AI-Companion-v0.42.54-298-Explicit-Game-Task-Sharing-APK.apk，726471818bytes，SHA-2569a2ec0b07e556ee270cb32102c5337fbc0267ce0ec654e88784e7d19b4937fc2；Artifact11092411285。CI monitor源码/digest一致，签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+297相同，可覆盖安装保留数据；未合并main、未正式发布。
- 真机待验：自然说“你现在去玩半小时白色房间，看看结果”无需Desire抽选开始；重要新进展能自然分享，小额重复不每步播报；聊天暂停会顺延有效计时，结束/限制按实际回报；“先别玩了”停止任务；重启/导入不自行重授30分钟。讨论示例和笼统“你可以自己玩玩”不建立固定时长任务。导出诊断仍需持续核对Jev原始概率、实际路由与fallback，未获得本轮真机样本不能标TRUE DEVICE PASSED。+297沉浸冻结、独立情绪层/语音开关、记住事项与圆形原图球作为关联回归保留。

## +299完整接班记录（从快速索引原样移入）

## 当前加急 · v0.42.55+299 存档 CursorWindow 与白天背景（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 用户 2026-09-30 20:37 明确只做两件事：修复现有存档失败、替换已生成并认可的白天背景；授权直接推送并构建测试 APK。上一轮其余方案暂缓，详见正文“2026-09-30 美术与存档完整性后续方案”。
- 截图证据：普通备份在 `SELECT * FROM settings` 报 `Row too big to fit into CursorWindow requiredPos=294 totalRows=295`。确定是 settings 的单条大值读取故障，尚无本机数据库证据可确定具体设置键；不凭行号猜键，不清空、截断或删除用户记录。
- 基线 +298 源码869a117e/总账2ebe1d6；独立分支 `agent/v04255-backup-cursor-window-day`。计划在既有导出事务中按字节分段读取大 settings，重组后仍导出原 key/value；常规 getSetting 同用有界读取，长值保持事务一致性。兼容现有 schema61/protocol6；不扩大本轮到 Live2D 全量备份补齐。
- 背景：仅把本窗口日光预览转换为 WebP 并替换公共 `assets/lingchat/background/day.webp`，沿用 Flutter/原生同路径、cover/IME/EGL 恢复机制；夜图、人物、配件、模型路由、游戏与界面其余项保持原实现。
- 验证：多 MiB 中文/emoji/NUL 字节重组、受限 CursorWindow 查询、完整数据库 JSON 导出/导入、Android 真 SQLite 游标烟测；完整源码门、Flutter analyze/tests、原生烟测、Kotlin、arm64 签名 APK。CI 与真机分别回填，不提前标成功。
- 实施：新增 SqliteSettingsReader，首段和后续每次查询最多64KiB BLOB；完整拼接后一次UTF-8解码，支持中文/emoji跨段与NUL，空值保留。导出在原全库事务内读取；单项小设置一次查询，大设置重新在事务内读。短段/字节不一致报错，不返回部分成功；无数据迁移/删除，无协议变更。实际背景1672×941 RGB，原预览无损WebP转换，1,606,718bytes，SHA-256 `6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7`。本地真实SQLite 3.85MiB中文/emoji/NUL无损往返通过，新增4项Flutter回归和1项Android游标烟测（已由最终CI补齐，见下文）；本机无Flutter SDK。局部快检中6项历史版号白名单已补+299；120项本地源码门通过，13项因未恢复私有资源/稀疏未取出Android测试或缺Kotlin工具链留给完整CI补齐。

- 首轮CI [36724790798](https://github.com/catkiss62/ai-companion-build/actions/runs/36724790798)，源码3a7d2007/tree c9d615a6：Android15原生6项烟测通过，含512KiB CursorWindow读取3MiB以上settings完整字节；前132项源码门通过。第133项发现CI恢复LingChat原素材覆盖已提交的新day.webp，哈希门正确阻止错误APK，未进入Flutter。修复素材恢复函数：仅day按已批准SHA-256保留，缺失/损坏则失败，其余61项仍按上游LFS校验；增加实际恢复函数的正常/损坏/缺失回归及APK内day哈希核验，保留原严格门。后续完整CI结果见下文。

- 第二轮36728003121，源码144776f3/tree d96cef6f：原生6项再次通过，build-apk在已通过资源/基线检查后，14:23:32Z进入既有桌宠素材生成步骤，至14:43Z超过20分钟未完成，尚未进入后续源码门/Flutter；上一轮相同步骤约5分钟。仅为构建恢复补该步骤15分钟超时、下载连接/总时长及停流超时，源码与素材完整性校验不变；同分支推送替代旧运行以取得取消日志并重跑，产品仍仅两项。未把未完成流水线记为通过。

- 最终源码a2341425dfd6192551e3a5470eed89b5038165f4，tree dbd8558ecbc53f1a720bec82358ccb7f5c3bc63c与本地一致；[Actions 36731605271](https://github.com/catkiss62/ai-companion-build/actions/runs/36731605271) conclusion=success。Android15原生6/6（报告Artifact11105103500，CursorWindow新用例实际执行且0失败）、133项源码门、Kotlin、Flutter analyze及1018项Flutter测试通过，包含4项新设置/导出/导入/损坏分段回归；arm64 Release、稳定签名及资源检查通过，APK内day哈希与批准预览完全一致。analyze沿用仓库非致命info/warning策略，未宣称零提示。第二轮被新版替代取消，取消日志无动画生成进度，无法确定下载/apt/转换哪个子步骤停留；最终这一步约6分钟完成，不归因为产品代码失败。
- [未发布+299测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-96970c13c85e77efbdd1)，Draft400107673，target a2341425，asset601202681，AI-Companion-v0.42.55-299-Backup-CursorWindow-Day-APK.apk，727738166bytes，SHA-256 8f848e1ceeaf992a3f54fb2bd1a5721d2316a478515906cf8be4f19302c242d3；APK Artifact11107390635。ci-monitor-v0345/.ci/v04255-monitor.txt的run/head/digest与Release一致，签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+298相同，可覆盖安装保留数据。真机仍待：先保存备份确认不再报settings CursorWindow错误，再看白天背景；未用本机数据库定位具体大键，未声称Live2D原生模型/舞台偏好等后续全量备份审计已完成。其余六项后续方案继续暂缓。

## +300实施记录 · 游戏间隔、持续摸头与完整存档（2026-10-01；CI PASSED / APK READY / TRUE DEVICE PENDING）

- 功能清单含用户中途追加的持续摸头，彩蛋时长已按02:04最新决定恢复原2.8秒，原任务未丢。普通单人推进统一至少120秒，10/5/1轮按实际成功状态变更累积，选择持久化、默认5轮；实际消息提交后才重置过程分享间隔，多轮真实结果合并生成，既有规划判断复用。终止/指定时长回报单独必达；报告提交后清理此前的过程队列，保留后续恢复游戏的新事件。过期Thought不能永久阻塞新分享。
- 自制小腿支点rootTilt从当前显示值限速，默认25°/秒，对比待机上界约19.6°/秒；跟随同一gain/speed设置，最高60°/秒对比待机约47.1°/秒。只限draw transform，不改模型BodyXYZ。有效摸头达到原手势门后持续到UP/CANCEL，头部移动出判定框不能提前释放；彩蛋原2.8秒且重复触发不重置/覆盖。原概率10%、原生表情和顺滑恢复保留。
- 记住事项快捷入口在左栏代办提醒上方，复用原页面/数据库。旧桌宠素材清理暂缓，七大规则删除放弃。
- 新状态包协议7包含相对路径Live2D模型/配件、原生舞台/悬浮显示位置偏好、完整表情包文件、SecureConfig九项非密钥配置；API Key、Cedar Token、密码不导出且目标凭据不覆盖。绝对模型索引从验证后的包重建；旧1～6包不覆盖新原生/secure配置。文件/偏好/secure配置激活后若DB导入失败，回滚原本状态。原有Brain/代次/ACK/lease/旧游玩授权失效规则继续保留。
- 逐项核查CREATE TABLE与exportAll：六个既有例外仅为迁移临时、运行审计/维护记录、设备转移回执（maintenance_runs/memory_retrieval_audit/messages_v20/proactive_policy_events/provider_health_events/transfer_receipts）；settings含记住事项、日历、Jev开关和其余可迁移用户状态。身份/权限/任务租约不跨机恢复。本轮不改变 schema61。
- 新增有意义行为测试：5/10/1轮及失败/只读排除、队列幂等/积压聚合/过期恢复/报告清理；v7本机与新安装往返、原生部分失败及DB失败回滚、文件损坏/缺失/穿越拒绝、v6兼容、空模型域、凭据排除；原生实际headpat/rootTilt行为及模型租约/索引恢复。运行结果待CI，不把仅添加测试宣称为通过。
- 本地Dart语法、YAML解析、diff检查、专项门/总账门通过；有序全套因缺Cubism AAR在第2项停止。依同一有序清单逐项诊断129/134通过，其余5项为未恢复私有AAR/立绘/桌宠/LingChat特效或未安装kotlinc。完整资源与Flutter/Kotlin/Android测试交给既有Actions，尚未构建成功。

### +300第二轮CI回归与模型存档边界补正

- 本地ce809c1/tree92090584对应远端99ee9512；补齐get_result/wait/poll不计轮数、实际Release说明后，本地b16b9ae/treebcdc3051对应远端a07f3d4。首轮36750751460被新版替代取消。
- [36751155364](https://github.com/catkiss62/ai-companion-build/actions/runs/36751155364) Android15原生9/9成功：CaicaiInteractionCadenceSmokeTest两项、真实模型租约/索引恢复、CursorWindow与既有生命周期/背景均实际执行且0失败；Artifact11113874815的XML已核实。134项源码门通过。Android完整单元测试在CaicaiInteractionTest.rarePatCompletesEvenWhenFingerRemainsDown失败：旧用例180帧（3秒）断言结束，与本次4.5秒冲突；不是新增4.5秒行为失败。更新旧用例同时断言3秒仍活动、普通摸头无法覆盖、接近4.5秒仍活动及随后结束。未把此流水线记为成功。
- 审计模型导入事务时补两条边界：尚未渲染确认的pending模型事务不与存档同时进行；导出验证当前已安装模型完整性，恢复验证incoming模型而允许替换原本损坏的目标模型，避免“需要恢复却因本机旧模型损坏而无法进入恢复”。失败仍保留旧树及索引用于回滚；增加实际原生用例覆盖pending租约拒绝和损坏目标路径。未复制渲染器，不提交模型权重，不改变BodyXYZ。

### +300最终彩蛋时长决定与一致构建

- 用户2026-10-01 01:59决定采用原摸头彩蛋时长，02:04再次强调代码与APK必须一致。直接核对+299原CaicaiHeadPat淡出公式（age-2.2）/0.6，原总时长是2.8秒；前次口头2.3秒已纠正。最终只把自制摸头彩蛋时长恢复2.8秒，按住到UP/CANCEL、彩蛋内不覆盖/重置保留，其它情绪/原装临时表情4.5秒不变。同步源码门、Java及Android实际行为用例、Release说明，重新完整CI，禁止把旧4.5秒APK作为本轮最终交付。第三轮36754213000由新推送替代，结果继续如实保留。
- 补正结果回报时间精度：Thought行保存毫秒、游戏事件保存微秒；回报清理覆盖完整的已记录毫秒，避免同毫秒已报告的最后一步再次分享。既有回归明确覆盖带微秒的旧结果，同时保留下一秒恢复游戏的新事件。

### +300最终构建、APK与真机边界（2026-10-01 02:37）

- 最终功能源码620e08852283d6a5389d307e161d02166443785d，tree85471e6f48418947e81b3ca225d0b801c4fdfe94；本地fe10a850773bab10d4253156cf0a824eca7df1d3同tree。第三轮36754213000因用户最终彩蛋时长决定被新推送替代取消；第四轮[36756872531](https://github.com/catkiss62/ai-companion-build/actions/runs/36756872531)已完成且conclusion=success。最终彩蛋原总时长2.8秒，2.2秒开始0.6秒淡出；按住持续/松开恢复及彩蛋期间不覆盖/不续期保留，其它4.5秒情绪/临时表情不变。
- 134/134源码validator通过；Kotlin/Android单元测试BUILD SUCCESSFUL（4m40s）；Flutter analyze沿用仓库非致命info/warning策略通过，Flutter实际1033项通过（原1018项+本轮7项分享与8项存档回归）。普通单人至少120秒、10/5/1等宽/默认5/只计真实成功推进、积压合并/实际消息提交后计间隔、报告清理带微秒结果/保留后续恢复事件均有回归；旧45分钟仅保留历史经历分享原政策，实时过程分享使用轮数门。到轮数仍须值得分享，终止/指定时长结果回报单独必达。
- Android15原生9/9、0失败/0跳过，实际报告Artifact11116749248（XML已下载核实）；CaicaiInteractionCadenceSmokeTest两项覆盖持续摸头/松手、2.8秒彩蛋防抢占/防重新计时、25°/秒rootTilt反向/暂停/待机接管；另含模型租约/索引重建、pending导入互斥、损坏旧模型可恢复、CursorWindow大值、既有生命周期/背景用例。该报告不是私有模型真机绘制观感证据。
- arm64 Release APK通过稳定签名、Genie/完整桌宠/tarot/shader资源核验；APK内白天day.webp与批准SHA-256 6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7完全一致，未重新生成或回退背景，+299大settings无损读取保留。
- [未发布+300测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-509ccfd78b2217c9fdc2)，Draft400290010，target620e08852283d6a5389d307e161d02166443785d，asset601559245，AI-Companion-v0.42.56-300-Game-Share-Portable-State-APK.apk，727767998bytes，SHA-256 c6049f59ccaec150d26d71bcdaf1ff5b28272a025aee1f8658832a7ec851fcbf。APK workflow Artifact11116914259；其ZIP digest876a81c8fcdcb9e890037df6bd88fd743f872792a69a0c71bc2e0aa484f41a3d是压缩归档哈希，不混作APK文件哈希。sha256附件asset601559246、CI Monitor附件asset601559250。
- ci-monitor-v0345/.ci/v04256-monitor.txt为status=success、run36756872531、head620e0885；Release target与monitor一致，GitHub上传资产digest与monitor APK hash一致。稳定签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48与+299相同，可覆盖安装保留现有数据；不合并main、不正式发布、不提交私有模型、旧桌宠图片清理暂缓、七大规则删除放弃。
- 真机待验收：按住摸头后头部移动不提前恢复，松手恢复；彩蛋2.8秒内继续摸不会覆盖/续期；自制小腿支点左右旋转不再瞬跳且身体XYZ不变；左栏记住事项直达原页面；默认5轮在值得分享时概括多轮结果，1轮/10轮是最少间隔而非强制播报，直接指定时长与半小时竞争共用该门；本机及另一设备实际存档还原Live2D/记住事项/表情包/非密钥配置，目标API Key仍留本地。本轮自动化已完成，TRUE DEVICE PENDING。

## v0.42.57+301 · 记忆星谷实施记录（2026-10-01）

用户批准纯视觉查看功能，外观沿用所附galaxy-template.html / 记忆银河搭建教程。不存在“星谷维护记忆”或模型重写；RememberedUserFacts仍走原入口，不参与星谷。全部active记忆由MemoryBrowseRepository同一数据库事务按created_at/id分页读取，投影只映射标题、类别、重要度、钉选、记录日期和原文；保留不确定推断标签。文本作为私有JSON文件而非拼进HTML，以textContent显示，HTML/emoji/NUL均不作为脚本执行；日期按本地年月日显示，UTC用于排序。

NativeMemoryGalaxyActivity以本地HTTPS虚拟域名拦截JS/字体/JSON，不走外网；无JS写入桥接，CSP约束本地资源，关闭file/content访问。Intent只传经规范路径校验的cache/memory_galaxy快照路径，避免Binder大JSON；返回、异常和释放清理临时快照。独立Activity退出销毁WebView，暂停取消动画帧，恢复续播；保留既有Flutter舞台生命周期。模板所有有效记忆展示；空数据正确显示空提示，加载失败展示失败信息而无演示故事。连线为模板原按类别的视觉聚合，并不等同精确话题关系。

MemoryPage保留原编辑/保存/归档，并新增折叠同话题条目和只读详情切换；查询只匹配非空现存topicKey+active，不使用主体或类别作假关联，不触发相关记忆检索计数。新增记忆星谷AppBar入口。“她”页原去找她按钮替换为MemoryGalaxyButton，局部CustomPainter渐变星空+流星；TickerMode与应用生命周期及减少动画选项共同暂停，控制器dispose。

桌宠PetEdgeDockPolicy在同一旧吸附阈值下优先上/下角落，其余维持最近边缘；纯策略JUnit覆盖非等距四角、等距、普通边缘、范围边界和窄屏重叠。未改抛掷/重力/半屏/沿边行走等机制，未触碰Jev兜底、Live2D身体XYZ或原2.8秒彩蛋时长。构建身份0.42.57+301，各历史源码门的版本白名单只新增本版；快照协议与schema未变。

最终状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。最终构建、截图和资产证据见本节末尾；冻结归档保持原SHA。

+301首轮CI 36780935800（功能远端c3343783、本地935b8464同tree b93a1d33）：生产/测试Kotlin编译通过，原有9项原生测试通过；新增3项停留加载页，日志确认WebView124且无模块状态。原生测试应用未声明INTERNET，与生产应用不同；Android WebSettings无权限时blockNetworkLoads默认true，虚拟HTTPS的ESM子资源未启动。修正测试Manifest以匹配生产权限，继续用本地资源来源及CSP拒绝外部请求证明离线边界，不降低640条/原文/暂停/空库/错误/清理断言。另将加载错误提示容忍DOM尚未创建。待重跑，不将失败轮标为交付成功。

+301第二轮CI 36782569619（远端3e0ee60a、本地9de5da46同tree 2d23b5c1）：生产与测试权限一致后仍是原9项通过、新3项启动超时，未到截图步骤；因此上一轮权限差异不是完整根因，不声称已定位完毕。补充原生固定资源状态/MIME、启动开关及分类控制台日志，测试超时输出脚本/资源/支持状态等匿名启动证据；不记录记忆正文。保留全部功能断言继续定位。

+301第三轮CI 36784152124（远端130ef3ca、本地09c664e4同tree 48396603）确认根因：JS开/网络未禁止/importmap支持且其余模块200，唯Three引擎404；本地文件虽存在，app/.gitignore通用build/规则使vendor/three/build/three.module.js未进入HEAD，实际此前发布129/130星谷资源。该公开引擎blob早已上传并校验0bcc7a286da2c115853ceec9deea19923e10ddc1，只漏进提交树。加最小忽略规则例外并纳入源码，新增全部离线资源必须被Git跟踪的验证；并保留最终APK逐文件哈希检查。前两轮权限假设不是完整根因，第三轮精确404证据用于修复，无视觉调整。

+301第四轮CI [36785322975](https://github.com/catkiss62/ai-companion-build/actions/runs/36785322975)（远端38977282177ed3dd63ab058f4b5ea7229eaebea7、本地279e2f3d同tree48306e48）完整success：Android15原生12/12、源码门、Kotlin、Flutter analyze/test、签名arm64 APK及离线资源检查均通过。原生XML Artifact11129299181已下载核实0失败/0跳过，640条真实渲染/原文/只读/外域拒绝/停帧恢复、空库、错误状态全部实际执行。截图像素断言通过，但UTP卸载测试应用清理externalFiles后原adb pull未取得PNG，因此尚未人工看图。下一提交只修测试截图保留：测试结束前通过UiAutomation固定路径复制到/data/local/tmp，wrapper必须取得非空PNG；不改生产/模板/资源。最终交付待这一轮实跑和截图复核，不把未取得的截图说成人工视觉通过。

+301第五轮36787573265（远端1cb3518e、本地b89cef8同tree91f44d94）仅截图保留辅助断言失败：真实像素断言先通过，但复制后的成功marker为空、目标PNG不存在；其余11项通过，APK步骤正确跳过。核对Android15官方UiAutomationConnection.java第552行直接Runtime.exec(command)，连写&&被当作cp参数而非shell语法。改为独立cp、独立cat两条固定命令，并将目标PNG与原实际截图逐字节比较；不改任何生产/模板/资源。第四轮已完成135源码门、原生12、Flutter1042、Kotlin/analyze和APK130资源哈希及稳定签名；本次继续实跑完成截图复核后再交付最终head。


### +301最终构建、模拟器截图与APK（2026-10-01）

- 最终远端54a15696159719171c028a05c2d6ba957a2453a4、本地2fb751501c758aaf4c53c1fb624f4b05deaf30f9，完全相同tree0a27d13401eec72d8ad44d52a3cd4f901b4553e5。[Actions36789231773](https://github.com/catkiss62/ai-companion-build/actions/runs/36789231773) completed/success；之后仅总账记录同步，不更改安装包功能源码。
- Android15原生12/12，0失败/错误/跳过，XML总耗时64.961秒；Native Artifact11131261020（ZIP SHA-25662575ec00fbd778c2028ce206659cc162b08d0fdea62ccb164f66d49c374caae）包含真实memory-galaxy-640-render.png，62964bytes。实际像素渲染和原截图/保留副本逐字节一致性通过；人工已查看PNG，星海、光晕、环线及模板文字确实渲染，无加载遮罩/错误回退。640全记录/原文HTML不执行/临时心动不改快照/本地域资源与外域拒绝/帧暂停恢复/关闭清理、空库和坏JSON均通过。此为模拟器证据，不等同用户手机视觉验收。
- 135/135源码validator通过；Kotlin/Android单元测试BUILD SUCCESSFUL；Flutter analyze通过，1042项Flutter测试通过，包括全量只读事务及写入拒绝触发器、精确同topic、投影原文及动画生命周期。最终生产代码和资源自第四轮38977282以来未改，第五/六轮仅修测试截图保留及记录。
- APK签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48沿用+300。全部130个离线星谷文件在APK内逐个SHA-256完全一致；已批准day.webp仍是6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7，Genie/完整桌宠/tarot/shader等原门通过。另只读逐字节核对15个受保护文件，保留+299大settings读取及+300游戏2分钟/默认5轮、原2.8秒摸头彩蛋、旋转限速和完整存档protocol7；Jev不加兜底、旧桌宠修图暂缓、七大规则不删。
- [未发布+301测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-43a85864492ba629cd8b)：Draft400462139，tagv0.42.57-memory-galaxy-corner-dock-test，target54a15696159719171c028a05c2d6ba957a2453a4；APK asset602000829，AI-Companion-v0.42.57-301-Memory-Galaxy-Corner-Dock-APK.apk，734318315bytes，SHA-256325eedd99dbcbf1026cbf0eeae82a13e2fa5a09a07302d8783b80d4b56ed4a0c。sha附件602000828、CI Monitor附件602000830。APK Workflow Artifact11131242918的ZIP digest6952d6adab1c15a1d718a9bf870373a912b3b478415ab63d18bb3b2a308e64e5是归档哈希，不能与APK文件哈希混用。
- ci-monitor-v0345/.ci/v04257-monitor.txt为status=success、run36789231773、head54a15696；GitHub计算的APK digest、monitor checksum和Release target逐项一致。仍为Draft，不合并main、不发布正式Release，不上传真实私有记忆/模型/备份。
- 真机待验：她页紫靛渐变缓慢星点/偶发流星，离页/后台暂停；两入口均显示实际主记忆，归档/记住事项不混入、详情原文和返回正常、同话题展开只读；桌宠轻拖到四角优先上下，普通侧边/抛掷/半屏/沿边行走保持。大量真实记忆及旧WebView/厂商设备的性能与触摸观感仍以用户手机为准。自动检查完成，TRUE DEVICE PENDING。


## v0.42.58+302 · 导出通知与星谷交互实施（2026-10-01）

用户09:43反馈上一轮效果挺好、星谷整体正常，并要求先检查三个方向；分析全程只读。+298与当前Live2D Stage同blob a18af1f5，+299分块读取未改载入；+300存档完整性新增AndroidPortableBackend.finish无条件revision，纯导出也触发，是明确多余重载原因。侧栏是showGeneralDialog，原入口保留inputFocus，关闭路由恢复输入法。颜色投影未命中原PAL，五类仅有蓝紫；原模板粉红未删。原短/长按同一有限三维raycast，没有最近节点长按，装饰14k银河/6400星尘不可点。

10:02批准五色方案及修复，并延续前述长按辅助。本轮仅在AndroidPortableBackend记录已尝试portableApply的token，finish在finally按标记刷新并移除；导出/未应用校验不标记，不再重建Stage；部分原生应用失败或收尾失败仍通知，同时错误继续上抛。native目录/租约/校验/恢复及schema61/protocol7不变。侧栏统一入口在任何await之前inputFocus.unfocus(scope)，不清草稿、不改常规requestFocus/Live2D IME布局。

星谷增加一份本地memory_interaction.js，显式五色映射，类别名称和原记忆不修改。长按550ms、全程移动最多8CSS像素；实时投影到当前CSS屏幕按二维最近，无半径限；只查可见真实memory points，排除behind/裁剪/屏幕外，单次O(N)。短按仍走原0.14世界单位射线；拖动回原点也取消，多指/取消/失捕/后台/blur均撤销，长按后的pointerup不重复。布局、粒子数量、Bloom、流星、重要度大小亮度保持，提示缩短以容纳手机宽度。

本地13项JS测试已通过；新增6项Flutter实际AndroidPortableBackend通道/通知回归及1项Android真实触摸空白天空选择/五色验证待CI。不会用假的native backend测试代替本次revision回归。仍需完整源码136门、Kotlin/Flutter、原生13项、APK131离线文件哈希与稳定签名验证；未通过前不标CI/APK成功。

本地独立执行136项源码门，131通过；剩余5项仅缺原有Cubism AAR/立绘/417桌宠帧/情绪特效或kotlinc，沿用CI精确恢复。YAML及23段Shell、Python语法和diff检查通过；7份载入/备份/摸头/游戏/四角受保护源码逐字节与+301一致，白天图SHA仍为批准值。当前无本地Flutter SDK，实际Flutter与原生触摸留待CI，不提前计成功。

### +302最终构建、触摸与APK证据（2026-10-01）

- 最终功能远端521effa77e61e915cc477913c8b7ddf7ad1db8f1、本地e13a736974cc627953733aa0e69ad4470cbf782e，完全相同treeea8702ee2ccc21d5b4c95004fc92012246db1d62；独立分支agent/v04258-backup-focus-galaxy-pick。[Actions36805517505](https://github.com/catkiss62/ai-companion-build/actions/runs/36805517505) completed/success，一轮通过。之后仅同步本总账，不改变APK功能源码。状态IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。
- 136/136源码validator通过，其中新门实际运行13项Node颜色/屏幕投影/手势行为测试；Kotlin/Android单元测试BUILD SUCCESSFUL；Flutter analyze按既有非致命info/warning策略通过，仍有既有提示，不宣称零提示；Flutter1048项通过。新增6项实际AndroidPortableBackend MethodChannel回归覆盖纯导出不刷新、未应用回滚不刷新、应用提交/回滚刷新、部分应用失败刷新以及finish失败仍刷新且保留错误。不是用假backend代替实际revision通知测试。
- Android15原生13/13，0失败/错误/跳过；下载并核实Native Artifact11137875874 XML，总耗时71.793秒。ZIP SHA-256c587a05df4ad41d16061684cda759a086735f509efad9be245951ee85f74493f。新增realLongPressOnEmptySkyFindsMemoryAndPaletteIsDistinct实际注入Android触摸：空白天空短按不打开详情、长按命中真实记忆，五类实际卡片填色逐项一致，点击前后快照SHA不变。旧640条全量离线渲染/原文安全/临时心动只读/外域拒绝/暂停恢复/关闭清理、空库/坏JSON，以及原Live2D生命周期/2.8秒摸头/旋转/模型租约/CursorWindow大值测试全部保留并通过。
- 实际PNG galaxy-preview/memory-galaxy-640-render.png为60985bytes、SHA-25609dcbeb7dc48ee3875967f8010f6fa2073cebe844f6e35e2261540461eb9ac81；已人工查看真实模拟器画面，五类fixture实际渲染，原星海/光晕/环线及模板文字存在，无加载遮罩或错误回退。五色精确值以原生DOM断言为证，不把缩小截图观感当作精确色值证据；不等同用户手机触摸或性能验收。
- arm64 Release使用稳定签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。APK中131个离线星谷文件逐个SHA-256与源码一致，批准day.webp仍是6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7；Genie/桌宠/tarot/shader等原载荷门均通过。未改schema61/protocol7、大settings分块读取、模型租约或Live2D Stage载入/渲染机制。
- [未发布+302测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-65dae53b720ceb33676f)：Draft400607040，tagv0.42.58-backup-focus-memory-interaction-test，target521effa77e61e915cc477913c8b7ddf7ad1db8f1；APK asset602289499，AI-Companion-v0.42.58-302-Backup-Focus-Memory-Interaction-APK.apk，734320437bytes，SHA-2566f678acfaaed3e1883c091b9f979294aa9b9c375e8767d2f5694d039ca39265d。sha256附件602289497，CI Monitor附件602289498。APK Workflow Artifact11138216952 ZIP digest a36aa68564226c2ca997a76d24bb391e570e0f710979e69ec89ea793b1d1bdd8是压缩归档哈希，不与APK文件哈希混用。
- ci-monitor-v0345/.ci/v04258-monitor.txt为status=success、run36805517505、head521effa7，签名与上述相同；Release target、GitHub上传资产digest及monitor APK checksum一致。APK未在当前环境重新下载700余MB全包，依据CI实际打包/签名/逐文件载荷验证及GitHub资产digest交叉核实，不声称本地再验签。继续Draft测试交付，不合并main、不发布正式Release，不上传私有模型/记忆/备份。
- 用户17:42询问进度，继续完成交付，未取消或追加范围。手机待验：保存普通备份/导出加密接管包后回聊天不再多余载入；真实恢复及失败回滚仍正确重载已应用模型；输入时打开并关闭侧栏不会自动唤起键盘，草稿保留、手动点输入正常；五类颜色不混同装饰金色，空白长按最近可见记忆、拖动/捏合不误选、短按保持原方式。用户此前“效果挺好的”仅确认+301整体观感，不能写成本轮真机通过。TRUE DEVICE PENDING。


### 本轮定点调查证据与回归约束 · 2026-10-01

- 本轮基线HEAD `04d91072`（此前仅开始调查的总账提交），最近5个提交核对完成；功能HEAD `521effa7`，Actions `36805517505` completed/success；分支`agent/v04258-backup-focus-galaxy-pick`。另建隔离worktree，不覆盖之前窗口工作区。本轮只更新总账，没有产品代码修改、APK或重复CI。
- 输入仅按结构/关键词/时序读取：旧`AI_Companion_Backup_2026-09-30T04-47-24.aibackup`，新`AI_Companion_Backup_2026-10-01T10-26-07.aibackup`及同日10:33诊断。私密消息、原始Jev上下文、模型本体均不提交公开仓。
- 旧包：state压缩6,749,086 bytes，媒体47,811,588 bytes；没有portable域。新包48个Live2D文件、215个表情包文件；只含当前菜菜/三配件，含配件moc3压缩31,786,029 bytes。无重复条目和旧模型副本，新增体积与完整迁移范围对应，不建议回退成漏模型/漏表情包的旧包。
- 实际过程分享（中国时间）：18:12:22、18:14:57、18:17:04、18:19:30、18:21:34、18:23:43；最后18:24:26为任务终止回报，应与过程分享分开。cadence水位32、completedPlayRounds33，今天没有普通主动聊天出口的非直接游戏分享。已有消息ID和Thought生命周期一一对应，不是页面重复显示同一消息。
- 调查路线修正：初步发现普通主动聊天缺门，但取得实际存档后证明今天6次过程分享均经过直接队列；主因进一步定位为持续游玩15秒覆盖原2分钟。不得继续用“所有出口都没读到5轮”解释本次样本，也不得将修普通出口单独视为完成。
- 新旧时序归因：+299修复SQLite CursorWindow大settings导出；+300新增protocol7完整可迁移资源；+302纯导出不递增Live2D revision。三者分开保留，不能撤销大settings无损读取或恢复导出重载来压缩存档。
- Jev按总账要求定点核对最后用户轮：daily=1、ordinary=.78（serious=.06/light=.14/mutual=.01/strong=.01；confidence=.74），最高概率直接采用ordinary；游戏态none=1、工具路由chat=1。自身none=.56/playful=.44（confidence=.41、差.12、close=false）采用none；正常形态气焰88→88，与该轮普通讨论相符。该两次chat判定status=used、耗时897/867ms，未走DeepSeek兜底；不修改既有概率/气焰规则，不宣称整体Jev已真机通过。


### 前置检查记录 · 2026-10-01（检查当时未改代码；用户随后纠正资源范围）

#### 检查 · MCP游戏分享过密与存档体积（2026-10-01，INVESTIGATED / FIX NOT IMPLEMENTED）

- 2026-10-01 18:29 用户追加：对比导出损坏之前约50MB存档与当前约150MB存档，检查+299大settings修复、+300完整性扩充和+302导出不刷新Live2D的区别。18:34收到本次存档和脱敏诊断，检查范围扩展为实际包结构、哈希/重复文件和真实游戏消息时序；本轮只检查，不改产品代码或构建APK。
- 用户反馈：选择5轮回复后仍每轮出现游戏内容，要求检查间隔是否生效；本次范围是定位实际执行/计数/分享出口，不先改产品代码或构建。
- 预期沿用+300：普通单人成功推进至少间隔2分钟，两次过程分享至少5次成功推进，约10分钟；查询/失败/等待不计推进。指定时长、自主半小时与普通后台应共用分享门，真正任务终止回报另行必达。
- 实际证据：本次+302存档与诊断已核对。今天的过程分享走直接队列，约每5次推进发一次；持续单人游戏每步实际约21～32秒，因此5轮只约2分钟。`continueDue`的`sustained`尾部15秒`deferContinuation`覆盖`recordPlay`普通单人2分钟时间，起源为+298持续游玩提交`e0d408d0`，+300修改分享按钮时未统一该路径。这是本次真机主因；2分钟规则仍存在，未被全局删除。
- 另有源码遗漏：`ProactiveEngine.evaluate`的间隔前检、提交前检查与`noteDelivered`都只针对`isImmediateCedarShare`；经普通主动聊天竞争选出的游戏念头会绕过这些检查和水位确认。今天样本没有这种非直接发送，不能冒充本次已发生事实，但修复应一并收口。真正结束/任务终止回报独立保留。
- 存档结论：旧protocol6包54,586,025 bytes；新protocol7包159,706,959 bytes。压缩后新增加Live2D 64,345,008 bytes和表情包40,946,046 bytes，聊天设置6,774,101 bytes、原媒体47,557,191 bytes基本未增长。新增资源属于+300补齐完整迁移，与+299大settings分段读取和+302导出不刷新Live2D不是同一问题。未发现重复路径或模型backup/staging目录；263项portable、84项media和state SHA-256全部匹配。包结构和哈希通过不能替代新机导入真机验收。
- 下一步（DESIGNED，尚未改代码）：让普通单人持续任务和自主连续游玩保留2分钟推进下限，保护多人监听/真实服务端定时；所有过程分享出口统一轮数门与提交后的水位确认。保留5/10/1轮分享设置、不新增模型调用、不为减小文件而删除模型/表情包。当前产品及APK仍为+302。

#### 原接班快照 · 2026-10-01 新窗口轻量对接完成

- 范围：用户本轮只要求接班，上个窗口任务已完成；本窗口核对最近交接片段、当前分支最近5个提交、最新Actions摘要、本轮交付/源码片段及直接相关约束，未改产品代码、未发起新APK构建。
- 接班基线：`agent/v04258-backup-focus-galaxy-pick`，接班前HEAD `f69ada3be87df1f2d2b340984d47a37a68d23449` 仅改本总账；功能与APK仍为 `521effa77e61e915cc477913c8b7ddf7ad1db8f1`，`v0.42.58+302`，schema61/protocol7。本次亦只更新交接文档。
- 已完成并经CI：导出不再误发Live2D变更通知；侧栏入口清除输入焦点；五类记忆颜色与550ms长按最近可见真实记忆。功能Actions `36805517505` success，交付文档Actions `36845165168` success；Draft `400607040` / APK asset `602289499` 的target和SHA-256与最终交付记录一致。既有136项源码门、1048项Flutter、13项Android原生通过均为上一窗口CI证据，本窗口没有重复运行。
- 真机边界：+301“效果挺好的”不能扩展为+302验收。+302普通备份/接管包导出后返回聊天、真正恢复/回滚后的模型刷新、侧栏键盘及草稿、星谷五色和长短按/拖动/捏合仍为 TRUE DEVICE PENDING；+297～+300各自剩余设备验收沿用原记录，不据构建成功改成真机通过。
- 决定覆盖：旧桌宠素材任务暂缓，大肥鱼/小小鲸是立绘，不能沿旧六项方案误当桌宠替换；七大规则删除已放弃，页面和共享导入导出保留。第二套Live2D的modelId/profile与切换隔离仍未实现，不能宣称已支持。
- 回归约束：保留已成功菜菜直接Hybrid Composition/原生GLSurfaceView及现有IME舞台；不用已失败TextureView或重建舞台方案猜修。星谷只读，不写记忆或新增模型调用；摸头彩蛋原2.8秒、完整存档/大settings读取、游戏分享及四角吸附继续保护。允许常规开发分支推送与Draft构建，不含合并main或正式Release。
- 下一步：以+302作为当前测试基线，先处理用户实际设备反馈或用户指定的新任务，不自行扩展旧方案。当前验收从下一节“当前交付 · v0.42.58+302”及末尾“+302最终构建、触摸与APK证据”进入；其他后续事项按“6. 后续待办与观察项”定点读取，并先以最新明确取消/暂缓决定覆盖旧条目。


### +301完整交付索引（原顶部内容完整保留）

## 当前交付 · v0.42.57+301 只读记忆星谷、星空入口与四角吸附（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户2026-10-01 05:15批准实施上一轮方案并追加“她”页按钮替换；基线+300功能620e0885、总账18edbf64（本地d696987e同tree dcc5c3d6）；分支agent/v04257-memory-galaxy-corner-dock，版本0.42.57+301，schema61/存档protocol7保持。授权推送构建延续。

- 记忆星谷：沿用用户HTML模板的星海、粒子、Bloom、流星与文案，独立原生WebView Activity，离线资源随APK打包；读取全部active主记忆，未随机抽样、无300条上限，归档/旧版本不显示，记住事项不加入。空库和错误不回退虚构示例。
- 只读路径：专用分页快照，不走AI relevantMemories；浏览/搜索/点击/临时“心动”均不写数据库，不增加召回或表达次数，不改重要度/钉选/冷却，不调用模型。模板连线仍按记忆类别作视觉提示，不声称是新知识图谱；列表详情另加精确已存topicKey的同话题条目，折叠查看、只读切换，不新增关系表。
- 入口：记忆库页+“她”页；原“去找她”位置替换为“记忆星谷”，紫靛渐变、缓慢星点、偶发流星；离开首页、后台、减少动画时停止。原其它聊天入口保留。
- 桌宠：同时进入水平/垂直吸附范围的四角优先上/下，保持原阈值；普通边缘、抛掷、重力、半屏、沿边行走不改。Jev Live2D不增加兜底；旧桌宠图片清理暂缓，七大规则删除放弃。
- 回归保留+299白天背景及大settings无损读取、+300游戏分享/自制旋转/2.8秒摸头彩蛋/记住事项/完整存档。新增数据库只读、投影、动画生命周期、原生路径和四角测试，APK离线资源逐个哈希核对；最终CI已通过并已查看真实模拟器星谷截图，真机待验。

最终[Actions36789231773](https://github.com/catkiss62/ai-companion-build/actions/runs/36789231773) success；源码54a15696159719171c028a05c2d6ba957a2453a4/tree0a27d13401eec72d8ad44d52a3cd4f901b4553e5与本地2fb75150同树。135项源码门、原生12/12、Flutter1042及Kotlin/analyze通过，130个星谷APK资源逐个哈希一致；真实640条星谷PNG已查看，非空画面及原模板效果正常。此前失败轮仅作排查历史，最终以本轮为准。

[未发布+301测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-43a85864492ba629cd8b)，Draft400462139/asset602000829，734318315bytes，SHA-256325eedd99dbcbf1026cbf0eeae82a13e2fa5a09a07302d8783b80d4b56ed4a0c；Release target、CI head及ci-monitor一致，稳定签名沿用+300，可覆盖安装。真机仍待入口动画、记忆查看/返回、四角吸附及既有功能实际观感验收；TRUE DEVICE PENDING。


### +303实施与验证起点 · 2026-10-01（IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING）

- 用户18:42明确纠正此前范围：外部导入的Live2D和表情包资源不进入存档，仅保存设置。此决定覆盖前置检查中保留完整资源的建议及+300的扩充方案；保留历史记录，不把旧建议当现要求。
- 新导出仍为ZIP protocol7，portable_state版本2/resource_files=external、两域清单空、portable_bytes=0。保留SecureConfig白名单与native_preferences；准备恢复只在旧版本1资源包中执行模型/表情包验证与目录交换。新包apply restoreModels=false，原生不写索引、不清旧资源事务目录；成功/失败保持配置事务与回滚。旧150MB包仍完整校验恢复。旧App会明确拒绝未知portable版本，不能先清空资源；应更新App后导入新包。
- 导出begin只读偏好且不验证外部模型树，finish仍沿+302仅在真正apply后发revision。没有动GL宿主、舞台生命周期或IME。
- 持续游玩去除尾部15秒defer覆盖，保留recordPlay的2分钟或更长服务端等待；终止回报和多人监听不变。过程分享前检、提交前检及消息落库后的确认覆盖全部isCedarGameShare；一般UUID消息可确认水位，旧逐步Thought仅结算其真实对应事件，不吞新结果。
- 回归新增：新包已有资源保留/无资源环境只恢复设置/外部排除声明完整性；独立构造旧v7包验证旧资源迁移/损坏拒绝/空资源明确清除；Android真实偏好与模型索引commit/rollback；直接/普通分享水位幂等及持续任务/自主游戏2分钟行为。版本0.42.59+303/schema61，分支agent/v04259-game-cadence-settings-only-backup。
- 本地总账门、新分享/portable源码门、原+297/+298门和diff空白检查通过。全137门本地在Live2DCubismCore.aar资源门停止，记忆星谷门缺离线资源；工作区仅有LFS指针且无Flutter SDK，交由既有CI按锁定资源恢复再完整验证，不宣称Flutter已通过。
- 总账快速索引在开始本轮前已达102,063 bytes、超过既有100KB门；将既有接班完整记录及+301完整交付条目移动到正式记录，保留顶部摘要与全部内容后门通过（约97.8KB）。未改冻结归档，未删除失败路线。


### +303首轮CI失败与修正 · 2026-10-01

- 功能远端a551f48/tree149d979与本地77e14ef同树；Actions36853738851在原生烟测compileDebugKotlin失败。实际错误仅PortableCompanionState的CaicaiRuntime引用：该Runtime与Flutter PlatformView同文件，原生独立烟测不能连带引入Flutter宿主。未进入Flutter/未生成APK，不能把本轮列为通过。
- 修正把模型release作为PortableCompanionState构造依赖；实际Bridge仍传原CaicaiRuntime.releaseModel，调用顺序/渲染逻辑不变。原生烟测传计数器，验证只读begin不release、apply才release，并运行真实配置/索引回滚；不复制Runtime、不重写渲染器。
- 发布首个本地gitpush被自动审批以目标/授权未明确拦截；随后核对catkiss62为用户已连接且有push权限的目标仓库、25项提交只有源码/测试/总账、无私密文件或真实密钥，直接重试通过审批但命令缺Git凭据。转用既有GitHub连接提交，blob及tree逐项与本地校验一致；未绕过仍有效的审批拒绝，未合并main或正式发布。

### +303第二轮CI及原生重跑 · 2026-10-01

- 修正后功能HEAD075612510065c9a57decc8ceedfb101ea5e73b4a/tree2ef8e4558a7488ad888518f134e894153fbe79df；Actions36854506956第一次attempt原生14项中13通过、1失败。新增便携设置commit/rollback通过，唯一失败为已有MemoryGalaxySmokeTest.realLongPressOnEmptySkyFindsMemoryAndPaletteIsDistinct的页面载入超时；诊断显示页面ready complete、配置和memory.json已载入，仍停在loading。本轮未改星谷生产代码/资源，不按超时猜改或削弱断言。
- 对同一源码只重跑失败阶段（attempt2）；原生job110346517462在Android15完成14/14，无失败/跳过，11:31:44 BUILD SUCCESSFUL。原生Artifact11159121970，ZIP digest b37d39a106167b2629b38493689b17e533f2c69071e384a30a940f5646f4dc76；第一attempt失败Artifact11158680834保留，不混作最终证据。APKjob110348343225随后启动，最终完整源码/Flutter/签名/资源核验结果待后续记录。
- attempt2原生XML已下载，实际14 tests/0 failures/0 errors/0 skipped。随后完整源码门和Kotlin单测通过，但Flutter analyze发现新增cedar_cadence_regression_v04259_test.dart第68行未传CedarToyAutonomyEngine必需secureConfig，阻止测试和APK。补齐SecureConfig.instance并移除该测试多余import；这是测试初始化遗漏，未变更产品行为，不把本轮标为最终成功。

### +303第三轮CI与模拟HTTP编码修正 · 2026-10-01

- 功能15fa37b55ec0be9b417d61956f3f6b4c70b4b87e/treee05d405，Actions36857417191的Android15原生14/14再次通过，最终原生XML已下载核实0失败/0错误/0跳过，Artifact11160335602 ZIP SHA-256 dc5d94dfb3633f25699ec5084778461a4ffecc79d206ce2dabd747f3612bffe5。完整137源码门、Kotlin与Flutter analyze通过；全量Flutter只有新增两项持续游戏测试失败，实际返回write_outcome_sync而非played_one_step，其余备份/旧包/导出通知/分享水位回归通过。
- 精确原因是测试MockClient的中文JSON响应没有Content-Type，http.Response用默认latin1编码中文时抛异常，被生产McpHttpClient正确分类为network_or_timeout并进入写结果同步分支；并非MCP结果控制逻辑回归。按dart-lang/http官方Response与utils实现确认，仅给该模拟响应加application/json;charset=utf-8，不改生产协议、同步围栏或断言。下一轮继续验证原两分钟行为和全包；此轮没有生成可交付APK。

### +303最终构建、回归与APK证据 · 2026-10-01

- 最终功能HEAD afe1baa58a5e9f63412ff1913aa14b64ebafced4/tree f4eda29002f87eafb5d660acfbca989b87bb5ec5，与本地f93f96e同树；隔离分支agent/v04259-game-cadence-settings-only-backup，版本0.42.59+303/schema61。最终[Actions36860037884](https://github.com/catkiss62/ai-companion-build/actions/runs/36860037884) completed/success、attempt1。此前三轮失败及原生重跑均保留上文，不混作最终成功；之后仅同步总账，不改产品/测试/构建源码。
- 完整137源码门通过，Kotlin BUILD SUCCESSFUL，Flutter analyze无错误，1056项Flutter全部通过。两项普通持续游玩/带taskId持续游玩测试在12:28:39/40 UTC实际完成规划与模拟MCP推进，核实nextActionAt为两分钟、30秒再唤醒不执行；不是夜间分支跳过。新包不含外部资源、导入保留文件、无资源环境只恢复设置、旧完整资源包恢复/损坏拒绝/回滚及纯导出不通知Live2D回归均通过。
- Android15原生14/14，最终原生job110361747353；Artifact11160943334已下载，实际XML为14 tests/0 failures/0 errors/0 skipped，ZIP SHA-256 852d84e39dbf9778b0bf16687ab7307e7711fb1ece2f1d06f4bb3294a62b800a。新增preferencesOnlySnapshotPreservesExternalModelFilesAndIndexOnCommitAndRollback实际验证只读begin不释放renderer、设置apply才释放、资源文件/路径索引在commit与rollback中均保留；大settings读取、原生生命周期、触摸及原星谷测试继续通过。
- 新导出仍为ZIP protocol7，portable_state2明确resource_files=external，不枚举模型/表情包文件。设置恢复不触碰资源索引/目录；旧portable_state1完整资源包保持验证/恢复/事务回滚。旧App不识别新portable版本会在应用前明确拒绝，用户应先升级+303再导入新包。+302导出revision修复、菜菜GL宿主/IME/渲染及Jev规则未变；不增加模型调用。实际159,706,959-byte包的资源压缩数据为105,291,054bytes；新导出约54MB为同数据结构估算，未冒充手机实测。
- arm64 Release沿用稳定签名30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48，可覆盖安装保留数据。131个离线星谷资源在APK内逐个哈希一致，已批准day.webp仍为6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7，Genie/完整桌宠/tarot/shader等原载荷门继续通过。
- [未发布+303测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cb53feb090790f12ef38)：Draft400893101，tagv0.42.59-game-cadence-settings-backup-test，target afe1baa58a5e9f63412ff1913aa14b64ebafced4；APK asset603227522，AI-Companion-v0.42.59-303-Game-Cadence-Settings-Backup-APK.apk，734318257bytes，SHA-256 d543f443b408ca9814e6b4cc00f144cbaa69681a589894cb541534140a038558。sha256附件603227521、CI Monitor附件603227536。APK Artifact11163140428 ZIP digest a6fb633d48385a5596d24be179dc6fdb4143be8fc9ad5098dfdeb147a6125600是归档哈希，不与APK文件哈希混用。
- ci-monitor-v0345/.ci/v04259-monitor.txt为status=success、run36860037884、head afe1baa5；Release target、monitor源码/签名/APK checksum、GitHub资产digest及Release URL逐项一致。未在当前环境重新下载700余MB APK，以CI实际验签/载荷核验与GitHub资产digest交叉确认；不宣称本地再验签。继续Draft测试交付，不合并main、不正式发布，不上传真实模型/备份/私密诊断。
- 当前状态IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。手机验收：导出文件约50多MB且Live2D不重新载入；新包导入已有设置正确、已安装模型/表情包仍在；持续普通单人每轮至少两分钟，默认5轮的过程分享约十分钟，终止报告不等攒轮数。实际模型/设备导出与后台节奏仍待用户反馈；不要据自动测试宣称真机通过。

### +303导入重载定点检查与修正方案 · 2026-10-01（DESIGNED / IMPLEMENTATION NOT STARTED）

- 用户21:18反馈导出没问题，导入仍导致Live2D重新加载，要求对比存档出错前版本。工作区基线308ac6a（仅交付总账）、功能afe1baa5；本轮无产品/测试/版本/工作流改动，无新APK。此前+303关于导出不重载/资源排除的真机反馈可记该子项通过，不能扩大为整个+303真机验收。
- 只读核验新附件AI_Companion_Backup_2026-10-01T13-14-48.aibackup（libfile_1c5f1c15ae948191b83ecdb8a3b21c22）：54,425,356bytes、86项（state/manifest及84媒体）；protocol7/schema61、portable_state2/resource_files=external、portable_bytes=0，两域文件清单为空。state及84媒体SHA-256全部一致、无重复ZIP路径；stage设置包含headBottom/headLeft/headRight/headTop/scale/x/y。没有改写用户存档，也未上传附件到公开仓。
- 存档CursorWindow错误前功能基线v0.42.54+298/869a117e。该SnapshotService用protocol6恢复数据库和已有媒体，不调用任何portable native apply/releaseModel/revision。CaicaiLive2DStage自+298至+303逐字节相同；恢复页面也没有新建整个App或pushReplacement。主要变化来自+300提交99ee951新增便携资源/原生设置恢复，不是+299无损大settings读取或Live2D载入机制改变。
- 当前v2 prepare已经restoreModels=false，不交换外部模型/表情包目录；但PortableCompanionState.apply仍无条件releaseModel，实际调用CaicaiRuntime.releaseModel→stopForDeletion→dispose，销毁原生视图。AndroidPortableBackend.apply仍无条件把token加入_reloadAfterFinish，finish递增revision，Stage监听后增加_modelRevision/ValueKey并创建新PlatformView。即使设置完全相同也执行这两个步骤，因此能直接解释本次设备反馈。+303现有settings-only restore测试还明确期望revision+1：测试符合当时实现，但这个保留不符合用户现在要求，下一次要改正确行为断言。
- 修正方案：原生release及Dart模型revision都仅绑定真实模型资源恢复；新v2设置包不释放renderer、不改变模型revision/原生view身份。偏好仍先完整校验并保持原提交/回滚，完成后对活跃视图同步最终caicai_stage缓存：动作gain/speed/pivot、scale/x/y、头部触摸区域，缺省值也按原默认恢复。复用tuneCaicaiMotion和applyStage(persist=false)，不通过重新载入模型读取设置；设置相同则跳过渲染更新，无活跃视图时由下次创建读取。恢复失败回滚后同步回原设置，不重建视图、不隐藏错误。
- 旧protocol6导入继续不碰原生资源；旧150MB/portable_state1包若确实替换模型文件仍按现事务释放并重建一次。独立ZIP模型导入/删除同样仍需重建，不为追求所有情况零重载而留下失效GL模型。新方案不动HC/GLSurfaceView、IME、Stage载入/生命周期、资源目录或+299大settings修复。
- 后续实施验证（尚未执行）：新包导入成功/中途失败/回滚/finish失败均不递增模型revision、不调用release；恢复不同设置及删除缺省键后，活跃视图位置/缩放/动作/摸头区域立即正确且view/execution identity保持；无模型/未打开聊天仍能恢复设置；导出零重载和旧资源包真实替换继续回归。沿用已获授权的开发分支/Draft构建；本轮为定点检查与方案，没有新增功能版本或APK。


## +304 设置包导入保留Live2D · 实施开始（2026-10-01 21:33）

用户明确“ok，开始修改”，延续开发分支推送与Draft APK授权，不合并main/正式发布。基线c8074c9550b3e328eb54d15eff1d103f23ef8010（+303功能afe1baa58a5e9f63412ff1913aa14b64ebafced4）。本轮版本0.42.60+304，分支agent/v04260-settings-import-live2d，schema61/ZIP7/portable_state2不变。

实施：设置包restoreModels=false不调用releaseModel、不登记Dart模型revision；PortableCompanionState.finish仅在最终提交/回滚后通知原生同步偏好，异常仍释放lease且保留错误。既有CaicaiPlatformView读取同一偏好、更新动作/缩放位置/摸头区域缓存，复用tuneCaicaiMotion和setStageTransform，不loadModels/dispose，不改HC/GLSurfaceView/IME/模型渲染器。活动编辑器的撤销快照同步，避免旧编辑快照覆盖刚恢复的设置。旧完整模型包仍释放、重建和恢复索引；纯导出不通知刷新，无活动视图时下次创建读取最终偏好。

新增验证目标：Dart设置成功/回滚/部分失败/finish失败revision保持；原生真实SharedPreferences提交/回滚只同步最终值、外部模型与索引不变；同一CaicaiCompanionView/renderer热应用并检查实际renderer参数、EGL context保持、缺失键默认值、导出不刷新；同步异常保留且释放lease；旧模型恢复仍release且不热同步。验证与构建未完成，此时状态IMPLEMENTING / CI PENDING / TRUE DEVICE PENDING。


### +304 本地实施与检查

代码IMPLEMENTED；本地138项逐项检查131通过，7项仅缺既有构建依赖：Live2DCubismCore.aar为LFS占位，立绘/桌宠/lingchat效果/星谷131资源未恢复，且未安装kotlinc。+304新门、+303备份/节奏门、+300完整存档门和总账门通过；diff --check通过。未把本地缺依赖记作全套通过，Flutter/原生行为尚未执行，完整Actions负责恢复固定资源并运行138门、Flutter、原生17项、Kotlin/analyze、签名和APK资源哈希。

生产热点仅修改portable释放/最终偏好通知、Dart模型revision登记和原生视图偏好读取/热同步。既有Java渲染器、GL生命周期、Stage Dart组件、模型加载/普通模型ZIP导入未修改；相同参数不重复更新动作或舞台，避免重置既有舞台运动。新增偏好读取器同时用于首次构造与热应用；回归直接检查生产SenRenderer字段和原视图/context保持，但不等同手机屏幕验收。公开分支提交仅源码/测试/工作流/总账，不含用户存档、诊断、模型或密钥。


### +303 原快速交付索引迁移留档

## 当前交付 · v0.42.59+303 游戏推进与仅设置备份（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 按用户最新决定覆盖+300资源方案：只保存Live2D/表情包等设置，外部导入资源不打包；保留+302纯导出不重载。按实际包约159.7MB中约105.3MB为资源压缩数据，新导出预计约54MB，手机实际值待验。
- 持续单人不再用15秒覆盖普通2分钟或更长服务端等待；所有过程分享出口统一5/10/1轮门及发送水位。默认5轮约10分钟，终止回报和多人协议保留。
- 新包导入保留本机模型/表情包及索引，恢复设置；旧150MB完整资源包兼容。新portable_state版本2需+303或以上导入，旧App明确拒绝；API密钥仍排除。
- 功能afe1baa5/treef4eda290，[Actions36860037884](https://github.com/catkiss62/ai-companion-build/actions/runs/36860037884) success：137源码门、1056 Flutter、原生14/14和签名/131资源哈希通过。[未发布+303测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-cb53feb090790f12ef38)，Draft400893101/asset603227522；稳定签名可覆盖安装。最终SHA、失败路线及真机边界见正式记录末尾“+303最终构建、回归与APK证据”。



## +304 最终构建、回归与APK证据（2026-10-01）

功能远端9ba2f176d30501dabe3cdf08c09f58f32e9600ea，tree5281e748bdf4f2d17e17376589b0c58e03991daf；本地首提交7adcf6ad6de2a9ff0b8bd1d55c0b7739f2be3e9b与远端同tree，上传21个源码/测试/工作流/总账blob及总tree逐个校验。随后本地同步远端且工作树干净。此最终接班文档采用后续[skip ci]提交，只改唯一总账，不改变APK功能树。

[Actions36871635441](https://github.com/catkiss62/ai-companion-build/actions/runs/36871635441)，run_attempt1，head9ba2f176，conclusion=success。本轮无失败CI或改用弱化测试；先前本地7项缺依赖仍保留为本地限制。Actions恢复固定依赖后：138源码/回归门全过、Kotlin桌宠/悬浮窗测试与编译通过、Flutter analyze按既有no-fatal-infos/no-fatal-warnings配置通过（306条info/warning，未宣称零提示）、Flutter1059项全部通过，arm64 Release编译、稳定签名、Genie/桌宠/塔罗/shader与APK资源校验通过。

原生Android15实际报告17 tests/0 failures/0 errors/0 skipped，artifact11167726170，ZIP168209bytes，SHA-2566e8433e2fd693b54eb9e0de9e8c5bb33cde3589f955f0b2ff58c2dd5cf6c80bb，已下载核验XML与ZIP哈希。新增三项为同一原生renderer热应用/回滚/缺失键默认值、同步失败保留错误并释放lease、旧模型恢复保留release/index与不热同步；已有settings-only外部文件/索引回归改为release=0及finish才sync。Flutter原生通道回归10项包括设置成功/回滚/部分apply失败/finish失败revision均不变，同时保留旧模型恢复revision+1和纯导出不刷新。生产reader与实际CaicaiCompanionView/SenRenderer通过模拟器验证；Flutter PlatformView实际手机屏幕表现尚未验收，不冒充TRUE DEVICE PASSED。

最终Draft401037240：[未发布+304测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-73790dec9e521a871822)，tagv0.42.60-settings-import-live2d-test，target9ba2f176。APK asset603408682，文件AI-Companion-v0.42.60-304-Settings-Import-Live2D-APK.apk，734320025bytes，SHA-256 ea7afacc400643c13e9f385627ccc31cd4c40ae2636549fc66ca101344dac707。SHA文件asset603408683、CI monitor asset603408681；APK workflow artifact11168014447，727411299bytes，其ZIPdigest f44a0080fec5f5d9427fb84e2d89052d74a316539a13895fad70d91898ce9a1c。Release计算的APK digest、CI sha256sum、ci-monitor-v0345/.ci/v04260-monitor.txt三者相符，monitor head/run/Release URL与本轮功能一致。Draft按tag REST读取404，改用授权Release列表解析ID401037240后核验，未用旧版产物代替。

实际APK签名305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与稳定测试签名及+303一致，可覆盖安装保留数据。所有131个离线Memory Galaxy资源在APK中hash-exact；原有Java renderer、宿主/GL生命周期、Dart Stage组件未改。+303资源排除、只读导出不重载、游戏推进/分享修复全部保留；外部资源不提交公开仓或重新打包进存档。

当前状态CI PASSED / APK READY / TRUE DEVICE PENDING；+303导出已获用户真机确认，不能据此把+304导入判真机通过。手机需覆盖安装后导入同一54.4MB新存档：人物无消失/重新载入、当前view/execution_id保持，动作/缩放位置/摸头区域按存档同步；导出仍不刷新，普通聊天/切页/输入法保留。不同设置、无已安装模型及旧完整资源包导入按各自范围验收。未合并main、未发布正式Release。


## 指定时长游玩持续中断 · 存档、诊断与源码对照（2026-10-01；DIAGNOSED / IMPLEMENTATION PENDING）

- 用户最新请求检查指定时间游玩为何在App卡掉、保存/读档及无明显卡顿或读档时中断。本轮检查基于+304功能9ba2f176及+302历史源码521effa7；不把前轮Live2D修改授权解释为本轮游戏功能已实施。产品代码、版本、APK均保持+304；用户实际导入Live2D观感仍待明确确认。
- 对照四份用户提供文件：2026-10-01T10-26-07备份、10-33-15诊断（+302），以及14-42-07备份、14-42-21诊断（+304）；文件名时刻为UTC，以下均为中国时间。用户原始包、诊断、对话全文和私密设置不进入仓库。
- 明确故障路径1：CedarPlaySessionStore.load要求时段processEpoch与当前Android进程一致；重启后拒读旧时段。CedarTimedPlayTaskStore.reconcile把period为空判作runtime_interrupted，生成终止回报、清空活动任务，并对匹配会话pauseAndRelease。Android两个FlutterEngine共用同一进程epoch，因此不能把正常多引擎并存误说成每轮必换epoch；桥接读取瞬时异常的兜底是否参与具体事件暂无证据。
- 明确故障路径2：snapshot_service普通备份导出的归一化副本及恢复设置都清空cedar_toy_play_session_v1；活动任务仍可在包内，导入后却找不到有效时段，于是同样runtime_interrupted。导出副本中的空时段或restored围栏不能证明保存动作清空了正在运行的本机时段。导出冻结会中止旧围栏内在途执行、暂停计时，原合同应为临时让路；不能把保存和恢复混称同一个直接终止入口。
- 历史正常中断：18:10:34开始30分钟白房间任务；18:24:00.685仍有成功cmd结果，18:24:11.739会话改为本地paused，18:24:16.174任务finished_or_waiting_user，18:24:26回报提前停止。33步、usedMs784318（约13分04秒）。+302即时备份显示solo、next_actor=companion、最后真实叙事未给终局；当时继续门allowed=true，疲劳约0.175、sleepDebt=0、restScore=0。即时诊断无同期重启，最后进程退出早于任务开始；故不能归因于疲劳或本次App重启。记录缺pause来源/调用入口，只能确认本地暂停随后被协调器当成任务结束，不能断定具体是谁触发，也不能把最终回复中的“等待交互”当真实服务器等待证据。
- 该设计缺陷在源码直接成立：reconcile用!session.needsContinuation判finished_or_waiting_user，而paused会使needsContinuation=false；同一分支混合本地暂停、等待用户和真实终局。规划失败原实现通常defer重试，并非所有规划失败都直接终止。后续应记录有界停止事件及来源/原前状态/任务id/epoch变化/围栏类别，保留首因而非仅最后理由。
- 第二次：22:23:45.375开始30分钟任务，22:37:34.202终止runtime_interrupted，成功4步；用户22:38:14明确说明此前App卡掉。经历13分49秒，但usedMs51616只约51.6秒。当前诊断只保存最近一次进程退出，不能用后来package_updated覆盖归因这一次具体崩溃类型。
- 最近一次：22:38:33.665开始20分钟任务，22:38:45及22:40:53成功两步；Android记录22:41:30.588历史退出package_updated，22:41:31.711新进程启动，22:41:34.217终止runtime_interrupted并本地暂停。对应安装更新重启，不是这次模型主动决定停玩。经历约3分01秒，usedMs19831只约19.8秒；最新允许继续门仍allowed=true、疲劳约0.373、sleepDebt=0、restScore=0。
- 明确计时缺陷：CedarPlaySession.tick仅累加gap>0且<=120000ms的整段；两分钟下一步间隔再加规划/网络耗时即可越界，导致整段不计。+303修正两分钟推进后更明显。不能用这个错误计数把十几分钟描述成实际只游玩几十秒，也不能通过无限放大间隔阈值把离线时间补成游玩。
- 建议后续完整修复：保留可迁移的任务意图、匹配会话与剩余有效预算；旧lease/fence/进程授权继续丢弃，当前Active Brain核对真实远端进度后重建执行状态，只续剩余预算。App离线/恢复/用户聊天暂让路均暂停计时；临时等待不终止任务，仅达到预算、明确终局、用户明确停止/替换或适用服务器限制等才形成准确终止回报。按已知活动状态/心跳计入正常两分钟等待与请求耗时，排除离线间隔；尊重服务器下一调用/等待时长，不重放未确认的远端写操作。保留唯一后台执行器、双引擎互斥及用户前台优先。
- 后续实施须修改原有“恢复旧进程即报告中断、绝不续玩”的明确测试合同，增加进程重启、同机备份恢复、当前Brain接管、本地暂让路、真实人类输入/终局、120秒以上正常等待、离线时间不计与两引擎重复协调等有效行为测试；完成后才可改状态为IMPLEMENTED/CI PASSED/APK READY。本轮无新增功能测试、无新构建，不宣称问题已修复。


## +305 指定时长游戏接续 · 实施授权与边界（2026-10-01 23:14 / 23:17）

- 用户批准上一轮排查后的修改，随后明确“本地暂停可以不用改，可以当作手动停止”；该最新决定覆盖前轮将所有本地暂停视为临时暂停的建议。本地暂停/手动停止仍取消当前执行、不再后台推进、保留远端进度；不得在恢复时自动复活已手动停止的任务。
- 授权目标：进程重启及读档保留任务意图、已用时长和剩余预算，丢弃旧进程lease/fence后由当前Brain重建执行状态；聊天抢占、存档冻结等暂让路不成为任务终局；修复两分钟等待加请求耗时漏计，补有界脱敏停止/恢复来源。真实终局、明确停止/替换、关闭与适用服务器限制仍结束并准确报告。保留真实服务端行动权/等待协议，不重放在途写操作；仅用已有唯一执行器与模型通道，不增加第二游戏循环或固定回复兜底。
- 基线功能9ba2f176、当前总账de5415e；新分支agent/v04261-timed-play-recovery，目标0.42.61+305，schema61/存档protocol7保持。旧+304测试APK和回退源不改变；最终需完整行为回归、稳定签名测试APK与总账证据，才可标CI PASSED/APK READY，真机仍待验。


### +305 用户追加澄清（23:21 / 23:25，覆盖先前建议）

手动打断按原设置直接终止当次任务，不保留待续预算；新“玩半小时”替换旧任务，预算从零开始，不叠加。保留现有手动中断及最终回报提示词，不增加“用户主动打断”等强调；新来源只用于脱敏诊断，不能进入回报正文。本轮修意外运行中断、读档与计时，未获授权改手动停止体验。


### +304接班快照原文（迁移保留）

## 当前接班快照 · 2026-10-01

当前分支agent/v04260-settings-import-live2d，功能9ba2f176/tree5281e748（tree全值见末尾），v0.42.60+304/schema61/ZIP protocol7/portable_state2，Actions36871635441成功，真机待验。设置导入保留视图并热同步；+303仅设置备份、持续单人两分钟与分享门保留。保护菜菜HC/GLSurfaceView、IME、摸头2.8秒、大settings读取、星谷只读。第二套Live2D未实现；旧桌宠素材暂缓；七大规则删除放弃。允许开发分支推送与Draft APK构建，不合并main/正式发布。后续文档提交不改变APK功能源码。



### +305 本地实现与构建前检查

- 已将用户任务与进程时段分离：当前Brain在任务/动作双lease下重建新clockId；保留预算和已落库结果，不迁移旧执行围栏。不恢复Desire自行获得的游玩授权；手动paused（含旧包缺pause_source）仍按原finished_or_waiting_user中性回报结束，不自动续玩。原Agent、态度暂停及最终正文提示词未改；来源仅在诊断32条环形控制日志中。
- 有效时长在原恢复唤醒每30秒检查，原动作租约45秒心跳保存长请求进度；普通推进保持120秒。指定任务三分钟无观测窗口才视为进程挂起，普通Desire授权保留原两分钟/日界规则；旧进程/恢复归一化的时段不计离线间隔。聊天生成入口、执行抢占及导出冻结只暂停时钟。新明确时长替换旧任务、usedMs从0开始；旧clockId和原子多设置比较拒绝恢复/替换后的晚写。
- 本地139门逐项检查：132通过；7项受当前容器未恢复的Cubism AAR、立绘/旧桌宠/特效/星谷素材和未装kotlinc阻塞。未跳过或放宽这些门，Actions沿用完整素材恢复和全部验证。新增真实SQLite双连接、时长/重启/同进程恢复/旧晚写/新任务不叠加/手动停止/等待与终局回归，以及实际备份导出/读档保留预算的验证；Flutter SDK本地不可用，行为测试待Actions执行。YAML、清单与差异检查通过，未宣称CI或真机成功。


### +305 并发完成清理复核

首次提交9828d3c/treec629e994已推送并触发Actions36888245042，原生烟测先通过，尚未交付。复核发现任务结束后的“暂停并释放”原为先读后写，前台在中间接管可能被旧后台清理覆盖；补充仅后台使用的原子完成清理，并比较原活动状态/前台lease/围栏/Brain，原手动方法流程保留。大状态比较在SQLite内返回单个整数，避免重新引入+299的CursorWindow大值问题；追加两个实际SQLite行为回归与本地SQL验证。该后续提交会替代首轮CI并自动取消旧运行，以最终源码和最终CI为交付准据。


### +305 最终源码与被替代的构建

- 并发完成保护提交86d0a01a/tree613fb8dc触发36890538387；随后检查Draft文案仍遗留+304说明，补正为本轮任务恢复与计时、保留手动Stop及中性回报。最终构建源码35a8f7633d623a527e94f5e8c5441c64e22721dd/tree6e5c762634d6fea5eb56d3b997fd983a318898fc，Actions36890835883。此前9828d3c和86d0a01a两次运行由新提交主动替代并取消，不是最终产物，也不作为功能回归失败。首次旧运行完整139门已通过，最终仍重跑全部检查。
- 最终CI、签名APK和真机状态须以随后成功证据更新；此处仅记录源码与替代原因，不预先宣称通过。


### +305 中间源码原生回归证据

Actions36890835883原生job110466094042成功。Android15实际XML报告17 tests/0 failures/0 errors/0 skipped，artifact11176213788，ZIP183234bytes，SHA-2561ba213f466c7bef44c36c65dadc8c965cfd552652d6544a60d9d0749c1b48e75；已通过下载工具取回并核验ZIP哈希/XML。包含+304同一renderer热应用/回滚/默认值、同步失败释放租约及旧完整模型恢复等，未把模拟器验收当真机观感。首次直接临时URL下载403，改用授权文件下载成功，不影响源码或CI。最终Flutter、完整构建及APK状态仍待后续证据。


### +305 测试调用复核与提前编译检查

复核发现新增回归中的finishExecution(execution)错误使用位置参数，现有方法要求executionId命名参数；已纠正为finishExecution(executionId: execution)。这是新增测试的可避免编译错误，35a8f763运行尚未完成Flutter analyze，主动取消并替代，不能把此前静态字符串门通过当可编译证明。最终构建源码9ff6bf25bb629b0a4b4830ed2c7a99eb7f30cc51/treee5beb5fa8d2914c40696af795fdddc1eaa439fdb，完整Actions36892634426。原生生产代码未变，仍以此最终运行重新校验。

额外只在临时开发分支agent/v04261-recovery-analyze增加快速分析workflow，ff863b0b触发36892856346，checkout显式固定9ff6bf25，对生产Dart与测试全量flutter analyze；不改变交付功能分支，不取代完整素材/原生/行为测试/APK构建。最终以完整运行及签名产物为准。


### +305 双数据库并发实际失败与修复候选

快速分析36892856346成功：checkout固定9ff6bf25，生产与测试编译无error；315条info/warning按原非fatal规则，不称零问题。随后快速行为lane64941cfe/Actions36893180747执行4份相关测试（仅不打包无关UI素材，完整APK lane仍保留全部素材验证），实际46 passed/1 failed。唯一失败为两真实SQLite连接同时恢复时BEGIN IMMEDIATE抛SQLITE_BUSY(code5)，不能通过单连接替代或顺序运行掩盖。其余重启/读档预算、临时等待、手动Stop、中性回报元数据、新时长不叠加、真实终局与两分钟节奏已通过。

候选7c089e3d106d932a26004658339cfa9f5c6d95af/treec22501bdca41b0f03c829cdf6176e2b64972eb77仅对tryAcquireLocalLease处理SQLite主结果码5：未获得数据库写事务时视为未获取逻辑lease，返回false，由原唤醒让路重试，保留所有原子事务/owner token/前台围栏，其他异常继续抛出。既有双连接行为测试保持不改。先由临时分析分支19f2b4f/Actions36894284006固定checkout候选，编译及47项复测通过后再推进功能分支和最终完整构建；在通过前不标修复成功。


### +305 锁竞争修复复测通过，进入最终完整构建

Actions36894284006/job110477250315对固定7c089e3d先全量analyze（无error，315 info/warning按原非fatal规则），随后实际47 tests passed。原双真实SQLite连接并发恢复测试通过，未改为单连接、未顺序化、未跳过。已将同一候选提交快进到功能分支agent/v04261-timed-play-recovery；最终完整Actions36894733801，source7c089e3d106d932a26004658339cfa9f5c6d95af/treec22501bdca41b0f03c829cdf6176e2b64972eb77。前9ff6bf25完整运行被新源码替代取消，最终以本次139门/全Flutter/原生/Kotlin/APK及签名证据为准。


### +304快速交付原文（+305期间迁移保留）

## 当前交付 · v0.42.60+304 设置包导入保留Live2D（CI PASSED / APK READY / TRUE DEVICE PENDING）

- 新版设置存档导入保留当前原生视图；提交/回滚后直接同步动作、缩放位置和摸头区域，缺失键回默认值。旧完整资源包仍恢复模型并重载。+303仅设置导出与两分钟游戏推进保留。
- 功能9ba2f176/tree5281e748，[Actions36871635441](https://github.com/catkiss62/ai-companion-build/actions/runs/36871635441)首次全绿：138源码门、1059 Flutter、原生17/17、Kotlin/analyze、稳定签名和131资源哈希通过。
- [未发布+304测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-73790dec9e521a871822)，Draft401037240/asset603408682；734320025bytes，稳定签名可覆盖安装。详细SHA及原生报告见正式记录末尾“+304最终构建、回归与APK证据”。手机导入观感尚待验收。


### +305 最终源码原生回归（7c089e3d）

Actions36894733801/job110479233862成功，Android15实际XML17 tests/0 failures/0 errors/0 skipped；最终artifact11179416978，ZIP191841bytes，SHA-2567fe5a1e5cdd925a96f3318b687db3c8081016d3f171ff292527b36fd577f77fb。已取回并核验哈希和XML，source固定7c089e3d；不使用被替代35a8f763的原生结果冒充最终。当前继续完整素材恢复/139门/Kotlin/全Flutter与签名APK，原生通过不等于最终构建或真机通过。


## +305 最终完整构建、签名与交付证据（2026-10-02；CI PASSED / APK READY / TRUE DEVICE PENDING）

最终功能源码7c089e3d106d932a26004658339cfa9f5c6d95af，treec22501bdca41b0f03c829cdf6176e2b64972eb77；分支agent/v04261-timed-play-recovery，0.42.61+305，schema61/存档protocol7/portable_state2保持。完整[Actions36894733801](https://github.com/catkiss62/ai-companion-build/actions/runs/36894733801)conclusion=success，buildjob110481301479成功、失败诊断job跳过。功能分支未合并main，Release保持Draft。以下正式交付覆盖此前IMPLEMENTED/CI PENDING以及所有被替代运行；后续总账文档提交不改变此APK源码与树。

139项完整验证门通过；Kotlin桌宠/菜菜/文本/ANR脱敏/隐私/备份/资源单元测试通过；Flutter analyze按原非fatal info/warning规则通过（314 info/warning、无error）；实际1082 Flutter tests passed（+304的1059基础上新增23个有效行为用例，原有测试合同按用户授权更新）。最终Android15原生17 tests/0 failures/0 errors/0 skipped、artifact11179416978及ZIP哈希核验见上节。另临时分析分支Actions36894284006对同一7c089e3d固定checkout，无UI素材打包的47项专项实际测试通过；仅作提前反馈，完整构建仍恢复全部固定素材、执行全部139门与1082项行为，不跳过原生/资源门。

修复结果：可迁移的指定时长任务与进程游玩授权分离；重启/读档后当前Brain在原任务/动作lease下以新clockId续用已保存预算，旧lease/fence和Desire自行授权不迁移。30秒原恢复唤醒与45秒原执行心跳保存正常两分钟等待及请求耗时，超过可观测窗口、离线及临时前台让路不补算游玩；保存冻结只暂停时钟，实际备份往返保留任务usedMs。后台完成清理和晚写比较状态/时钟/任务/前台围栏，SQLite大状态比较只返回整数；数据库写事务忙时获取lease返回未获取，由原唤醒重试，其他异常仍抛出。双真实连接并发测试保持不改且已通过。继续使用原唯一执行器、已落库结果和服务端下一调用/原不确定结果处理。

按用户23:17/23:21/23:25最后决定，本地暂停/手动中断仍直接结束当前任务，含旧包缺pause_source的本地paused状态不自动复活；新“玩半小时”从零替换，不叠加旧余额。原Agent工具、态度Pause和最终回报提示词未改，来源仅进入32条有界脱敏诊断，任务回报不含来源/epoch/clockId。真实终局、关闭、适用限制仍按原门结束；临时等待、重启、保存/读档不再被通用runtime_interrupted分支误判终局。两分钟普通单人推进、5/10/1轮分享及+304 Live2D导入不重载均在原生/Flutter回归中保留。

最终Draft401142295：[未发布+305测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fd6b8028d13084f6cc9f)，tagv0.42.61-timed-play-recovery-test，target7c089e3d。APK asset603731423，文件AI-Companion-v0.42.61-305-Timed-Play-Recovery-APK.apk，734330053bytes，SHA-256d4ef7a761b48cc2afc0dfd784abc08c08d839240c7159deecf607386661cf669。SHA文件asset603731424、CI monitor asset603731430；workflow APK artifact11179284801，ZIP727423386bytes，digest e50f062a75dcbc2c4beb2aef882a8d670344a19f9f8730c5965d17d68efbf9dd。授权Release列表、CI实际sha256sum与ci-monitor-v0345/.ci/v04261-monitor.txt的run/head/URL/hash一致，未用旧包替代。

稳定测试签名305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，实际APK签名校验步骤成功，与+304及前轮稳定身份一致，可覆盖安装保留数据。所有131个离线Memory Galaxy资源在APK中hash-exact；外部导入Live2D/表情包不重新打入存档，不提交用户原始包/诊断或私密配置到公开仓。原生/Flutter检查通过不证明手机视觉或远端模型规划自然语言已验收。

真机重点：覆盖安装后发10分钟或20分钟游戏任务，正常两分钟推进；切出后重新启动、保存/读档或聊天暂让路，回来只续剩余有效预算，离线不算、无重复终止回报；手动停止后重启不得恢复已结束任务；读取停止后保存的存档也不得续玩。新半小时不叠加旧余额，结束语气沿用原设置。同时检查设置存档导入人物无重载、导出保持外部资源排除。真实终局/关闭等仍正常结束。当前CI PASSED / APK READY / TRUE DEVICE PENDING；用户未回报本版真机结果，不宣称TRUE DEVICE PASSED。


## +306 开始修复与 +305 真机反馈 · 2026-10-02

## 当前交付 · v0.42.61+305 指定时长游戏接续（CI PASSED / APK READY / TRUE DEVICE PENDING）

- [未发布+305测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-fd6b8028d13084f6cc9f)，Draft401142295/asset603731423；734330053bytes，稳定签名可覆盖安装。
- 重启/读档后只续保存的剩余有效预算，聊天与存档冻结暂让路；两分钟等待与长请求正常计时，离线不计。本地手动停止及原中性回报保持，新指定时长从零替换、不叠加。
- 功能7c089e3d/treec22501bd，[Actions36894733801](https://github.com/catkiss62/ai-companion-build/actions/runs/36894733801)成功：139门、1082 Flutter、原生17/17、Kotlin/analyze、稳定签名及131星谷资源哈希通过；另47项专项实际行为通过。完整SHA/替代及失败路线见正式记录末尾。手机实测待验。

用户报告指定时长工具登记后对话卡住、读取存档慢。实际+305诊断显示第二通道启用，工具阶段成功，最终正文未提交；两次工具后等待分别约89秒（用户停止）和约61秒（导出时），不能凭此声称已证实服务端永久挂起。新备份76418行，state.json 34293945字节，恢复每行独立await txn.insert。代码确认聊天续期依赖delta、原网络超时作用于原始字节（保活会重置），分别修复为既有取消围栏续期、有效delta无进展超时。第二通道策略/重试次数/120秒阈值保持。批量恢复128行或256K字符一批，仍在同一事务；不截断大settings，不删除历史。新增专项行为测试与阶段诊断；测试和APK待完成。用户私有备份/诊断不提交仓库。


### +306 三版对照、实际连接与专项验证 · 2026-10-02 02:08

- 对照功能：+303 afe1baa5、+304 9ba2f176、+305 7c089e3d；前三版deepseek_client、final_reply_route、agent_tool_runner对应Git blob完全相同。+303→+304功能差异是Live2D设置导入，不改游戏/正文流程；+305在durable runner进入生成前增加游戏时钟pause，另改游戏恢复/计时/写入围栏。
- 用户的新截图01:58显示钓鱼10分钟同样停在已登记、活动已在本机暂停。17:32备份实际白房间旧session是paused且pause_source为空，01:29、01:31只有新guide事件，没有新play outcome。不能把工具登记当游戏已经开始；三版均在正文提交后activateCommitted。
- MCP实际只读连通探测：Cedar首页HTTP200约10.28s；initialize/tools/list/list_games均403。进一步读取403响应确认Cloudflare1010 browser_signature_banned；在确认拒绝后停止重试，未换身份绕过。此环境访问被站点拦截不证明官方宕机；用户01:31目录/指南约2s成功。无用户Token/API密钥被导出/提交/打印，也未改其远端游戏进度。两个备份的正文provider、endpoint、model一致（第二通道启用），不是此次升级换了正文配置。
- 候选1fe7577、019199d的第一轮快检36903090152：完整流程四版均通过提交/激活断言，但测试把一次内部DeepSeek判断计成第二次最终正文，计数断言失败；修正为按真实第二通道endpoint计数，没有放宽提交/任务激活断言。另无进展超时用内层async*过滤SSE，取消会等待下一yield，空保活测试真实超时失败；改为可取消的asyncMap/filter流解析，保留原失败用例，不降低门。
- 最终候选65b21322693b4e9b67f907a9d476d9ff90cf286f/tree6e4d99b7e860525b62165d200393999001931a59。快检36904052231全绿：分析无error（316既存/提示级问题），72项行为测试通过；独立matrix将同一timed_reply_pipeline_v04262_test放到+303/+304/+305/+306，四组全部成功，覆盖真实runner、本地native timed tool、模拟第二通道正文、SQLite正式提交、paused游戏恢复激活。不是外网模型/MCP游戏实测，不能将它等同用户真机根因已修复。
- 无输出期间改在既有取消围栏检查续30秒聊天租约，10秒间隔；不会另起游戏循环或请求模型。失去所有权只suspend，显式用户Stop仍cancelled_by_user。SSE无有效delta才触发120秒deadline，空保活不续命，错误HTTP响应体也有deadline；保留原第二通道两次尝试及失败后DeepSeek兜底策略。诊断增加body-free generationRequest和backupRestoreTiming。
- 实际存档76418行，按128行/256Ki字符批次估算632次插入batch代替76418次逐条调用；不裁剪历史、不截断大setting，单一事务保持。4万行实际SQLite完整恢复、末尾坏行回滚全部旧批次、大于3MiB设置无损测试均通过；手机实际耗时待新诊断验证，不能拿CI速度当手机速度。
- 本地当前139门中132通过，7项因缺资源/原生工具等待完整Actions恢复（不是逻辑失败）；误对273个历史validator全量执行的结果不作为当前门。完整APK36904432860已开始，尚未交付，后续文档提交不改变65b2132功能构建源。


### +306 最终构建交付 · 2026-10-02 02:32

- 功能源65b21322693b4e9b67f907a9d476d9ff90cf286f/tree6e4d99b7e860525b62165d200393999001931a59；完整Actions36904432860（18:07—18:31 UTC）success。139项源码/回归门、Kotlin原生测试与编译、Flutter analyze（316 info/warning按既有非fatal规则，无error）、1092项Flutter测试、arm64 Release APK、稳定签名和固定资源校验全部成功。快检36904052231的72项及四版本模拟流程成功证据仍见上节，不能替代外部服务或手机验收。
- Android15原生报告17 tests/0 failures/0 errors/0 skipped；Artifact11182599694，ZIP195846bytes，SHA-2565e78e7c66800a4a2d97d420bd58ea0bbc66ef6e290082e16a159991faf223ce4，已下载核验XML。APK内131个离线Memory Galaxy文件、49个Genie/Jiuhu/OpenJTalk文件与22个塔罗JPG均hash-exact，桌宠等完整载荷门全部通过。
- [未发布+306测试包](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-47419c1a160cf54bd59a)，Draft401242273/tag v0.42.62-reply-wait-restore-test，target65b2132；APK AI-Companion-v0.42.62-306-Reply-Wait-Restore-APK.apk，asset603874804，734338929bytes，SHA-2563aa13a278f75eb501921a1513bb30f2da96e01090ea09f60efaa56f840baf793。CI实际checksum、GitHub资产digest、ci-monitor-v0345/.ci/v04262-monitor.txt一致。工作流APK Artifact11185311176（压缩包digest c6a1dce43caee3eb81e8b73d6ec2cf07fc975514f099f633388ea727899ed89d）。未在本机再次下载734MB APK，不冒充本地重新验签。
- CI实际V2签名证书SHA-256305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与前版稳定测试签名一致。仍为Draft测试，不合并main、不正式发布。
- 交付边界：修复已确认的无输出租约续期/SSE有效进展超时缺陷、批量事务读档和脱敏阶段诊断；这次真实手机“登记后没有正文”的直接根因仍未证实，不能声称根因已修复或官方宕机。公开MCP探测被Cloudflare1010阻断后已停止，未绕过拦截、未用用户身份实际启动远程游戏。新版指定时长正常回复并开始游玩、真机读档速度仍为TRUE DEVICE PENDING。
- Draft原工作流沿用+305说明，已由仅说明修正的临时工作流36907621577成功替换为+306实际改动和未确认根因边界；helper提交85fc7f09edf0e0d30f8d4496e2a12627501a3f23。修正前验证完整构建success及Draft/target65b，修正后API复核正文一致、draft仍true、APK目标与资产不变；不重打APK。
- GitHub在编辑Draft说明后将html_url更新为untagged-47419c1a160cf54bd59a，顶部及交付链接已同步最新API；CI monitor保留构建时旧Draft路径，run/head/checksum不变，Release id401242273及APK asset603874804仍一致。


## v0.42.63+307 · 实施边界记录

用户已指定 **0.42.62+306 为真机可用的对照/回退基线**，无需额外整包备份。基线源码 65b21322693b4e9b67f907a9d476d9ff90cf286f；新分支 agent/v04263-stability 从公开提交 a77f5191c7dc74ee6daaede040ac60fec6f6be10 开始。IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING。

本批处理恢复一致性、异步写入、下载等待、提醒同步及沉浸房间写入边界，补故障测试后再交付。保留手动停止、中性回报、两分钟推进及设置读档不重载 Live2D。桌宠渲染和图片地址过滤暂缓；工作区、陪玩模型及低频澄清另批。基线可用不代表此前所有长时场景都已验证；具体历史证据保留。


## +307 稳定性第一批实施记录

用户指定Astra xhigh实施，以0.42.62+306为可用对照，不要求整包复制备份。独立分支agent/v04263-stability从a77f519开始，候选0.42.63+307。原始内部审查记录不进入公开分支；此处仅记录批准的实施范围和测试状态。

已实施：读档持久化恢复日志与启动恢复、SQLite提交判定及准确完成提示；异步任务在最终写入事务核对状态身份和租约；沉浸房间待机写入保护及准备失败时释放租约；图片/MCP请求的时间和体积边界、取消清理；提醒镜像按当前存档同步；读档校验及JSON解析移出UI线程；主进程与语音子进程退出记录分列，Dart异常只记录类型、函数标记和指纹。

提交d986dd9、2d11c37、5784a2a分开保存。前两次专项测试暴露未消费流取消、Dart构建提示误判，均保留失败证据；第三次Actions36933085939通过。包含九个真实SIGKILL故障切点，以及图片、MCP、旧状态写入、沉浸租约、恢复收尾及原有游戏节奏测试。完整原生/Flutter构建尚未完成，不称APK READY或真机验收。

本批保留模型双通道、手动暂停即停止且不累计剩余时长、不强调由谁打断、单人两分钟推进、5/10/1轮过程分享。设置存档不包含外部Live2D/表情包资源，设置导入不重载模型；老资源包仍兼容。不动桌宠渲染/动画和图片地址过滤；闪退根因尚未证实。API凭据来源绑定需要协调多通道旧配置及恢复回滚，不符合本轮可选项“小改且低风险”的前提，暂不实施。分享夜间规则需确认设计，保持现状。

下一批：游戏任务状态说明、提醒时效展示、离线结束房间、低频澄清；工作区与陪玩模型后续讨论。本次提醒生成已提供真实计划时间，但完整时效体验仍随下一批验收。读档改善仅确认工作移出UI线程，实际设备耗时/内存尚待测量，不承诺固定加速比例。

### +306 原接班快照（原文保留）

## 当前接班快照 · 2026-10-02

当前分支agent/v04261-timed-play-recovery，+306功能65b21322693b4e9b67f907a9d476d9ff90cf286f/tree6e4d99b7e860525b62165d200393999001931a59，Actions36904432860完整success，Flutter1092/原生17项通过，139门、Kotlin/analyze及资源签名通过。[+306测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-47419c1a160cf54bd59a)。+305用户真机报告工具登记后无正文，不能称已验收。三版同一完整模拟流程与+306候选均通过，专项72项通过；真实第二通道卡住直接原因仍未确认。Cedar首页实测HTTP200，MCP被Cloudflare1010拦截，不能据此宣布官方宕机。schema61/protocol7/portable_state2不变；手动Stop与中性回报、两分钟推进、5/10/1轮分享和Live2D设置导入不重载保留。允许开发分支推送/Draft构建，不合并main/正式发布。其余证据与保护见正式记录。

## +307 最终构建与交付证据

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。功能HEAD 5ad45f0bbc159d8300ba1e75ab324555d2ef7a9d，tree96c4e8c17781b1da5f944c2439c6483a9b34e6b1；后续此总账更新不改变APK源码。Actions36946211181完整成功，专项36946211173成功。139项源码门、1136项Flutter测试、18项Android15原生测试、Kotlin单元测试、Flutter analyze、arm64 Release、资源哈希和稳定签名检查全部通过。杀进程九切点包含rename中间、SQLite事务中、提交后收尾及重复启动恢复；不以正常抛异常替代实际进程退出。

[+307未发布测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f766059b1837df323a54)：Draft401461684/asset604466459，734363521bytes；SHA-256964e2964c757229b73a3d5ac77ced9046662bd5bd62a067b4da46844406b18ee。GitHub资产digest与构建checksum、ci-monitor-v0345/.ci/v04263-monitor.txt一致；签名305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148与+306一致，可覆盖安装。未合并main、未正式发布；+306原Draft与源码保留。

最终差异核对：Cedar任务/自主游戏逻辑、主动分享规则、Live2D Java渲染及PlatformView宿主均未变更。新增MCP流式响应按请求ID收取正式结果，不调整40秒游戏等待配置。已通过原有游戏状态机、节奏和双通道相关回归。用户无需手工复现故障注入，只需继续留意日常聊天、游戏、读档和提醒；具体手机读档耗时、Live2D外观及长时使用仍属真机待验，偶发闪退只补证据采集，未宣称根因已修。

本轮至此完成第一批稳定性修复。下一批体验/低频澄清未在此版本实现；可选API来源绑定暂缓，桌宠及图片地址过滤按用户决定暂缓。早前失败CI与中间状态保留为历史，不覆盖最终成功证据。


### +307 交付时接班快照（历史原文保留）

## 当前接班快照 · 稳定性第一批

分支agent/v04263-stability，候选0.42.63+307；+306为用户确认的可用对照。专项85项通过；完整Actions36946211181通过，[+307测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f766059b1837df323a54)已生成。schema61/protocol7/portable_state2保持。手动停止、中性回报、两分钟推进、5/10/1轮分享和Live2D设置导入不重载保持。允许开发分支/Draft构建，不合并main、不正式发布。上次接班快照完整移至文末。


## +308 接班与实施记录 · 2026-10-02

接班核对了上窗口大检查工作记录及大检查后决策、+307实施/交付总账、当前分支HEAD/最近五提交和最新Actions摘要。远端稳定分支HEAD与本地一致。上窗口只建立体验分支，尚未写第二批补丁；不存在需要拼接的半成品。历史上下文工具恢复了四项方案与用户批准，但没有逐字完整对话，不能称整窗口逐字已读。低频澄清按现有Phase4边界（高影响歧义/连续反证、偶尔一次、非问卷、不自动改人格）实施，不扩展娱乐测试。

开工状态：四项均未实现、待专项与完整CI；+307用户真机验收补记为通过日常测试。后续逐项追加真实修改、失败路线及最终证据。

### +308 本地实现、复核与推送阻塞（本窗口结束检查点）

第一份本地功能提交ac7f086，随后修正和+308构建元数据在同分支。没有成功推送、没有+308 Actions或APK，不能报CI或真机通过。+307日常真机认可已确认，顶部旧交付时的PENDING仅属历史状态。

- 游戏：只读投影pending/active/本进程有效计时/待回报/终态诊断，区分登记、首次推进前、正在玩、恢复、等待和结束。显示保存过的有效时长，界面不启动任务、不扣时间、不计离线时长；手动Pause仍终止本次任务，回报后可看到上一时长任务已结束。增加game/session诊断标识以正确匹配，不改执行、两分钟节奏或5/10/1分享。
- 提醒：原定/当前时间及延迟进入既有最终正文调用，往日事项按回顾表达，不能假称刚到点或已完成，不猜真实事项是否失效。延迟超30分钟的积压提醒至少间隔10分钟，以已落库消息为依据；保留确定ID去重/确认及原双通道。列表显示原定时间已过但完成未知，年度闰日不误当3月1日。
- 沉浸：本地结束和待归档记录同事务，不等API；后台/房间列表闲时重试，原文保留、失败指数退避。摘要/筛选记忆/清任务同事务；删除、读档身份变化、待机及租约失效阻止迟到写入。结束后拒绝旧正文/滚动摘要，接管等待与恢复清理加入归档租约。沿用DS内部整理与虚构记忆标识。复核去掉controller直接原生唤醒，维持平台隔离，由列表和恢复协调器调度。
- 低频澄清：仅相关普通用户轮次，重复支持/反证且仍未解决的高影响相处倾向，或同主题高重要度事实与重复推断分歧。明确纠正/边界不再要求确认。全局至少3天、同项至少30天且须新证据；旧证据不因沉默或时间过去而重复。只记offered，不记asked/answered；不新增模型调用、不改人格或记忆，回答走原MemoryExtractor证据和版本流程。角色扮演、主动消息、工具结果轮次及显式亲密路由不注入。

本地验证：139项源码门逐项执行并对照未改动+307工作树。初次128通过；新增两处失败是顶部索引超100KB及旧沉浸门仍查同步endRoom，均已修复（+302顶部全文移至文末不删史；检查实际worker归档/时限/任务身份）。另两项是调用cwd错误，改在app下执行通过。因此132/139本地通过，余7项与基线一致，缺本地私有/构建资源或kotlinc（Cubism AAR、立绘、417桌宠、Lingchat、星谷两门、Kotlin密码门）。YAML和diff格式检查通过。15项新增Dart行为测试覆盖离线结束、退避、摘要/记忆原子回滚、删除/真读档/待机时迟到结果、并发worker、结束后拒绝旧消息、游戏只读投影/Stop、提醒时效、澄清频率/明确纠正；本地无Flutter SDK，尚未执行，不把源码门当行为通过。

失败/阻塞：git push新分支被自动审批拒绝，理由为当前窗口没有足够明确的新分支/仓库内容外传授权。未改用GitHub写API绕过；只读检查确认该分支无Actions。定点检索没有找到明确覆盖本次分支的用户授权原话。SDK下载尝试404/超时，未获得Flutter SDK。后续本地执行环境还发生暂时503，不将未执行命令当作成功。

下一步：用户明确授权将agent/v04264-experience现有源码及本轮必要修正上传catkiss62/ai-companion-build、运行CI并构建未发布测试APK后，先跑新增15项和原相关测试/analyze，再完整139源码门、Flutter、原生、签名/资源构建。只推开发分支，不合并main、不正式发布、不上传存档诊断或私有模型。无需重做全面接班/第一批。其他候选仍从6.3及+307末段取，桌宠/图片地址过滤/工作区/陪玩模型不混入本批。


### +302完整历史交付索引（接班顶部原文迁移，内容保留）

## 当前交付 · v0.42.58+302 导出刷新、侧栏焦点与星谷交互（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户2026-10-01 10:02授权按五色方案实施，并修导出后Live2D重载和侧栏输入法；延续长按最近记忆方案。基线+301功能54a15696、总账552b78e4（本地addda81同tree48bab8ab），分支agent/v04258-backup-focus-galaxy-pick，版本0.42.58+302；schema61/protocol7保持。

- 纯导出只结束读取租约；真正尝试应用原生恢复后，成功或回滚均刷新Live2D。保留完整存档和大settings无损读取，不调整渲染/生命周期。
- 统一侧栏入口先清除输入焦点及恢复历史，保留草稿和正常点选输入。
- 五色：共同经历#ff7ec4、用户资料#7ed9cc、AI Self#b98cff、偏好/边界#8f9fff、其他#ffa18f；重要度大小/亮度保持。
- 550ms单指静止长按选择屏幕投影最近的可见真实记忆，无距离上限；短按保留射线选择。拖动、多指、取消、失捕、后台取消长按；不选装饰星/镜头后/屏幕外/空库。只读、不加模型调用。
- 新增真实Android触摸、13项JS行为与6项原生通道通知回归均通过；沿用稳定测试签名，既有2.8秒摸头彩蛋、游戏分享、四角吸附及已认可星谷外观保留。

最终[Actions36805517505](https://github.com/catkiss62/ai-companion-build/actions/runs/36805517505) success；功能521effa7/treeea8702ee，136源码门、Flutter1048、原生13/13及Kotlin/analyze通过。131个星谷APK资源哈希一致，真实640条五类PNG已查看。[未发布+302测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-65dae53b720ceb33676f)，Draft400607040/asset602289499，734320437bytes；APK SHA-2566f678acfaaed3e1883c091b9f979294aa9b9c375e8767d2f5694d039ca39265d与monitor及Release digest一致。手机导出返回载入、侧栏输入法及触摸观感仍待验；详细证据见末尾+302最终记录。


### +308 授权后继续验证 · 2026-10-02 16:32（北京时间）

用户明确授权将agent/v04264-experience当前改动及本轮必要修正推送到catkiss62/ai-companion-build、运行CI并构建未发布测试APK，不合并main、不正式发布。承接本地6be25b3/tree a89680bf；因当前文件权限变化，在当前可写目录建立独立Git副本，源码树保持一致，不修改旧工作树。先执行既定专项/analyze与完整构建，实际失败与最终证据继续追加。


## +308 首轮 CI 与手动暂停必要修正 · 2026-10-02

用户本轮明确授权后，GitHub 接口推送远端功能提交 `70b0bcf10dc485a4c273ebbd14f61194e3e6b739`，tree `7cd9779d50be9adb28d45c719289225316f8a59b` 与本地 `a46f17e` 完全一致。原生 git push 因本机无 GitHub 登录凭据未成功，随后使用已连接接口完成，没有绕过授权；只更新 `agent/v04264-experience`。

首轮专项 Actions `36985080998`：Flutter analyze 成功，行为测试99通过/1失败；失败在新增游戏状态测试的手动暂停后 active task 仍存。检查实际窗口按钮同样只调用 `CedarToyActivityStore.pause`，依赖下次后台 reconcile 结算；若立即恢复可能绕过暂停终止，故不能仅放宽测试。修正 store.pause：先取消执行并持久化暂停，同时取消未提交登记，再立即使用现有 end/finish 原子结果路径结算，保留 `finished_or_waiting_user` 中性原因。已暂停重复操作也结算；不累积旧时长、不添加游戏推进或新循环。补测立即恢复后无旧任务/时钟、回复晚到不能激活已暂停登记；本批行为用例增至16。

首轮完整 Actions `36985081071` 已启动；截至修正时原生烟测进行中，不能记为通过。后续最终 Actions 与APK证据以追加记录为准。此次必要修正本地 v04261 时长恢复/围栏/中性停止门和 git diff --check 通过；Flutter 仍以CI实际执行为准。


## +300完整历史交付索引（从快速索引完整迁入，不删历史）

## 当前交付 · v0.42.56+300 游戏分享间隔、旋转、持续摸头与存档完整性（CI PASSED / APK READY / TRUE DEVICE PENDING）

用户2026-09-30 23:22批准以下修改；基线+299功能a2341425、总账526e1bb4，本地同tree df232243；独立分支agent/v04256-game-share-portable-state。授权推送/构建延续，不再重复确认。

- [x] 游戏厅三按钮改成“10轮回复 / 5轮回复 / 1轮回复”，等宽、默认5轮，选择持久化且后台同样生效。普通单人自主推进固定至少2分钟；已承诺的多人事件监听/轮到用户/服务器定时协议不靠UI按钮加速，也不把轮询算推进。
- [x] 5/10/1为两次过程分享之间的最少成功游戏推进轮数；指定时长任务、自主半小时竞争和普通自主推进共用门。无值得分享的进展不发，到轮数不强制播报。默认5轮约10分钟而非严格定时器；失败、查询、等待不计。
- [x] 一次正文可概括多轮尚未分享的已保存结果；消除旧最近6条导致10轮信息不足，保留事件身份、排队合并、用户聊天/沉浸/Brain/写入围栏。分享判断仍合并现有DeepSeek下一步规划，Gemini一次最终正文；不增加逐步判断调用。任务终止结果回报仍独立必达，不再等待攒满轮数。
- [x] 只调整自制@rootTilt、小腿支点整体左右旋转：Jev目标速度接近自主待机、略快；检查接管、反向、退出和回到待机，保留身体XYZ及头/表情/平移原效果。
- [x] 2026-10-01 00:31追加、02:04最终修订：Live2D自制摸头在有效手势按住期间持续表情，UP/CANCEL才恢复；头部自身移动导致触点暂离区域不应提前松开。彩蛋采用原总时长2.8秒（2.2秒开始淡出、0.6秒淡出），期间新普通摸头或重复彩蛋不能抢占/重置计时；保留原10%概率与平滑恢复。参考Sen按住/松开机制，勿改模型自带表情；不改其它4.5秒临时表情。
- [x] 左栏代办提醒上方增加记住事项入口，复用原页面和同一数据源，不改重要性/提醒逻辑。
- [x] 完整存档审计并补齐可迁移的Live2D当前模型/配件及舞台偏好、SecureConfig非密钥配置、表情包及桌宠显示/位置偏好；API Key/Token/密码仍排除，设备身份/进程lease/旧游玩授权不复制。普通备份与接管包均核验，旧包兼容；新机导入无模型、哈希损坏、部分失败保持事务回滚，实际模型不提交公开仓。
- [x] 专项行为、134项源码门、Kotlin/Android单元测试、Flutter analyze及1033项测试、Android15原生9/9、arm64签名APK均通过；真机仍待验收。保留+299大settings无损读取和已批准白天图。

最终CI：[36756872531](https://github.com/catkiss62/ai-companion-build/actions/runs/36756872531) conclusion=success；功能源码620e08852283d6a5389d307e161d02166443785d/tree85471e6f48418947e81b3ca225d0b801c4fdfe94，与本地fe10a850同tree。摸头彩蛋为原2.8秒，其余本轮任务完整保留。失败/替代的前三轮记录见正文，不作为最终交付。

[未发布+300测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-509ccfd78b2217c9fdc2)，Draft400290010/asset601559245，727767998bytes，SHA-256 c6049f59ccaec150d26d71bcdaf1ff5b28272a025aee1f8658832a7ec851fcbf；稳定签名与+299一致，可覆盖安装。Release target、CI head、ci-monitor-v0345/.ci/v04256-monitor.txt及GitHub计算的APK digest一致，代码和安装包都采用2.8秒。真机尚待游戏分享节奏、连续摸头、旋转观感与实际设备存档往返验收；不宣称TRUE DEVICE PASSED。

旧桌宠图片任务暂缓，且用户纠正大肥鱼/小小鲸是立绘而非旧桌宠；原六项方案中的素材路径仅是立绘路径，不能据此替换旧桌宠。七大规则删除任务明确放弃，其页面与共享导入导出均保留。




## +308 修正后验证进度 · 2026-10-02

修正功能提交远端 `dad52be3c45f97f7aa2064eca8dceb70e68d194f`，本地 `1d1d451f33efdd9f79c1e588e9c85cea89383253`；两边tree均 `53553806c2cc74a0141a0249ee8fabfd0ca461b0`。专项 Actions `36985831218` success：Flutter analyze成功，101项行为测试全通过，含本批16项。新版完整 Actions `36985831222` 已通过 Android 15 原生18项（08:51 UTC日志BUILD SUCCESSFUL），正在恢复固定资源；全量 Flutter/APK/签名资源验证此时仍 PENDING。首轮完整 `36985081071` build job cancelled，不能作为最终构建。

为保持快速接班索引小于100KB，将+300完整历史交付段落原样迁入正文末尾；冻结归档未改变，唯一总账门通过。最终交付后需追加最终完整CI、Draft/asset/校验值、签名和真机待验事项；不得把上述中间进度当最终交付。


### +308 真机待验边界（CI不能代替）

- 游戏：指定时长回复提交前显示已登记；提交后按保存的有效计时显示，不把打开窗口当作授权或推进。中断/读档后恢复等待不能算离线时间；手动暂停立即结束旧任务，快速继续不能恢复旧剩余时长；终止后结果仍走原有中性回报，已送达仍可见上次结束状态。
- 提醒：断网跨日/过期事项重连后应说明真实计划时间与延迟，不假定事项已完成或仍需马上执行；积压补送沿现有幂等消息路径并至少间隔10分钟，不连发多条。
- 沉浸：断网时本地结束立即成立且保留完整原文，显示待整理；重启后任务仍在，有网络且不占用主聊天时补整理，失败继续保留原文；成功仅入一次共同记忆；删除、读档、待机期间迟到结果不能越过围栏写入。
- 澄清：仅重要、相关且有双方证据的普通话题可能自然出现一个简短可选问题；不要求每次触发、不新增每轮规划；明确纠正/边界应直接尊重，沉默不确认、不追问。真实回答仍走原有证据与记忆版本链。
- 回归观察：普通双通道最终正文、单人两分钟与5/10/1轮分享、设置读档不重载Live2D继续按既有契约；真机未报告前不标TRUE DEVICE PASSED，不把+307日常验收扩展到+308。


## +308 最终CI与未发布APK交付 · 2026-10-02 17:10（北京时间）

状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。本批四项全部完成；新增16项行为测试并修正首轮CI暴露的手动暂停即时结算遗漏。不是只写方案或只编译；但未在用户手机运行，不得记为TRUE DEVICE PASSED。

- 功能源码：远端 `dad52be3c45f97f7aa2064eca8dceb70e68d194f`，本地 `1d1d451f33efdd9f79c1e588e9c85cea89383253`，tree均 `53553806c2cc74a0141a0249ee8fabfd0ca461b0`。最终总账回写仅修改本文件，不改变产品/工作流/资源或已构建APK；保留不同提交历史下源码树完全一致的验证方式。
- 专项 [Actions36985831218](https://github.com/catkiss62/ai-companion-build/actions/runs/36985831218) success：Flutter analyze和101项行为回归通过。首轮99通过/1失败及实际代码修正已在前文保留，不隐去失败路线。
- 完整 [Actions36985831222](https://github.com/catkiss62/ai-companion-build/actions/runs/36985831222) conclusion=success、head=`dad52be3`。Android15原生18项通过；Source and regression validation139/139通过；Kotlin测试BUILD SUCCESSFUL；Flutter analyze通过；Flutter全量1152项通过（其中experience_v04264_test.dart16项）；arm64 Release APK构建及所有APK资源/签名验证通过，report-ci-failure跳过。
- APK：[未发布+308测试包](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0cac33eb64faac342d0c)。Draft release `401660027`，tag `v0.42.64-experience-test`，draft=true、published_at=null、target=`dad52be3c45f97f7aa2064eca8dceb70e68d194f`。APK asset `605227641`，文件 `AI-Companion-v0.42.64-308-Experience-APK.apk`，734386153字节。SHA-256 `fbe209532a97c5756520e1e1bbe94e5e190020b47f7ce2594ae2eacaa777a43f`，与构建日志、ci-monitor-v0345/.ci/v04264-monitor.txt和GitHub实际资产digest逐一一致。
- 持久签名：`305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，apksigner与CI monitor一致，沿用既有测试签名，可覆盖安装。Genie运行库字节身份、桌宠素材、Caicai边界、塔罗与离线记忆星谷资源均由既有APK检查通过；本批没有改动桌宠渲染/模型素材。
- CI Monitor asset `605227647`；checksum asset `605227642`。Workflow APK artifact `11217304620`（727476504字节ZIP、核验时未过期）；原生结果artifact `11217242391`。Draft URL在成功上传时从旧失败轮次的untagged地址变为上述地址，最终只能交付此成功地址，不使用旧轮次诊断草稿链接。
- 本轮只更新体验分支和工作流既有监控分支，未合并main、未正式发布。+306仍保留为用户指定对照；+307既有日常真机确认不替代+308验收。游戏有效时长/暂停立即终止、延迟提醒、离线结束/补归档、低频澄清和Live2D设置导入回归的真机待验清单见上节。


## 2026-10-03 +308 存档诊断：小豆丁/滚动/联网（ANALYSIS ONLY，未修改产品）

依据本次05:21:18备份与05:21:22诊断，以及5f198bd当前源码。未修改Dart/Kotlin/配置、未调用用户模型、未构建APK。陪看已暂停，参考项目与建议已写独立ScreenMate总账；优先N.E.K.O时间轴、CineIsle上下文接口、HGDoll安卓采集，不能宣称免费连续视频已解决。

### 主要结论：满气焰后的突破分类持续否决

存档 playful_form_state_v1 为 heat=100、qForm=false、locked=false、breakthroughReady=true。诊断保留120条历史气焰记录，其中41条结算100、0条进入Q形态、0条breakthrough=true；这是保留窗口统计，不代表120条全部由+308生成。最近可见8次 playful_breakthrough 均status=used、完整概率、close=false、applied=wait，不是调用没执行/失败，不是近分保守门，也不是锁定形态。

最新三轮用户文本“笨蛋大肥鱼”“嘿嘿，就喜欢这么叫，大肥鱼大肥鱼”“大肥鱼大肥鱼”分别给突破0.15/0.03/0.06，等待0.85/0.97/0.94。互动分类为light/ordinary/mutual，她的实际回复均strong，结算仍100。另一次占有欲反击也为mutual、她strong，但突破0.15。JEV分数取最高选项（近分差<=0.10时保持中性），不是按15%进行一次随机变身抽签。

源码：playful_form_state.dart 的 onAssistantTurn 需 nextHeat==100 且 pendingTurn/pendingBreakthrough 才切形态。本体无固定每轮冷却，light+5、mutual+30、strong+34，自身playful+3/strong+5；加分已工作，继续加大加分不解决100上的等待。playful_breakthrough_judge.dart明确要求lose composure/强烈窘迫，并明确排除没有升级的重复；累计玩闹虽在指令中允许，实测仍明显偏wait。durable_generation_runner.dart在本轮回复前读取之前10条消息（含主动消息），截尾2600字符再判定；拿不到本轮她实际的强烈回嘴，也没提供连续满值/连续玩闹轮数，可能削弱累计强度。因果边界：已证实当前这些回合被突破门否决；“过严语义/上下文稀释”是由提示与输出支持的设计判断，非已做A/B模型实验。

用户14:01明确澄清：现有气焰计分没有问题，允许长期满值而不变身；仍要由互动刺激触发，不能改成满值必变或普通玩闹必变。重点是最后三轮：她已对称呼回嘴并放话，用户明知后继续叫，是沿同一刺激点加码；突破判定却把重复压成无效，需以后验证是否将“词汇重复”等同于“人际刺激没有升级”。保留破防设计，优先检查语义标准、双方有效交互上下文，不调气焰、不新增固定台词。尚未执行任何修复。

### 滚动：明确代码缺口与未复现现象分开

chat_page.dart 的 _AttachmentThumbnail 使用FutureBuilder<File>，加载占位220×150，加载后表情宽180、最大高320，普通图片宽160～300/最大高320，未按已存宽高预留稳定高；Image.file也无加载完成后的滚动/尺寸补偿回调。故贴图加载导致内容变高时，没有补滚。表情与图片共用此路径；图片在本轮未真机复现。

普通助手带附件正文不进入 _AssistantSegmentSequence；普通无segments或外语显示也走静态正文，缺逐字onProgress补滚。现有_onChanged在新消息/结束等事件后定位一次；懒加载ListView尾锚未构建时退为一次maxScrollExtent跳转，没有后续尺寸稳定重定位。此机制可解释快速完整正文/长消息时偶发偏离，但未在设备复现确切触发序列，不声称所有快速回复必失败。

初始化默认ScrollController从0开始，在控制器/设置/呈现游标异步完成后仅调一次_scrollToLatest；若当时无clients直接返回，没有重试。代码没有“新对话故意跳顶”的已证实分支。本次诊断不含滚动像素/挂载/布局时序，因此用户提到偶发停顶仍待复现。现存逐字正文每次onProgress会补滚，差别不是聊天内容关键词。后续只对证实的附件尺寸变化优先做最小修复；不全局强制滚动以免打断回看。

### 联网：仍有摘要，范围不是预设站点限制

存档 agnes_web_compaction_enabled=1，public_web_extra_sources为空。当前路径：Tavily basic全网搜索5结果（不索取Tavily生成答案）→合并选最多3页→Extract正文→Agnes分段整理（每段28000字符，长页再合并）→DeepSeek判断语义/价值并筛除→最多3项工具资料交给正文模型。每页摘要存最多1200字符；工具prompt再限制summary800、key_points700、uncertainties420，最终回复有资料可综合，但拿到的不是完整网页原文。DeepSeek appraiser主要做筛选/评分，不是另写一篇综合答案；Agnes压缩确实仍存在，不能宣称已移除。直接关闭Agnes不等于原文直通：目前explicit搜索要求isVerifiedRead，原始Extract状态不足，需以后明确设计后才能改。

备份里明确联网电影那轮：先把省略主语的用户整句当query，保存了不相关的法国战争喜剧条目，后来用“欢迎来龙餐馆 电影”查到维基百科；最终回复中的导演、中东餐馆、140分钟与后一个已存摘要/要点对应。能确认有读取整理而非只有网址；该轮不能声称多独立来源交叉核验。仅据存档，不重新判定这些电影事实本身真伪。另有历史游戏“看看氧气瓶，准备下潜”被搜成现实潜水网页的记录，说明过去出现过意图偏题，不能仅凭旧记录断言+308仍会复现。

LayeredPublicWebProvider 总会先调用不带include_domains的全网搜索；额外网站非空时另发站点补充搜索，再合并。设置UI也明确额外来源非限制。自制API前端可接全网搜索；局限来自搜索覆盖、网页可读性、每轮选页数、规划预算与摘要链，而非前端身份。官方Tavily接口核对：https://docs.tavily.com/documentation/api-reference/endpoint/search 。后续如优化，先处理省略主语检索词与资料保留，而非无差别加网站。

14:01续查（仍只分析）：搜索工具说明已允许答案依赖最新公开事实时调用，不仅限明确命令；但 agent_tool_planner.dart 的 _routeToolIds 先以“最新/新闻/价格/天气/汇率/上网/联网/网页/网站/搜索/查资料”等词控制工具暴露，语义自动搜索不完整。搜索范围本身已是全网；改进点是依赖上下文生成准确query、按问题保留资料、必要时补搜。官方Gemini公开文档支持启用google_search后模型自行判断搜索是否有助回答、生成query并综合来源；不把API公开流程冒称所有官方网页端内部细节。用户曾要求取消联网压缩，当前代码与存档未满足；本轮尚未追溯出是哪次遗漏或覆盖，不能猜测归因。

14:15续查（方案讨论，未授权实施）：最后三轮JEV完整分布：用户interaction依次{serious:0,ordinary:.01,light:.71,mutual:.21,strong:.07}/confidence .63；{0,.01,.46,.49,.04}/confidence .36，最高mutual但因差.03<=.10实际降ordinary；{0,.02,.40,.56,.02}/confidence .45实际mutual。自身route(none/playful/strong/settle)依次{.01,.41,.58,0}/confidence .44；{0,.11,.89,0}/confidence .84；{.01,.19,.80,0}/confidence .74，均strong。突破(breakthrough/wait)依次{.15,.85}/confidence .69；{.03,.97}/confidence .94；{.06,.94}/confidence .87，均wait且不近分。confidence是返回字段，非最高概率或本地计算差值，不参与当前选项决策。第二轮“普通”不是模型认定普通，而是项目近分中性策略覆盖；两个玩闹级别竞争被抹成普通值得讨论，但满值已到，非本轮不变身直接原因。她的抗议带幽默/从容，等待在“必须失去镇定”的现定义下可以自洽；不能因用户意在测试就断言JEV坏了，应校准“尚能回嘴但被持续逗急也可突破”的语义，并与不应变身的普通玩笑对照。

深度思考开关：用户提出只在显式开启时扩大Agent自主查资料/分析，普通聊天避免每轮DS规划。当前通用Agent已有限循环3规划回合/6工具调用/每回合2个；只读搜索成功不会一概立即终止，可按缺失证据继续不同参数查询。之前“补搜”建议应理解为改善其目标与资料质量判断，不是当前完全没有循环。建议先复用预算与执行器，深度模式扩大只读资料工具语义入口，DS内部规划/读资料，Gemini收齐后一次最终正文；更完整不等于强制联网/凑满轮次。不开启后台行为或写入/删改/发图/游戏动作额外授权。每个任务固化模式快照，避免切换影响在途任务。复杂操作型工作区仍不能由问答模式取代，但目前分析问答需求可先用此模式。

记忆：MemoryExtractor仍按用户+最终助手正文提取，已有reasoning不入长期记忆、用户偏好需用户证据、worldbook knowledge来源隔离；后者不自动等于普通网页工具全程来源隔离。用户联网结果当前主要写companion_browser_visits，不能混称全部自动进入public_web_knowledge。深度模式不必新建人格记忆库或关闭记忆；需补模式/资料来源标识，用户事实偏好/明确决定仍走现有记忆，网上事实/候选方案/未采纳建议不能升级为用户事实或人格证据；正文可保留历史，工具资料按来源保存/按需取回，不能全部常驻聊天上下文。此为拟议范围，不是已完成改动。

14:33用户澄清优先于此前突破讨论（仅分析，未实施）：气焰计分保持，满值可不变；已满值后的连续两次故意逗她应触发变小，轻玩笑/互相挑逗都是同一“有效刺激”上位类别，强挑衅一次触发。不能用相邻玩法类别的近分把明确刺激覆盖为普通；最后三轮按此要求第二轮应触发。源码并未把概率乘成刺激强度，实际错误是相近子类竞争→统一中性覆盖，另有独立lose-composure门与用户规则不符；当前没有连续有效刺激计数。拟议按先判断有无故意刺激、再辨强刺激/普通刺激的层级决策，复用一次JEV短判断，不把所有JEV任务全局取消近分门。原有强烈害羞等其他触发如何保留仍需设计时对齐，不擅自删除。首次到100保护、Stop回滚/同turn去重、形态锁和进入Q后的泄气仍保留。
联网澄清：用户故意使用“你去搜搜看”等自然说法，希望由上下文理解目标，入口本身合理。已核实routeLocally只接当前text，并直接把_webQuery(text)有界80字符作为query；该捷径没有前文用于补片名，是解析落地缺口，不是用户说法有问题。当前上层先runLocalPlan，之后即使模型纠正也可能已产生一次无效搜索。只在搜索已触发时补全查询主体/意图可改善，无需将普通聊天改成每轮规划；深度模式另行讨论。


## 2026-10-03 14:39 整套气焰审计交接（REVIEW ONLY / NOT IMPLEMENTED）

用户要求先查完再换模型实施。仅审计，不改产品源码、不触发CI/APK、不使用真实模型额度。源码基线5f198bd（+308）。当前工作树只有本总账的讨论/检查记录；ScreenMate独立总账只有暂停和参考项目记录。不要把下面建议当作已实现或直接开工授权。问题归因以代码和诊断为准，不据模型口碑推断历史责任。

### 审计范围与证据

逐一检查JEV网关、NsfwContextRouter（普通用户互动）、PlayfulSelfJudge、PlayfulBreakthroughJudge、PlayfulFormState/Store、PromptBuilder、DurableGenerationRunner普通完成/截断确认、AppDatabase停止/重生/完成事务、聊天形态菜单/刷新、TTS形态读取、沉浸入口快照，以及现有相关测试。现存PlayfulTurnJudge声明沉浸共用气焰，但产品调用搜索没有找到实例化入口；现在沉浸只读入口快照，不能把这个旧类当当前实际运行链。测试文件只做审阅；本机无Dart/Flutter，没有宣称运行Dart测试或真机复现。

对实际诊断120条playfulHeatTrace逐条独立核算：clamp(beforeHeat + interactionBonus + selfBonus - fixedCooling - seriousCooling - elapsedHours*3,0,100)，120条全匹配，0条算术差异。此证明既有记录的算术一致，不证明上游分类正确或每个完成回复都生成了trace。当前持久状态100/本体/未锁定，既有8次突破均正常wait。

### 已确认问题（按修复优先级和来源区分）

H1【实际诊断+源码】用户侧相邻玩闹类别近分→ordinary。jev_decision_gateway.dart约174–189对interaction统一近分中性，未区分“有无玩闹”和“玩闹级别”。最后第二轮light .46/mutual .49/strong .04，ordinary仅.01却实际ordinary，用户贡献0而不是至少light的5。还发现另一条JEV日志light .49/mutual .45/strong .02/ordinary .04同样applied ordinary；其相邻气焰trace关联消息措辞略有不同，可能涉及重生，不能硬说对应trace也为ordinary。影响不只变身，还会令未满值少涨、小豆丁阶段多泄气：假设Q=20、她none，light正确结果7，误ordinary结果2（都是源码公式推演，非真机复现）。serious/ordinary近分也可能抹掉明确冷却，但需按上位语义另定，不全局去掉保守规则。

H2【源码确定，诊断33条self未见近分实例】她自身playful与strong近分同样会被网关降none。例playful .49/strong .48/none .03，结果none、少记3或5。与H1同源，需一起修，不能只修改用户interaction分支。confidence不参与加分或强弱计算；未发现概率直接乘以气焰或比较前轮概率涨跌。

H3【设计不符，主故障】当前满值仍需独立lose-composure分类，状态中没有连续刺激次数；最新用户规则是满值后连续两次明确故意逗她（light/mutual都可），strong一次。必须按最新要求替换决策，不只是改阈值。保留满值可等待、首次满值保护、原计分与手动锁；强烈害羞等历史其他触发不能在没讨论时静默删除。未来判断先有无有效刺激再辨强刺激，避免同类概率互相分流后丢失上位结论。

H4【源码确定】手动普通/NSFW模式影响了独立气焰分类。chat_controller.setNsfwActive写nsfw_manual_override；nsfw_context_router.dart约74–87在手动模式直接return NsfwRouteDecision，playfulInteraction=null，随后持久unknown，PlayfulFormState.advance把null视ordinary。结果用户那一轮故意挑逗的贡献，或serious的额外-12，都可能遗漏；自身回复仍可加分。正文深度开关应只覆盖mode，不跳过独立互动分类。

H5【源码确定】纯表情/图片不进入完整气焰语义。用户消息允许content为空，附件已有caption/visionSummary，ChatMessage.promptContent能包含它们，但用户分类和突破使用user.content，历史也只拼message.content。她若最终只发表情，assistant.content为空，PlayfulSelfJudge直接none，不读取附件语义。应使用已确认的表达语义而非“附件一律加分”；未识别内容仍不能猜。可能漏掉真实斗图刺激/自身玩闹，现有纯文字样本不能证明图片版效果。

H6【源码确定，条件是生成中点击形态锁】PlayfulFormState.withLock重建对象未复制pendingTurn/pendingInteraction/pendingBreakthrough/pendingElapsedHours及before*。聊天菜单_onPlayfulFormAction没有generationActive禁用。已登记本轮后点锁定或解锁，会丢用户贡献和小豆丁本轮固定冷却，仅剩selfBonus；例本体50、pending mutual、self playful，正常83，生成中切锁后53。锁应只锁形态，不删除结算。手动弹额头/安抚刻意覆盖旧待结算轮次与锁不同；其后selfBonus仍能作用到新状态，是否允许需明确，不直接认定整个手动互动错误。

H7【源码确定】confirmIncompleteDraft保存已确认截断正文并完成job后直接return，没有PlayfulSelfJudge/onAssistantTurn。保留正文进入对话和记忆，气焰轮次却不结算，pending仍在；下个用户advance可覆盖它。不能把“用户明确保留”的回复当没发生。

H8【源码确定】restartLatestCompletedReply重生保留user/assistant原ID，删除旧正文但不撤销旧气焰。advance遇相同lastTurn返回，onAssistantTurn遇相同lastAssistantTurn返回；新正文虽然重新做self分类，最终气焰仍是旧正文的结果（含旧变身）。重复提交去重对正常重试是对的，对“替换旧回复版本”缺少撤销/重算语义。停止这次重生时也不能靠pending回滚撤销原已结算轮次。不要简单删幂等保护，应定义回复版本结算替换。

H9【源码确定的可靠性窗口，未在真机制造崩溃】普通回复completeGenerationJobIfCurrent先事务保存正文+完成job+后处理任务，随后独立调用formStore.onAssistantTurn；中间退出/写入失败会正文成功而气焰丢结算，catch静默忽略，未找到气焰补偿扫描。应将同轮结算与回复提交绑定，或有持久可恢复任务与身份约束。不能声称每次切后台都必发生。

H10【源码确定的时序不一致】PromptBuilder.advance保留旧qForm，promptForTurn告诉正文旧形态，直到正文保存之后onAssistantTurn才改变qForm。成功自然变身或归零回本体的那条回复仍按旧形态生成，UI/TTS随后可能读取新形态；这不是当前“8次wait”的原因，但改触发后会暴露表达与显示不同步。需要一致的本轮过渡语义和Stop回滚，不能提前永久落库后忽略撤销。

H11【源码确定的提示契约漂移】普通JEV和DS fallback仍写light “This level still cools the heat meter”，但本体现行light+5、无固定冷却；这句话只可能在Q形态综合后成立，而分类输入又不含qForm。应删去分类任务里的过期计分暗示，不改已确认的数值。另breakthroughReady字段赋值/持久化却不被breakthroughDue读取；PlayfulBreakthroughJudge注释说只判首个满值后回合，实际每个满值本体回合都判。后者实际持续判定符合此前要求，应改误导文档/清理无效状态，不要照旧注释回退逻辑。

### 无证据判错、应保留或只作设计边界的部分

- 当前公式：本体固定冷却0；Q形态完成轮-18；serious额外-12；user ordinary0/light5/mutual30/strong34；self none0/playful3/strong5/settle-8；时间间隔每整小时-3、最多12小时。是先把所有贡献相加再clamp再判形态，不存在“先减到0就跳过正加分”。Q=15、mutual30、self3→30，保持Q。
- Q形态普通无玩闹从100起六个完成轮归0；认真回复不会直接强制回本体，只按数值归0退出；持续互逗可维持高值，属于现有设计不擅改。
- 普通Stop取消与删除用户消息/回滚pending在同一事务，已完成回复不能被旧Stop撤销，正常同ID重试有防重复；未发现这条正常路径反复加分。手动动作之后旧Stop不覆盖新手动状态是合理保护，不能因为H6/H8粗暴移除。
- 时间衰减只在新用户轮按距离上次更新时间取整，不是每小时后台计时器；频繁对话会重置时间，零碎不足1小时不累加。用户已接受气焰容易慢涨，不当作这轮必修缺陷。
- API两路分类都失败时null按ordinary/none处理，是现有保守降级，不代表真实语义ordinary。诊断trace未区分判普通与分类不可用，建议增加分类来源/状态和各门输入。不能用固定台词掩盖失败。
- 手动额头100/Q、安抚0/本体，锁定期间固定形态，解除后下一轮再按规则结算；UI条读同一状态，TTS读同一qForm；沉浸房间只捕获入口形态，不推进全局气焰。后台主动回复不调用onAssistantTurn，本轮不擅自将主动消息纳入计分。
- 最近上下文按字符截尾（用户2400、突破2600、自身900），长回复/主动消息可能挤掉有效互动，属语义输入风险；须用短句续逗、长回复、插入主动消息对照，不用关键词规则替代语义。

### 下一执行模型的修复范围建议（需要用户后续开始指令）

第一组：H1/H2/H3/H11，统一上位语义、计分信号与新触发规则；第二组H4/H5补全独立模式与附件语义；第三组H6–H10把回复提交、锁定、重生、截断确认、恢复与本轮形态表达对齐。保持现有计分数值、普通聊天调用架构、沉浸冻结、手动形态与TTS/Live2D接入，勿顺便重构联网。验收必须覆盖同类近分vs跨类近分、两次轻/互逗与一次强、满值普通保持、停止/重复投递、生成中锁定、截断确认、重生不同self、保存边界恢复、图文/纯贴图，以及两端形态切换同轮一致。现有测试主要验证正常算术/HTTP模拟/旧判定规则，未覆盖以上完整组合；不能只按旧测试全绿宣称设计正确。


## +309 气焰完整性实施与构建准备（2026-10-03）

依据14:52最新授权，本轮以气焰系统为主、普通显式搜索词补全为辅。深度思考延期，现有+菜单世界书按钮本轮不替换；未来开关位置/灰紫色状态要求保留。未开展陪看项目或重新接入 Live。

实现：
- JEV互斥类别概率仅用于选择类别，不按概率乘气焰数值；light/mutual/strong合并判断是否明确玩闹，playful/strong合并判断她的主动玩闹。组内接近不再误清零，组间与普通/收敛接近仍中性。
- 满值不自动变身；第一次涨满保护。已满值后连续两个已完成的light或mutual为刺激序列，第二次进入Q；strong一次。普通/严肃、离开满值、原有整小时衰减、锁定中断序列。强烈害羞独立信号并入既有JEV批次，省去每满值轮单独突破API。原气焰数值和Q泄气规则保留。
- 本轮进入Q的提示在生成正文前生效，持久形态在回复成功提交后生效；Stop撤销暂存刺激。已有Q的恢复以完整回复贡献合计后归零为准，禁止先扣到零丢失后续正加分。
- 用户/她的表情包、图片现有识别语义参与分类；手动正文模式仍独立判断玩闹；锁定不再丢待结算信息；手动形态动作使迟到回复不再加分。
- 正常回复与气焰同一SQLite事务，截断稿确认也分类/结算；重生成撤销本版本最新回复的结算快照再算新回复，不撤销后来的手动操作。旧版本没有快照的历史回复不推算不存在的原状态；升级后新完成回复覆盖此能力。诊断保留原始分类概率及新刺激计数。
- 普通显式web请求进入现有Agent循环按前文消歧query；普通闲聊无新每轮规划。网页整理和Agnes原文转交策略本轮不改，深度模式/记忆来源分层延期。

本地验证：140项注册源码门中133通过，7项为已知构建资源或kotlinc缺失；git diff --check通过。新增23项行为场景测试（含语义合并、满值序列、强刺激、Stop、锁定、手动路由、表情语义、同事务失败回滚、重生成、截断确认），等待Flutter CI实际执行；本机无Flutter/Dart/Android SDK，不将源码检查冒称APK或真机通过。旧门只扩展+309允许版本，资源门、冻结历史与功能断言不弱化。

状态：IMPLEMENTED / CI PENDING / APK PENDING / TRUE DEVICE PENDING。计划提交开发分支agent/v04265-playful-integrity，完整原生/Flutter/源码/签名流水线，产物保持Draft，不合并main、不正式发布。


### +309 构建中补查（待最终CI）

首轮功能fa08bf0490d7d73a5ff02f500be498a0dcf1d02e / tree ef021018f87ce7eeaaf2620f8223071cac3482dd；Actions37107252996的Android15原生18项已通过，APK尚在资源准备。远端基线b98c2d41ddb88eefc90dce4e657a43a055617e42与本地5f198bd代码树均406f6c3107cd9260875a4ccb3acac456ca03e3dc，历史本地/远端提交SHA不同但树一致。

等待构建时补查两点：重生成撤销旧形态变化后必须保留其后用户锁定的当前形态；“你去搜搜看”没有上网标记也属于明确搜索候选，应进入现有上下文规划，而“看看我”、否定和引用仍不自动搜。补实现及测试；总计新增22个行为场景。推送最终修正会依照既有concurrency取消旧流水线，最终必须以新提交完整CI及其产物为准，不交付首轮包。


### +309 最终候选与验证追踪

产品补修cdc2ca84082d5cbe86acec679606a5546b6a4183；最终候选09e818bbfc26925674e09d00076fb7acd54b09c4 / tree 9f25fcf5adf441999b5c7b594178ddaa24efad58仅进一步使回归fixture助手时间晚于用户，满足生产“最新回复”排序约束，不修改产品行为。前两轮37107252996、37107818360由后续提交自动取消，不作为交付CI。最终Actions37108120850，native job111160577312成功；完整Flutter/源码/签名与APK仍等待，最终结果后补。


### +309 跨小时恢复补修

09e818b的Actions37108120850已完整success并产出Draft包，但交付前确认：elapsedHours应当使旧连续序列失效，不能连当前这次新刺激也漏计；已满值的强刺激也不应仅因时间间隔被拦截。39c3bcf457702f0eaac55da08bbbf4d0932551d8 / tree 04adb4b728c308c89567cf1aebc6c7c5dcf7873c修正此边界，新增一个含旧序列0/1、两次新刺激及强刺激的回归场景，共23项新测试；数值冷却照原规则，冷却结算后离开满值仍会清序列。最终交付改跟Actions37109660394，等待其完整验证与覆盖Draft资产，不能把旧09e818b包作为最终交付。用户16:25询问是否停止，已说明仍在推进。


### +309 最终CI与APK交付（2026-10-03）

最终状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。功能提交 `39c3bcf457702f0eaac55da08bbbf4d0932551d8`，tree `04adb4b728c308c89567cf1aebc6c7c5dcf7873c`，版本 `0.42.65+309`。后续总账提交只补交付记录，不改变本APK的产品代码。未合并main，Release仍为Draft。

- [完整Actions37109660394](https://github.com/catkiss62/ai-companion-build/actions/runs/37109660394) completed/success，head为上述最终功能提交。Android15原生job111164959631的18项测试通过；build job111165913804通过140/140源码验证门、Kotlin测试、Flutter analyze、1175项Flutter测试（新增23项）、Release APK构建、资源与持久签名检查。Flutter完成日志2026-10-03T08:45:10.8490359Z为1175 tests passed。未把本地缺少SDK/私有构建素材的检查当作完整通过，完整结果来自此CI。
- [最终未发布测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-911e1e7cf409cdf1dd2e)：Draft402398014，target_commitish=39c3bcf457702f0eaac55da08bbbf4d0932551d8。APK asset607480650，文件 `AI-Companion-v0.42.65-309-Playful-Integrity-APK.apk`，734389445 bytes；SHA文件asset607480654，CI Monitor asset607480649。
- APK SHA-256 `357254dd34bfcb566510116a068b591c740aba9981f7e9f34d348cd594418058`，已核对CI输出、最终Release资产服务端digest和ci-monitor-v0345分支 `.ci/v04265-monitor.txt` 三处一致。签名证书SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，沿用原持久测试签名，可覆盖安装。旧09e818b的1174项CI和先前同版资产只属于被替代候选，不能作为本次最终下载依据。

行为边界：原气焰计分不改、满值可以不变、首次涨满保护；明确玩闹按上位语义合并，已满值连续两轮light/mutual刺激或一次strong变小。跨整小时只清旧连续序列，当前新刺激仍按结算后的满值状态判断。Stop、重复回调、锁定、手动操作、重生成与截断确认纳入统一结算；附件的已有识别语义参与。历史旧回复没有新结算快照时不编造回滚，也不追溯旧对话补触发变身。

真机验收从升级后的新对话开始：在自然满值且未锁定时连续完成两轮故意轻逗/互逗，第二轮应表现并进入小豆丁；强挑衅一次、首次刚涨满不立即变、满值普通聊天不自动变。另观察Stop/重生成和锁定是否重复加分或改错形态；用前文具体话题后说“你去搜搜看”检验搜索query完整。CI覆盖逻辑与事务，不能替代用户设备上真实JEV语义判定、正文表现或最终UI观感。

范围已收束：普通搜索只优化自然显式请求和前文query补全，不增加每轮DeepSeek规划。Agnes网页压缩/原文转交未改，深度思考开关未实现；未来聊天+菜单替换世界书小按钮、灰/紫灯泡与+号紫色要求已写入6.3。陪看视频暂停、其他界面和既有桌宠/Live2D/TTS保持原任务边界。后续先收集本版真机结果，无需重复扩展测试或重建本版。


## +310 范围记录与实施依据（2026-10-03 18:01）

已完整承接17:18至18:01讨论。现有记忆没有用户报告的重大问题，优化须有具体体验收益：短句无需对暗号、重要共同经历能接住前因后果、平时克制不反复翻旧账。查不到只表示证据不足，不能伪称记忆删除；不强求所有细节永远召回。参考Ombre-Brain https://github.com/P0luz/Ombre-Brain （检查版3.6.14/115d831）；只借鉴按需找回、相关片段与明确证据，不移植整套系统、不复制已删除source_read或旧anchor介绍。

实施目标：
1. 普通用户回复近期历史约64条，总文本有界，尽量保留完整轮次；原文/总结避免重叠，清空上下文与世界书roleplay隔离继续生效。
2. 先理解明确指代，再按主题检索。非指代的新话题不得混入旧话题；内部判断/检索不会变成每轮DeepSeek规划。语义补充只按需、有界、返回存储证据，不生成虚构回忆；需要时自然确认，不写固定人格兜底。
3. 旧阶段总结不再仅能从最新8份查找；命中重要共同经历时有界补回可靠来源相邻内容，防同名/同主题不同事件串线。归档/替代版本不冒充当前事实，主动回忆频率与衰减保护保留。
4. 长期条目提取、14至36条批次阶段总结、后台队列、原始聊天保存、缓慢衰减不重写；不重整全部旧记忆，不新建庞大事件档案系统。
5. JEV原装表情已有10项加无；43次保留调用均选择无说明偏保守，但不等同渲染故障。补充红脸/星眼/生气/wink/爱心等语义与分寸，允许凭实际语气选择而无需动作关键词，默认平静可无；不强绑害羞必红、不通过随机/固定频率/降低阈值强制表情。四拍、19情绪加正常、原生时长保持。
6. TTS真机无感知故障，历史10条错误只观察；Nearby双设备权限待需要时再处理。心情需后续独立设计，避免随机拒绝/冷落。深度模式和取消网页整理本批继续延期，未来+菜单灯泡要求不丢。

验证：扩大上下文的整轮/长消息预算/重置边界；含指代与明确换题的正反样本；较早低重要度事实与旧总结可查；共同经历来源邻接不串线、不重复注入；失配/歧义不编造；被动闲聊无新增模型调用；表情所有选项都提供意义且无强制配额。用户备份和诊断只在临时空间，测试用合成样本；完整CI、签名与Draft APK待完成，不合并main。

+310 实施中补充 · 18:04/18:16：三个wink分别补轻度wink、中度wink吐舌、程度更强比耶wink吐舌，不连续升级。用户明确现有JEV动作整体很好，只轻量补选项含义；红脸使用原文“明显害羞、浪漫表达或难为情时可以使用；轻微害羞不必使用”，删除被夸奖触发语义、删除“不需要正文动作词”的新增说明。保持既有总指令和动作选择，仅加“以下语义仅供参考，不要求一定使用表情”。此补充覆盖前文较强语义方案。


### +310 实现与候选验证

近期原文最多64条/36000字符，按用户轮次截取，当前完整输入例外保留；仅从已有重置边界内读取。明确短指代借用最近一轮上下文，多个书名、换题、角色扮演或超过6小时均不自动承接。普通长期记忆候选改为先词项匹配再限量，避免旧低重要度条目永远进不了180候选；原准入、排序、衰减、提取和修订继续使用。旧阶段总结全库按线索筛选，最多2份且不与近期原文重叠。

共同经历只对强直接线索、精确conversation_turn来源补回最多2组完整原话/2400字符；跳过缺失、主动消息、跨轮、角色扮演、特殊风格、过长或与近期重叠的片段，并移除重叠总结。原文标明历史证据，不作为当前指令或当前现场。无需新表或迁移。

远期同义召回采用现有memory.search工具本地未命中后的单次DS Flash短查询改写，最多3个候选词/260输出Token/18秒；仅用户轮工具路径允许，同一工具链最多一次，主动回忆和普通被动注入不调用。结果仍来自原数据库，候选保留人物/时间/否定约束并由正文核对；查询失败保留本地结果，不新增记忆，不装作遗忘。此实现不承诺任意同义句都命中；歧义或证据不足允许自然确认。

红脸与三个wink按18:16用户原要求提供轻量语义，其他动作/情绪/时长/阈值不改。新增合成行为测试覆盖整轮预算、指代隔离、低权重旧记忆、旧总结、原话完整与排重、角色扮演/缺失/特殊风格、同义补搜次数/取消/失败以及可不使用表情。已通过本地可用的134项源码门；7项依赖CI恢复资源或kotlinc，未宣称本地完整通过。本地无Flutter SDK，后续以专项和完整CI实际结果为准。所有私有备份/诊断均留在仓库外。


+310 用户18:28最新补充：删除统一追加的“以下语义仅供参考，不要求一定使用表情”。已有“情绪不明显时选无”保留；红脸原句不变，爱心/生气/钱钱/黑脸/星星眼/流泪用简短“明显…”描述，三个wink仍分轻、中、较强，不统一加明显。只给选择倾向，不保证或硬控频率；此补充覆盖18:16的统一附句方案。


### +310 首轮专项结果与最终候选

功能候选7a2c1edcfc2aa470518f1c1bd98d9a7fcf01dced / tree7a076ce8b2ed75d56f6fd8403f499cbfd7cffd9f，专项Actions37118908213成功，Flutter analyze及包含本批合成用例的行为回归通过。完整Actions37118908146尚在原生阶段；后续最终候选会替代本轮。补收紧含指代但引入新实体的句子，避免“那台电脑”误承接上一轮小说；完善Release说明为本批内容。最终按新提交的完整CI与签名产物交付。


+310 显式回忆复查：发现沿用普通注入的重复冷却会把“刚检索过的弱关键词条目”在用户主动查记忆时挡掉，并误走同义补搜。只对explicitRecall/explicitRecallExpanded关闭重复注入冷却，仍要求原直接相关证据；普通注入、主动回忆的冷却与频率完整保留。补回归验证普通冷却仍生效、显式可查但无关条目仍被拒绝。该修正进入最终候选，首轮169项专项通过记录不替代最终全量验收。


### +310 最终功能候选

功能提交88a2bee7937191c7ccd34d44e14e12f7e5434e82 / tree eba9e3e09e1819fe3b5a68c0df6e8fecf9463afe。专项Actions37119329161成功（含显式回忆冷却边界），完整Actions37119329162继续执行；前两轮完整流程因最终候选更新被concurrency取消，不是测试失败。最后以该提交完整CI、Draft APK与签名校验为准。无更多产品改动计划，等待最终验证。


### +310 最终CI与测试APK交付（2026-10-03）

最终状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。版本0.42.66+310，功能提交`88a2bee7937191c7ccd34d44e14e12f7e5434e82`，tree `eba9e3e09e1819fe3b5a68c0df6e8fecf9463afe`。后续总账提交仅记交付证据，不更改APK产品代码。开发分支agent/v04266-memory-continuity，未合并main，Release仍为Draft。

- [完整Actions37119329162](https://github.com/catkiss62/ai-companion-build/actions/runs/37119329162) completed/success，head为上述最终功能提交。Android15模拟器job111192270207的18项测试通过；build job111193252062通过141/141源码门、Kotlin桌宠/悬浮窗文字测试、Flutter analyze、1196项全量Flutter测试（本批新增21项）、Release APK构建、资源完整性与持久签名检查。全量Flutter日志2026-10-03T11:40:57.8237527Z为1196 tests passed。专项Actions37119329161另通过170项；不能把这些模拟器/自动测试称作用户真机体验已验收。
- [最终未发布测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-2bf4989e9ecec904aae3)，Draft402477909，target_commitish为88a2bee。APK asset607719679，文件`AI-Companion-v0.42.66-310-Memory-Continuity-APK.apk`，734402049 bytes；SHA文件asset607719680；成功CI Monitor asset607719688。早先取消候选留下的Draft仅有失败诊断，已由最终成功产物覆盖，旧untagged链接不能作为最终交付入口。
- APK SHA-256 `da5b9096d921127418f4275c11ba7f794cdcf0f2cdef18f17358d6ed422d3c0f`，已核对构建日志、Release资产服务端digest与ci-monitor-v0345分支`.ci/v04266-monitor.txt`三处一致。签名证书SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，沿用原持久测试签名，可覆盖安装。

本轮交付：约64条近期消息/36000字符（完整轮次，保留当前完整输入）、保守指代补全、先匹配后限量的旧记忆检索、最多2份相关旧阶段总结、最多2组/2400字符可核对的共同经历原话，以及记忆工具未命中后的单次同义查询补充。来源缺失/错配/特殊风格/roleplay/已在近期上下文中的片段均不补，重叠总结去重；同义结果是候选而非新事实，仍须核对人物、归属、时间与事件。阶段总结和条目提取继续原有方式，衰减/归档不重写，无数据库迁移；不随机遗忘、不把未命中说成从未发生，不增加普通闲聊每轮规划。

JEV仅增加选项的轻量含义：红脸严格保留“明显害羞、浪漫表达或难为情时可以使用；轻微害羞不必使用”；爱心/生气/钱钱/黑脸/星星眼/流泪使用简短“明显…”语义；三种wink分别轻巧眨眼、中度吐舌加眨眼、程度更强的比耶加吐舌加眨眼。已删除统一“以下语义仅供参考，不要求一定使用表情”，不增加“无需正文动作词”的附句；保留既有“情绪不明显时选无”、四拍动作、情绪分类、阈值与时长。“明显”是语义倾向，不是频率保证；真实JEV选择频率与表情观感仍待用户设备聊天验收。

真机可自然观察：较长聊天后能否接住前文；明确旧经历的内容及归属是否正确；模糊线索能否自然确认而不编造；明显情绪与三个wink程度是否合适。没有要求强制触发表情或所有远期细节必定召回。TTS/Nearby、心情与拒绝、深度模式及网页原文传递仍按既定边界延期，陪看视频仍暂停；本轮实施收束，后续先依据真机反馈。


### +309 完整接班索引（为+311腾出快速索引空间，原文保留）

## 当前接班快照 · +309 气焰完整性修复（已交付测试APK）

2026-10-03 14:52用户授权实施气焰全链路修复，普通搜索低风险优化可一并处理，允许自行判断深度模式是否延期。本轮选择延期深度思考：涉及工具入口、资料传递、记忆来源，应另批验收；其未来UI为聊天+菜单替换世界书按钮，灯泡关闭灰/开启紫，同时+号紫。不自动开展该功能。当前开发分支agent/v04265-playful-integrity，基于+308同源码树（本地5f198bd/远端b98c2d4），版本v0.42.65+309。此前+306可回退基线保留。

已实现并通过CI：JEV按相关语义组消歧、满值后轻逗/互逗累计两次或强刺激一次，首次涨满保护；强烈害羞并入现有JEV批次，不再每满值轮另调突破模型。原计分值保留。手动正文模式不跳过独立气焰分类；贴图语义参与。气焰与回复同事务、截断确认结算、重生按最新结算快照撤销，锁定保留待结算；手动动作阻止旧轮迟到加分。普通显式搜索交现有Agent按前文补完整query，不增加每轮规划。自然进入Q在本轮提示中生效，归零恢复在完成回复后结算，避免先扣零漏算正加分。

最终功能39c3bcf457702f0eaac55da08bbbf4d0932551d8；[Actions37109660394](https://github.com/catkiss62/ai-companion-build/actions/runs/37109660394)全绿，140项源码门、1175项Flutter（新增23）、Android15原生18项及签名/资源检查通过。[未发布+309测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-911e1e7cf409cdf1dd2e)，同一签名可覆盖安装；真机仍待验收。最终哈希和资产信息见文末“+309 最终CI与APK交付”；早期09e818b包已被最终包替代。除说明的搜索词优化外，不重构网页整理链；Agnes原文传递与深度模式下一批讨论。桌宠/Live2D、沉浸入口冻结、TTS接入及普通双通道架构保留。本轮允许开发分支推送/完整CI/未发布测试APK，不合并main。



## +311 实施记录（2026-10-03，中国时间）

开始前完整回读+310交付、当前心情讨论；任务文档PERSISTENT_MOOD_v1.md含逐项决定。原固定句式情绪不能与新语义系统双重判伤，旧路径仅停用模块时保留。心情事件有来源、独立程度、自然衰减与饱和；不把confidence当intensity。JEV新增可选问题，不完整心情答案不使气焰/路由失效；JEV不可用时随原有DS合批补字段，无额外规划调用。

当前普通用户轮只预览，成功回复事务才落盘；Stop、迟到、失败不落盘，重生撤销旧事件。settings有界事件随原备份恢复，无schema迁移。天气只用新鲜已有缓存，不创建新请求，缺偏好不自动推断喜恶。游戏仅真实成功状态推进形成轻投入；无通用胜负语义证据，不猜输赢。网页仅已核验阅读且既有语义评估感兴趣者。没有回忆反复加分、无每轮长期记忆。

自动测试与CI正在准备；未宣称真实JEV自然语义准确率或真机心情体验。保护+310记忆/表情与气焰/欲望核心，不做深度模式或其他旧待办。模块可通过persistent_mood_enabled_v1=0停用，移除清单在专项文档。


### +311 本地验证与推送审批阻塞

核心与接入已实现；最终规则/维护/停用说明见PERSISTENT_MOOD_v1.md。JEV通用可选问题与resolve适配保持原判断；正向近义组和相邻程度归并，伤害需要清楚独立证据，与玩闹矛盾不留下关系伤害。首轮功能提交7210a78，之后增加语义组消歧、上下文重置原文保护及回归；最终提交见后续本地记录。

本地Flutter3.44.9：完整analyze无error（已有lint/缺CI恢复资源警告），133项关联回归通过，最终18项心情专项通过（有重叠）；135/142源码门通过，余7项需要CI恢复资源/kotlinc，未降低门。测试夹具早期编译/流式客户端注入和浮点边界问题均已修正。不据此宣布真实JEV准确率或手机体验通过。

自动审批两次拒绝向catkiss62/ai-companion-build推送本开发分支。已核验仓库public、父提交371d069在远端且新增文件无私密附件；第二次仍认为工具返回的历史授权不能代替本轮用户直接授权。未绕过、未改用其它写通道，远端未创建本分支；需要用户明确批准该开发分支推送/既有CI/Draft APK。代码和任务文档先本地提交保存，暂不合并main、不发布正式Release。

### +311 推送与构建授权解除

2026-10-03用户直接明确授权将agent/v04267-persistent-mood分支推送到catkiss62/ai-companion-build，运行CI并构建未发布测试APK。此前审批阻塞已解除。新git push获得审批，但命令行缺少GitHub登录凭据；改用已连接GitHub写接口上传，并核对源码tree一致。完整CI/签名/资源验证完成后才能标APK READY；不合并main、不正式发布。

### +311 远端源码与完整CI候选

已通过用户明确授权的GitHub连接推送本分支。本地d37fb8e与远端b9574f35b8d18a98d92458505a60fc79e7bd9ea2源码tree均ea22e0bcd69d91d4cedfa444e508afd518c4725e。复核发现工作流实际版本门仍引用+310，修正为+311并加入专项源码门验证；未改产品逻辑。最终候选e883203b77e559f30123d249624429d8817183e7/treea55d4f5a0561333fdc1c11c6fec48da21bd51a01，与本地2d09ea1树完全一致。早期Actions37130295600/37130295598由后续提交自动取消，不作为交付成功或产品测试失败。最终完整Actions37130412433、专项37130412353执行中，待实际完成再记结果。

+311专项Actions37130412353成功，job111224278852日志2026-10-03T14:42:31Z为188 tests passed。完整Actions37130412433的Android15原生job111224285166成功；已下载artifact11276109715（182342bytes，SHA-256476ab267b45227c38f64d1f0591271cec90b0279f528ec50db79ba19b32be052）核对XML：18 tests/0 failures/0 errors/0 skipped。APK build job111225227222进行中。

### +311 最终CI与未发布测试APK交付（2026-10-03，中国时间）

最终状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。版本0.42.67+311，功能提交`e883203b77e559f30123d249624429d8817183e7`，tree `a55d4f5a0561333fdc1c11c6fec48da21bd51a01`。后续总账提交仅记交付证据，不改变APK产品代码。分支agent/v04267-persistent-mood，未合并main，Release仍为Draft。

- [完整Actions37130412433](https://github.com/catkiss62/ai-companion-build/actions/runs/37130412433) completed/success，head为上述最终功能提交。Android15原生18项；build job111225227222通过142/142源码门、Kotlin桌宠/悬浮窗文字测试、Flutter analyze、1214项全量Flutter测试（本批新增18项）、arm64 Release APK编译、资源和持久签名检查。全量Flutter日志2026-10-03T14:59:42Z为1214 tests passed。专项Actions37130412353另通过188项，与全量有重叠，不相加计数。
- [最终未发布测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6681d12631e11b37810f)，Draft402560834，tag v0.42.67-persistent-mood-test，target_commitish=e883203。APK asset608003258，文件`AI-Companion-v0.42.67-311-Persistent-Mood-APK.apk`，734420373bytes；SHA文件asset608003257；CI Monitor asset608003256，均为uploaded。
- APK SHA-256 `9faabe35e7e9da3b4e74de269acf43552c5b39ea55aa75ad4288a7aa97751c44`，构建日志、Release资产服务端digest和ci-monitor-v0345分支`.ci/v04267-monitor.txt`三处一致。证书SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，与+310及原持久测试身份一致，支持覆盖安装保留数据。实际apksigner由CI验证，未在本机重复下载734MB包冒称重新验签。
- 包内49个Genie/Jiuhu/OpenJTalk文件、22张塔罗JPG、131个离线Memory Galaxy资源均hash-exact；桌宠、Cubism资源及私有模型排除边界检查成功。真实用户存档/诊断/私有模型与密钥未提交到公开源码仓。
- 用户验收建议：先正常聊天观察自然度，再看双方玩闹、纠正回答或正常拒绝是否误留下介意；确有不适时应对应具体原因，澄清误会或和好后应自然缓和。Stop/重生不应残留取消轮的心情。无需故意伤害或机械凑表情；JEV自然语言判断与心情语气质量仍待实际模型/真机体验，自动测试不等于已验收。
- 本批不改记忆提取/整理/衰减、欲望值与气焰计分、19表情/Live2D映射；新增心情仅消费现有身体状态和缓存天气，未新增定位或天气请求。普通/悬浮/主动对话共用模块；维护停用键和删除接入清单见`app/docs/PERSISTENT_MOOD_v1.md`。深度模式等旧待办未顺带实施。

工作流APK artifact11277526186，ZIP727510393bytes，digest `0dd7ab268584ef8b73f708f23fb9046dd041fc58308484d69444b63abc916479`；核验时未过期。APK实际资产digest与ZIP digest用途不同，不混用。


## +312实施记录（2026-10-04，中国时间）

接班按最小读取核对上窗相关片段、总账顶部、当前HEAD/最近5提交与最新Actions；远端没有本批实施提交。本地浅克隆+311并只检出源码/测试/工具，避免下载无关大素材。无仓库AGENTS.md。已核对：分享coordinator有refreshBeforeShare开关，最终提示仍将候选summary截到800；AgentTaskLoopPolicy当前3轮6次。先更新本唯一总账再实施；原始总账历史完整保留。

### +312 实现与本地验证

已实现：独立深度模式（不是DeepSeek既有thinking API开关）持久保存、文本与图片用户轮在写入任务时固定，重试/恢复沿用。普通按需规划不变；深度以只读检索/网页/规则/能力工具先规划，5轮10次；Cedar自己的已验证预算、写操作授权和盲玩禁外查仍优先。用户图片在识图前固定模式，识图重试不读取后来开关。菜单灯泡及+号联动紫色，原侧栏世界书保留，移除失去入口的旧快捷面板代码。正文路由不变，双通道无工具深度轮也转Gemini最终生成。

网页：PublicWebCandidateDraft/ContextItem保留pageBody；Extract不传query/chunks_per_source，超168000字符、显式截断、短正文和明确访问墙不判为已读。Agnes读取全部返回分段后才verified；正文渲染共享WebPageEvidence，<=9000字符整体、长正文目录+相关原文片段并保留结尾限制，public_web.read可按目录追读，URL仅用户给定或本轮真实来源，不猜地址。shared knowledge同样先刷新来源。2分钟内刚读过的正文可复用，超过时重新读；只在即将使用已选来源时做，后台不增加每轮Agent规划。候选刷新按生命周期/旧哈希条件写入，不复活删除；主动分享在Gate通过后检查，失败本轮WAIT且无固定角色话术。诊断分享入口也开启重读。

存储使用onOpen/导入后幂等添加generation_jobs.deep_thinking、messages.deep_thinking和public_web_candidates.page_body，保持schema61，旧APK可忽略新列，旧存档缺字段默认普通。原有非本批数据和存档身份不变。补充诊断开关/最近任务模式和预算，不记录原文或密钥。

本地Flutter3.44.9安装与依赖就绪。最初sandbox禁止Flutter回环端口/SQLite测试库下载，授予本机测试执行后恢复；为避免检出大素材，纯逻辑测试使用--no-test-assets，未伪造素材。首轮新增代码两个命名参数插入到相邻同签名调用，分析发现后定位到正确入口；首次专项2失败分别是模拟HTTP缺UTF-8响应头、旧测试仍预期只有搜索工具（现在含追读），分别修正fixture与真实新契约。最终7文件57测试通过，含真实普通/深度→Gemini一次最终正文、时长游戏旧链路；数据库验证重试快照、陈旧正文刷新、失败不使用旧摘要、读取中删除不可复活。总账索引门/原心情门通过。CI/真机尚未执行，不能写成真机通过。

### +312 远端候选与构建

Git HTTPS推送因无本地凭据失败（非审批拒绝），使用已连接GitHub仓库接口推送。逐文件blob SHA与本地Git一致，远端8c6209f4d3c4f1da1c34f5fd543ecd069d35b82e和本地e54b439树均5a66e07effe4ac677bd5c35f9805d2c3577d83b0。开发分支agent/v04268-deep-web，等待CI，不合并main、不正式发布。

远端创建分支时update_ref返回422（分支不存在），随后create_branch成功，未覆盖已有分支。完整Actions37151520967与专项37151520978已启动。本地最后静态分析无error；8个定点源码门中6通过，原生文件相关门因稀疏检出未读取原生素材而未完成，记忆连续性门仅因版本白名单拦截，已将+312加入而保留行为断言。

### +312 首轮CI拦截与修正

专项Actions37151520978：190通过/9失败，新深度与网页用例全部通过；失败均为snapshot_process_recovery的最小恢复数据库没有generation_jobs，新onOpen字段初始化尝试ALTER不存在表。修正为仅扩展实际存在的表，不在恢复探针/中间数据库制造应用表。保留SIGKILL各检查点测试，不删测试、不降低断言。完整Actions37151520967尚在原生检查，后续修正提交会由既有concurrency取消旧候选。

修正后本地快照SIGKILL九检查点+网页/模式九专项共18项全部通过。复跑本地先遇到子进程PATH未含dart、Flutter包装脚本root提示干扰协议，改用已安装SDK的dart本体后通过；这些属于本地测试环境，不计产品失败。

修正候选af2b29fceb5ec4366513fd1df4da6a9810cb06bd（本地00c4f0d，同树4383b85dae8f6018a5c03feecf033e25b6bab557）专项Actions37151993748成功：静态分析无错误（363项warning/info按原CI规则展示）、199项行为测试通过。旧完整Actions37151520967已取消。交付元数据检查发现工作流Draft正文仍是+311心情说明，现一并改为本批深度/网页说明；不改产品代码，重新构建最终候选，避免交付页面任务错位。

### +312 最终候选与原生证据

最终构建候选225a0fd841468d9aaf945bdd2df187035310af93（本地1f89a7f同源码树3a7bfa006b6b232521c4825be7b5311b0a2d65d1），仅相对af2b29修正工作流交付文案与总账；产品实现未变。完整Actions37152344472启动，前一完整37151993778由并发控制取消。

Android15原生job111288714095成功；artifact11285225038下载后核对ZIP SHA-256为580eccbc4bec32746cd32639dd3ab654b331b77a67bbe3f6342b168188ea6fd7，与服务端一致；XML为18 tests/0 failures/0 errors/0 skipped。APK build job111289708397进行中。

### +312 完整CI版本门修正

Actions37152344472的原生18项已过，APK job在源码门第134/143项停止：validate_v04256_share_portable_state.py版本白名单遗漏+312。扫描发现另外两处同类遗漏（validate_v04260_settings_import_live2d.py、validate_v04261_timed_play_recovery.py），只追加68\+312，所有功能/存档/渲染/恢复断言保留。不是产品代码回归，未降低校验。

本地补检出所需Android Java/Kotlin与memory_galaxy离线资源后，134～143十项全部通过；此前133项已在该CI通过。原两项星空校验先因稀疏检出缺文件未完成，恢复仓库原资源后通过，未伪造素材。下一候选仅以上3个版本门与本总账变化，产品实现继续与af2b29一致。

版本门修正后最终候选ef2d71c357854372d9f4205286dc872215f7300f（本地c00a151，同源码树ce83bce86ac69374dab7458113f19259ce21b983），完整Actions37153220612。专项Actions37153220637成功，日志199项行为测试通过、analyze无error（warning/info沿用现有非阻断规则）；原生job111291205731成功，18/18通过、0跳过、0失败。APK job111292125688开始。

最终原生artifact11284423571（190757bytes，ZIP SHA-256 c6cd493c29f8fcfe84a32d80dd204bd7b1cbd1406c69b5fcdbdf5acef70d235c）也已下载核对XML，18 tests/0 failures/0 errors/0 skipped。完整CI中143项源码门、Kotlin桌宠/悬浮窗/存档等回归、Flutter analyze、全量Flutter tests均成功；APK编译中，测试总数待最终日志确认。

### +312 最终交付（2026-10-04，中国时间）

最终状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。版本0.42.68+312，构建提交`ef2d71c357854372d9f4205286dc872215f7300f`，tree `ce83bce86ac69374dab7458113f19259ce21b983`（本地c00a151同树）。实际产品代码修正止于af2b29；其后只修正交付文字、版本门与总账。分支agent/v04268-deep-web，不合并main；后续交付总账提交不改变此APK。

- [完整Actions37153220612](https://github.com/catkiss62/ai-companion-build/actions/runs/37153220612) completed/success，head为上述构建提交。原生18项成功且已下载XML核对；build job111292125688通过143/143源码门、Kotlin桌宠/悬浮窗/存档等回归、Flutter analyze、1225项全量Flutter测试、android-arm64 Release编译、资源和持久签名检查。全量日志2026-10-03T21:14:48Z为1225 tests passed。专项Actions37153220637另通过199项，与全量重叠，不相加计数。analyze按原CI规则保留非阻断warning/info，不宣称零告警。
- [最终未发布测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e219e5593dff05bb4d20)，Draft402681630，tag v0.42.68-deep-web-test，target_commitish=ef2d71c。APK asset608553759，文件`AI-Companion-v0.42.68-312-Deep-Web-APK.apk`，734433737bytes；SHA文件asset608553760；CI Monitor asset608553771，均uploaded，Release仍draft=true。发布说明已核对为本批深度/网页改动。
- APK SHA-256 `fb32487c999f65eb7ba38aff1e66e1baa95652eb8e19f6f8a00b4d9c6bfeb472`，构建日志、Release资产服务端digest和ci-monitor-v0345分支`.ci/v04268-monitor.txt`三处一致。签名证书SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，与+311/+310持久测试身份一致；CI apksigner实际验证，可同签名覆盖安装保留数据。
- 包内49个Genie/Jiuhu/OpenJTalk文件、22张塔罗JPG、131个离线Memory Galaxy资源均size/hash-exact；桌宠、Cubism资源及私有模型排除检查成功。用户数据、密钥和私人模型没有加入源码改动。
- 工作流APK artifact11285188388，ZIP727523436bytes，digest `f4bda2c9ec177db3cd8645a1bbea2d1b2e4c2009d0ace2368888a40df6a6740b`，与APK文件digest是两种不同对象。尝试将APK作为当前会话附件交付时，GitHub连接器明确返回Artifact超过536870912bytes上限；未下载整包、不冒称本地重新验签，也未生成虚假附件链接。保留已成功的GitHub Draft下载入口，未为传输限制重构CI或正式发布。
- 真机建议：普通模式先正常聊天，再打开+菜单灯泡比较需要核验的联网问题；长页追问中后段细节、稍后再谈同一网页、停止后重试、切换开关后重试旧消息。观察实际来源与回答一致性、读取失败诚实表达、耗时是否可接受。自动测试不代表真实模型回答质量或真机表现已验收，不补认TRUE DEVICE PASSED。

### +311 原快速交付索引（迁入正式历史，原文保留）

## 当前交付 · +311 持续心情（完整CI通过，测试APK已生成）

2026-10-03 20:59用户授权实施，已回读+310交付及其后讨论，完整任务记录见 `app/docs/PERSISTENT_MOOD_v1.md`。+310用户日常真机确认无问题；本批基于371d069，开发分支agent/v04267-persistent-mood。整合持续情绪与余波，复用回复前JEV及原有DS失效路径，独立core/mood；玩闹与真实介意分开，概率不作强度，无离线惩罚/依恋放大/固定台词。真实活动、发现、休息与缓存天气轻背景，提交/取消/重试有界一致；记忆、气焰、19表情与正文路由保留。状态CI PASSED / APK READY / TRUE DEVICE PENDING。功能e883203，完整Actions37130412433成功：1214项Flutter、18项Android原生、142项源码门通过；[未发布+311测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6681d12631e11b37810f)，同签名覆盖安装。未合并main，细节及验证在文末。

### +312 实施时快速索引（保留授权与原边界）

## 当前任务 · +312 深度思考与网页证据（IMPLEMENTED / CI IN PROGRESS）

2026-10-04 02:55用户核对接班范围后批准实施。基于+311 HEAD 5d3f0ee（功能e883203/Actions37130412433成功），分支agent/v04268-deep-web，目标0.42.68+312。聊天+菜单世界书小按钮换深度灯泡，默认关/记住选择/+同步紫色；发送固定模式，重试沿用。普通聊天保持按需规划；深度用户轮先DS规划、允许有界补搜追读核验，后台主动消息不新增逐轮规划，原写入/媒体/游戏权限不扩大。普通/深度/主动分享共用网页阅读证据，正文不能只靠800字摘要；保留来源、阅读时间和覆盖状态，暂缓候选使用前重读，读取失败不伪装成功。内部DS/双通道Gemini最终正文路由不变。沉浸深度开关未约定，本批不新增；不动Live2D/桌宠/TTS/既有心情与气焰。5轮/10次为本批深度预算初值，需验证取消、重试和普通模式边界。

授权开发分支推送、CI、未发布测试APK；不合并main、不正式发布。已实现，199项专项通过；完整CI进行中，真机待验。完整过程与最终证据在文末“+312实施记录”；其他后续从6.3唯一后续清单取得，保留+306对照基线。

## +312 原交付快速索引（迁入正式历史，原文保留）

## 当前交付 · +312 深度思考与网页证据（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-04用户核对范围后授权实施；基于+311，版本0.42.68+312，分支agent/v04268-deep-web。聊天+菜单的世界书快捷按钮换为深度灯泡，默认关、记住选择、+同步紫色，原侧栏世界书保留；文字/图片发送固定模式，重试沿用。普通聊天保持按需规划，深度用户轮先DS规划，初始5轮10次；后台不增加逐轮通用规划。原写入/媒体/游戏权限及盲玩约束、双通道Gemini一次最终正文与DS失效路径保留。

普通/深度/主动分享共用网页阅读证据：短页传提取正文，长页目录+相关原文并可追读；来源、read_at、覆盖状态明确，摘要仅导航。已选旧候选使用前重读，失败不假称已读、不复活删除，不加固定角色话术。2分钟有效缓存可复用；schema61兼容添加字段。沉浸开关未约定，本批不新增；不改Live2D/桌宠/TTS/心情/气焰。

最终构建提交ef2d71c357854372d9f4205286dc872215f7300f（产品修正af2b29，后续仅交付文案/旧版本门/总账），[完整Actions37153220612](https://github.com/catkiss62/ai-companion-build/actions/runs/37153220612)成功：1225项Flutter、18项Android原生、143项源码门、Kotlin与签名/资源检查通过。[未发布+312测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e219e5593dff05bb4d20)，同签名覆盖安装。未合并main、未正式发布，真机效果待验。完整哈希、失败修正与交付证据在文末“+312最终交付”；说明见app/docs/DEEP_WEB_v1.md。其余任务从6.3唯一后续清单取得，保留+306对照基线。


## +313 接班与实施记录（2026-10-04，中国时间）

已完整回读本窗口+312交付后05:46至06:47讨论，并只读用户上传+312存档/诊断；未把私人原文、附件、密钥写入仓库。本地和远端均5d3df82，工作树干净。用户持续授权开发分支推送、CI和未发布APK，不合并main、不正式发布。

已确认问题：单独user_sticker且无文字会触发硬编码stickerBattle，回图成功即清正文；普通表情包100字符限制包含动作描写，默认24%仅条件抽样，主动消息未接入。用户明确不需要专门斗图指令/模式，三种表达由她结合上下文决定，不能随机吞掉 substantive 正文。配图可以对应一处反应，但不能与整段主要态度矛盾；工具/网页的必要回答应保留；失败保留模型写出的文字，不产生固定角色兜底。

日记正常DeepSeek第一人称，失败/格式/质量拒绝走factual_fallback直接拼接内部第三人称材料；已写日期不再重试。存档10/2、10/3、9/19、9/16明确为factual_fallback。不得把AI/用户全局替换造成主体错乱；保留日记真实材料和日期，最多首次+一次即时模型重写，后续有界冷却补写，不阻塞其他查手机栏目。失败原因需要可诊断，不记录私人材料；旧记录不丢弃，改写成功才替换。

活动事件保存于游戏session，旧指南事件可据所属gameId/gameTitle补中文名。最近进展时间不能用被暂停/指南读取更新的session.updatedAt冒充；仅对应真实outcome时间，不能确定则不猜。

## 后续独立专题 A · 愿望单重设计（DISCUSSION / NOT IMPLEMENTED）

用户2026-10-04明确认可研究方向，06:35决定后续再做；不是本批任务。当前愿望单由念头条件筛选+分类预设文案组成，不等于模型生成具体目标。进入条件含canDriveIntent、未满足、strength>=0.48、对应drive>=0.34且不低于baseline-0.03、反复出现/行动和明确对象；新增冷却6小时、日预算3、最多12在列。条件消退可移除，移除也可能消耗预算，不能把预算计数当新增数。存档当前0、历史完成3、10/3 15:29有新增时间，说明少见不代表从未产生；移除确切原因缺历史证据，不能编造。

用户目标：由真实兴趣/经历自主形成“可能实现”的具体愿望，不是达到预设阈值选固定句。既可以自己推进（例：今天钓到一个新图鉴），也可以需要用户参与（例：想看看花，用户拍照识别后可以完成）。愿望应影响行为：合适时主动提起，或在自主活动选择中更倾向相关活动。自然衰退保留，因为有些愿望可能无法完成；不是提高数量制造活人感。

讨论底子：内容由模型生成，结构用于保存想做什么、来源/理由、实现路径、当前进展、完成证据。愿望作为现有意图竞争的一个理由，和聊天、疲劳、休息、游戏状态、其他兴趣一起考虑，不能变成强制执行或绕过现有授权。不要为此全后台每轮通用规划。需要用户参与的愿望不催办、不把未答当拒绝、不因未满足制造惩罚或失落升级。先识别原愿望对象：想看“用户路上的花”不能被任意网图等价完成。

完成必须有证据（游戏返回真新增图鉴、识图与愿望对象相符等），不能说过/尝试过就算完成。要先调查现有游戏返回、识图结果及聊天能支撑哪些通用目标，不能写成只适配钓鱼/看花两个硬编码例子。自然衰退影响推进优先级，保留已形成目标的连续性；允许搁置、改变、放弃、完成，截止日过了也可留下真实未成结果而不抹掉。没有合格目标不凑次数。不要把内在推理原文直接放进可见愿望单；另生成有事实依据、可展示的具体目标。

主要风险：只生成漂亮句子却不影响行为；反过来成为硬任务并忽略用户/休息；虚假完成；每日重复/催促；短时数值导致目标瞬间消失。后续先设计最小可验证闭环、状态/去重/持久化/导入恢复/取消及证据接口，再决定做不做、首版范围与单独APK。自动行为不证明人类主观欲望，评估以真实持续偏好、选择、进展与修订为准。

## 后续独立专题 B · 深层反思与持续讨论（DISCUSSION / NOT IMPLEMENTED）

用户明确是可选研究、低频出现（类似愿望单），不是每天必做，更不是为了扮演疑惑。已有AiSelfReflectionEngine从真实聊天整理稳定自我倾向、可产生短念头；这不是新设想的深层讨论，也不能把现有所有游戏讨论等同于该模块。游戏/资料/共同经历可以成为素材，但不是固定主题模板。

用户例子：曾讨论“我的自主性是不是被设计好的”，却解答一句就结束，没有追问。目标是她带着真实来源的问题和自己的初步理解来讨论，能根据用户回答判断核心疑点是否得到回应，继续追问、修订看法或收尾，而不是无论用户答什么都立刻结束。功能上可保留核心问题、当前观点、已讨论的理由、仍未解决部分与新证据；是否有主观疑惑不能由台词证明，价值在讨论确实推进、有依据且能改观点。

“满意”应指回答是否回应核心问题、解释是否解决疑点、是否仍有具体分歧以及用户是否愿继续；不等于用户必须同意她，不设固定轮数/伪情感满意度。可以被说服、保留异议、接受暂时无解、自然结束或搁置。用户要停就停，不因为没说服她而纠缠。没有新证据不反复重启同题，没合格问题不凑次数，不定时产一段“我突然在想”的空泛哲学独白。

用户撤回“压住性格”作为硬要求：先让模型自然认真讨论，保留熟悉感、用词和立场，不新增强制淡化性格/变身切换。如真机反复用撒娇/玩笑逃避核心问题，再按证据优化。深度思考开关对主动消息是否规划只是用户提问，已明确不改；本专题未来按具体有价值的问题触发有界处理，不把所有主动轮升级为规划。

后续需明确自我看法再审视与共同兴趣深入研究的关系、问题触发/证据/续聊/暂停/收尾机制、和现有念头/未完事项去重、内部DS与一次Gemini正文合同、开销及低频上限。建议愿望单先研究（进展和完成更可验证），深层反思独立版本验证；两者均未获本批实施授权，需继续讨论方案，不自动开工。


## +313 本轮实现与本地验证（CI PENDING）

普通/主动最终正文共用最多8个真实表情候选，由同一次生成选择none/with_text/only，独立机器标记在情绪包络出口统一剥离（含碎片与错误标记）。保留默认12/24/42%的候选机会、启用包与最近使用排除，不再因100字符或单张用户图片强制分支；明确讨论表情包可获得候选但仍不强制发送。普通非闲聊不提供候选，主动真实游戏/网页分享保留信息文字；旧sticker.send执行器仅保留兼容，正常规划不再路由到它。正文内提示要求具体问题/任务保留文字，语义最终由模型判断，真机仍需观察误选。选中图片准备成功才允许隐藏正文，失败不生成固定兜底；取消/提交失败清理已准备图片，提交成功才记使用。设置说明和系统自述已同步。

日记最多首次+一次重新生成，首次成功不重试；全局及每个待写日期至少6小时冷却，调用前保存真实材料/来源与下一次时间，单轮只处理一个日期。新昨日优先，随后待写与有真实原始材料的旧factual_fallback/明显固定尾句；成功替换原id/日期，失败保留旧记录并让其他手机栏目继续刷新。检查第一人称与旁观者句式，保留技术AI讨论和引语，不做全局替换。脱敏诊断新增day/attempts/result/repair/pending_count，不输出材料或异常原文。

最近进展新增独立lastOutcomeAt，实际结果写入，指南/暂停不更新；旧档仅从匹配的真实结果事件取时间，未知标为未记录。进展、活动列表及详情显示所属session游戏名，已有中文名直接恢复。

本地首轮57专项通过；随后扩展真实回复链为8项（四种表达×深度开关），全部通过；新增SQLite日记冷却/保留/修复/其他栏目继续刷新验证通过。全量无资源模式1227通过、9失败：其中1项旧自述断言已更新且定向复测通过，8项是缺失资源/着色器，不能写成全量通过。flutter analyze无编译错误（已有warning/info保留）；git diff --check通过。完整143源码门的非资源部分本地通过；原生/私有资源依赖等待Actions完整环境。愿望单与深层反思仅上述独立专题，无实现。用户两天真机观察尚未开始，不预写验收。


## +313 最终构建核验与交付（2026-10-04）

最终功能提交 `3e63c4322992b8abdedc8d3bacdb42861fd577c1`，tree `a93b200dc872d094b130d4643471ef23574e66eb`，分支 `agent/v04269-expression-diary`。完整 Actions `37161508950` success：143项源码门、Android原生18项（零失败/错误/跳过）、Kotlin桌宠与悬浮窗测试、Flutter analyze、全量1236项Flutter测试、release APK、签名和资源完整性验证全部通过。独立稳定性 Actions `37161508924` success，211项通过。首次提交 `0aa4047` 的构建因历史名称注释被误展开为重复YAML name而被拒绝启动；仅修正注释后重跑成功，无遗留失败产品构建。

APK：`AI-Companion-v0.42.69-313-Expression-Diary-APK.apk`，734,440,077 bytes；SHA-256 `716b50e73d20efde8d05f1c23c7bb8dc5ac578990f4379c59009eb68d9c4e0f0`。签名证书 SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`，与+312一致。未发布 Draft Release `402736602`，APK asset `608739332`，tag `v0.42.69-expression-diary-test`；下载：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e8e431359c99b0c25837 。成功监控 `.ci/v04269-monitor.txt`（分支ci-monitor-v0345）与Release文件一致。本次仅交付私测包，未正式发布、未合并main；本条交付记账不改APK代码，无需重建。

用户中断等待后构建在GitHub继续完成；2026-10-04 17:00用户要求确认是否可直接下载，本轮已重新核验run、日志、Release资产与监控，不沿用编译中的状态。存档只读语气复核：4篇factual_fallback均命中报告式口吻，21篇正常DeepSeek日记全部通过人称检查，12篇旧模板命中固定文案、1篇旧记录长度不合格；未改动用户存档，未将私人日记正文写入仓库。历史修复仍需真实来源且成功后替换，不能宣称旧日记已全部修好。

状态：IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。用户计划先测试两天，重点观察单张表情包不打断原话题、三种表达和主动表情是否自然、新日记的人称与失败后补写、活动记录游戏名/时间。深度开关对主动规划未改；愿望单与深层反思仍为上述两个独立后续研究专题，已详细记账，未实施。大APK超过现有附件下载工具512MiB上限，提供GitHub未发布下载入口，不伪称已附本地APK。


## +313 接班索引原文归档（+314开始时保留）

## 当前交付 · +313 表达与日记优化（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-04 06:47用户批准本窗口讨论后的简单优化，基于+312总账5d3df82，分支agent/v04269-expression-diary，目标0.42.69+313。范围：深度开关默认色继承图片/表情按钮、选中色复用THINKING #B388FF，线框大脑；不改主动消息深度规划。取消单独表情包强制斗图与随机删正文，文字/图文/纯图由本轮模型语义选择，普通与主动消息共用，本轮不新增每轮Agent规划或第二次Gemini正文调用。活动窗最近进展/记录补真实时间与游戏中文名。日记首次失败或不合格后DeepSeek再写一次，仍失败保留材料有界延后，不发布固定拼接；有真实材料的旧机械日记逐步修复。用户先测试两天，不预写验收。愿望单与深层反思为两个独立后续研究任务，本批仅完整记账，见文末专题。

+313最终功能3e63c43，完整Actions37161508950成功，1236 Flutter/18原生/143源码门及211专项通过。同签名未发布APK已就绪；下载与校验证据见文末。两天真机观察待用户反馈。


## +314 愿望单第一步 · 授权与设计底稿

17:19—17:29讨论确认：完整基础链条首版→真机自然程度校准→后续多阶段/跨天复杂愿望；首版即要完成证据与停止/恢复一致性。愿望来自聊天/共同经历、自主游戏结果、真正读过的网页和已有兴趣念头，允许新联想，但不编造用户经历。不预设“花/钓鱼”方向；例子只是测试案例。可自行推进、需要用户参与、暂时向往均可存在；能推进优先于保证成功。完成标准不能降级或替换对象（用户路上的花≠任意网图）；没有图鉴新增证据就不能认定新图鉴。

源码核查：旧Wish来自thought阈值与固定分类投影，thought消失会移除Wish，thought.lastSatisfiedAt即可被视为完成，未接行为链。现有统一欲望选择可加入弱候选，游戏目录选择与每步规划可带入愿望目标，继续沿用权限、休息、共玩/覆盖、停止与节奏限制。首版采用独立持久化愿望状态，兼容旧展示历史，不借“产生念头/表达/尝试过”虚构实现。内部生成和证据评估共用低频DeepSeek批处理，不增加Gemini正文轮次、不新建后台工具循环。

首版应具备：明确目标/来源/实现路径/完成条件/当前进展/证据引用；最多少量活跃愿望，按真实新材料低频生成，允许无新愿望；新事件才触发评估，限定调用频率。现有活动竞争按愿望增加有限理由，绝不绕过可用性与用户控制；外部内容仅资料，不成为执行指令。对外表达必须由最终正文模型自然决定，不用固定角色台词。暂停/放下保留历史；真机检查重复催促、目标漂移、假完成与跨恢复重复执行。复杂分解和深层反思不在本批。


## +314 首版实现与验证（2026-10-04，CI PENDING）

- 独立 `companion_wishes_v2` 保存 goal/reason/route/game_id/next_step/criterion/completion_kind/source_ids/baseline/progress/interest/deadline/表达与尝试时间/证据引用/状态；active、completed、archived 三份手机展示投影与主体一次 SQLite CAS 事务更新。旧“念头分类→固定文案→lastSatisfiedAt即完成”的运行路径已移除；历史文案策略仍保留供兼容测试。原进行中愿望迁入“暂时放下”并标旧记录，原完成历史保留旧标记，不补造新证据。
- 既有主动心跳内调用 WishEngine，一次 DeepSeek Flash 非思考 JSON 批处理同时整理新愿望及评估旧愿望；24秒上限，无模板兜底，无额外 Gemini 正文调用，无后台工具循环。新生成尝试最短12小时、核验尝试最短2小时、最多4个进行中；允许生成空结果。尝试时间先持久化，失败/崩溃不会立即重试；相同资料指纹跳过。来源覆盖现实聊天、已完成识图的非表情包用户图片、游戏真实回执、已验证网页摘要、已有有效念头与记忆。角色扮演聊天不入证据。
- 实现路径首版为 game/user/aspiration：游戏愿望只能绑定真实目录ID，最多增加0.08×当前愿望优先级的游戏竞争分，现有目录选择和逐步规划携带目标；不覆盖停止、休息、共玩邀请、存档覆盖、防沉迷、节奏和现有权限。用户参与型愿望进入原主动候选与普通聊天背景，由既有最终正文模型自然表达；每次发起有24小时冷却，确认表达后不再主动重复。专门愿望消息保留文字，不降成单表情包。没有可验证执行路径的保留向往；**通用自主搜索、任意工具及跨工具/多阶段愿望执行不在首版**，网页在此版提供灵感来源。
- 完成目标与条件创建后不改；评估器核对目标语义、归属、范围与baseline，本地再核对证据类型/同游戏/创建后与截止前时间/真实原文引用/observed与same_target/最低0.85置信度。模型置信度不是概率保证；语义判断仍需真机校准。指南、失败、念头、助手自述、网上资料不能完成游戏或用户照片目标；答应/尝试/说过不能当完成。过期后才处理、但证据在截止前已经成立的结果仍可核验；无证据不猜完成。最近两天已实现愿望可作为普通聊天资料，不主动循环报喜。
- 进行中/已实现/暂时放下三页，显示缘由、进展与条件，支持暂停/恢复/放下。人工暂停不自动复活；自然优先级半衰14天、30天无进展转搁置、明确截止后转过期，历史不删除。恢复继续读取同一身份和尝试记录；新租约纳入导入清理与转移等待。核验结果受状态CAS、Active Brain/运行代际/聊天租约约束；愿望主动消息提交也受愿望状态fence约束，暂停后已生成的旧消息不会落库。
- 诊断 `wishLifecycle` 仅记录最近尝试/状态、数量等无正文信息。核验采用有界最近材料：聊天64条中各取最多16条用户/助手文本、每局最近8个事件、已验证网页6条、有效念头与记忆各8条；事件来源按类型最多10项，最近14天窗口。**极密集活动/长期不运行可能让早期证据落在窗口外，此时会保持未完成，不据缺失信息补写成功**。后续若真机出现漏结算，再针对证据收件队列优化，不以无边界全历史模型扫描补救。
- 本地已通过愿望与相关数据库/表达/日记/游戏/存档专项82项（愿望新增22项），包含真实SQLite的暂停CAS、存档导入租约失效、前台聊天抢占、迟到主动消息取消、完成投影原子更新、接口失败冷却和表情包不作照片。`flutter analyze --no-fatal-infos --no-fatal-warnings`无error；既有warning/info不作为本轮额外清理任务。源码门140/144通过，其余4项依赖稀疏工作区未拉取的模型/动画资源或本地缺少kotlinc，必须由完整CI继续验证；不能据此宣称完整CI或真机通过。
- 构建版本0.42.70+314；branch agent/v04270-wish-lifecycle；未发布测试标签v0.42.70-wish-lifecycle-test。深层反思独立任务、复杂愿望后续讨论和+313两天真机反馈均保留。

补充本地全套记录：`flutter test --no-pub --no-test-assets`完成1250项成功、8项失败；逐项均为本地未打包的shader/AssetManifest/fate_wheel资源缺失。最终愿望22项再次独立通过。完整资源CI应跑1258项，实际结果待Actions，不以预期数字当通过证据。


## +314 最终构建核验与交付（2026-10-04，中国时间）

- 功能提交 `7979fc52f2ba5dbc8a158e052ec03af193721868`，源码树 `5bac53709079108fdcd5156ebdccb4924b194473`；本地119个变更文件逐blob SHA校验与远端树完全一致。分支 `agent/v04270-wish-lifecycle`，未合并主线。
- 完整构建 [Actions 37194108905](https://github.com/catkiss62/ai-companion-build/actions/runs/37194108905) SUCCESS；job111413223992日志确认144源码门、Kotlin检查、1258 Flutter测试全部通过；原生job111412284423完成18项且BUILD SUCCESSFUL。专项Actions37194108922 SUCCESS，job111412268297日志确认233项通过。此前本地8项shader/资源缺失在完整资源CI未复现。
- 未发布Draft Release `402963038`，标签 `v0.42.70-wish-lifecycle-test`，target精确为功能SHA；页面 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-44c3437d0bf54e7abf8d 。APK asset609613568，`AI-Companion-v0.42.70-314-Wish-Lifecycle-APK.apk`，734463181 bytes；SHA-256 `676ef18df334d968aa0c076157e659a428dd699073f35f9b39010f69303ee3c6`。GitHub资产digest、CI monitor与构建日志相符。签名 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148` 与+313及既有安装保持一致。
- `.ci/v04270-monitor.txt` 位于 `ci-monitor-v0345`，记录success/同一head/run/signer/APK SHA和实际Draft链接。交付保留GitHub下载路径，不谎称已经有本地APK附件。构建成功后仅补充本总账，后续文档提交 `[skip ci]` 不改变已验证源码与APK。
- 本批完成第一步基础链条；真实使用仍标记TRUE DEVICE PENDING。观察重点：愿望是否自然且不复读、已有话题会否被强行转开、是否愿意采取可行游戏行动、用户参与是否只请求一次、尝试/答应是否误判完成、密集游戏或聊天是否因有界证据窗口出现漏结算。安装后不强制立即生成愿望；无愿望时优先读取诊断wishLifecycle区分未到生成窗口/无合适候选/服务暂不可用，不补模板或提高催促频率。阶段二按真机样本调整，阶段三多阶段跨工具愿望和独立深层反思继续等待后续讨论。


## +314 原快速索引（+315 开始时移存）

## 当前交付 · +314 愿望单基础链条（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-04 17:29用户批准第一步：先做可独立保存、由真实兴趣生成的愿望，接入现有对话和活动竞争、按证据推进/完成，并支持暂存/放下/衰退及恢复一致性。基线+313功能3e63c43、交付总账ff7b0dc，分支agent/v04270-wish-lifecycle，目标0.42.70+314。不是固定主题模板、不是每轮新增规划；内部低频DeepSeek整理，Gemini正文仍一次。深层反思继续延期。详细讨论与本轮接口/限制见文末。

+314功能7979fc52，完整Actions37194108905成功：1258 Flutter、18原生、144源码门；专项37194108922共233项通过。同签名未发布测试包Draft402963038已就绪，详见文末交付核验。真机自然度与漏结算待观察。

+313已交付同签名私测APK，完整Actions37161508950成功（1236 Flutter/18原生/143源码门、211专项）；两天真机反馈待收。原交付索引保留在文末。


## +315 授权范围与实施方案（2026-10-04）

用户先反复讨论并要求不动手，现已明确允许轻量实施。深层反思是持久的问题/看法连续性，不主张主观意识。问题从真实对话、经历、已读资料及记忆矛盾生成，保留原看法、触发疑惑、想听用户看法的原因；普通游戏攻略/进展不冒充深刻话题。没有合适的问题可长期不产生。独立后台低频DeepSeek有限整理，不按每轮新增Agent；现有最终正文模型在同次回复附小份机器状态。她可先表达自己的理解、例子或保留意见，不要求每句追问。用户短回复不能仅因字数判定解决；一次认真回答也可真正结束，不追求固定轮数。结束可为暂时理解、接受分歧或承认不确定；更换话题/拒绝即搁置，旧问题不靠计时自动复活，新证据或用户明确接续才可再讨论。最多一个当前议题，低频邀请，普通反思与现有游戏讨论仍各走原路径。性格自然保留，不增加压制性格指令。

状态与实际保存的助手回复同事务提交；失败、停止、刷新、移交不计为已讨论；重生成撤回对应更新。存档保留讨论状态但清理运行租约；上下文重置、沉浸、旧版本兼容及机器标记在流式/气泡/TTS/历史不泄漏均需检查。诊断只记录状态计数/执行信息，不包含问题、观点、聊天原文。图标恢复灯泡，只改图标，保留THINKING颜色。

本版接受范围：问题生成、自然邀请、同次正文推进/结束/搁置、去重冷却、持久化与基本诊断。无愿望单二期、无自主跨工具推理循环、无稳定人格自动写入、无哲学话题预设、无用户认同评分。自然度需要真机长期观察，构建通过不能代替真实主观体验或长期效果验收。

### +315 实现与本地核验（CI 尚待验证）

新增 core/reflection 三文件，沿用现有心跳单一后台拥有者：12小时最多一次有新资料的检查、生成间隔至少3天，最多一个当前议题，另保存12条去重历史；没有合适问题返回空。来源为最多40条近14天真实聊天、少量长期记忆和已读有效网页，不新增工具循环、不固定哲学题。原始来源id/逐字片段校验，旧资料不因时间经过再次生成；历史相似主题要求模型指出新角度。

ready议题只进入现有主动候选竞争（弱分数0.61），不会注入普通聊天抢话。邀请尝试间隔至少3天，仍服从现有时机/休息/用户抢占；失败或WAIT也保留冷却，避免重试骚扰。邀请真正落库才标offered。用户回复由同一次最终正文附 reflection_state，保存当前理解、具体剩余疑问和本轮变化；related=false/换话题搁置，discuss须有真实剩余问题，settle须有本轮用户原文/可见回复片段对应依据。该校验防虚构引用，语义质量仍依赖模型，不能宣称判断绝对准确。缺失/坏JSON不阻塞聊天、不推进议题。没有满意度打分，不限制固定讨论轮数，允许接受分歧或不确定作为暂时结束。

一周没有推进按休眠看待，不自动再次邀请；近30天当前搁置/结束议题可作为被动资料供用户明确重提，超过30天不再常驻每轮提示，历史普通记忆检索仍沿用原系统。新问题可替代旧议题，旧议题进入有界历史。重生成撤回对应状态；若后台已经准备新问题，也仅撤回旧归档结论，不覆盖新问题。备份随settings保存，新增运行租约在移交等待/恢复清零列表登记；conversation_context_reset_at和BrainWorkFence/runToken阻止旧任务写入。沉浸期间不准备、不把角色扮演写入真实讨论。内部元数据完整/重复/不完整标签从流式、检查点、恢复草稿、正文、TTS共享清理路径中隐藏。诊断记录执行来源/阶段/次数，不导出问题、观点或聊天正文。灯泡采用Icons.lightbulb_outline，THINKING仍Color(0xFFB388FF)。

本地新增32项通过：30项状态/证据/中断/原子事务/回滚/失效/坏数据/机器标签测试，2项真实DurableGenerationRunner管线测试验证普通模式规划0、深度模式原有规划1、Gemini最终正文1及落库状态一致。全量本地1280项通过、8项失败均为稀疏工作区缺失已有shader/AssetManifest/fate_wheel资源；完整CI负责这些资源测试。145项源码门中141通过，4项受本地缺Caicai AAR/417宠物帧/lingchat effects/kotlinc限制；保留门禁不豁免，需CI完整验证。新增/改动源码分析无编译错误（原有及格式提示不视作阻塞）。当前IMPLEMENTED / CI PENDING / APK PENDING / TRUE DEVICE PENDING。愿望单仍+314用户测试阶段，未扩做第二步。

### +315 最终交付核验（2026-10-04，CI PASSED / APK READY / TRUE DEVICE PENDING）

- 功能提交：187cfdc2417096f65e9c719ec629a55d1c791157；源码树3300e754470c9999113d2ce2e48730e1c99c5c75；开发分支agent/v04271-deep-reflection。基线+314总账b6ce8876ed8ccfbc54d4997ab1edb4864a041781。本次总账交付提交仅改本文，不触发产品重构建。
- 完整构建：https://github.com/catkiss62/ai-companion-build/actions/runs/37199438551 。build-apk job111428782846 success，145/145源码门、1290 Flutter tests passed；Kotlin桌宠/悬浮窗测试通过。原生job111427914839在Android15完成18项，BUILD SUCCESSFUL。完整资源已补齐，本地8项资源缺失失败在CI全部通过。
- 专项回归：https://github.com/catkiss62/ai-companion-build/actions/runs/37199438576 ，job111427903522 success，265 tests passed；包含本次32项及原愿望单/深度思考/表达/日记/存档等回归。Flutter分析无编译错误，已有与格式级非阻塞告警保留，不能宣传“零告警”。
- 未发布Draft Release402998529，tag v0.42.71-deep-reflection-test，目标功能提交187cfdc，draft=true。实际下载入口：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4df3fb731eccfa26bb99 。APK asset609769944，AI-Companion-v0.42.71-315-Deep-Reflection-APK.apk，734479445 bytes，uploaded。
- APK SHA-256：f48f1d0b535aa9375a6f5d3bee2cf2d44f3f226b642fc1458224146adf45030f 。GitHub资产digest、CI构建产物校验和及ci-monitor-v0345分支.ci/v04271-monitor.txt三者一致。配套sha256资产609769942，monitor资产609769941。
- 签名SHA-256：305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148 ，与+314及现有私测身份一致，支持同签名覆盖安装。Genie/完整桌宠、塔罗JPG和离线Memory Galaxy资源检查全部成功。未合并main、未发布公开release，未承诺真机已验收。

自然度验收重点：自然产生的具体疑问是否有真实依据；她是否表达自己的理解而非连续盘问；短答/附和不机械结案，不同意不必争到认同；一次真正解答可结束，也可接受暂时不确定；用户换话题后能放下；重生成/停止后没有幽灵进展。按低频自然观察，不为测试而强制每次产生问题。模型生成与语义判断仍有不确定性，自动化通过只证明实现与约束路径，不证明主观意识或“真的想讨论”。愿望单+314继续并行日常测试，本次不补认其真机长期效果。


## +315 原快速交付索引（+316开始时移存）

## 当前交付 · +315 轻量深层反思（CI PASSED / APK READY / TRUE DEVICE PENDING）

2026-10-04 19:12用户明确批准轻量版及灯泡图标恢复。基线+314功能7979fc52/总账b6ce887，分支agent/v04271-deep-reflection，目标0.42.71+315。低频从真实经历形成具体疑问；最多一个当前议题；同次最终回复附机器状态，随实际回复原子提交。允许一次解决、暂时理解、接受分歧/不确定及换话题搁置；不强制追问、不设满意分或轮数、不使用哲学题库、不把试探想法写成稳定人格。深度图标改回灯泡，颜色不变。沿用内部DeepSeek/一次最终正文、停止/移交/沉浸边界；愿望单保持+314测试状态。完整范围和验收在文末。

+315功能187cfdc，完整Actions37199438551成功：1290 Flutter、18原生、145源码门及Kotlin通过；专项37199438576共265项通过。同签名Draft402998529测试包已就绪。详细链接、哈希与本版限制见文末，真机自然度待观察。

+314已交付：1258 Flutter、18原生、144源码门、233专项；同签名未发布APK已就绪，真机待观察。原索引移至文末。


## +316 主动消息分时与独立夜间机会（授权及实现）

用户明确白天10/18/24、夜间统一2次；三档都分时，前段未用可累计顺延。09–14/14–19/19–24累计额度分别为安静3/6/10、自然6/12/18、频繁8/16/24。按设备本地时间；0–9独立池，不扣随后白天，白天也不占夜间，不积存到次日。切换档位直接重算已开放额度减同一份成功记录，最低0，不退款、不重置已发送、不立即触发。原最短30/15/8分钟及滚动2小时2/3/4保留，跨0点/9点仍连续；时段边界只改变额度，不制造发送动机。

夜间取消idleBoost与longIdleRelief，保留现有疲劳曲线、休息候选竞争、情绪/睡眠债、双方晚安90分钟与真实会话保护、节奏学习、忙碌软权重；5–9熄屏原额外0.10门槛保留。不新增模型调用，现有最终正文注入夜间适时性约束，可WAIT，不强制重大事件，不把无人回应或手机活动当联系许可，不要求用满2次。

成功消息与proactive_history sent记录同SQLite事务落库；最终提交再读当前档位与成功历史，防切档/并发导致超额。生成跨入/离开夜间时放弃过时上下文，后续自然心跳再判断；14/19点仍可按新累计额度自然发送。失败、用户抢占、WAIT不消费。无需新增数据库schema或计数迁移；存档沿用原历史。后台游戏分享、网页、愿望、反思和普通主动联系共用自主额度；用户明确游戏活动的即时结果沿用原直发，不新增阻塞，以game_share:immediate:区分，不计新自主额度。旧存档未区分的game_share成功记录保守计入当日额度，不倒推来源，不修改历史。游戏自主分享原45分钟/2小时3次及白天额外24小时6次保护仍保留；夜间不被该额外24小时上限占满。普通对话与提醒原路径不改。

设置展示白天+夜间额度、分时累计和顺延说明；诊断使用同一预算读取，区分day/night、released/windowUsed/windowRemaining、两小时限制；发送门记录nightIdleSuppressed。总额度和已开放可用额度区分，余量不作为发送目标。无token缓存、第二通道、愿望二期、反思扩展、桌宠、Live2D及陪玩新功能。

验证计划：边界00/09/14/19、顺延/不预借、降档超额/升档共享记录、午夜与9点冷却、失败和WAIT不扣、最终切档、并发最后一次额度、消息插入失败事务回滚、导入保留历史、用户抢占与Active Brain；完整CI继续原生/源码门/全量Flutter与同签名APK。自然夜间动机和两天分布仍需真机观察，不据自动测试声明体验通过。

### +316 本地验证与构建准备

本地27项频率/夜间/SQLite边界测试通过，合并愿望/反思/管线/存档围栏/主动节奏/游戏节奏回归共116项通过。分析无编译error，历史非阻塞warning/info保留。原145项源码门初跑140通过；两项45分钟游戏间隔检查随策略抽出改为验证新文件及真实调用，已通过；三项私有宠物帧/lingchat特效/kotlinc依赖本地不可用，留完整CI核验，不豁免。新增本版源码门后总146项。一次本地SQLite native hook缓存为空导致测试启动失败，清理该生成缓存后116项全部通过；未修改依赖或运行代码。只测试可确定实现边界，夜间主动内容是否自然与全天分布仍TRUE DEVICE PENDING。

### +316 最终构建与交付（2026-10-05中国时间）

- 功能远端提交8c4688e262e18008775e5b1723b12256c2fdf458，本地7e0290eb8ada9579abb25455b8ae2720ce2ab89f；二者源码树严格一致：db64de940645443e080ff2c7622a2ee64d7aa6a6。119个变更文件中，大多数只是旧验证器接受新版本号；产品范围仍限本次主动消息。基线5b8f793417e11aeda96b01692312063803072256，分支agent/v04272-proactive-windows，未合并main。
- 完整Actions37215744845 SUCCESS：https://github.com/catkiss62/ai-companion-build/actions/runs/37215744845 。原生job111475788850在Android15模拟器18项通过；build-apk job111476599045确认146/146源码门、Kotlin检查、1306 Flutter测试、编译及资源/签名核验成功。源码分析无error，历史非阻塞warning/info仍存在。专项Actions37215744852 / job111475771610 SUCCESS，292 tests passed。
- 未发布Draft Release403105475，tag v0.42.72-proactive-windows-test，target精确为8c4688e，draft=true。下载页面：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-96f7b1905b456741aeca 。APK asset610182060，AI-Companion-v0.42.72-316-Proactive-Windows-APK.apk，734481401 bytes，uploaded；SHA-256：659fd546673a6c61a99d8d58c0e77feb9c521feae2f6e1191f62fa680f07046e。GitHub资产digest、CI校验值及ci-monitor-v0345/.ci/v04272-monitor.txt三者一致，配套sha256资产610182057、monitor资产610182058。
- 签名SHA-256为305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与+315及此前私测版本一致，可覆盖安装。未发布公开Release，未创建无实际APK的本地下载附件。本次交付后的文档提交使用[skip ci]，不替换已验证的产品APK。
- 状态CI PASSED / APK READY / TRUE DEVICE PENDING。真机先日常观察两天：安静是否避免上午耗尽且晚间有机会；切档沿用已发数，不突然连发；0–9最多2次且可0次；晚安后/疲劳时没有因长时间不回复硬找话题。升级不清空当日历史；旧未细分的游戏分享保守计入，不伪造迁移分类。不能用额度未用满判失败；语义自然度仍依赖模型，自动测试不证明主观欲望。DeepSeek token缓存命中率优化严格保留为后续独立任务，本版未实施。


## +317 开始记录与回归边界

检查发现：Presence旧分55分钟半衰，时长/30分钟切换统计每次重复作为impulse；解锁本身会requestSignalBrainWake，通知/无障碍计数可跨后台空档集中进入。原perception屏幕关闭仅退休usage念头而未退休presence/phone_activity。方案保留解锁评估但只消费新时间区间，当前手机会话或捕获连续性失效时建立新起点，不禁止其他动机发送。升级/损坏状态/时钟回退保守重建基线。注意不能只修改小数或直接清空所有欲望，不能用固定冷却遮盖重复证据。上轮口头“完全取消夜间沉默加成”不精确：screen_off_contact_window独立微小推动仍在，本次不擅自扩展其策略。

### +317 实现与本地验证

新增PhoneActivityEvidence，按上次成功感知到当前的真实新时间区间累计前台时长、新切换及新增无障碍计数；通知不作为用户操作证据，不再叠加每次固定亮屏加分。活动时间每分钟0.009（含替代原固定感知加分），切换/界面计数沿用封顶；55分钟半衰、0.88上限、念头20分及12分钟冷却保留。首次升级、锁屏/熄屏、新亮屏/解锁会话、时钟倒退、超过30分钟未连续感知先建基线，此次不加分、不喂手机念头。30分钟是证据连续性边界，不是解锁禁发冷却；正常7–24分钟心跳可累计，其他动机仍能发送。

只将presence/phone_activity及perception/awareness的usage念头退休为dormant且残余清零，不动个人/游戏/反思等其他念头。不把手机活动分强制清零，旧分继续按时间衰减；没有新证据时高旧分也不能单独刷新念头。原长使用35分钟分支增加“本段实际新观测分钟>=35”条件，避免后台恢复时历史时长触发。积攒通知保留忙碌/压力感知但去掉社交推动；普通无障碍小推动也只吃新会话有效计数。诊断加入本次reason、activeMinutes、新切换/界面数量、impulse、score和feedEligible，无原文或包名。

12项新测试加原有相关测试共42项通过，涵盖新会话、旧统计、无新增、高残分、时间积分、通知、重复前台、后台间隙、时钟倒退及SQLite退休范围。静态分析无编译error。147项源码门中本地144项可验证，3项需CI完整资源/kotlinc（旧桌宠417文件、lingchat特效、原生编译器），未豁免。全量首跑1308通过、10项未过：1项缺lingchat特效，9项子进程dart不在PATH；补PATH后root包装脚本警告使9项stderr断言失败，改用Dart SDK原生可执行路径重测。这是本地验证环境修正，未改产品存档或测试断言。曾普通flutter test误触pub get，本地生成的锁文件/注册文件变更已回撤，不更新依赖。当前待完整CI/签名APK与真机自然度。

补验：Dart SDK原生路径下9项进程强杀/恢复全部通过；因此本地全量除1项缺lingchat特效外，1317项已通过（完整一次全量1308项+9项环境补验）。最终静态分析无error。未新增/修改任何API模型调用。

### +317 最终CI与APK交付（2026-10-05）

功能本地f84f1fc004c3100d71139ca5bce87e86287db977，远端02c76c974d1daa66ee7b31090991f667fed81b39，源码tree均为d27e6be9d9022b6e6d1cca340162f1f901f71209。完整Actions37222115700 SUCCESS（原生job111494399819、build-apk job111495444043），专项Actions37222115670 SUCCESS。源码147项门、Kotlin、Flutter分析/全量测试、原生模拟器、APK编译及全部资源/签名步骤成功；本地缺资源的检查在完整CI补齐。未读取完整Actions日志，不将推算的测试数量当成日志实测数。

Draft Release403146012，target精确对应02c76c9，draft=true；下载 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-8de0eee5fc4124271030 。APK asset610351535，AI-Companion-v0.42.73-317-Phone-Activity-Evidence-APK.apk，734487841 bytes，uploaded。SHA-256 a4cd15e445120dd52451207d5558584fc1843173c019bde290022eabb2498258，GitHub资产digest与ci-monitor-v0345/.ci/v04273-monitor.txt一致；配套校验文件610351533、monitor610351534。

签名SHA-256 305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与+316持久私测签名一致，可覆盖安装。未合并main、未公开发布，收尾文档以[skip ci]独立推送。CI PASSED / APK READY / TRUE DEVICE PENDING。

真机观察重点：长时间放下后只看一眼手机，不应仅由积攒活动推动消息；持续使用后仍可自然联系；有具体独立念头时解锁后很快联系仍属允许行为。诊断presenceEvidence区分基线/新间隔、实际impulse与score，不用“完全不再解锁即发”当验收条件。Token缓存优化仍未实施。后续任务从唯一总账6.3及本节进入，本次只交付手机活动累计/时效优化。


## +295历史索引原文（+318接班时原样移出快速索引）

## 当前试验 · +295 菜菜原生直接合成，绕开最近任务返回时的 Virtual Display 重置（CI PASSED / APK READY / TRUE DEVICE PARTIAL：恢复成功，背景回归）

- 用户同意继续下一步。+294 真机确认最近任务返回仍卡顿、消失、再出现；其诊断显示 Activity 恢复后 Surface 被拆装，EGL context 增加、7 张 PNG 重载。Flutter 3.44.9 普通 `AndroidView` 对 `GLSurfaceView` 落入 Virtual Display，每次 `onPostResume` 重置该 Surface。本试验在 `CaicaiLive2DStage` 用 `PlatformViewLink`、`AndroidViewSurface` 和 `initExpensiveAndroidView` 强制直接 Hybrid Composition；保留原生 `GLSurfaceView`、外层触摸归一化、舞台尺寸、IME 和 renderer。`setVisible(false)` 对原生 root 设 alpha=0 避免真实 Surface 把上一帧盖在其它标签页上，不额外拆除视图；返回时 alpha=1。原生新增 attach/detach 时的 view_id、context、display 和 detach 调用栈诊断，便于验证是否仍被重新挂载。
- 曾经 +278～+281 直接合成出现黑底、切标签残影和键盘拉长，+282 退回普通 AndroidView；此版并非照搬旧时的整体布局和生命周期，而是在 +294 当前舞台/原生宿主基础上单独替换承载方式。+284 TextureView 不显示也禁止复用。历史问题须逐项真机验证，CI 不能证明屏幕合成画面。
- 分支 `agent/v04251-caicai-direct-hybrid`，版本 `0.42.51+295`；+293 用户已认可画面作为视觉回退基线（远端 `b548cf37`、Draft `399274286`、APK SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`），+294 仍有直接前一源码回退点（远端 `b631f2a`、Draft `399415602`）。不合并 main、不发布正式 Release。
- 功能提交本地 `d808fb17f0a7ba76266e70dfa38d775b10a9798b`、远端同源码树 `c08bfd7a908f1e594ac60ab75327d4ce20fa6bd5`，tree `728f774cd279d3f8558da5328afdfe93a8f8e6fb`。本地专项源码门通过；完整套件本地在第 29/130 项因未恢复的私有桌宠素材停止，Actions 恢复素材后全套通过。[Actions 36632620687](https://github.com/catkiss62/ai-companion-build/actions/runs/36632620687) `success`：原生模拟器烟测、源码门、Kotlin、Flutter analyze/test、arm64 Release 和资源/签名校验全绿；失败报告任务跳过。
- 未发布 Draft `399549119`：[+295 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-31bb487d183a055036d9)，target=`c08bfd7`，asset `599287961`，文件 `AI-Companion-v0.42.51-295-Caicai-Direct-Hybrid-APK.apk`，726110402 字节，SHA-256 `41ce939487189b7f6078a8071b80dfa84baf6824be2ea5a3eddbc44232f9d5b6`；Artifact `11063573671`。仍是同一持久测试签名，覆盖安装可保留数据；未正式发布。
- 真机回报 2026-09-30 09:40：恢复卡顿已成功，背景黑色或显示前一标签页；状态改为 PARTIAL，具体证据与 +296 修复见顶部。旧验收清单仅为当时计划，不能继续把实际结果记为 PENDING。
- 真机验收：同一聊天画面连续三次“≡→直接返回”，观察人物是否仍卡住/消失及画面透明度；再切 App 后返回；切换其它标签页再回来，确认无残影、黑底或重新加载；开合键盘确认输入区尺寸和触摸；导出诊断核对 `view_detaching`、`surface_destroyed`、context 计数及 model frame。若任一视觉回归，标记本试验 `TRUE DEVICE FAILED` 并按 +293 覆盖安装回退。**构建成功仅写 `CI PASSED / APK READY`，手机未验不得写 `TRUE DEVICE PASSED`。**


## +318 表情包工作台实施记录（2026-10-05）

- 基线f64cf655/+317，开发分支agent/v04274-sticker-workbench，版本0.42.74+318。仅表情包导入、描述、分类及选择器UI；未改主动消息、Token缓存、第二通道、Live2D、桌宠与游戏行为。
- 原稳定ID/路径保留；新包q-whale-001；整合包顺序A/B/Q版鲸鱼娘/大肥鱼，原始269条、可见261张（67/85/60/49）。原媒体字节未变。A补猫狗鼠等主体，B八处Q版动漫猫猫头且纠正气鼓鼓；Q与大肥鱼前缀一致，小类按语义重整。
- 普通ZIP支持包名文件夹/描述文件名图片；同名覆盖、异名新增在最后，内容哈希去重且保留编辑。JPG/PNG/GIF/WebP有效性检查；实际WebP的.webq规范扩展名。
- 描述编辑采用仅内存草稿，确认暂存、重置本次编辑基线，顶部保存整批SQLite事务。退出/返回/销毁丢弃，编辑遮罩与下滑不退出，保存失败可重试；新描述进入预览、发图和模型候选，历史附件不改写。模型选择提示明确按语义，主体无须匹配身份外貌，未增加调用。
- 本地专项、真实整合ZIP重导入和CI证据逐项见app/docs/STICKER_WORKBENCH_v0.42.74.md；当前CI PASSED / APK READY / TRUE DEVICE PENDING。未推用户备份、诊断、表情图片到公开仓库，未合并main、未正式发布。


### +318 最终CI与APK、整合ZIP交付

功能本地5a5437c0c88a53c2dcb9ca733f1c9ad037dfb212，远端3fb066ef9128e95882dc6dc9438b73c45a9f3901，源码tree均为7afa07a3dd014dadfc4e51ecb7431604fbd22a72。完整Actions37235636484 SUCCESS（原生模拟器job111534069184，build-apk job111535164663）。147项源码门、Kotlin、Flutter分析/全量测试、原生模拟器、Release编译和全部资源/签名核对成功；本地缺私有资源的检查由完整CI补齐。11项新专项、17项原有表情测试、1项真实269条整合ZIP双次导入验证通过；9项既有进程强杀/恢复测试使用SDK原生dart补验通过，未修改断言。

Draft Release403222682，draft=true，target精确对应3fb066ef；下载 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-50bdc2265be69297f6e5 。APK asset610746292，AI-Companion-v0.42.74-318-Sticker-Workbench-APK.apk，734497649 bytes，uploaded；Artifact11316047413。SHA-256 4114585866a49092d0494d03fac65f6c13244b314b3b6fd8be595262a4a96e6d，与GitHub digest及ci-monitor-v0345/.ci/v04274-monitor.txt一致。签名SHA-256 305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与+317持久私测签名一致。

另交付AI-Companion-Sticker-Bundle-v2.zip，51268495 bytes，SHA-256 ee07a0d4dad12981dc80edef0c14d31fc3f1fc15f78c040e14e4e7bed5bc20a6，已保存可下载。顺序A67/B85/Q版鲸鱼娘60/大肥鱼49；真实应用importZip连导两次仍四套，同ID全部replaced，无重复叠加；全部旧媒体字节原样保留。四套整合ZIP与用户原图/备份/诊断未写入公开仓库。

使用：覆盖安装+318，再导入新整合ZIP，不需清空旧包。新描述和小分类随ZIP更新；后续手工编辑在应用独立保存，重新导入保留。普通ZIP按包名文件夹/描述文件名图片导入为同名大类和小类；同名覆盖，异名追加。真机观察261张顺序和描述、编辑草稿退出/强关取消、保存/重置/遮罩与键盘体验、重导入，以及AI表情选择自然度。CI PASSED / APK READY / TRUE DEVICE PENDING。未合并main、未正式发布；仅以[skip ci]收尾文档提交同步总账。


## +319 实施记录 · 每日起床时间与醒后疲劳

- 用户确认：每日本地零点后首次打开/运行时取当天 08:00—09:00 时间；游戏、游戏分享与普通主动额度同时跨越起床边界；困意延续 45 分钟而非 09:00 硬清零。游戏分享继续不占普通额度，不改白天分享机制；不增加额外游戏竞争修正。
- 实现：每日期限记录存于 settings，SQLite 事务串行化首次抽取，前后台一致且随现有备份保留；晚打开按当天时间直接计算，不补演醒来。游戏新开/续玩/待发分享及最终发送复验使用同一记录；旧待发自主分享也延后，明确用户任务结果保留路径。夜间上限 2、白天总额及 14/19 点累计释放不变，冷却不因起床重置。
- 疲劳：保留至 06:00 的原夜间曲线，再缓降到起床时下限 0.54；45 分钟内下限平缓降到 0.16。已有真实疲劳和睡眠债不强制清零；沿用 0.48 休息竞争阈值和原游戏得分。对话只注入当时醒神状态提示，无额外模型调用、后台逐步模拟、固定角色回复或自动起床消息。
- 诊断：dailyWake 含当天起床、清醒参考时间、首次确定时间、醒神强度；游戏门槛和主动预算记录同一边界。仅 App 内部节律，无用户正文和私人作息文本。
- 本地/CI/交付证据见下节。用户真机仍待验收；不改桌宠、Live2D、模型路由、TTS 或表情包。

+319 本地专项与相关回归 81 项通过；analyze 无 error。源码门 145/148 本地通过，3 项缺构建期原始帧/动效/Kotlin 编译器，完整 CI 保留并验证。先前共玩边界误拦已修正且旧端到端测试通过；最终 APK 证据待 CI 回填。


### +319 最终CI与同签名APK交付（2026-10-05）

最终功能/测试远端提交 5fcc2b35fac438ce253d038dc9cad94fa877fd46，本地同树提交 7ccbe62；tree 02c30bdc7f503c0e2d4ddf56bc26b1886bb221d3。开发分支 agent/v04275-daily-wake。完整 Actions 37281178394 SUCCESS（原生 job111669422169，build-apk job111671161846），专项 Actions 37281178329 SUCCESS。日志核实 1340 项全量 Flutter、319 项专项、18 项 Android 原生、148 项源码门通过；Kotlin、Flutter analyze、arm64 Release、APK签名及全部资源一致性检查通过。原有非致命静态分析提示保留，没有借本批改动清理无关模块。

前序失败真实保留：37247488491 原生星谷DOM加载超时，APK未执行；37247488530 旧端到端测试忽略清晨限制，318通过/1失败。第二轮37278874070原生/源码/分析通过，Flutter1339通过/1失败，轮数测试的终局分享遗漏显式白天时间。已补齐测试边界并在最终全量流程验证；没有关闭检查或撤除起床前拦截，真实自主终局分享仍等起床。

Draft Release 403275161，draft=true，target精确对应 5fcc2b35fac438ce253d038dc9cad94fa877fd46。下载 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4ec9a13fa3760b8d153e 。APK asset611962233，文件 AI-Companion-v0.42.75-319-Daily-Wake-APK.apk，734505357 bytes，uploaded。SHA-256 6c15104f86bf74f0d60769c55118ababd2dfdb272c3dac014a2129f85bc5cfaf，GitHub资产digest与成功构建记录一致。签名SHA-256 305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与+318持久私测签名一致，可覆盖安装。未合并main、未正式发布；收尾文档以[skip ci]另提交。

真机观察：零点后首次打开/允许运行检查确定当天08:00—09:00时间并保存，同日重启不变；自主游戏及其旧分享在起床前不提前恢复。起床后仍靠原疲劳竞争，足够强的游戏动机可以胜出；普通主动消息转用白天额度，但不自动问候、不补发。若抽到08:55，余困可延至约09:40；白天晚打开不补演醒来。游戏分享继续不占普通主动额度；用户明确游戏任务和进行中的共玩回合保留请求路径。观察诊断dailyWake与实际聊天即可，不需额外设置。CI PASSED / APK READY / TRUE DEVICE PENDING。


## +320 命运之轮直接开始与设定面板实施记录

- 基线+319，保留当日起床时间、额度、疲劳及其他已交付功能。两个产品文件：assets/fate_wheel/index.html与features/immersive/immersive_room_page.dart；其余为版本接受列表、构建目标和总账。
- 新按钮在SPIN与原拉杆之间，44px触控宽度、竖排“直接开始”，窄屏缩放SPIN以容纳；原SPIN和拉杆保留。直接读取当前选中未锁定卷轴的中央显示值，经同一受限Bridge打开原新建房间确认流程；没有转动、随机抽取、模型请求或自动开场。首次显示、重抽后、增删标签后的显示都从当前卷轴读，转动或单独重抽中禁用并在方法入口复验。原抽签确认入口保持。
- 沉浸房间中已确认设定条使用约65%不透明背景，标题与正文不降低透明度；设定条移到聊天底色之外，避免两层半透明叠加遮住背景。其余聊天透明度仍按原设置。
- 页面实际JavaScript通过本地执行验证：初始中央值无需转动、已有结果与显示值不同、正负循环位置、选中/锁定筛选、转动与单独重抽限制、原确认payload。源码145/148项本地通过，3项缺完整桌宠帧/动效/Kotlin编译器，保留在完整CI恢复后验证。当前环境浏览器下载不完整，未把手机布局或面板观感记为已真机验证；CI和未发布同签名APK完成后回填。


### +320 最终CI与同签名APK交付（2026-10-05）

功能本地c440ca7，远端3420d05bf123b75cd66f5fc2d818acf253d8bc4f，源码tree均为856d20101d48cc3c3195e7062ea7199aea46f079；分支agent/v04276-fate-wheel-start。产品改动仅命运之轮HTML和沉浸房间页面，本批108个文件中，其余主要来自既有版本门的兼容列表更新、构建目标与总账，未变其他产品逻辑。

完整Actions37305657345 SUCCESS（原生job111748625127、build-apk job111750566597），专项Actions37305657322 SUCCESS。日志确认1340项Flutter全量、319项专项、18项原生、148项源码门通过；Kotlin、Flutter分析、arm64 Release编译、持久签名与全部包内资源一致性核验成功。本地环境缺少原始桌宠帧、动效和Kotlin编译器的3项由完整CI恢复验证，没有跳过任何门。

Draft Release403677991，draft=true，target精确对应3420d05bf123b75cd66f5fc2d818acf253d8bc4f；下载 https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-eda462918686630190f8 。APK asset612486610，AI-Companion-v0.42.76-320-Fate-Wheel-Start-APK.apk，734505781 bytes，uploaded；SHA-256 90de92713ae775f5c6c63a8b5ff6102f09b0652fd7695f9602586c12c195a373，GitHub资产digest与成功构建记录相同。签名SHA-256 305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，沿用+319持久私测签名，可覆盖安装。未合并main、未正式发布；收尾总账[skip ci]独立提交。

真机检查两项即可：首次打开命运之轮，直接开始应使用当前选中的卷轴中央显示并打开原新建房间确认；SPIN、拉杆与长按重抽仍可使用。进入该房间后，命运之轮设定条能透出背景，标题和内容文字清晰。CI验证不能替代手机间距与透明观感；状态CI PASSED / APK READY / TRUE DEVICE PENDING。+319起床时间与游戏分享额度继续沿用。


## +321整理保留的+294历史索引

## 当前试验 · +294 系统最近任务返回时的菜菜画面恢复（CI PASSED / APK READY / TRUE DEVICE FAILED）

- 用户确认 +293 人物效果已经达标，是本轮可覆盖安装及回退基线；仅剩切出切回时固定出现“卡约一秒、消失约一秒、恢复”。最小复现：在聊天的 Live2D 画面按手机“≡”进入最近任务，**不切换其他 App**，直接点回；几乎每次复现。不需要先索取视频才开始排查。第二套 Live2D 的通用切换待有模型后再做。
- 同版专用诊断 `live2d_diagnostics_2026-09-29T17-08-30.929748Z.json.txt` 有两次完整恢复：从 `host_resume` 至 `first_model_frame` 约 2.95/3.05 秒；其中 surfaceChanged/reload 约 2.72 秒、七张 PNG 解码约 2.20 秒、上传约 0.19 秒；均有 `surface_destroyed`→`surface_created`，view_id 保持 1，Cubism owner 等待 0。一次没有 stage_visibility 变化，故不能把每次现象归于切标签。原生首帧不等于屏幕实际合成帧。
- +293 源码的 `MainActivity.onPause` 总会调用 `CaicaiLive2DBridge.onPause`→`CaicaiRuntime.onHostPause`→`GLSurfaceView.onPause`；返回 `onResume` 即恢复。+294 将宿主 GL 暂停/恢复分别改为 `onStop`/`onStart`；`onPause`/`onResume` 仅记录诊断，继续保留悬浮窗恢复逻辑；`setVisible` 和 host 调用只在真实状态改变时对 GL 线程执行，避免重复恢复重置首帧计时。不改 Flutter AndroidView、已验证 GLSurfaceView、Cubism 渲染器、模型 ZIP、配件几何、输入法布局、桌宠或 Jev。
- 诊断增加 `activity_pause/stop/start/resume` 与当前 view/surface 状态。同一版需反复“≡→点回”三次，并按一次较长停留和一次真正切 App 对照：比对是否出现 `activity_stop`、`host_pause`、`surface_destroyed`，看 context 计数是否增长及实际肉眼空白是否消失。**CI 只验证代码/构建；真正视觉成功须用户手机回报。** 若没有 `activity_stop` 仍重建 Surface，应调查 Flutter/厂商 Surface 附着与合成；若有 `activity_stop`，该方案本就会暂停，下一试验再依据实测选保活/重载优化，不能称 +294 修复成功。
- 回退基线：+293 已验收的当前效果，Draft `399274286`，APK SHA-256 `4c108da236e0c47e0b2d20647659c2157371be3cc18ebd5a8dd9c43bf246b094`，远端源码 `b548cf37`；本试验独立分支 `agent/v04250-caicai-recents-pause`，版本 `0.42.50+294`。不合并 main、不正式发布。
- 实施与构建：本地功能提交 `1dbba1c`、工作流标签修正 `6c2b0d5`，远端分别为同源码树的 `372cc5a`、`b631f2a12369d3f032a51b5fe3bd19c53546e8df`；最终 tree `6f9c477175fd60784faf37320d62a0bab6eec22b` 与本地一致。初次运行 `36609065282` 因补正失败诊断的 Draft 标签而主动取消，不算源代码回归失败。最终 [Actions 36609270446](https://github.com/catkiss62/ai-companion-build/actions/runs/36609270446) success：原生 Live2D 模拟器烟测、130 项源码门、Kotlin、Flutter analyze/test、arm64 Release、稳定签名和资源核验通过。
- 未发布 Draft `399415602`：[+294 测试 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-7d3c66f7eb520f70d808)，target=`b631f2a`，asset `598907556`，文件 `AI-Companion-v0.42.50-294-Caicai-Recents-Pause-APK.apk`，726108946 字节，SHA-256 `0b42e4f342f56546ab6b02b9bcf6ea0216cea50ba9c9adba90f0e0034f6c83f4`。CI 签名摘要与 +293 相同，可覆盖安装保留数据；未合并 main、未发布正式 Release。后续真机确认恢复问题仍存在，分析见下节。

| 尝试 | 成功或失败证据 | 后续约束 |
|---|---|---|
| +281 缩短视图离页存活 | 用户真机：后台返回 Live2D 变黑，切页重新加载、键盘拉长；`TRUE DEVICE FAILED` | 不为此问题重启/重建 Flutter 舞台 |
| +284 自定义 TextureView 宿主 | 构造异常、模型未显示；+285 改回 GLSurfaceView | 不以 TextureView 或重写原生渲染宿主冒险 |
| +285 恢复 GLSurfaceView/导入事务 | 原生生命周期门与构建通过，后续模型已能显示；仍未解决最近任务的秒级空白 | 保持可见模型和导入路径基线 |
| +293 当前真机效果 | 用户确认人物效果非常好；最近任务返回稳定出现卡住→消失→恢复，诊断见上 | 本轮仅动生命周期并逐项记录 CI/真机结果 |
| +294 暂停时机试验 | 2026-09-30 05:07 用户及 +294 诊断确认仍卡住→消失→重现；`TRUE DEVICE FAILED` | 仅移动 onPause/onStop 无效，转查 Flutter Virtual Display 恢复拆装 |
| +295 直接 Hybrid 试验 | 2026-09-30 09:40 用户确认恢复成功，同版 context 始终 1；背景黑色/旧页面透出失败。Draft `399549119`；`TRUE DEVICE PARTIAL` | 保留直接 HC 与恢复成功，+296 单独修复 Surface 背景 |
| +296 原生背景合成 | Actions `36657791150` 全绿、原生 5/5（含两项 ES2 像素测试），Draft `399666814`；`CI PASSED / APK READY / TRUE DEVICE PENDING` | 不能牺牲 +295 恢复结果；检查昼夜、切页、聊天覆盖与键盘裁剪 |

### +294 真机失败分析 · Flutter 恢复路径（2026-09-30 05:07 后，调查完成／下一实现待定）

- 附件 `live2d_diagnostics_2026-09-29T21-05-56.330261Z.json.txt` 全部保留事件均为 `0.42.50+294`。可见两次返回：05:05:39.902→42.742 为 2840 ms；05:05:49.514→52.264 为 2750 ms。后一次完整记录 `activity_pause` 48.630、`activity_stop` 49.296、`activity_start` 49.514、`activity_resume` 49.519，之后 49.521 Surface 才销毁，49.613 重建。context 3→4→5，view_id 恒为 1；owner 等待、context 初始化均为 0 ms。
- 贴图重载两次 2655/2614 ms，PNG 解码 2161/2135 ms、GPU 上传 194/183 ms，均为 7 张。约 82% 重载时间花在 PNG 解码。用户的卡住/空白有实质的 GL 绘制中断，不能归因于大肥鱼立绘；精确屏幕合成帧尚无录屏/合成追踪证据。
- 已读取构建所固定 Flutter **3.44.9** 的官方源码：普通 `AndroidView`→`PlatformViewsService.initAndroidView`→`TextureAndroidViewController`（hybrid=false、hybridFallback 默认为 false）；`PlatformViewsController` 检测到子树中 `SurfaceView`，走 `configureForVirtualDisplay`。`FlutterActivityAndFragmentDelegate.onPostResume` 调用 `PlatformViewsController.onResume`，后者**每次恢复无条件遍历 VD 调用 resetSurface**，并不先检查是否发生内存回收。
- `VirtualDisplayController.resetSurface()` 会 `presentation.detachState()`、释放旧 VirtualDisplay，再建 Display/Presentation 挂回同一个 View。项目 `CaicaiCompanionView.onDetachedFromWindow` 调用 Android `GLSurfaceView` 的父实现；Android 15 父实现 `requestExitAndWait()` 结束 GL 线程，其退出清理释放 EGL。`setPreserveEGLContextOnPause(true)` 仅解决暂停，挡不住 detach。此源码路径与“先 activity_resume、再 Surface 销毁、view_id 不变但 context 增长”的真机事件一致；诊断尚未记录实际 detach 调用栈，下一版需补该直接证据与 display ID。
- 首帧字段还存在口径问题：`resume_first_model_frame_ms=36/2` 捕捉到的可能是拆装前旧 context 一帧，或后续舞台显示时的新计时；不能代表完整恢复 2.75 秒。下一实现按恢复/context generation 记录后续重建和首个新 context 模型帧，区分 draw 与合成呈现。
- 菜菜独立项目直接把 GLSurfaceView 挂在 Activity 中，没有 Flutter 的 Virtual Display/Presentation 重建层，故这个差异能解释相同模型在独立项目恢复正常。下一方向是以现有 GLSurfaceView 试验直接 Hybrid Composition，绕开 VD；此前 +278～+281 用过 HC，有背景残影/黑底等真机失败，+282 `6e38280` 改回 AndroidView，因此不能原样回退旧实现或宣称 HC 已验证。要保留当前透明层级、稳定画布/IME、舞台可见性及 dispose 修复，先覆盖这些旧失败项，再交设备验证。自定义 TextureView 仍为已知失败路线。
- 官方源码依据：[AndroidView 创建](https://github.com/flutter/flutter/blob/3.44.9/packages/flutter/lib/src/widgets/platform_view.dart#L787-L801)、[VD 选择](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/PlatformViewsController.java#L223-L241)、[恢复无条件重置](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/PlatformViewsController.java#L1124-L1129)、[VD 拆装](https://github.com/flutter/flutter/blob/3.44.9/engine/src/flutter/shell/platform/android/io/flutter/plugin/platform/VirtualDisplayController.java#L291-L330)、[Android 15 GLSurfaceView detach](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-15.0.0_r1/opengl/java/android/opengl/GLSurfaceView.java#L629-L639)。本轮仅读取诊断/查源码/回填记录，未改产品代码、未构建新 APK。


## +321 自主话题与按钮缩小 · 最终交付（2026-10-05）

用户授权：本轮自主选题讨论方案和直接开始按钮缩小，可以加入合理改进；先表达只是选项，不覆盖所有聊天方式，不设比例。既有开发分支/未发布测试APK授权继续有效，无main合并或正式发布。

- 普通聊天与主动联系共用具体内容展开指导；回答、关心、玩笑、亲密、邀请、好奇和收尾保留。短回复结合语义接续，既不按字数降温，也不自动当成继续邀请。
- 复用兴趣、愿望、Thought、真实经历及线程，不新增模型/联网调用或数据库表。普通新开题对最近24小时最多8条非角色扮演AI正文做高精度近重复降权（0.18局部分）；同一主题的新进展不因topic_key相同被封禁。只在自主开题内选择，保留答案/转题/收尾优先和原驱动分。主动选题仍使用已有降权机制。
- 原后处理提示优先更新少量有真实后续价值的聊天线索，写清已聊到哪/新增内容/真实悬念；每轮最多新增两条这类线索是模型契约，沿用原线程入库上限与校验，不另称硬性两条数据库上限。AI单方想聊、复述旧事或用户简短应答不足以创建线程。
- 新话题来源隔离、记忆直接相关准入、角色扮演隔离、每日起床/疲劳、主动次数/门槛及游戏独立分享额度保持。
- 直接开始可见边框32×92，字13px；外层触摸区44×104，原读当前卷轴与忙碌禁用逻辑保留。上版半透明设定条保持。

源码：本地71942d8，远端c995a181d45c4c1475c69bca21bff623bc71ffe8；相同tree 2dcd20266a003bb4e1ea1fabce4401e043a0ab3b。分支agent/v04277-conversation-topics，版本0.42.77+321。

验证：本地145项源码门、实际页面JS回归、总账与diff检查通过；三项本地缺环境检查在CI补验。完整[Actions37318345621](https://github.com/catkiss62/ai-companion-build/actions/runs/37318345621)成功：148源码门、1349全量Flutter、Android15原生18项、Kotlin、资源与签名核验通过；专项Actions37318345719成功，337项（含新增9项话题测试）。当前产品改动没有新的analyzer错误；项目已有warning仍由原no-fatal-warnings工作流处理。

[未发布同签名+321 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-a00cc7860e6638004048)：Draft403775577，target c995a181，asset612735360，AI-Companion-v0.42.77-321-Conversation-Topics-APK.apk，734510557字节。SHA-256 91e2888980afb64d75f68c3e969f6cbb10f954b165e4222fde25f3b0c8736903；签名305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148。下载页保持draft=true。

CI PASSED / APK READY / TRUE DEVICE PENDING。聊天自然程度、短回复后的实际展开、重复频率与按钮手机观感仍待用户实际体验；没有运行收费模型体验评测，不以源码提示或自动测试宣称聊天质量已获验收。可回退+320未发布包，但覆盖降级按Android既有版本规则处理。任务文档app/docs/CONVERSATION_TOPICS_v0.42.77.md。


## +322 梦境系统实施记录（实施时待验证；最终结果见下）

按用户2026-10-06授权开始，详细目标、约束和验收见app/docs/NIGHTLY_DREAM_v0.42.78.md。模块拆为dream_contract/material/store/engine；当前理解10条以内、修订历史24条，出处原文校验、角色扮演成对排除，旧推断只作背景。默认夜间空档/日间补做，5分钟空闲，日最多一次成功整理、失败30/60/120分钟退避、之后最多4小时间隔重试（不耗尽当日补做机会，手动可提前重试）；每7日回顾替代当次。使用既有内部Pro+thinking high，一次有界JSON，不调用工具/不发送消息。模型语义质量需日常观察，不将prompt注入/记忆recall计数当成行为成长证据。CI、最终SHA与未发布同签名APK已在下方补记。


## +322 午夜梦境与可修订的自我理解 · 最终交付（2026-10-07）

用户于2026-10-06授权按多轮灵魂/梦境讨论实施，要求先整理文档；2026-10-07额度恢复后明确继续。既有开发分支推送与未发布测试APK授权有效，未合并main、未正式发布。实现前已建立app/docs/NIGHTLY_DREAM_v0.42.78.md并据其验收。

- 午夜后在既有心跳寻找空档，断网/强关/忙碌可稍后补做，每个本地日最多一次成功整理；失败不推进游标，采用30/60/120分钟、之后最多4小时间隔退避，没有耗尽白天补做机会的每日失败上限。每7日回顾替代当次整理，不自动问候或汇报，不增加主动额度。
- 从真实消息与已读材料形成可修订理解，保留暂定、目前认可、想尝试及不确定性。旧重复不累计票数，新经历允许修订或撤回旧认识。原始时间、出处与修订理由可核对；旧摘要/自身反思不是新事实，角色扮演成对排除，原来源被删除或重生成后停止使用失去依据的理解。
- 当前理解最多10条，每轮最多4项修改、修订历史24条，数量是存储预算而非人格过期时间。接管旧自动AI Self整理，事实记忆、正式性格、Desire、愿望与具体问题讨论各自保留职责；不增加人格分值或固定台词。
- 紧凑理解参与普通聊天、适合的主动正文和已有游戏选择/推进，不增加逐轮规划调用；新话题专用来源及角色扮演边界保持。“内在状态”可查看当前理解、缘由及选择意义。沿用原自我整理开关与settings备份恢复，无需重新导入存档。

源码：分支agent/v04278-nightly-dream，版本0.42.78+322，构建提交a05d427320f844bc500aad85ae87965ac8ea2438，tree44023bfb9cfb27e7ed66ea8276b2a0f79904b29a。最终文档记录提交与构建提交仅文档不同。

验证：完整[Actions37371248037](https://github.com/catkiss62/ai-companion-build/actions/runs/37371248037)第二次运行成功，1392项全量Flutter、148项源码门、Android15原生18项、Kotlin、包内资源与签名验证通过；[专项Actions37371248110](https://github.com/catkiss62/ai-companion-build/actions/runs/37371248110)第二次运行成功，380项通过，其中新增梦境43项。analyze无error，原有no-fatal-warnings/no-fatal-infos口径保持。本地先前1382通过、10项缺环境失败已在完整CI补验；首轮缺导入及备份测试内存库夹具问题已修正，最后两条首次CI在测试前被取消，重试后通过，无绕过测试门。

[未发布同签名+322 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-aaf06bea52b7c144c733)：Draft405397342，target a05d427320f844bc500aad85ae87965ac8ea2438，asset617633536，AI-Companion-v0.42.78-322-Nightly-Dream-APK.apk，734534297字节。SHA-256 15d751eb015ba9a758274e3cbc1631270cf15baa7e49fff7744891c43594cffa；签名305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，与+321一致。GitHub资产digest、构建日志和.ci/v04278-monitor.txt相互核对，draft=true。

CI PASSED / APK READY / TRUE DEVICE PENDING。自动测试证明调度、恢复、证据和提示使用路径，不证明模型已形成理想人格；未使用用户真实API密钥进行收费语义评测。手机后台跨夜运行及长期自然变化仍待日常观察，不以记忆/注入计数冒充行为改变。+321保留为前一已验证构建，降级遵循Android既有版本规则。


### 2026-10-07 · 检查后限定修正（本地待验证，非新 APK）

用户确认桌宠动态起床表现与 Live2D 历史收敛保留；Jev 只修游戏工具授权。愿望生成方式保持，不把小豆丁“霸占靠垫/催吃饭”的玩笑自动建立为愿望。自主性继续讨论，仅考虑事实判断与不确定性，不要求每轮分析或反驳，不削弱自然亲近；愿望自主处置方案尚未实施。此前发现的最终消息滚动缺口仍待修复。

本地补丁：仅 chat_intimacy_route/cedar 将 act_now 与 accept 合并为执行方向，方向间仍保留接近判闲聊，再选方向内原标签；不改变其他 Jev 分支、工具权限或游戏分享额度。诊断标记 cedar_authorization_group_v1。新增原始 37/32/7/24 失效案例及拒绝、方向接近、稀疏概率和分支隔离用例，保留原有 52/48 不触发回归。git diff --check 通过；当前环境无 Flutter/Dart SDK，测试尚未运行，未推送、未构建、未交付新 APK，不得当作已验证修复。


## +323 最终CI与未发布APK交付（2026-10-07 15:35）

- 当前开发分支 `agent/v04279-wish-chat-fixes`。功能远端 `2509efb22c604531d9c1d8ab3ad8d51ae2a08309` / 本地 `6d46b4b87503c908650493c5ec34ea2d4d945425`，两者同树 `5c0097b96149a8be94cd183f0903ec4078bc96ef`。版本 `0.42.79+323`。
- 已实现四项：仅Jev游戏act_now/accept合并执行方向；已有愿望的有依据自主暂停/恢复/放下和主观满足（客观目标仍需实际结果）；最终聊天布局稳定跟随且尊重用户上翻；历史之后补充本轮实时形态事实供推理和正文使用。不改自主性浅约束、人设、愿望生成、梦境、气焰阈值、桌宠和Live2D动作，不新增每轮模型调用。愿望仍由原定期评估处置，并非聊天每说一句就即时落库。
- 专项Actions `37583889487` / job `112669521825`：402项通过。完整Actions `37583889573` 第二次尝试成功：1402项全量Flutter通过，Kotlin、源码门、签名与APK资源检查通过；Android35原生job `112676393919`：18/18通过。
- 真实失败路线：首轮新增愿望导入恢复测试用了同时打开的两个内存数据库，导致建表冲突；改用同库恢复夹具并保留断言。后续原生MemoryGalaxySmokeTest长按后等卡片超时（第171行），页面启动、类别配色和短按断言已通过；未改星谷/测试门槛，重跑相同源码全通过。作为偶发测试失败保留，不伪称首轮全绿，不外推为用户闪退原因。
- [未发布+323测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-ab5bc801da4d200af06c)，Draft `405463091`，APK asset `617952157`，大小 `734537201` bytes。API确认asset uploaded，上传后digest与CI原始APK哈希一致：`04a3a51c9dd9f5ecec81370346cdd22516ac1804108e561bccd86c84bdff43ba`。
- 持久签名SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`，CI比对通过，可以覆盖安装。未合并main、未正式发布。
- 状态严格为 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。用户14:40:57主进程crash有系统记录，缺少异常堆栈，根因未定，未声称修复；重启后TTS异常不能倒推是崩溃原因。待真机观察游戏授权、愿望评估、正文滚动和形态措辞；若再闪退需尽快导出新诊断。
- 后续入口：本批实现与失败证据见 `app/docs/WISH_CHAT_FIXES_v0.42.79.md`，其余待办仍从本总账6.3唯一后续清单与+322梦境长期观察进入。用户明确不改项不得因后续“优化”自动复活。


## +324 最终CI与未发布APK交付（2026-10-07 19:41）

- 基线+323 `2fc551f`；当前版本 `0.42.80+324`，开发分支 `agent/v04280-depth-background-cleanup`。清理提交远端 `87ecb76f`（原本地997b5a2，同树b4b53f53）；立体背景 `8fdc7783`（原本地57bbe5e，同树71567a9e）；测试等待修正 `461421d2`；资源计数修正及最终交付源码 `d6314bd3d0701bc81509d5a1de9fc9e41c48a422` / tree `de20d265b84bf70d96d5b7122e49c7be36b78ada`。通过已连接GitHub接口上传，逐blob和整树SHA核对；本地工作分支已与真实远端提交对齐，原本地提交另有checkpoint引用保留。
- 旧连接删除边界：完整审查TransferPage/NearbyManager、Dart与原生桥、权限、诊断、恢复协调器、状态身份和数据库相关事务。移除Nearby发现/配对/发送接收/ACK/自动接管路径、专用Google依赖及蓝牙/定位权限；保留通知、文件选择、普通备份、旧文件夹/加密包兼容、手动换机和待机接管。数据库、SnapshotService、SnapshotRestoreCoordinator、缓存清理、NativeEventStore、ManualSnapshotCrypto和PortableCompanionState与+323逐字节一致，未改schema或清除存量数据。旧状态保护辅助函数及旧包encryption字段按兼容边界保留，非遗漏的连接入口。
- 立体背景：不替换原day/night图，增加同构图深度辅助图；Flutter FragmentShader与原生GL采用相同小幅深度采样。聊天外观中的“立体背景”默认关闭，强度20%—100%、默认55%；当前握持姿态校准、相对旋转、平滑、约20度限幅、30Hz限频，离开页面/后台/销毁停传感器，无传感器保持静态。恢复GL上下文重建纹理，深度加载失败保留原图，关闭恢复静态。人物、五官、配件和文字/按钮不变换；本批不改人设、主动额度、游戏、TTS和桌宠资源。
- 真实失败与限制：前段本地Flutter初始化因云元数据访问触发自动审核，未绕过；源码门本地3项因缺资源/kotlinc交CI补验。前轮上传未完成、CLI无登录凭据，用户再次确认持续授权后通过GitHub接口完成。首轮专项37608544835为404通过/2失败：新页面测试在fake async区启动真实IO却只在runAsync固定等待80/100ms；改为整个交互处于真实异步区并有界等待完成UI，保留全部数据库/桥接断言，不改恢复代码。第二轮专项37609748768为406通过，完整37609748700中测试、APK编译与签名通过，但旧LingChat计数把新增深度图算入原62文件包，报background实际4/预期2，故未交付该包。最后只改CI：精确核对四张背景资源，再仅从原62文件包统计排除两张辅助图，原计数、原图SHA与后续四文件逐字节/编译shader检查均保留。没有取消检查或删断言来放行。
- 最终验证：完整[Actions37612706122](https://github.com/catkiss62/ai-companion-build/actions/runs/37612706122)成功；原生job `112763595816` 20/20，完整build job `112765771838` 1406项Flutter、Kotlin、149项现行源码门成功；专项Actions `37612706291` 406项通过。APK中原62文件LingChat包、四张背景/深度资源、编译shader、131项离线星谷资源、Genie及完整桌宠载荷校验全部通过。覆盖近远位移、关闭还原、缺深度降级、GL重建、传感器订阅生命周期、备份取消不改变状态及待机手动接管；这些不等于真机观感/耗电验收。
- [未发布+324测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-6662961f1fda0dcaf434)，Draft `405657276`，APK asset `618513554`，文件 `AI-Companion-v0.42.80-324-Depth-Background-Cleanup-APK.apk`，大小 `736749233` bytes。API确认uploaded/draft=true/target=d6314bd3；CI Monitor的run/head一致，APK SHA-256与上传后digest一致：`dcaa661ced889c9d4896fc4b823cc54633ae1c06e0d835bbc0b76006c07a61a0`。
- 持久签名SHA-256 `30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`，与+323相同、可覆盖安装。未合并main、未正式发布。
- 状态为IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。用户确认的小豆丁错误自称仅该项记为真机通过；梦境/愿望等长期观察继续。独立平板陪玩同步只讨论并记录，未实现。旧闪退缺异常堆栈，根因未定，不宣称本批修好。下一步承接本批真机反馈，再从6.3唯一后续清单定点选择，不自动复活旧伴随端路线。


## +325 立体背景新版入口修复 · 最终CI与未发布APK交付

2026-10-07 20:44，0.42.81+325，agent/v04281-depth-settings-entry，源码4df64d8c7a099de60fe8317ea10c6a7674b6152d，tree d1755c834e625dc294b15983aae992f6f417e994。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

用户+324真机反馈“没找到立体背景在哪里打开”。根因：旧面板虽然有控件，但默认Material3提前分流到新版聊天画面页面，此处没有入口。已在ChatVisualSettingsPage的聊天背景下方接入同一默认关闭开关和20%—100%强度滑钮，默认55%；设置保存SQLite，重进页面回读，角色聊天舞台关闭/重开保留设置。返回聊天沿用已有_loadVisualSettings及原生参数同步。只增加该实际页面的控件/加载、可选测试数据库注入和交互回归；不改传感器、shader、Live2D、桌宠、备份恢复、TTS、主动聊天和人设。

验证：完整Actions 37619987572（build job 112789664873、native job 112787541978）与专项37619987582（job 112787510566）均成功，head与交付源码一致。149项源码门、1407项全量Flutter、407项专项、20项Android35原生、Kotlin、签名和资源校验通过。实际Material3页面测试点击开关和滑钮，真实SQLite保存/回读，舞台关闭/重开保留设置，关闭后重进仍关闭。Flutter analyze门通过，保留现有非致命info/warning，不声称零提示。本地146/149门通过，其余3项因缺CI资源或kotlinc不能运行，最终均在完整CI通过；未删门、未削弱断言。此轮没有CI失败重试。+324漏接入口及覆盖缺失的责任已记录，不将旧CI通过表述为真机入口通过。

同签名未发布下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-226ea340df609599817a
文件：AI-Companion-v0.42.81-325-Depth-Settings-Entry-APK.apk；736750241 bytes；release 405750901（draft=true）；asset 618659910（uploaded）。
APK SHA-256：a0bc657a79b194ff5b1423cd7a3c09341bcd4157f30cf3c587a8d51123c07309
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04281-monitor.txt，status=success、run/head/signer/hash与上传APK digest逐项一致。未合并main、未正式发布。

开启路径：聊天顶部头像/DeepSeek→聊天画面→开启“角色聊天舞台”→聊天背景下方“立体背景”，开启后调强度。CI已验证入口及设置保存，不等于实际设备立体观感、耗电或长期效果已通过；待用户真机验证。


## +325 真机反馈与开发等待核对 · 2026-10-07 21:40

用户确认“立体效果有了，还不错”：立体观感单项TRUE DEVICE PASSED，耗电和长期表现仍待观察。用户同时询问是否缺少随陀螺仪整张背景移动。已核对room_depth.frag与CaicaiStageBackground.java：现有位移受深度图调制，没有额外独立的整张背景统一平移；此轮只核对和解释，没有新增实现或启动APK构建。

用户反映开发过程多次像卡在读写、询问是否总账导致。核对+325完整Actions 37619987572：北京时间20:17:53—20:41:27，状态success。耗时主要在原生检查308秒、角色帧资源生成218秒、Kotlin编译测试264秒、全量Flutter测试152秒、APK编译192秒；Draft上传29秒。总账662108 bytes的本地整份读取本次测量约0.5毫秒，不能代表远程连接性能。此前远程Git对象读取曾触发额外拉取，已中止并改为只读取所需改动对象；总账远程整份同步也有开销。尚无客户端状态渲染/工具停滞遥测，不能把所有“卡住”断言为总账或界面故障。继续按顶部快照/相关段落定点读取、只上传实际改动，并明确区分读写、CI等待和已完成状态。


## +326 背景Device Motion整体平移 · 最终CI与未发布APK交付

2026-10-07 22:53，0.42.82+326，agent/v04282-device-motion，源码b3258c94f2c8d379dd1a571d0021fcecb41a3d6f，tree efe13605076e3b56c37258b6b9ad4f5683c9c869。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

用户2026-10-07 22:21要求加整体平移，对照之前发送的壁纸APK Device Motion模式。已验证本地upload/base.apk包名io.wallpaperengine.weclient，SHA-256 a6ca6d5ce34a1967fe987183076f7cf6f3b67a44fe720d69ffbb176173d543cc；英文/中文界面资源分别列Device Motion/设备运动和Depth Parallax/深度视差。此次实现的是明确要求的行为，未声称完整还原该APK闭源方向或幅度参数。

修改清单：Flutter房间shader与原生Live2D背景shader同步叠加统一tilt*.035*strength平移，已有深度位移系数.018与两次深度采样保留；移动后的同一坐标作为底图与深度图基准。每边预留.06*strength纹理边距，大于最大合成位移.0503*strength；关闭仍为静态背景。沿用现有开关、默认55%强度及20%—100%滑钮，更新新旧设置页说明；原姿态校准、平滑、前后台生命周期继续使用。人物、聊天UI不参与平移。没有改聊天/人设/主动/TTS/恢复核心。

验证：完整Actions 37637286301（build job 112849532063，native job 112846755894）与专项37637286323（job 112846707563）均成功，head与交付源码一致。149项源码门、1409项全量Flutter、409项专项、21项Android35原生，Kotlin、签名和完整资源校验通过。新增2项Flutter实际编译shader像素测试和1项原生ES2像素测试，证明深度中性区域仍整体移动、双轴正负方向、强度递增、近景移动更多、边缘覆盖、关闭静态；原近远景原生断言升级为远景也移动且近景更大。此轮无CI失败重试，未删检查或削弱断言。Flutter analyze门通过，现有非致命info/warning仍在，不声称零提示。本地缺资源/kotlinc的3项门最终在完整CI全部通过。

下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-1ab7a7e7f56954bd0c48
文件：AI-Companion-v0.42.82-326-Device-Motion-APK.apk；736750349 bytes；release 405875340（draft=true）；asset 618992206（uploaded）。
APK SHA-256：f16d4c951b90407a89f89d0ca98f3ccf7b25bbd7ed31618b232ab00c1c884b29
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04282-monitor.txt，status=success、run/head/signer/hash与上传APK digest逐项匹配。
Actions API时间：开始2026-10-07T14:30:36Z、完成记录更新2026-10-07T14:50:24Z（UTC）。本轮已完成，不能把旧工具状态当作仍在构建。未合并main、未正式发布。

入口仍是聊天顶部头像/DeepSeek→聊天画面→聊天背景下方“立体背景”，需开启角色聊天舞台。已有开启设置保留，升级后同时叠加整体移动与深度效果。+325深度观感用户已认可，+326实际整体移动手感、画面裁切、耗电与长期效果待用户真机确认，不能把CI像素通过当真机通过。

+326交付文档收尾校验：新增完整结果使顶部快速索引超过既有100KB限额，已将+325重复摘要收短，正式记录及冻结归档完整保留。未修改或跳过上限检查，修正后重新校验。此为交付文档本地校验，不是APK构建失败。

## +327 背景逐帧平滑 · 最终CI与未发布APK交付

2026-10-08 00:37（北京时间），0.42.83+327，agent/v04283-background-smoothing，源码6dbde7c49a96f732a8f35975b2461ec27ac1e077，tree 4a4f89a14e35cf41590677a72ca355c0bdb69cce。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

问题证据：用户2026-10-07 23:53报告背景帧数偏低，23:55确认人物动画正常。代码中的姿态请求33333微秒和30ms门槛将目标更新限制在约30Hz，Flutter/native背景直接使用事件位置。这是可确认的台阶来源；人物正常不能单独排除背景GPU成本，尚无用户设备实测FPS。

修改清单：姿态改为请求16667微秒、15ms重复事件门槛，实际采样由硬件决定；既有120ms姿态滤波保留。Flutter背景由显示帧ticker按35ms时间常数向最新目标平滑，原生在既有GL帧做相同时间响应，无新原生渲染循环。收敛后Flutter停止ticker；关闭、切页、后台、传感器不可用及重新校准立即停止/归零，native深度开关及GL重建也复位。原整体平移、深度shader、强度和边距均未改，人物动画帧率未改。

验证：完整Actions 37650541415（build job 112895018928、native job 112892450243）及专项37650541791（job 112892410889）均success，head与交付源码一致。149项源码门、1413项全量Flutter、413项专项、22项Android35原生通过，Kotlin/Java单测、analyze、签名及完整资源门通过。新增Flutter核心3项、真实widget1项，Java平滑核心3项、ES2像素1项：低频单次输入之间连续变化、30/60/120帧时间响应一致、收敛停调度、后台/切页/释放/复位停止。原像素几何测试等目标收敛后仍执行原幅度/边缘断言；未削弱断言或跳过检查。本轮CI无失败重试。新增host-owned RoomMotionInterpolator加入既有host排除清单，导入源码26文件数及原SHA保持，原源码钉住门通过。本地缺桌宠帧/LingChat特效/kotlinc的3项已在CI补验。analyze仍有非致命提示，不声称零提示。

下载：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f30a80b0b9613d403ee3
APK直链：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-f30a80b0b9613d403ee3/AI-Companion-v0.42.83-327-Background-Smoothing-APK.apk
文件：AI-Companion-v0.42.83-327-Background-Smoothing-APK.apk；736752169 bytes；release 405962303（draft=true）；asset 619217660（uploaded）。
APK SHA-256：b122abdb3a884a90b2cca75ff62d1eab1be6067358d8ae22feddd3d4934cd4eb
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04283-monitor.txt，status/run/head/signer/hash与release APK digest逐项一致。原62文件LingChat、四张背景/深度图、编译shader、131项星谷、塔罗22张、Genie/桌宠资源均校验通过。
Actions API：2026-10-07T16:15:01Z开始，2026-10-07T16:34:48Z更新为completed/success。当前已结束，不应将旧工具状态判为还在构建。没有合并main或正式发布。

用户设备的实际FPS、手感和功耗仍TRUE DEVICE PENDING；此次交付证明去除了已知30Hz姿态限制并有逐帧过渡，不能保证任何手机稳定60FPS。沿用聊天顶部头像/DeepSeek→聊天画面→聊天背景下“立体背景”及既有开关/强度，无需重新开通。构建和最终总账分别提交，APK对应上述源码commit。


## +328 系统待办确认 · 最终CI与未发布APK交付

2026-10-08 03:50（北京时间），0.42.84+328，agent/v04284-reminder-confirmation，源码deba3136bc2dc61ecaa7754d99136fea703478d0，tree 100952dffd42c7200ef31eb8ddf1e4606552d57e。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

授权与范围：用户2026-10-08 02:15授权阅读上下文后实施。保留最长5分钟，系统到点响铃；深色紫色计时卡片只有确认键，无左滑/取消，通知栏停止动作移除，Android所需的服务状态通知保留。确认仅表示收到，不表示完成；超时仅表示无确认，不推断没听见。超时后补确认保留曾超时及原停铃时间。原生前台/浮窗/锁屏页共享持久化状态，应用内保留待确认入口；清通知、返回、重建不误确认或重置计时。

到点建立一次独立、不占日常主动额度的生成提醒，系统响铃不等模型。快速确认或超时不取消初次提醒，也不强制新回复；用户实际发送消息取消尚未投递提醒，旧请求迟到不能写入聊天或通知。编辑/删除/停用、恢复身份变化、更新一次发生也拦截旧投递。消息围绕事项和原定时间，不声称铃声仍在响，不固定句式。确认/超时事实进入普通回复及普通主动上下文。普通主动在生成前及最终SQLite提交时双重检查：响铃中和实际结束后10分钟暂停、不扣次数、不积压已生成正文，恢复后正常重新评估；用户回复、明确安排的其他提醒、原独立游戏分享语义保留。

重复规则增加每天、自定义星期、独立启用开关，兼容仅一次、每年及旧JSON；本地下一次调度不依赖确认和AI运行开关。每次发生有独立身份，同时到点不覆盖，逐条确认不误停其他事件，计时基于原始开始/截止和单调时钟。缓存仅状态序号推进时落盘，取消轮询不重复写相同数据。每个事项初次提醒沿用12小时迟到有效界限，近7天最近12条事实进入提示词；本机保留最多100条非响铃历史。模型实际投递仍取决于AI运行条件与网络；导入保留重复配置，旧运行身份的未发提醒与缓存失效。

验证：完整Actions 37673051886（build job 112972486008、native job 112970193713）及专项37673051744（job 112969412877）均completed/success，head逐项匹配源码。149项源码门、1424项全量Flutter、424项专项、26项Android35原生通过；Kotlin/Java、analyze、签名与完整资源校验通过。新增真实SQLite/受控异步模型/真实widget/原生生产视图与记录测试，覆盖秒确认、用户消息抢先、原子提交、修改失效、超时补确认、静默10分钟、恢复身份与旧快照、仅新状态写缓存、星期编辑/开关、日期跨年/闰日/时区、卡片重建计时、多个事件独立确认。analyze门通过但仍有非致命提示，不声称零提示。

过程修正：第一轮界面测试发现编辑器控制器过早dispose，修复为TextFormField管理生命周期；恢复测试补齐正式恢复协调器提供的新epoch；两项原生测试改为按occurrence身份核对结果，保留确认/其他项响铃/计时/真实按钮断言。未删除测试或放宽断言。数据库只增加提醒导入与消息提交门，备份/恢复/所有权方法未动，另六个共享核心文件hash保持；整文件数据库钉住随已审阅增量更新。原Caicai导入源码及资源钉住保持。

下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-26a8aa0da9f6ea12d228
APK直链：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-26a8aa0da9f6ea12d228/AI-Companion-v0.42.84-328-Reminder-Confirmation-APK.apk
文件：AI-Companion-v0.42.84-328-Reminder-Confirmation-APK.apk；736780301 bytes；release 406072898（draft=true）；asset 619639128（uploaded）。
APK SHA-256：7c705eac95c2455b91ff2fe5127a325e7729aeaf1fd48906a828d1afe4706e8e
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04284-monitor.txt。status/run/head/signer/hash与release APK digest逐项一致。没有合并main或正式发布。

最终Actions从2026-10-07T19:15:06Z到2026-10-07T19:48:41Z，含排队；资源步骤618秒、Kotlin312秒、全量Flutter166秒、APK编译207秒、Draft上传33秒。中途旧HEAD因修正被取消，不应混同最终成功HEAD。用户03:45两次询问状态时仍在APK编译，已明确尚未交付；最终上传后立即提供直链，随后收尾总账。无证据将开发等待归因于总账，本轮缓存优化针对应用内重复写入。

使用：聊天快捷面板→代办提醒，在编辑器选择重复类型与星期；同页提供精确提醒、锁屏全屏、悬浮窗权限入口。自动化证明代码和受控时序通过，用户手机实际锁屏/浮窗、声音/振动、系统后台限制及真实网络模型表现仍需真机验收，不记为TRUE DEVICE PASSED。APK对应上述源码commit，总账收尾为单独文档提交。

## +329 授权、恢复与实施入口

2026-10-08 08:55用户明确授权agent/v04285-reminder-compact-cache本次改动及必要修正上传catkiss62/ai-companion-build，运行CI并构建未发布测试APK。上一轮本地27c3b66/cbc0305在推送时被自动审批阻塞，未启动CI；期间旧窗口目录被回收。当前窗口从远端同一eb5c5f3基线恢复对话中完整补丁，旧SHA不冒充现提交。当前仓库公开，用户本轮授权已解除上传阻塞，不合并main或正式发布。

范围：右下角精致黑紫小卡、缩小确认按钮、前台不打开新页；响铃使用来电音量，尊重静音/振动；DeepSeek缓存仅有依据低风险处理，高收益高风险方案记录。保留5分钟、确认仅收到、每次发生身份、多条独立、用户消息取消未发提醒、独立额度、结束后10分钟普通主动静默。提示词/记忆/实时状态/第二通道不为缓存改写。必须重跑完整验证并查看实际渲染，CI与真机严格区分。

+329中途核验：首推41acfcf专项428通过；完整37710902856原生28/29，卡外触摸测试未等待异步performClick，APK未构建。修正为系统输入注入+等待主线程空闲，断言保留。真实截图另发现背景覆盖按钮内边距，已修正并补最小48dp宽断言。最终待测源码d22ab783e3a933e5aa3684a62d6b1f0c425e5137（tree5ed7dbecf688684b526356ad0de1082d0580772c），完整37711964410/专项37711964395运行中，未声称通过。

+329截图重跑：d22ab78原生29/29通过，但真实截图为空白首帧；未将其记为视觉通过。补等待绘制及卡片底色像素断言，最终源码6e7c330a511e1ff0240a3d5df14f42ab6504b1ef（tree780247269a81dc7c4488e9c6830a86540c7b7feb），完整37712705898/专项37712705851。上一完整构建因新版推送自动取消，后续只核对最终HEAD。

+329最终原生与视觉：8513ea508014e1527c7ace8c6525be17c04134fc，tree6f63234e3254cc67653bc048068c5972d2de26de。完整37713200224原生job113103672400：29tests/0failures/0errors/0skipped，83.531秒；专项37713200199：428通过。原生artifact11522548395（sha256:229a414920e3fafdc6bd662721e84df137d94dd38cce370c65429e8f72aafb1e）真实截图已复核：右下角280dp上限黑紫卡，按钮内边距和48dp触摸宽高通过，外部点击与音量流恢复通过。6e7c330非公开截图API编译失败，改公开waitForIdle后通过；该失败未改产品代码。APK构建正在进行，真机仍PENDING。


## +329 最终交付核验 · 2026-10-08
源码8513ea508014e1527c7ace8c6525be17c04134fc；完整Actions37713200224全部必需任务成功。全量Flutter、静态分析、源码门、Kotlin测试、APK编译、稳定签名及完整资源验证通过；专项428项、原生29项通过，最终截图已复核。状态CI PASSED / APK READY / TRUE DEVICE PENDING。
未发布下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e1f86bbcf4416f1a9784
文件：AI-Companion-v0.42.85-329-Compact-Reminder-APK.apk
SHA256：ef8f965e58a7252007b28e9cea33477f6e4545df6d119a965968d816078cbf34
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
本轮完成右下角黑紫小卡、来电音量及缓存诊断隔离；不宣称缓存命中率提升。待真机验证来电音量/静音振动、锁屏/浮窗、确认/超时和多提醒。历史测试失败及修正路线保留；后续任务从总账6.3入口继续。


## +330 开始记录 · 2026-10-08
用户12:22明确授权按本窗口方案实施；先前分析讨论完成，没有隐含删除存档或修改人格许可。基线远端ac45a6d（本地交付文档同blob，4d8f5f1），新分支agent/v04286-expression-wish-awareness。详细设计、证据、测试范围见app/docs/EXPRESSION_WISH_AWARENESS_v0.42.86.md。当前仅DESIGNED / IN PROGRESS，未声称实现/CI通过。

+329原接班快照保留：
## 当前接班快照 · +329 提醒小窗、来电音量与缓存审计（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.85+329，agent/v04285-reminder-compact-cache，源码8513ea508014e1527c7ace8c6525be17c04134fc。用户已授权推送/CI/未发布APK。右下角黑紫小卡直接挂原页面；响铃跟随来电音量；DeepSeek仅补诊断，不改提示/记忆/路由。专项37713200199的428测试通过；完整37713200224已成功，APK编译、签名及资源校验通过。此前卡外触摸测试时序、真实截图暴露按钮内边距已修，原生29项与截图复核通过，APK已就绪；HyperOS真机待验。恢复与失败路线见文末及app/docs/REMINDER_COMPACT_CACHE_v0.42.85.md，后续从6.3取。

### +330 实现及验证过程（2026-10-08，CI尚未结束）
- 当前源码aca8596477d98650b7f005bf1ec9dae6bb7c4ab6，tree45f21b487c2c8e563f0f98124a575d118ce53325；本地4cda70e与远端源码树一致。
- 通知：保存Android消息类别/持续服务/组摘要/内容摘要/消息时间；30分钟有界去重，5分钟近期证据、3分钟有效期；系统/推广/服务不算聊天，同一通知新内容保留，通知到达不推断用户忙碌。主动额度及唤醒方式保持。
- 愿望：统一自主处置输出字段，扩展已有愿望时的原始聊天检索至256条并保留相关决定及上下文，仍有14天/条数限制；字段校验及原criterion不变。诊断记录无提案、应用、拒绝原因，不保存聊天正文。原存档白房间想通/结案原话在倒序索引81/83，旧recent64看不到，新窗口可以覆盖；不删除或强行完成旧愿望。
- 待办：EmotionEnvelope清理正文/分段/通知，现有分类器写情绪元数据；空正文不发。既有提醒时间、确认、用户发言接管、普通主动静默合同保持。
- 表达：同一次正文调用自主选择展开、直接程度、分享/承接/追问/收尾、玩笑/动作；近6条只有结构统计，允许维持语气，不强制轮换、不用短回复推断讨厌话题。文字演出开关默认开；角色扮演免注入，新话题不读取旧结构，明确格式优先；不改人格/梦境/白房间游戏机制。
- 本地149项源码检查初轮122通过，18项版本列表及表达入口断言更新后通过；9项缺CI外部资产或Kotlin工具链，交由完整构建验证。
- 首轮源码dbe5d7d：专项37728701773因新增测试缺android_bridge导入在analyze失败；完整37728701813被后续提交替换。第二轮d005ac5：专项37728979645 analyze通过、446测试通过/1失败（新增集成测试没有真实user消息夹具），完整37728979662被后续提交替换。两处均修正测试，未借此改产品历史路由或放松断言。
- 当前专项37729350521、完整37729350559仍运行。没有发布/真机验收结论；等待准确结果后补交付信息。
- 进展更新：专项37729350521已成功（analyze通过、447项测试通过）；完整37729350559的caicai-native-smoke成功，build-apk阶段开始。仍无APK交付结论。

### +330 最终交付（2026-10-08，CI PASSED / APK READY / TRUE DEVICE PENDING）
- 产品源码：aca8596477d98650b7f005bf1ec9dae6bb7c4ab6；源码树45f21b487c2c8e563f0f98124a575d118ce53325。最终文档提交只包含本总账和本版设计/验证记录，使用[skip ci]，产品代码与APK不变。
- 专项 https://github.com/catkiss62/ai-companion-build/actions/runs/37729350521 成功：Flutter analyze通过、447项测试通过。
- 完整 https://github.com/catkiss62/ai-companion-build/actions/runs/37729350559 成功：源码回归、Kotlin桌宠/悬浮窗/待办测试、Flutter analyze、1446项全量Flutter测试、29项Android原生测试、release构建、资源完整性与稳定签名检查全部通过；APK上传成功。
- 未发布下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-c2c8f01f80ed2abe1173 。Draft Release 406425036，tag v0.42.86-expression-wish-test，target aca8596477d98650b7f005bf1ec9dae6bb7c4ab6。
- APK：AI-Companion-v0.42.86-330-Expression-Wish-APK.apk；资产620806591，736800029字节。直链 https://github.com/catkiss62/ai-companion-build/releases/download/untagged-c2c8f01f80ed2abe1173/AI-Companion-v0.42.86-330-Expression-Wish-APK.apk 。校验文件资产620806593、CI记录资产620806614。
- SHA-256：67c2c4c7e46b027d70ba57c721a0ac19a80545058e904002a84c4d36ccc5256b；CI计算值与GitHub上传资产digest一致。
- 签名SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48，与+329相同，可覆盖安装。
- 使用说明：文字演出→自主表达方式默认开启、可以关闭。旧愿望在后续既有评估时机读取相关原话并自行提出处置，不在安装时删除/强制完成。待办标签修复适用于新生成回复；不批改历史聊天。
- 真机待验：通知分类对设备/App实际通知格式的效果、白房间愿望后续自主处置、自然表达多样性、待办新回复显示。没有凭CI宣称真机通过，也不承诺模型每句必然不同或永久不误判。


## 当前接班快照 · +330 表达选择、通知判断与愿望同步（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.86+330，agent/v04286-expression-wish-awareness，源码aca8596/tree45f21b4。通知/愿望/提醒标签/自主表达已实现；专项37729350521、完整37729350559成功，447专项/1446全量Flutter/29原生通过。同签名未发布APK与证据见文末及app/docs/EXPRESSION_WISH_AWARENESS_v0.42.86.md。真机效果待用户验收；入口6.3。


## +331 Live2D耳鳍与表情分层（2026-10-08）

用户16:22授权：七预设与wink分开、明确可和情绪及五官叠加，道具策略不加强；同时尝试修正画面右耳初始偏扁。比较菜菜fb04512f，默认配置blob一致，固定耳旋转未补偿投影宽高比；已数学确认非等距，但不能据此宣称截图唯一根因。实现按sceneHeight补偿成像旋转、保持校准平移/角度/比例；七预设与wink分题同次Jev调用，原生允许两层共存、同层互斥及组合wink手势冲突保留。详情与测试见app/docs/LIVE2D_EAR_FACE_v0.42.87.md。当前IMPLEMENTED，构建和真机均待验证。不上传用户截图/诊断/私有模型。

## +331 最终CI与未发布APK交付

源码a857385dec246e69a71510901511c84ba7a7b75d，tree aa1ccadb8e4c5f7baddfdb12728e30d95612e456。完整Actions37750314371与专项37750314477均成功：149源码校验、448专项、1447全量Flutter、29 Android原生回归及Java/Kotlin单元测试通过。耳旋转像素长度/支点/缩放测试与预设/wink互斥测试包含在Caicai*Test门内。签名/APK资源校验通过，沿用+330签名。

下载：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-3284acba17a4e6bbaa4b/AI-Companion-v0.42.87-331-Live2D-Ear-Face-APK.apk
草稿页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-3284acba17a4e6bbaa4b
Release406622978，asset621281205，736801493 bytes。
APK SHA256：ff5d1963c0e779ac033b1f05cf638e7d93f43e489116f718b7daa6db3debae87。
Signer SHA256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。

状态CI PASSED / APK READY / TRUE DEVICE PENDING。用户需观察画面右耳默认宽度、变小及转头、输入法开关，并自然观察七预设与wink组合。数学失真已修正，不等同已证实截图唯一根因；没有真人模型渲染A/B验收。表情不设频率配额，道具策略不加强。未合并main、未公开发布草稿、未上传私有模型和用户诊断。

## 当前接班快照 · +331 Live2D耳鳍与表情分层（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.87+331，agent/v04287-live2d-ear-face。七预设/wink独立判断及原生共存；耳鳍旋转按逻辑舞台比例补偿。道具策略不变，无频率配额。完整37750314371与专项37750314477通过；耳鳍待真机对比；详见app/docs/LIVE2D_EAR_FACE_v0.42.87.md和文末。+330交付证据保留文末。


## +332 右耳临时调整（2026-10-08）

18:04用户取消先前“修复右侧耳鳍”默认关闭开关；该开关未实现。保留+331的修复显示，改为画面右耳整体网格位移/旋转临时编辑，方便用户校准后导出诊断并由后续任务固化默认值、移除编辑入口。临时值默认零，不改变当前显示。位移以未手调右耳宽度为单位（正x右、正y上），角度为逆时针度数；在耳间约束之后、整体root之前，右耳所有drawable同矩阵变换。预览静止、确认保存、取消回滚。初次启动/热恢复读取偏好，诊断明确列出值和编辑状态。CI通过，真机校准待用户确认。详见任务文档。


交付状态：CI PASSED / APK READY / TRUE DEVICE PENDING。源码2bf43e165f3e9308b58c703301851d1a641bdd69，tree0303e28847ff0d49fdfc30f6bf1f95fb8ea378d7。完整Actions37763443087（build113267104033、native113265230837）成功；专项37763443064成功，452项；全量Flutter1449项、Android原生29项及Java/Kotlin、源码、签名、资源检查通过。新刚性变换测试覆盖距离守恒、不同宽高比、零值、缩放；编辑保存/取消及偏好热恢复通过。未替代用户真机位置验收。

首次完整37761824780被PortableCompanionState.kt固定哈希拦住；复核该文件仅新增rightEarX/rightEarY/rightEarRotation三个便携偏好白名单项后更新钉住值，未修改恢复事务或削弱检查。初次专项37761824661亦通过。复跑完整与专项均成功。

APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-7d812a92ed33b5d5c0f7/AI-Companion-v0.42.88-332-Right-Ear-Editor-APK.apk
Release406700602，asset621541522，736807709 bytes。
SHA256：04ff083c54f5e86fb560735fc8d70f037fb841a38bdd112682adaf073c2cbb8b
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。保留同签名Draft APK，未发布或合并main。
下一步：用户在Live2D设置→调整右侧耳鳍（临时）调整并确认，导出Live2D诊断；收到确认参数后再固化默认值并删除入口。


## +333 右耳定版（2026-10-08）

用户真机调整截图水平−7.5%、垂直4.0%、旋转显示9.4°；同次诊断caicai-runtime-v287实际已保存right_ear_adjust_x=-0.075、y=0.04、rotation_degrees=9.45、editing=false。按诊断完整精度9.45°固化，不按一位小数反算。右耳全部drawable仍通过原共同刚性矩阵在耳间约束后变换，尺寸变化时位移仍按原耳宽缩放；左耳不变。移除“调整右侧耳鳍（临时）”入口、滑条、previewRightEar命令和动态偏好读取，避免更新后旧设置双重叠加。备份白名单保留旧键以便导入+332存档，但渲染器不使用它们；原+332定版诊断由固定值键说明。版本0.42.89+333，分支agent/v04289-right-ear-baked。CI通过、APK已交付，用户真机对新版显示待核。详见app/docs/RIGHT_EAR_PLACEMENT_v0.42.89.md。


最终交付：CI PASSED / APK READY / TRUE DEVICE PENDING。源码a3a5b15051294b1ffa792bb4c06d1d9b9fc16e9f，源树b4a00efa8319ff55fb57866fd224b544e8b5a021。完整Actions37805027819（build job113409859915、native job113406994251）和专项Actions37805027930（job113406946098）均成功；149源码门、1447全量Flutter、450专项、29 Android35原生及Java/Kotlin通过，APK签名/资源校验通过。
APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-2b24ab65170a4acaa614/AI-Companion-v0.42.89-333-Right-Ear-Baked-APK.apk
Release407040117，asset622356758，736802525 bytes，SHA256：3f5ef4d82b7ef68231a183dfd8f229b85ec674d4623a7f770043071e43c94dbf。
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。保留同签名Draft APK，未发布或合并main。用户给出的+332画面即参数基准，+333安装升级后显示和入口移除仍待用户真机核对。


## +334 旧桌宠修图接入 · 实施记录

用户授权替换自己抠图及补全的306档图像，并生成两档缩图，要求先读桌宠代码、保持功能和素材可维护。已核对PetSkinManifest、PetAnimationPlayer、PetFrameCache、PetFrameView、旧资源恢复/校验与最终APK构建路径。上传ZIP中58张306有像素变更、118张小中档未变；ZIP内yawn为旧图，使用另外上传的修订yawn。全部新306画布与旧图相同。生成59个原件对应的177张PNG，保留独立PNG以便GitHub预览和下次修图。原始冻结素材归档不变；构建在源包历史验证后按清单复制，不改播放器，不新增运行时解析/图像处理。当前IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING。


## +334整理保留的原接班快照 · +333 右耳定版（APK READY / TRUE DEVICE PENDING）

0.42.89+333，agent/v04289-right-ear-baked。用户真机确认诊断−0.075、+0.04、9.45°；固定右耳整体变换，删除临时入口/命令/偏好读取，旧存档耳值兼容但不生效。见app/docs/RIGHT_EAR_PLACEMENT_v0.42.89.md；+332交付记录留文末。

+334 推送阻塞：自动审核拒绝将本轮用户新上传修订图推送到公开仓库，理由为素材向GitHub目的地外发授权未明确；未绕过拒绝。已完成本地生成、代码核查和资源验证，待用户明确允许推送到catkiss62/ai-companion-build的agent/v04290-pet-retouch分支并构建未发布测试APK。此时尚无远端CI结果或新APK。

+334 授权解除：2026-10-09 19:12用户明确允许本批修订图片和改动推送到catkiss62/ai-companion-build的agent/v04290-pet-retouch分支并构建测试APK。此前审核阻塞解除；命令行push缺少认证，改用已连接GitHub仓库接口上传同一源码树，不扩展发布范围。

+334 跨窗口续传接班：上一窗口达到上下文上限。当前本地分支干净、HEAD128fa5d，检查点pet-push-state334.json保留205项及uploaded_count=140；逐项git hash-object核对全部一致，待传65项。远端目标ref为404、该分支Actions数量为0，故不能把已存Git blob当成完整推送或构建成功。远端+333分支HEAD47171054997db64ab799f4af8f802bd34d28eaf8，最近有效专项37805027930与既有完整37805027819成功。PCA上窗口检索出错，使用现存唯一总账、本批任务文档、上传检查点及当前远端事实定点交接；没有遍历聊天或扩读历史。已复跑177图字节/尺寸校验和完整实际帧引用集合校验，均通过。继续保留59原件、118预乘Alpha单次Lanczos缩图、原画布/路径/帧序及原播放器；上传检查点逐项落盘，最终源码tree须与本地完全一致，完整CI、APK内177张新图及417文件验证和稳定签名通过后交付。尚未宣称CI或真机通过。


## +334整理保留的+308顶部接班索引

## 当前接班快照 · +308 体验改善第二批

2026-10-02 接替因对话上限被用户手动停止的窗口。当前开发分支 `agent/v04264-experience`，基于 `0ff59c0ff850af4dd78857baf13eb46ed254470f`（+307功能 `5ad45f0`，Actions `36946211181` success）；接班时工作树干净、无第二批产品改动或构建。用户已确认+307真机无问题并允许开始第二批；这只表示本次日常验收，不补认尚未观测的极端/长时场景。+306仍是用户指定的可用对照，不需整包备份。

本批四项：游戏任务真实状态/有效剩余时长；离线/过期提醒准确时效表达；沉浸房间先本地结束、联网补整理且失败保留原文；重要信息矛盾的低频澄清，未答暂缓、不把沉默当确认、复用现有记忆修订。当前 v0.42.64+308 IMPLEMENTED / CI PASSED / APK READY / TRUE DEVICE PENDING。首轮发现手动暂停未立即结算，已修复并补测；专项101项、全量Flutter1152项（含本批16项）、Android15原生18项、139项源码门及签名/资源检查全部通过。2026-10-02 16:32用户明确授权本分支当前改动及本轮必要修正推送、CI与未发布测试APK构建；上轮授权阻塞已解除。

必须保留：手动暂停即停止当前时长任务、不积存待补时长，中性结果回报；单人至少两分钟推进和5/10/1轮分享；普通聊天不增加每轮DS规划；内部处理DS、双通道正文Gemini一次最终生成；设置读档不重载Live2D；+307状态围栏/取消/恢复事务。禁止固定角色回复兜底。桌宠渲染、图片地址过滤、可选API来源绑定暂缓；工作区与陪玩模型另议。允许开发分支推送及未发布测试APK，不合并main/正式发布。

最终功能提交 `dad52be3c45f97f7aa2064eca8dceb70e68d194f` / tree `53553806c2cc74a0141a0249ee8fabfd0ca461b0`；[完整Actions36985831222](https://github.com/catkiss62/ai-companion-build/actions/runs/36985831222) success。[未发布+308测试APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-0cac33eb64faac342d0c)，Draft401660027 / asset605227641，SHA-256 `fbe209532a97c5756520e1e1bbe94e5e190020b47f7ce2594ae2eacaa777a43f`，同一持久签名可覆盖安装。未合并main、未正式发布，真机体验仍待用户验收。

完整本轮记录从正文“+308 接班与实施记录”进入，最终证据见文末“+308 最终CI与未发布APK交付”。后续优先验收本批；其余候选仍从6.3唯一后续清单及+307末段取，不复活已撤销旧任务。



+334 接班校验修正：续传文件全量205/205完成，远端tree359c9e3a9a7dcd0c85e3de3eb97885418cd05a75与本地863b743相同，远端源码0c48f2f，完整Actions37935827155启动。接班记录写入后，额外本地总账校验发现quick index100448字节超过既有100000上限；将旧+308顶部全文搬至正式记录区并留下入口，未删历史/改阈值。专项workflow原push列表漏了+334，本次补入现有列表，使修正提交同时运行完整和既有专项门；不改测试范围或产品行为。修正后的完整CI与APK仍待验证，原运行被新提交替代。


## +334 首次完整CI失败定位与修正

源码479b286f6a6df072540df0cacd86ab770f33f012 / tree903b5720e30f01c8dd4ae3e42bffa0b2dde9f73d，完整Actions37936112594：150源码门、Kotlin/Java单元、1447全量Flutter、29原生、release编译、177修订图与417源包文件逐字节校验、稳定签名均通过；在后续“Verify release APK Genie and complete pet payloads”失败。实际报错为sleepy_yawn_187.png不符合approved aligned source；旧段仍钉住修图前的dcbbcba4/f6659dc5/141a8840三图哈希。新版三图画布136×160/171×202/222×261不变，新哈希056911ef/c82d3c95/252553bd；306即用户独立原件。不能将此运行写为CI PASSED或APK READY。专项37936112662成功450项。

修正只将APK旧哈欠哈希段改为读取已审核修订manifest里的三个精确SHA-256，保留固定三档尺寸、PNG/文件清单、未知集合拒绝及前置177图/417源包验证；原validate_v0342_personality_appearance.py的冻结原图哈希仍保留，并在覆盖前执行。不改人物图、播放器或测试门，不删除/放宽失败校验。后续改306并再生成时不需手改第二套哈希。定点检索确认旧哈希仅在冻结来源校验和该APK段重复。重跑前直接执行workflow实际哈欠验证段，分别检查三张修订图接受、旧图拒绝和修订集合缺项拒绝，再启动完整与专项CI。上一窗口和本次的推送授权继续有效。

操作记录：生成续传检查点时git diff默认对中文路径转义，首次解析失败，改用--name-only -z按NUL解析后所有205项逐个哈希匹配；没有丢失或改名文件。CI仅按当前步骤和报错范围提取，不完整回显日志。


## +334 最终CI与未发布APK交付

2026-10-09续传和必要修正完成。交付源码`1f6de26c69958a59db9569c10f5a5e7b759c2c73` / tree`dde723b7cadfdb8149acabc030b5c1e6f2405426`，与本地560ef2d内容树一致。205项原续传文件全部完成，补上专项分支触发后共206项相对+333变更；177 PNG无需重复上传。全部59张306原件和用户ZIP/独立yawn逐字节相同；118张187/238从对应306单次预乘Alpha Lanczos缩小。运行时播放器、帧序、时序、镜像、锚点、设置和新动画保持原逻辑，最终包验证完整96 clips/23013 frames/192835596 bytes。

完整Actions[37939853983](https://github.com/catkiss62/ai-companion-build/actions/runs/37939853983)成功，build job113853699637、native job113851195620；专项Actions[37939853995](https://github.com/catkiss62/ai-companion-build/actions/runs/37939853995)成功，job113851151756。150源码门、Kotlin/Java桌宠/Live2D/悬浮窗/待办及既有单元、1447全量Flutter、450专项、29 Android15/API35原生全部通过。release编译、177修订图和417源包全文件逐字节检查、旧哈欠改为manifest精确哈希后的完整资源门、塔罗/星谷/背景资源和稳定签名全部通过。

Draft Release407936478，target明确指向交付源码；未发布、未合并main。
下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4cf0810a030b12182bda
APK：AI-Companion-v0.42.90-334-Pet-Retouch-APK.apk
直链：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-4cf0810a030b12182bda/AI-Companion-v0.42.90-334-Pet-Retouch-APK.apk
资产625177441，736803277 bytes；SHA-256：`a5c064e350be6b40595e5d3c7a7fe50752888f903f0959597f0b31a554e0f113`。CI计算值、成功monitor及GitHub上传资产digest三方一致。校验文件资产625177442，成功CI记录资产625177448。
签名SHA-256：`30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48`，与既有+329/+333持久身份一致，可覆盖安装。

失败路线保留：37935827155因总账quick index100448字节修正而被新提交取消，不是通过；37936112594虽然1447/29等和177/417字节检查通过，但后置旧哈欠原图哈希不接受修订图而失败，不能标绿。旧源图校验仍在覆盖前执行，最终APK哈欠哈希统一读取审核manifest，固定尺寸/恰好三档/未知缺项拒绝保持。实际workflow段本地接受三张新图、分别拒绝每档旧图、拒绝缺项；最终37939853983实际完整门通过，不是跳过或放宽校验。中文Git路径检查点解析用--name-only -z；稀疏检出的维护README用git add --sparse提交，未漏维护文件。

交付状态CI PASSED / APK READY / TRUE DEVICE PENDING。静态三档预览已检查；需要用户真机查看小/中/大档白边、补全部位，以及入睡/醒来、行走衔接和自然播放。没有实体REDMI设备测试，不把模拟器/CI通过当成用户验收。唯一总账已更新；后续任务仍从6.3和本批app/docs/PET_RETOUCH_v0.42.90.md进入。冻结历史归档字节和哈希不变，旧+308顶部全文移入正式记录，顶部只保留入口。


## +335 开工与原+334接班快照留存

## 当前接班快照 · +334 旧桌宠修图（CI PASSED / APK READY / TRUE DEVICE PENDING）

0.42.90+334，agent/v04290-pet-retouch。59张用户306原件、118张透明缩图；首次完整CI旧哈欠哈希冲突已修正，重跑通过。相同路径替换，运行代码不改。维护、验证与来源见app/docs/PET_RETOUCH_v0.42.90.md及文末。

2026-10-09接班历史（已完成）：本地HEAD128fa5d，上传检查点为205个变更文件中140个Git blob已上传、65个待传；远端开发分支未建立，本版Actions尚未启动。全部检查点路径/哈希与本地一致，177张修订图和现用帧覆盖校验通过。沿用用户19:12指定分支上传/构建授权，保留已有对象并补传缺失项；以+333远端4717105为基线核对最终tree后触发构建。当时CI和真机均PENDING；现CI通过，真机仍待验证。后续任务入口6.3，不扩展本批范围。

最终源码1f6de26；完整37939853983、专项37939853995成功，150源码/1447全量Flutter/450专项/29原生及177修订图、417源包和稳定签名通过。[同签名未发布+334 APK](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4cf0810a030b12182bda)已就绪；完整哈希和失败路线见文末。三档观感与动作衔接待真机观察。


检查证据：用户+333存档69附件中57条表情引用50个blob（25用户/32助手），50原图12,350,790 bytes、缩略图10,066,362 bytes，无同SHA重复原图、无遗留空blob附件。当前用户和助手均经prepareImage/commitDraft，首次从sticker_packs复制到media_blobs，再发仅复用。旧文档“直接引用图库”不准确；清理页混列非重复聊天媒体。只读检查未修改用户原备份。2026-10-10 00:13用户授权本任务实施、验证和测试APK。

+335 首轮专项37959021020：静态分析通过，471行为通过/2失败；10项新增共享存储测试均通过。旧组合包测试用安装目录重造ZIP而带上本机引用清单、备份结构夹具1x1PNG被Flutter实际解码拒绝；已定点修订夹具并保留导入与解码校验。追加不同原图共用缩略图的删除保护。源码门因共享恢复入口变更，审阅后更新对应两文件固定哈希；协议、数据库schema、原生恢复不变。仍CI PENDING，不交付首轮包。

+335 第二轮专项37959646477/源码792b73c：474项全部通过，包含11项新共享存储回归和2项真实备份恢复测试。完整构建源码6cf1b7251a1b19618828f2ed12c65f85fd562c73（本地45d367f，同树0d505c4feb090d10ae7f2c3760e9d74781c4c56f），Actions37960129667，配套专项37960129742。本地源码门143通过，7项缺既有资源/kotlinc交完整CI；不把本地缺项冒充CI通过。运行代码与签名待完整验证，真机PENDING。


## +335 最终CI与未发布APK交付

2026-10-10：0.42.91+335，agent/v04291-shared-stickers；源码6cf1b7251a1b19618828f2ed12c65f85fd562c73（本地45d367f），tree0d505c4feb090d10ae7f2c3760e9d74781c4c56f。完整Actions37960129667（build job113922980893、native113920628757）和专项37960129742成功。150源码门、1460全量Flutter、474专项、Android原生及Kotlin/Java通过；177修订PNG、417源包、96 clips/23013 frames、TTS/塔罗/星谷/深度资源和稳定签名门均通过。没有省略旧资源门。

交付APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-3af8d7187795ebbb0af9/AI-Companion-v0.42.91-335-Shared-Stickers-APK.apk
下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-3af8d7187795ebbb0af9
Draft Release408144930，APK asset625608110，736817013 bytes；SHA-256 dedece455b5cde6e59e6895ec1f924e04f5019bda93487d614c02d9fd862dc6a。CI实际校验和上传资产digest一致。
Signer SHA-256 30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48，与前版一致，允许覆盖安装。未合并main，未正式发布。

本版实现：导入图库与消息共享不可变原图，双方与Agent表情发送直接建立引用；已有旧图库自动归一，仍允许按需产生一份共用缩略图。保护图库/聊天/相册所有权以及同缩图多原图边界，恢复备份保留本机图库原图，保留当前不携带全图库的备份策略。清理界面不再把图库持有的原图列为可删缓存，并如实说明删除历史媒体的影响。完整实现/失败路线/复用与迁移验证见app/docs/SHARED_STICKERS_v0.42.91.md。

状态仅CI PASSED / APK READY / TRUE DEVICE PENDING。用户真机重点：打开一次表情面板或清理页完成既有图库整理；双方重复发同图，不新增原图副本；关闭重开App和备份恢复后历史图保持；删图库后历史聊天仍能显示；仍有普通聊天图片可出现在清理列表。用户上传的+333存档与诊断只读留本地，没有推送或修改。


## +336 表情面板读取优化 · 实施记录（2026-10-10）

2026-10-10用户报告每次打开转圈数秒并授权优化。基线+335/8ded16e9，agent/v04292-sticker-picker-speed，目标0.42.92+336。按包批量解析共享映射，复用内存索引；导入/删除/启停/保存描述及恢复后刷新。无新增图片副本。方案和验证入口app/docs/STICKER_PICKER_SPEED_v0.42.92.md；其他任务仍从6.3定点读取。构建与真机尚待验证。

旧面板反复scan/readRecords并逐图fileFor，导致重复读取整包JSON及目录查询。新目录冷读一次索引/按包解析映射，暖读仅检查包级元信息及已有恢复epoch。新增600张不同PNG/重复打开/跨实例与并发/变更失效/异常修复/旧图库迁移测试，实际SnapshotService测试增加目录失效检查。保留+335共享原图、安全迁移、删除保护和外置图库备份策略。CI/安装包最终结果后续追加，不把实现视为真机通过。


## +336 最终CI与未发布APK交付（2026-10-10）

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。
源码d113aa586ef083fa54aef4554b9b84c6d6888508（本地8f2442f），tree f70e6d1d8a7f28b841d7026d9c148c25d8554eab；分支agent/v04292-sticker-picker-speed。
完整Actions37983371136成功（native113999204991/build114001322337）；150项源码检查、1469项全量Flutter、29项Android15原生、Kotlin和资源/签名检查通过。同源码专项37983371114通过483项。先前专项37982939024也通过483项。
600张不同PNG测试：冷读123050μs/暖读3069μs；每包记录读取一次、逐图fileFor为0，复开不增图片文件。前次独立专项为176281μs/2839μs。均为CI样本，不代表真机耗时或+335同条件对照。

交付Draft Release408311823，tag v0.42.92-sticker-picker-speed-test：
https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-3fdb7f790e133d701ae1
APK：AI-Companion-v0.42.92-336-Sticker-Picker-Speed-APK.apk，asset626074088，736822257 bytes（约703MiB），uploaded。
SHA-256：00097a19e016305fa60d8eac373315443df3be785893c217c488fdcd5a432ba6（CI日志与GitHub资产digest一致）。
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48，未变化。
校验文件asset626074090，CI监控asset626074091，均uploaded。未合并main、未正式发布。

修复：面板按包批量解析映射；复开复用内存元数据索引；导入/删除/启停/描述保存/恢复后正确刷新。保留共享原图、历史消息和旧包迁移保护，不新增图片副本。+334修订的59张306源图与118张派生图（177PNG）在APK内核验通过，原417文件/完整桌宠动画及TTS等载荷保留。用户备份和诊断未上传。
首轮专项仅测试依赖引用错误，已改为Flutter自带接口，随后两轮专项和完整构建通过；未放宽断言、未新增图片库依赖。完整过程见app/docs/STICKER_PICKER_SPEED_v0.42.92.md。
待真机：覆盖安装后首次打开及连续关闭/重开表情面板的等待；描述编辑、启停/重导入后显示。首次进程启动或图库变化仍需加载，不承诺所有设备零等待。


## +337 实施记录 · 2026-10-10

IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING。相关性复用现有Jev批次，明确来源与历史来源合并去重、有限并发完整读取并展示进度；增加正文与网页阶段耗时诊断。兴趣探索和近期发现交替，依据公开题材/兴趣/共同话题，保留少量探索，区分主要事件与发布日期并检查重复报道。没有近期证据则不凑新闻。偏好形成和工作区仅审计，学习运行策略未修改；短句偏好误拒有针对性测试。完整范围、边界和真机待验见app/docs/WEB_RELEVANCE_RECENCY_v0.42.93.md。不上传用户诊断或存档，不合并main。


## +337 最终交付 · 相关网页读取与近期发现（2026-10-10）

CI PASSED / APK READY / TRUE DEVICE PENDING。功能源码aa9669b6d191be83032d8affcc1984b2332d856b（本地24fcb1e），tree059bde2f34c2a17edb00d0a1ca95a62cbf1326f4；分支agent/v04293-web-relevance-recency。完整Actions38028661621/build114145945108成功，150源码门、1478全量Flutter、Kotlin和资源/签名检查通过；同源码专项38028661659/job114144801226通过528项，Android15原生114144888018通过29项。先前中间版本16945ad的527专项和29原生通过，完整构建因补充质量保护被新版本取代；不混作最终完整CI证据。

修复：旧网页检索后借现有Jev批次确认相关性，不确定仍读原文，可选项缺失不重跑主路由；来源去重、有限并发完整读取与可见进度；网页及正文通道耗时记录；近期发现与原探索交替，结合已有成熟兴趣、用户内容偏好、近期共同话题及少量探索；事件日期与发布日期分开核验，旧闻重发/重复报道/时间不明不凑近期分享；空搜索不记接口故障。不增加普通聊天逐轮Agent，不降低完整阅读标准，不恢复已撤回的Phase3C消费注入。

偏好形成与工作区仅审计：短句/同义表达的固定措辞和中文重合门可能误拒；短句进不了语义复核；有反证的候选即使重新成熟也可能被普通聊天查询排除；沟通偏好的六小时环境式激活限制仍需评估。短期上下文可以影响表达，回复后已有提取队列，不是只能空闲学习。不能把全部拒绝视为误判；学习运行策略没有改。深度思考通常已有DS工具规划，以讨论为主暂不必加通用工作区，可将来另议有界讨论笔记。完整分析见app/docs/WEB_RELEVANCE_RECENCY_v0.42.93.md。

同签名Draft Release408691466，target aa9669b6，tag v0.42.93-web-relevance-recency-test：
https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-d94d8e8a410d9c8c70f8
APK asset627172435：AI-Companion-v0.42.93-337-Web-Relevance-Recency-APK.apk，736834041 bytes，uploaded。
SHA-256：cbfcaab96c4acea618f871b7b7701cd8d57a0350c966e170d91463df9cf64c72（CI/GitHub digest一致）。
签名：305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148，未改变。校验文件627172434、CI监控627172441均uploaded，Actions artifact11661497279。未合并main、未正式发布、未上传用户诊断/存档。图库共享原图、资源和其他既有链路保留；177张修订桌宠PNG及原完整载荷核验通过。

待真机：聊天无关网页等待是否减少、相关原文读取进度是否可见、停止与引用行为；近期分享的新颖性/真实日期/自然度。没有用CI性能代替真机提速结论。当前总账与任务文档均已同步交付证据。


## +338 游戏意图连续性 · 实施与验证记录

2026-10-11用户授权开始。实现分享历史对照、念头正文/理解修订及基于真实证据的旧记录修复、单人自然停顿的愿望机会、输入与结果回执、近期双向聊天方向参考、API26/27舞台真实隐藏。详细边界和测试计划见app/docs/GAME_INTENT_CONTINUITY_v0.42.94.md。CI尚未完成，不宣称APK就绪或真机修复。第6项不实施，保留用户关于梦境仅标题美化的解释。
