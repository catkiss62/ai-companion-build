# AI Companion · Android 桌宠原项目动作同构说明

版本：`v0.33.1+56`  
日期：2026-08-15（Asia/Tokyo）

## 纠正内容

v0.33.0 的 D1 预览将工作素材集压缩成单一 238px、27 个播放器条目和 66 张 PNG，并自行编写了简化 manifest。该做法没有按视觉相似性逐帧去重，但错误地把原项目的“18 个行为动作”拆成了“27 个图片片段”，同时漏掉三档尺寸选择、enter/body/exit、程序性动作、动作持续时间和拖拽生命周期。

v0.33.1 撤销该精简路线：

- 完整保留用户提供的 417 个文件、111,962,623 bytes，不删除外观相似帧，不丢弃 GIF、候选图、masters、说明文件或三档运行帧。
- 直接读取原始 `assets/manifests/actions.json`（format v4，SHA-256 `3db9c886c7ebb0a73df996796cc10f1649fda39b0d3e8b86dad053085ac3ac59`）。
- 行为层严格保持 18 个原动作；素材层保持 28 组 asset、210 张 187/238/306px 运行帧。其中 201 张由当前 manifest 直接引用，另外 9 张上游 runtime/fallback 文件也原样保留，不因当前未引用而删除。
- Android 端移植原项目的最近尺寸选择、方向素材选择、帧时钟、90ms 同素材淡入淡出、enter/body/exit、优先级/中断/返回状态、程序性效果和抛掷物理。
- GIF 继续作为原项目的预览资料保留，但运行时仍按原代码读取 PNG 帧，避免把展示 GIF 错当动作源。

## 18 个动作中文对照

| 中文 | 原始 ID | 关键衔接 |
|---|---|---|
| 待机 | `IDLE` | 循环；方向可切正面/背面 |
| 眨眨眼 | `BLINK` | 5 帧 → 待机 |
| 四处看看 | `GLANCE` | 7 帧 → 待机 |
| 发呆 | `THINKING` | 思考姿势 → 待机 |
| 散步 | `WALKING` | 起步 → 四帧循环 → 收步；左右素材独立 |
| 开心 | `HAPPY` | 单次 → 待机 |
| 被摸摸 | `HEAD_PAT` | 6 帧，不可被低优先级打断 |
| 说话 | `TALKING` | 单次 → 待机 |
| 生气 | `ANGRY` | 单次 → 待机 |
| 被戳 | `POKE_REACT` | 4 帧 → 待机 |
| 尾巴被碰 | `TAIL_REACT` | 4 帧 → 待机 |
| 吃东西 | `EATING` | 3 帧 → 待机 |
| 扫地 | `SWEEPING` | 单次 → 待机 |
| 睡觉 | `SLEEPING` | 入睡 → 睡眠循环 → 醒来 |
| 抓取中 | `DRAGGING` | 拖动期间保持，必须由松手事件退出 |
| 落下 | `FALLING` | 释放帧 → 落下循环，由物理落地退出 |
| 着陆 | `LANDING` | 3 帧 → 待机；重摔可排队眩晕 |
| 眩晕 | `DIZZY` | 重摔反馈 → 待机 |

## 预览验证

- 预览页按钮显示“中文名 + 原始 ID”，状态栏显示当前 phase、asset、尺寸档和帧号。
- 可切换左/右/背面/正面以及 187/238/306px，验证三档文件和方向素材。
- 在角色区域真实拖动：移动超过阈值进入 `DRAGGING`；松手强制进入 `FALLING`，先播放 `released_airborne` enter 段；物理稳定后进入 `LANDING`；重摔排队 `DIZZY`。
- “复位待机”是预览页的显式逃生按钮，防止保持态被误判为播放器卡死。

## 后续边界

本阶段仍是普通 Activity 隔离预览，不替换 Overlay。动作同构验证通过后，D2 才把相同播放器接入独立 Android 桌宠窗口，并复用现有悬浮聊天入口。


## 自动验证证据

- GitHub Actions run #47（ID `31867409197`）完整通过：417 文件恢复、源协议与历史回归、Kotlin 动作/物理单测、Flutter analyze/tests、release APK、APK 内完整 payload 核验、SHA 和 artifact 上传。
- artifact `9242561565`：`AI-Companion-v0.33.1-56-Desktop-Pet-Source-Parity-APK`，ZIP digest `sha256:4058b67b7d8739c57dae6442306fc6524c81229e6b542d56c15c206e2aeafac9`。
- APK：238,499,224 bytes；SHA-256 `456d618776b1729353ea1735a63a139eb344cab9e1b296066bdbed04ef1759b7`。
- 下载后独立读取 APK ZIP 再确认：417 个 source 文件、210 张 runtime PNG、1 份原始 actions manifest、1 份中文标签表。

## 从旧 Android 方案吸收的长期约束

以下仍有效的内容已从退役的 `ANDROID_DESKTOP_PET_PLAN_v2.md` 并入，避免只保留素材同构而丢失系统边界。

### 定位与架构

桌宠只是同一个“她”的表现层，不建立第二人格、第二欲望或第二心情数据库：

```text
AI Self / Desire / Thought / Awareness / Chat / TTS
→ Pet Presentation Policy
→ Android Overlay Renderer
```

优先复用一个前台 Service，在内部区分 Pet window/controller 与 Chat window/controller；动画、触摸和聊天各自有职责，但共享同一生命周期与角色状态。桌宠不能读取 Thought 原文，也不能绕过主动消息 Gate。

### 性能与系统边界

- 屏幕关闭、锁屏、低电量、省电或内存压力时暂停/降级动画并释放非当前缓存；
- 银行、敏感页或 `HIDE_OVERLAY_WINDOWS` 场景可能由系统/目标 App 主动隐藏，不能无限自愈抢回；
- 桌宠窗口不得被屏幕识别再次捕捉而产生视觉回音；
- 文件选择器、全屏页和 Overlay 恢复是独立问题，不能靠桌宠功能掩盖；
- 拖拽、横竖屏、安全区、锁屏恢复和长时间内存稳定必须分别测试。

### 素材许可

当前素材仅按用户授权用于私人、非商业 AI Companion，并保留 attribution。该授权不自动扩展到公开发布、商业发行或第三方再分发；用途改变时必须替换素材或取得明确授权。皮肤导入还需校验路径穿越、压缩炸弹、超大图片、缺帧、非法 fps、hash 与许可字段。

### 交互不可回归

- 桌宠与悬浮球二选一；
- 桌宠双击打开菜单，单击/触碰保留身体互动；
- TTS 实际播放与已提交正文可触发 TALKING，合成等待不伪装为说话；
- 用户沉默、屏幕陪伴或普通等待不映射成伤心、追问和关系确认；
- 动作表达可甜、俏皮、好奇、专注、犯懒、得意或吐槽，不能全部退化为撒娇和等待。

