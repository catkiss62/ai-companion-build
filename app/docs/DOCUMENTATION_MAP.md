# 文档地图

> 目标：一个永久总账入口，少量按领域维护的当前契约；版本演化和退役材料由 Git 历史保存，不让多个旧状态同时参与 AI 检索。

## 1. 阅读顺序

1. 根目录 `AI_Companion_当前总账.md` 顶部“当前接班入口”，读到“历史工作记录”标记即停；
2. 本文档；
3. 与当前任务直接相关的专项设计；
4. 实际源代码、测试/validator、CI、最新脱敏诊断和实机结果；
5. 修改旧功能时，按总账模块导航定向回读对应历史；只有系统审计、冲突或无法定位的回归才默认全文扫描。

冲突优先级：

```text
用户最新明确决定
> 实际源码与 CI/实机证据
> 最新脱敏诊断
> 当前总账
> 当前专项设计
> Git 历史
```

## 2. 唯一总账

- 永久入口：`/AI_Companion_当前总账.md`
- 后续只修改这一个文件，不再创建 v37、v38 等版本号副本。
- README、App README 与 Roadmap 只链接这个入口。
- 历史总账从 Git 历史恢复，不在工作树建立“历史总账”目录。

## 3. 当前专项文档

### 人格、驱动、情绪与关系

- `INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md`：欲望/内在驱动唯一融合主干；已吸收旧审计中的 screen companion 与维护约束。
- `PERSONALITY_TRIAL_SYSTEM_v1.md`：性格试穿。
- `PERSONALITY_INNER_VOICE_v2.md`：长期人格内心声。
- `PROMPT_WORKBENCH_v1.md`：提示词工作台。
- `PERSONALITY_LEARNING_GROWTH_PHASE1.md`：人格学习/成长 Phase 0 分类、Phase 1 只观察证据合同与第一真机卡点。
- `NSFW_CONTEXT_ROUTER_v1.md`：独立上下文路由与安全边界。
- `EMOTION_ENGINE_EXPANSION_EVAL_v1.md`：情绪引擎扩建/停止判据。

### 普通聊天时间语义

- `ORDINARY_TIME_SCENE_BOUNDARY_v0.41.12.md`：普通聊天真实用户现场/最近互动双时钟、手机预计算 gap band、短寿命活动重判与沉浸 Session 隔离。
- `PHASE01_TIME_AUDIT_HARDENING_v0.41.13.md`：Phase 0+1 旧 Memory/Relationship 绕过审计、direct feedback/命题边界、半小时双时钟一次详细注入、主动消息不刷新用户现实与人称出站守卫。
- `AGENT_OPERATION_TRUTH_SCREEN_OBSERVATION_v0.41.14.md`：可核验操作必须有匹配 terminal Outcome、成长系统 observation-only 元数据只读，以及用户明确触发的一张当前屏幕截图、敏感页 Gate 与临时字节隐私合同。
- `SELF_EXPERIENCE_DESIRE_WEB_PHASE2A_v0.41.15.md`：Phase 2A 自我回顾候选/体验 Outcome、baseline-centered 欲望动力学、熄屏联系窗口、三类自主联网与四分支结果评价合同。
- `PHONE_UI_INTEGRATION_v0.41.16.md`：Phase 2A 观察兼容的查手机/快捷侧栏/沉浸布局整合合同；明确购物车隐私、只读状态页及总设置第二步边界。
- `CHAT_UI_MOOD_HOTFIX_v0.41.17.md`：v0.41.16 真机呈现热修；固定聊天白字、三处对白颜色联动、THINKING 折叠头、心情图宽度、购物车 emoji 与侧栏关系天数单一数据源。
- `SETTINGS_INFORMATION_ARCHITECTURE_v0.41.18.md`：总设置六域、侧栏单一真源、分小节保存、高风险动作隔离、自检副作用分层，以及同包对白紫色/主动回想文案合同。

### 身体与感知

- `DUAL_CHANNEL_SENSE_v1.md`
- `SOMATIC_CONTRACT_TOUCH_v0.32.0.md`
- `SOMATIC_AI_TO_SELF_v0.32.1.md`
- `DESKTOP_PET_SOURCE_PARITY_v0.33.1.md`：已吸收桌宠架构、性能、隐私与素材许可边界。

### Agent 与联网

- `AUTONOMOUS_ACTION_FOUNDATION_v0.34.7.md`
- `PUBLIC_WEB_DISCOVERY_v0.34.8.md`

### UI 与仓库入口

- `UI_INFORMATION_ARCHITECTURE_v1.md`：五域迁移；已吸收性格底色 UI 的唯一数据源约束。
- `DOCUMENTATION_MAP.md`

### 本地 TTS

- `TTS_RUNTIME_UPGRADE_v0.39.5.md`：当前妹居 TTS 资源、调用、分句与停止契约。
- `TTS_RUNTIME_MANIFEST_v0.39.5.json`：当前 32 项打包资源的大小与 SHA-256 清单。

## 4. 后续可逐步合并，但不阻塞开发

| 未来当前契约 | 可吸收来源 |
|---|---|
| `PERSONALITY_PROMPT_SYSTEM_CURRENT.md` | 性格试穿、内心声、提示词工作台中仍有效的重叠原则 |
| `SOMATIC_SYSTEM_CURRENT.md` | 触觉身体契约与 AI-to-self；双通道文档保留来源原则 |
| `INNER_DRIVE_DESIRE_SYSTEM_CURRENT.md` | 当前融合备份内容，文件名从 BACKUP 稳定迁移 |

只有当新契约完成、引用更新且内容核对后，才删除来源文件；不为追求文件数量而强行合并不同职责。

## 5. 本次已退役的工作树入口

以下路径已在确认并吸收独有内容后从工作树删除，仅从 Git 历史恢复：

- 版本号总账 `AI_Companion_接班总账_v36_2026-08-17.md`
- `app/docs/HANDOFF.md`
- `app/docs/PROJECT_TASK_LEDGER.md`
- `app/docs/DEV_STATUS.md`
- `app/docs/DESIRE_SYSTEM_AUDIT_v1.md`
- `app/docs/ANDROID_DESKTOP_PET_PLAN_v2.md`
- `app/docs/PERSONALITY_BASE_UI_v1.md`

更早的根目录 v29–v32 与 `HANDOFF_LEDGER` 版本文件也只留在 Git 历史。

## 6. 文档维护协议

1. 新任务、排期、实现、CI、实机证据统一更新永久总账；
2. 专项文档只保存稳定机制、接口、边界和验收标准；
3. 总账链接专项文档，但不整篇复制；
4. 每次删除前先扫描引用并吸收独有内容；
5. 旧验证器不能强制要求可变交接文档存在；
6. 纯文档提交不提升 APK 版本，不冒充运行实现；
7. Git 历史负责恢复，工作树负责表达当前真相。
8. 历史过程保留在永久总账的档案标记之后；新增当前记录写在标记之前，并保持档案基线可机械核对。
