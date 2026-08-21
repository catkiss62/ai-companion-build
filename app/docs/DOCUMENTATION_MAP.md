# 文档地图

> 目标：工作区只保留一个“当前总账”入口；成熟系统保留各自的当前契约；历史过程交给 Git 历史，而不是让多个过期总账同时参与检索。  
> 本文件记录信息层级和清理计划，不代表候选文件已经删除。

## 1. 阅读顺序

新的开发窗口或 AI 接班时按以下顺序读取：

1. 根目录当前总账；
2. 本文档；
3. 与当前任务直接相关的专项设计；
4. 实际源代码、CI、最新脱敏诊断和实机结果。

发生冲突时：

```text
用户最新明确决定
> 实际源码与 CI/实机证据
> 最新脱敏诊断
> 当前总账
> 当前专项设计
> Git 历史
```

文档不能覆盖已验证的实际行为；旧版本号不能覆盖当前决定。

## 2. 唯一总账迁移

当前分支的唯一最新总账内容仍在：

- `/AI_Companion_接班总账_v36_2026-08-17.md`

目标稳定入口：

- `/AI_Companion_当前总账.md`

迁移必须一次完成：

1. 用当前 v36 完整内容创建稳定入口；
2. 更新 README 和所有活动文档中的引用；
3. 做链接与关键词扫描；
4. 核对新旧内容一致；
5. 经用户确认后删除版本号文件。

在完成这组操作前，不额外创建第二份完整总账，以免短期出现两个“当前真相”。

## 3. 建议保留的当前专项文档

### 人格、驱动与关系

- `app/docs/INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md`：欲望与内在驱动统一系统的成熟基线。
- `app/docs/PERSONALITY_TRIAL_SYSTEM_v1.md`：性格试穿机制，待后续并入人格当前契约。
- `app/docs/PERSONALITY_INNER_VOICE_v2.md`：人格内心声与连续性，待后续并入人格当前契约。
- `app/docs/PROMPT_WORKBENCH_v1.md`：提示词工作台，待后续并入人格/提示词当前契约。
- `app/docs/NSFW_CONTEXT_ROUTER_v1.md`：独立的上下文路由与安全边界，暂不与人格文档混删。

### 身体与感知

- `app/docs/DUAL_CHANNEL_SENSE_v1.md`：双通道感官源资料与项目适配。
- `app/docs/SOMATIC_CONTRACT_TOUCH_v0.32.0.md`：触觉身体契约，待后续合并成身体系统当前契约。
- `app/docs/SOMATIC_AI_TO_SELF_v0.32.1.md`：AI-to-self 身体通道，待后续合并。
- `app/docs/DESKTOP_PET_SOURCE_PARITY_v0.33.1.md`：桌宠来源一致性与追溯。

### Agent 与联网

- `app/docs/AUTONOMOUS_ACTION_FOUNDATION_v0.34.7.md`：自主行动基础契约。
- `app/docs/PUBLIC_WEB_DISCOVERY_v0.34.8.md`：公开网页发现能力与边界。

### 本轮新增

- `app/docs/EMOTION_ENGINE_EXPANSION_EVAL_v1.md`：是否扩建情绪引擎的客观判据。
- `app/docs/UI_INFORMATION_ARCHITECTURE_v1.md`：五域 UI 分类与迁移顺序。
- `app/docs/DOCUMENTATION_MAP.md`：本文档。

## 4. 建议合并的文档组

合并前先逐段检查独有内容，不能只按文件名删除。

| 目标当前契约 | 建议吸收来源 |
|---|---|
| `PERSONALITY_PROMPT_SYSTEM_CURRENT.md` | `PERSONALITY_TRIAL_SYSTEM_v1.md`、`PERSONALITY_INNER_VOICE_v2.md`、`PROMPT_WORKBENCH_v1.md`、仍有效的人格 UI 决策 |
| `SOMATIC_SYSTEM_CURRENT.md` | `SOMATIC_CONTRACT_TOUCH_v0.32.0.md`、`SOMATIC_AI_TO_SELF_v0.32.1.md`；`DUAL_CHANNEL_SENSE_v1.md`保留为来源与原则 |
| `DESKTOP_PET_SYSTEM_CURRENT.md` | `DESKTOP_PET_SOURCE_PARITY_v0.33.1.md` 与旧 Android 桌宠方案中的独有内容 |
| `INNER_DRIVE_DESIRE_SYSTEM_CURRENT.md` | 以 `INNER_DRIVE_DESIRE_SYSTEM_BACKUP_v2.md` 为主，吸收旧审计中仍未体现的有效结论 |

“CURRENT”文件完成、链接更新并核对后，才讨论删除来源文件。

## 5. 待用户确认的迁移/删除候选

这轮不删除。建议下一次用一个受控的纯文档提交处理：

### 总账与交接重复入口

- `AI_Companion_接班总账_v36_2026-08-17.md`  
  仅在 `AI_Companion_当前总账.md` 创建、引用更新、内容核对后删除。
- `app/docs/HANDOFF.md`  
  含大量版本过程和可能过期的 APK/状态摘要，与当前总账重复。
- `app/docs/PROJECT_TASK_LEDGER.md`  
  与当前总账重复，容易形成第二套任务状态。
- `app/docs/DEV_STATUS.md`  
  版本和 schema 已明显落后。

### 已被更成熟方案覆盖的候选

- `app/docs/DESIRE_SYSTEM_AUDIT_v1.md`  
  先核对并吸收独有结论到当前欲望/驱动契约。
- `app/docs/ANDROID_DESKTOP_PET_PLAN_v2.md`  
  先核对独有内容是否已经进入来源一致性或代码。
- `app/docs/PERSONALITY_BASE_UI_v1.md`  
  先把仍有效的 UI/人格结论吸收到当前人格契约或 UI 信息架构。

### 已经不在当前 PR 分支中的旧总账

根目录 v29–v32，以及 `app/docs/HANDOFF_LEDGER_v15/v21–v28` 已不在当前开发分支的工作树中。它们仍可从 Git 历史恢复，不需要再建立“历史文档”目录。

## 6. 为什么值得整理

整理不会让模型本身突然变聪明；真正的收益来自：

- 只有一个当前任务状态，不再让 AI 猜哪份总账更新；
- 减少相互冲突的版本号、APK 哈希、schema 和完成状态；
- 专项设计按领域读取，降低无关上下文与 Token；
- 保留成熟系统的完整因果链，不把所有内容塞回一份巨型总账；
- Git 历史仍保留演化过程，可恢复但默认不参与检索。

因此应做“入口去重 + 当前契约合并”，不做无目的的大规模改写。

## 7. 清理执行协议

1. 列出精确路径和每个文件的去向；
2. 用户确认删除范围；
3. 先建立新稳定入口/合并文件；
4. 更新 README、总账和内部链接；
5. 搜索旧文件名、旧版本号和失效相对链接；
6. 核对文档内容与当前代码/CI；
7. 最后删除已确认的来源文件；
8. 使用纯文档提交，不提升 APK 版本、不冒充代码实现；
9. 在总账记录“已设计/已整理/已实现/CI/待实机”的准确状态。
