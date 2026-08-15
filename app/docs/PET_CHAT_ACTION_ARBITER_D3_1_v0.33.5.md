# 桌宠聊天动作仲裁 D3.1（v0.33.5+60）

## 目标

本轮让桌宠在悬浮聊天打开时继续显示，并把真实生成/TTS 状态接入原 `THINKING`、`TALKING` 动作；同时合入两项真机视觉小修。

数据库 schema 维持 `21`。没有新增 Desire、Thought、Memory、Somatic 或人格真源。

## 聊天窗口与桌宠窗口

- 悬浮球模式沿用旧行为：聊天展开时隐藏悬浮球。
- 桌宠模式不再因聊天展开而隐藏。
- 聊天窗口显示并更新输入 flags 后，桌宠窗口通过移除并立即重新添加的方式成为同类型 `TYPE_APPLICATION_OVERLAY` 中最后加入的窗口，因此位于聊天框上方。
- 桌宠窗口仍只有自身方形范围接收触摸；窗口外的聊天列表和输入框继续正常操作。进入/退出输入模式后再次确认桌宠层级。
- 锁屏、系统 cover、入口切换和服务释放仍沿用原生命周期，不因聊天共存扩大可见范围。

## 生成与 TTS 到动作的纯映射

`PetConversationPolicy` 只读取已有真实状态：

| 已有状态 | 桌宠 cue | 动作 |
|---|---|---|
| 无生成、TTS 非 playing | idle | 不强制表达动作 |
| generation active，phase 为 thinking/cancelling/未知 | thinking | `THINKING` |
| generation active，phase 为 answering | talking | `TALKING` |
| TTS phase 为 playing | talking | `TALKING`，优先于生成 phase |
| TTS synthesizing，但没有活跃生成 | idle | 不把“合成中”伪装为已经说话 |

发送成功结束后保留 3 秒 TTS discovery grace，使聊天已收起时也能捕获紧接 durable commit 启动的自动朗读；一旦观察到 synthesizing/playing，轮询持续到真实 idle。

## 动作仲裁

- `THINKING/TALKING` 是持续 cue，不修改原 actions manifest 的 2400ms/2900ms 时长。
- 原动作自然结束回到 `IDLE` 后，如果 cue 仍有效，则重新进入对应动作，保留原 enter/body/exit 语义。
- 拖动、下落、着陆、眩晕、摸头、戳碰、尾巴反应和生气仍可按原 priority/force 规则打断聊天表达。
- 瞬时动作结束回到 `IDLE` 时，若 generation/TTS 仍有效，则恢复 `THINKING/TALKING`。
- cue 变 idle 时，只退出当前 `THINKING/TALKING`；不会强行中断触碰或物理动作。
- 动画本身不写 Thought/Desire/Memory，不产生 satisfy，也不绕过现有 Gate。

## 真机视觉修正

- `ANGRY` 源 PNG 已有橙色怒气标记；关闭 `PetFrameView` 额外绘制的红色对角 `×`，避免它被误认成未读/关闭角标。源 PNG、帧序、时长和动作 manifest 不改。
- 竖屏额外底部安全距离由 4dp 调至 10dp，只上移约 6dp。
- 横屏以及竖屏上、左、右边界保持 v0.33.4 数值不变。

## 验证

- `PetOverlayContractTest` 验证 thinking/answering/playing/synthesizing 到 cue/action 的纯映射。
- `validate_v0335_pet_chat_action_arbiter.py` 冻结置顶共存、输入模式重置层级、生成/TTS 轮询、3 秒 discovery grace、动作恢复、底边 10dp 和愤怒特效去重。
- GitHub Actions 继续执行全部历史 validators、Kotlin 桌宠单测、Flutter analyze/tests、release APK、417 文件素材包和 6 个 arm64 native 库字节核验。
