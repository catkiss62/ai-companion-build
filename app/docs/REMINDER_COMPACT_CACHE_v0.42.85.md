# +329 右下角提醒小窗、来电音量与DeepSeek缓存审计

## 基线、授权和恢复
基线0.42.84+328，源码deba313，交付文档HEAD eb5c5f3。完整Actions37673051886成功，真机浮窗/锁屏/响铃待验。上一轮已补查+328交付到最后授权之间的讨论，补回04:25的来电音量要求、04:29低风险审计边界及04:30开工授权。用户最后追加右下角黑紫精致小卡。

上一轮本地实现27c3b66、阻塞文档cbc0305未上传：自动审批拒绝git push，理由为未确认信任/授权的“私有”仓库。只读API随后证明仓库实际公开且连接有push权限，但当时未取得明确本轮上传授权，因此未绕过。146源码门通过，3项本地资源/kotlinc不足，Flutter/原生新增测试和APK都尚未执行。

2026-10-08 08:55用户明确授权agent/v04285-reminder-compact-cache本次改动及必要修正推送、CI和未发布测试APK。旧窗口临时目录已回收；当前窗口从远端同一eb5c5f3基线恢复对话中记录的补丁，重新核验/测试。旧SHA仅保留历史，不能冒充新提交。本轮不合并main、不正式发布，不上传个人诊断/存档/私有模型。

## 范围与实现
- 前台右下角黑紫小卡直接挂到已有MainActivity，不启动新页面，也不依赖系统悬浮窗权限。280dp宽上限、12dp间距；真实可见区域避让系统栏和输入法，卡外原界面仍可操作。无待确认时不轮询。前台卡与系统浮窗互斥。
- 其他App上的系统浮窗同样右下角；锁屏/点通知仍用系统允许的提醒Activity，但为透明无全屏底色/遮罩的小窗口。解锁情况下不发fullScreenIntent。
- 标题最多两行、原始截止计时、细紫进度条、多条数量；确认可见胶囊约36dp高，触摸区48dp。确认只处理对应occurrence；切前后台/重建不确认、不重置倒计时，不增加左滑/取消。
- 音频由USAGE_ALARM改USAGE_NOTIFICATION_RINGTONE，跟随来电音量，保持原提示音文件选择。普通模式响铃，振动模式仅振动，静音不响不振；勿扰由系统来电策略处理，不强制音量。在本App有响铃时音量键指向来电，结束/离开恢复原通道；其他App上的音量键归系统/前台App，不能保证替其切通道。
- +328的5分钟、确认仅收到、超时事实、独立发生身份、多条独立、用户发言接管未发提醒、独立额度、结束后10分钟普通主动静默保持。提醒runtime、数据库、投递以及普通/主动/Cedar提示模块与基线逐字节一致。

## 缓存审计证据
仅定点提取用户2026-10-07T06:45诊断modelUsage段，报告是+322而非+328，120条为有限历史窗口。agent_tool_planning 3次：input65632/hit14592/miss51040；cedar_background_plan 5次：37469/5120/32349；memory_extraction 30次：260459/132224/128235。不能当本版效果或稳定基准。

final_reply 31次输入619335、proactive_final_reply 13次输入178911，均hit=miss=0；旧记录无provider/model，不能把这些视为DeepSeek 0%命中，也不能事后断言每条的服务。第二通道不纳入缓存优化。旧shape只哈希content，空content的不同tool_calls会被看作相同。

现有工具schema递归键排序已完成，不计本轮收益。低风险处置仅诊断：增加通道枚举、模型/接口脱敏哈希、完整缓存计数可用标记、请求开始到usage回报的耗时（不是首字）；新增DeepSeek专用按用途/模型/接口汇总，排除第二通道、无标签旧记录、缺失/不自洽计数。保留旧byLane。shape v2增加包含tool_calls、tool_call_id、role、reasoning等字段的完整消息哈希；不存正文、工具参数、凭据或完整接口。请求体、提示顺序、工具列表、重试和模型路由不变，不声称本轮提高了缓存命中率。

依据：DeepSeek Context Caching https://api-docs.deepseek.com/guides/kv_cache/ 的自动前缀缓存；Android AudioAttributes https://developer.android.com/reference/android/media/AudioAttributes 与AOSP audio attributes映射中RINGTONE/SONIFICATION对应STREAM_RING。本轮未添加cache_control、未假定固定TTL或最低token门槛。

## 高风险候选（REVIEW ONLY / NOT IMPLEMENTED）
| 候选 | 定点证据与潜在收益 | 风险/后续要求 |
| --- | --- | --- |
| 固定规则前移 | prompt_builder：身份、分层规则、世界书、动态context，然后操作真值/形态/内心契约；普通与主动共用。历史final_reply多仅前2～3条稳定，但该lane不是可靠DS样本。 | 改变优先级/角色扮演/形态/新话题隔离；先积累通道隔离数据，再最高思考力度专项与同上下文回放。 |
| 游戏指南/实时状态拆分 | cedar_background_plan：固定Cedar规则+含指南/局面的store.promptContext+分享/梦境/愿望；历史hit5120/input37469。 | 不得弱化next_call、授权、盲玩和实时局面；风险高，不在本轮处理。 |
| 记忆裁剪/状态刷新频率 | 记忆提取已有稳定system、动态user；主聊天实时包含心情/梦境/气焰/天气/提醒。 | 冻结或裁剪会损失事实和真人感，不可只追命中率；先评估绝对miss/input、时延与质量。 |
| 工具消息/思考续接改写 | 旧content-only哈希漏tool_calls变化。 | 协议和工具连续执行敏感，只补观测，不删除/重排/规范化实际消息。 |

## 验证与失败路线
旧轮源码门首次暴露历史版本白名单补充不足、快速索引超100KB；已补+329条件并压缩新顶部，完整记录保留，未放宽功能断言。旧轮补丁编辑首次因同一文件delete/add冲突未应用，随后整段写入成功，没有半应用状态。

本轮恢复后必须重新执行验证，不沿用旧本地结果冒充本轮结果。新增Dart实际HTTP请求不变、工具消息哈希差异、第二通道/旧数据/缺统计隔离测试；原生生产卡片/宿主测试覆盖右下角、卡外点击、48dp触摸、独立确认、重建/前后台计时、音量流恢复并保存真实截图。原149源码门、全量Flutter、专项、Android原生、签名及完整资源检查仍由CI执行。自动化通过不代表HyperOS真机已验收。

当前：IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING。
