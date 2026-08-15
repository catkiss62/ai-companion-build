# AI Companion · Android 桌宠 D0/D1 实现说明

版本：`v0.33.0+55`  
日期：2026-08-15（Asia/Tokyo）

## 本阶段结果

- D0 资产锁定：用户提供并授权其私人、非商业 AI Companion 项目使用；项目内保留来源署名和未来公开发布时必须替换/另行授权的边界。
- 将原约 107MB 工作包缩成 238px Android 运行皮肤：27 个动作、66 张透明 PNG、约 4.8MB；候选图、masters、source sheets、GIF 预览和原项目对话配置均不进入 APK。
- D1 隔离播放器：新增安全 manifest loader、路径/帧数/fps/画布校验、12MB 有界 LRU bitmap cache、逐动作帧时钟、优先级状态机和普通原生 Activity 预览。
- 系统页新增“桌宠播放器预览”入口。它只打开普通 Activity，不创建 Overlay，不改变旧悬浮球服务。
- Activity 进入后台时暂停帧循环，销毁时清空播放器回调与缓存。

## 动作集

`idle / blink / glance / think / idle_back / walk_left / walk_right / walk_start_left / walk_start_right / walk_stop_left / walk_stop_right / dragging / released_airborne / falling / landing / sleep_enter / sleep / sleep_wake / talk / happy / angry / dizzy / poke / head_pat / eat / sweep / tail_react`

## 状态优先级

`DRAG > SYSTEM > SPEAK > NOTICE > DESIRE_EXPRESSION > RANDOM_IDLE`

首版状态机拒绝低优先级事件抢占拖拽等不可中断动作；单次动作完成后回到 `idle`。D1 只提供人工预览按钮，不连接 Desire/Thought，也不读取聊天正文或 Thought 原文。

## 性能和安全边界

- 单皮肤最多 64 个动作、单动作最多 48 帧、fps 1～30、画布 32～2048px。
- 只接受皮肤根目录 `actions/` 下的 PNG，拒绝绝对路径和 `..` 路径穿越。
- 当前打包集全部为 RGBA PNG，最大边不超过 512px；CI 要求资源集与 manifest 一一对应且总大小低于 6MiB。
- D1 不修改 `OverlayBubbleService`，因此不会把桌宠误当成文件选择器/全屏 Overlay 冻结问题的修复。

## 下一阶段 D2

在同一个现有前台服务内增加独立 `PetWindowController`：桌宠窗口与聊天窗口分层；实现点击展开聊天、拖拽、松手下落/落地、安全位置、横竖屏恢复、锁屏暂停。完成真机验证前保留旧悬浮球回退入口。


## 自动验证

- PR #11 head：`393e64dee0e505d78ff7da4cad0169d73a128187`。
- GitHub Actions run #43（`31861829909`）：素材/静态契约、全部历史 validators、Kotlin 状态机单测、Flutter analyze/tests、release APK、A2 原生 payload 全绿。
- artifact `9240951958`；APK SHA-256 `db532702a4b0e5412613f05e71b940688ba467e53b747aedf762e6d42dcd2d1a`。
