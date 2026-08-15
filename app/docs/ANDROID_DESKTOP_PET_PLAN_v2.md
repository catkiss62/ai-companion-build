# AI Companion · Android 桌宠方案 v2

更新时间：2026-08-15（Asia/Tokyo）

## 1. 结论

可以把 `QCYTSN/ds-local-pet` 的动画组织、行为调度和互动原理拆解后，在当前 Android 项目中重新实现；不需要完全复刻，也不直接搬运 PySide6/Windows 窗口代码。

这个仓库比旧 macOS 参考更接近用户想要的动作表现：公开树中有约 18 类运行状态、分层微活动/完整活动、点击与拖拽、抛落物理、状态恢复和较完整的 PNG 帧目录。但“Windows 项目”不等于能直接移植：透明窗口、托盘、窗口置顶停靠和 Win32 感知必须改写为 Android Foreground Service + WindowManager。

推荐路线：把它作为主架构参考，借鉴 MIT 代码中的 manifest、播放器、状态机和行为调度；Android 渲染与系统窗口层重写。仓库视觉素材明确不在 MIT 许可内，未取得作者或权利人书面许可前不得打入 APK。

## 2. 参考项目与许可边界

### 主参考：QCYTSN/ds-local-pet

- 仓库：https://github.com/QCYTSN/ds-local-pet
- Python/PySide6、Windows 透明桌宠；代码、manifest 与对话配置采用 MIT。
- 可借鉴：`animation/asset_registry.py`、clip/player/state machine/transitions，`assets/manifests/actions.json`，activity director/classifier/scheduler，点击/拖拽/移动/落地与恢复策略。
- 动作资产目录包含 idle、blink、walk、talk、think、sleep、happy、angry、dizzy、poke、head_pat、dragging、falling、landing、eat、sweep 等语义，适合作为 Android 动作契约参考。
- Windows 专属部分不移植：PySide6 透明窗口、系统托盘、Win32 顶层窗口停靠、Windows updater/awareness。
- **许可红线**：仓库 `ASSET_LICENSE.md` 明确说明角色视觉资产不受 MIT 覆盖，来源和再许可未获保证；`assets/processed/runtime`、masters/candidates/previews 与 `sprites/*.png` 都不能因为仓库公开就默认复制或再分发。
- 若实际改写 MIT 代码，必须在 Third-party notices 记录仓库 URL、固定 commit、MIT 文本和修改说明。
- 若用户取得视觉素材明确授权，可按本方案皮肤包契约接入；否则先用自制/生成且权利清晰的占位角色。

### 历史参考：2048Nemo/DeskPet

- macOS 14+，Swift/SwiftUI/NSPanel，GPLv3。
- 只保留其外部皮肤、动作目录、缓存与回窝等概念参考；不复制 GPL 源码或未授权预览素材。

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

- `QCYTSN/ds-local-pet` 视觉素材的作者/权利人明确授权，且授权范围包含修改、打包 APK 与向用户分发；仅有 GitHub URL 不等于授权。
- 若无法取得授权：用户自有素材、委托素材或权利清晰的原创/生成角色资产。
- 首版角色的偏好（体型、服装、主色、动作气质）与是否需要音效；这不阻塞 Activity 隔离播放器。



## 13. 2026-08-15 用户上传素材包审计

用户提供 `素材.zip`，共 475 项、压缩后约 112MB。审计结论：

- 目录和文件名与 `QCYTSN/ds-local-pet` assets 树完全对应，包括 `candidates/state_actions`、`processed/masters`、`processed/runtime/states`、`manifests/actions.json`、`runtime_inventory.json` 和角色 ID `dafeiyu`。
- 包内没有 LICENSE、NOTICE、作者授权或独立来源说明。
- `character_spec.json` 的 `user_authorized_generated_assets=true` 是原项目管线状态；不能解释为对 AI Companion 的再许可。
- `source_inventory.json` 中部分原始参考明确为 `user_authorized=false`。
- 因此该 ZIP 归类为同源 assets 副本，不是独立授权来源。换下载页面或压缩包名称不会改变许可边界。

技术上若取得许可，不应将整个 ZIP 打入 APK：

1. 只保留 `processed/runtime/states` 的最终帧、必要的 `actions.json`/character spec 和一张预览。
2. 排除 candidates、masters、source sheets、chroma sheets、生成 prompt、previews、dialogue 与 source inventory。
3. 转换为 Android 皮肤包契约，生成逐文件 SHA-256、画布/anchor/hitbox/fps 索引和 attribution。
4. 先在普通 Activity 隔离播放器验证，再接 WindowManager Overlay。

原审计状态已在用户进一步说明并明确授权本私人项目使用后更新：`USER_AUTHORIZED_PRIVATE_USE_WITH_ATTRIBUTION`。这不是公开再分发许可；APK 若转为公开发布或商业发行，仍必须替换素材或取得明确授权。


## 14. 2026-08-15 D0/D1 实施状态

- 用户提供 `素材-替换原图片.zip` 并授权仅用于其私人、非商业 AI Companion 项目；项目内保留 `ATTRIBUTION.md` 与 `LICENSE.txt`。
- 逐像素审计确认重新导出的 389 个图像与原包画面一致，因此来源说明按“用户授权的原素材重导出”记录，不表述为独立重绘。
- Android 打包只保留 238px 运行集：27 个动作、66 张 RGBA PNG、低于 6MiB；candidates、masters、source sheets、GIF 预览和 dialogue 均排除。
- D1 已实现普通 Activity 隔离播放器、安全 manifest loader、12MB LRU 帧缓存和动作优先级状态机；未修改现有 Overlay 行为。
- 下一项为 D2 Overlay MVP；实现说明见 `docs/DESKTOP_PET_D0_D1_v0.33.0.md`。
