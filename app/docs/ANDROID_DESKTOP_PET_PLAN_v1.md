# AI Companion · Android 桌宠方案 v1

更新时间：2026-08-14（Asia/Tokyo）

## 1. 结论

可以把 macOS DeskPet 的产品原理拆解后，在当前 Android 项目中自行实现，不需要完全复刻，也不需要强行把 Swift/macOS 窗口代码“移植”为 Kotlin。

找不到完整角色动作帧，不是因为它是 macOS 项目，而是因为 DeskPet 把皮肤设计成用户放在本机目录中的外部资源；公开仓库主要提供引擎、图标和预览，没有随主分支分发完整皮肤包。其主分支当前使用透明 PNG 序列帧，没有发现 Live2D 模型文件。

推荐路线：借鉴行为、状态机、皮肤格式和性能策略；Android 引擎从零实现；未确认授权的代码和素材不复制。

## 2. 参考项目与许可边界

### 主参考：2048Nemo/DeskPet

- macOS 14+，Swift/SwiftUI/NSPanel。
- GPLv3，且基于 GPLv3 项目；如果复制或改写其源码并发布，可能带来 GPL 派生作品义务。
- 动画为透明 PNG 序列帧，支持 idle、walk、sleep、happy/hurt、drag、fall、home、music 等动作。
- 皮肤放在外部目录，不代表公开预览角色素材已经授权给本项目再分发。
- 可借思想：动作目录、`config.json`、随机待机、拖拽/回窝、动作音效、按段预载、流式补帧、相同帧跳过重绘、回窝清缓存。

### Android 辅参考

| 项目 | 可借鉴 | 许可/采用限制 |
|---|---|---|
| `hushino/akimeji-shimeji-and-padorus` | Kotlin、Compose/Room、WindowManager overlay、动作与拖拽组织 | README 称 MIT，但仓库未发现独立 LICENSE；许可确认前只看架构 |
| `lirenzhiling/codex-android-pet` | React Native overlay、WebP spritesheet 导入、拖拽交互 | MIT，可作为导入/交互辅参考，不引入其整套技术栈 |
| `skyvanguard/GooseDroid` | Java Canvas、行为树、物理与触摸概念 | All rights reserved，只能借抽象思路，不复制代码/素材 |

## 3. 本项目中的定位

桌宠不是第二个角色，也不是第二套人格/心情/饱食度系统。它是现有“她”的一个表现层：

```text
AI Self / Desire / Thought / Awareness / Chat / TTS
                       ↓（只读表现事件）
                Pet Presentation Policy
                       ↓
               Android Overlay Renderer
```

- Desire 决定整体动机，但不会直接每次驱动动作。
- mood/当下状态映射表情与动作强度。
- TTS 播放时可做 speaking 动画。
- 新主动消息可做轻提醒动作。
- 屏幕陪伴开启时可切换共同观看/安静待机动作。
- 角色身份、记忆和关系仍只有现有数据库真源。

## 4. 首版范围

### 必做

- 透明背景角色动画。
- idle 多变体与随机选择。
- walk/移动、drag、release/fall、home/回窝。
- 点击展开现有悬浮聊天；长按或拖拽移动。
- 位置保存、安全区域约束、横竖屏适配。
- 全局开关、尺寸、动画频率、音效、点击行为。
- 低电量/高温/后台受限时降帧或静止。
- 一个自制或明确授权的占位皮肤包。

### 能增加乐趣、适合后续迭代

- happy、pout、curious、sleep、yawn、music/sway、peek、surprised。
- 消息到达时挥手/探头；用户点击时随机回应。
- 跟随 Desire/Thought 的低频“想起事情”动作，不自动弹文字。
- 屏幕陪伴：面向屏幕、安静坐下、偶尔反应。
- 表情包系统与桌宠动作共用语义标签，但不共用渲染资源。
- 可导入皮肤包与预览/校验。

### 首版不做

- Live2D。
- 复杂 2D 物理、骨骼或 60fps 常驻。
- 多宠物并存。
- 用桌宠重做 AI 人格或另建需求数值。
- 把桌宠开发当作现有 Overlay 卡死/全屏消失问题的替代修复。

## 5. Android 技术架构

### 5.1 窗口层

优先复用现有 `OverlayBubbleService` 的权限、前台服务和聊天入口，但把窗口拆成职责清晰的两层：

1. Pet window：透明动画、触摸命中、拖拽；尽量小的真实命中区域。
2. Chat window：继续承载现有 Overlay 对话，按点击展开/收起。

若现有 service 生命周期过度耦合，可保留一个前台 service，在内部使用独立 `PetWindowController` 和 `OverlayChatController`，避免再起第二个常驻服务。

### 5.2 渲染层

- Kotlin 自定义 `View` + `Canvas` 或 `ImageView`/drawable 帧播放器均可。
- 首版优先 WebP/PNG 序列；皮肤安装时生成尺寸与帧索引清单。
- 按动作预载首段，后续帧流式读取；LRU 缓存有内存上限。
- 同一帧不重复 invalidate；App 不可见/屏幕关闭时暂停。
- 默认 8–15 fps 足以表现桌宠，按动作单独配置，不追求固定 60fps。

### 5.3 状态机

```text
HOME/IDLE
  ├─ timer → IDLE_VARIANT / WALK / YAWN / SLEEP
  ├─ tap → REACT → IDLE
  ├─ drag_start → DRAG
  ├─ drag_end → FALL/LAND → IDLE
  ├─ message/tts → NOTICE/SPEAK → IDLE
  └─ go_home → WALK_HOME → HOME
```

优先级建议：

`DRAG > SYSTEM_HIDE/PAUSE > SPEAK > NOTICE > DESIRE_EXPRESSION > RANDOM_IDLE`

动作不可无限抢占；每个来源有冷却，重要动作结束后回到稳定状态。

## 6. 皮肤包契约

建议目录：

```text
pet.json
preview.webp
actions/
  idle_01/
  idle_02/
  walk_left/
  walk_right/
  drag/
  fall/
  land/
  sleep/
  speak/
sounds/
LICENSE.txt
ATTRIBUTION.md
```

`pet.json` 至少包括：

- `id`、`name`、`version`、`author`
- `license`、`source_url`、`redistribution_allowed`
- canvas 宽高、anchor、默认 scale、hitbox
- 每个 action 的帧路径、fps、loop、mirror、interruptible
- 可选音效、随机权重、前后继动作
- 最低引擎版本与资源 hash

导入时必须校验路径穿越、压缩炸弹、超大图片、缺帧、非法 fps、许可字段和 hash。

## 7. 与现有 AI 状态的映射

| 状态/事件 | 桌宠表现 |
|---|---|
| 无事件 | 多样 idle，不机械循环同一动作 |
| curiosity 较高 | 看向一侧、探头、短暂观察 |
| reflection/Thought fixation | 思考/发呆，不自动显示 Thought 原文 |
| attachment 较高 | 更容易靠近聊天入口或轻提醒，不持续黏人 |
| fatigue 较高 | yawn/sleep，压制活跃动作 |
| stress 较高 | 轻微不安后回稳，不演惩罚/冷暴力 |
| libido | 普通状态完全不映射；仅亲密会话内使用独立合规动作集 |
| TTS playing | speaking/lip-like 简单动画 |
| 主动消息成功提交 | notice/wave，一次即可 |
| 屏幕陪伴 | co-watch/quiet 动作，用户沉默不触发伤心状态 |

男性向表达过滤：动作集要有甜、俏皮、好奇、专注、犯懒、得意、吐槽式反差等多样性，避免所有事件都映射成撒娇、等待和恋爱确认。

## 8. 性能与系统边界

- 屏幕关闭、设备锁定、低电量、省电模式下停止帧循环或降到静态。
- 每套皮肤记录解码内存预算；低内存回收非当前动作缓存。
- Android 15/厂商系统对 overlay 的限制要做设备矩阵验证。
- 银行/敏感/使用 `HIDE_OVERLAY_WINDOWS` 的 App 可能主动隐藏悬浮窗，这是系统/目标 App 决定，不应无限自愈抢回。
- 文件选择器、权限页、全屏游戏问题需单独复现；桌宠上线前不能掩盖现有冻结缺陷。
- 桌宠窗口不应进入屏幕捕捉分析造成视觉回音；尽量捕捉目标 window 或在分析前屏蔽自身 overlay。

## 9. 数据与隐私

- 皮肤设置、位置和动作偏好可进入普通配置。
- 不保存用户每次拖动的细粒度轨迹。
- 桌宠只消费结构化状态，不读取 Thought 原文、聊天明文或截图。
- 自定义皮肤默认本地；跨设备同步前先确认大小、许可和用户选择。
- 音效、角色图和动作帧逐文件记录来源、作者、许可、修改情况。

## 10. 实施阶段

### D0 · 研究与资产锁定

- 确认首个角色资产来源和再分发许可。
- 决定 PNG 文件夹还是 WebP spritesheet 作为首版标准。
- 用自制占位素材完成许可无风险原型。

### D1 · 隔离播放器

- 在普通 Activity 中实现 skin loader、状态机、帧缓存和测试。
- 不先碰 Overlay，避免把渲染与系统窗口问题混在一起。

### D2 · Overlay MVP

- 接入 `WindowManager`、拖拽、安全位置、点击展开聊天、暂停/恢复。
- 验证前后台、锁屏、横竖屏、文件选择器返回、典型游戏。

### D3 · AI 状态联动

- 只读接入 TTS、消息、fatigue、curiosity 等有限事件。
- 加优先级、冷却和不抢占规则。

### D4 · 皮肤导入与乐趣扩展

- 导入校验、预览、动作标签、音效、更多 idle 变体。
- 屏幕陪伴动作在对应功能存在后再接。

## 11. 验收标准

- 连续运行 8 小时无明显内存持续增长，锁屏后动画停止。
- 拖拽不卡顿、位置不出安全区域、横竖屏恢复合理。
- 点击与拖拽不误触，聊天窗口和 Pet window 不互相抢输入。
- 动作调度可预测、可中断、不会短时间抽搐式频繁切换。
- Active Brain 转移不产生两个主动行为源；非 Active 设备可显示静态或停用。
- 屏幕陪伴中用户沉默不会触发伤心、追问或 `no_response` 表情。
- APK 不包含未授权素材；每个打包资源有许可记录。

## 12. 当前仍需要用户后续提供的资料

不阻塞原理开发，但决定最终外观：

- 用户最喜欢的 DeskPet 视频/皮肤/角色的确切链接或素材包。
- 如果存在所谓 Live2D 分支、Release 或外部皮肤，请给具体 URL/文件名。
- 可再分发授权；若没有，就以自制新角色或明确开放许可素材替代。


