# AI Companion · Android 系统桌宠 D2

版本：`v0.33.2+57`  
日期：2026-08-15（Asia/Tokyo）

## 本阶段结果

D2 把 v0.33.1 已验证的原动作同构播放器接入真实 `TYPE_APPLICATION_OVERLAY` 窗口，但不建立第二个 Service，也不删除旧悬浮球。

```text
OverlayBubbleService（唯一前台服务）
├─ 主入口二选一
│  ├─ legacy Bubble window
│  └─ PetOverlayWindow
└─ 共用 Chat overlay / unread / TTS / background brain
```

桌宠与悬浮球是同级模式，只显示其中一个；切换模式不重启后台大脑，不复制聊天状态。已有用户默认保持悬浮球，避免升级后突然改变入口。

## 桌宠实际大小

素材清晰度与屏幕显示大小从本版开始分离：

| 档位 | Overlay window | 约可见角色高度 | 源素材档 |
|---|---:|---:|---:|
| 小 | 112dp | 约 98dp | 187px |
| 中 | 152dp | 约 134dp | 238px |
| 大 | 200dp | 约 176dp | 306px |

三档共享同一动作 manifest。改变大小保持角色底部和中心位置，随后重新夹紧到刘海、状态栏、导航栏之外的安全区域。

## 触碰协议

触碰区域直接移植 `ds-local-pet/pet/interaction.py` 的归一化几何：

- 头部单击或按住：`HEAD_PAT`；
- 脸/身体单击：`POKE_REACT`；
- 左右侧中下部尾巴区：`TAIL_REACT`；
- 5 秒内连续戳三次：`ANGRY`；
- 移动超过 6dp：`DRAGGING`，不触发点击；
- 松手：`FALLING`，物理稳定后 `LANDING`，重摔排队 `DIZZY`。

单击反应等待 Android double-tap timeout 后确认。第二次按下进入双击候选时立即取消第一下的待执行单击，因此双击不会先播放两次“被戳”。

## 双击选项

双击桌宠打开独立 Overlay 小菜单：

- 打开现有悬浮聊天；
- 小 / 中 / 大；
- 切换为悬浮球；
- 关闭菜单。

聊天展开、锁屏或系统安全页面覆盖时，桌宠播放器暂停并移除菜单；聊天收起或设备解锁后复用既有 Overlay 健康恢复路径。

## 设置与兼容性

系统页新增：

- “桌宠 / 悬浮球”二选一；
- 桌宠实际显示大小“小 / 中 / 大”；
- “开启/关闭悬浮陪伴”统一服务按钮。

模式和大小存在原生 `overlay_state` preferences，半成品阶段卸载重装可清除。D2 不改 schema 21，不改聊天、Memory、Desire、Somatic、TTS 或 Active Brain。

## 尚未接入

- Desire / Thought / mood 自动选择桌宠动作；
- 自主走动、屏幕边缘活动节奏；
- 将 TTS 合成/播放状态映射为 `THINKING/TALKING`；
- 桌宠动作与主动联网、屏幕陪看的反馈。

这些属于 D3。D2 先验证系统窗口、直接互动和旧悬浮球兼容性，避免把窗口故障与 AI 调度故障混在同一轮。

## 自动验证

- `validate_v0332_desktop_pet_overlay_d2.py`：共享服务、互斥模式、单双击、三档大小、桥接与 UI 契约。
- `PetOverlayContractTest`：上游头/脸/身体/尾巴分区与显示尺寸/素材档映射。
- `PetActionStateMachineTest`：动作优先级、拖拽状态链与抛掷落地物理继续回归。
- 产品提交：`6ff6ed8439c980d4f167310974a9ece8c7c143b1`；PR #13。
- GitHub Actions 产品 run #54（ID `31873700153`）全绿：完整素材恢复、全部历史与本版 validator、Kotlin 桌宠状态/物理/触碰契约测试、Flutter analyze/tests、release APK、APK native/payload 核验和 artifact 上传均通过。
- artifact：`9244295960`，名称 `AI-Companion-v0.33.2-57-Desktop-Pet-Overlay-D2-APK`；ZIP digest `sha256:1c3126f90582e11c936f521215cdfb547d28cb6bb53cea01debc66d6148c5716`。
- APK：238,601,828 bytes；SHA-256 `6ed7067612ef164f2412ff517da59af35340fba626b4508923ccdd7aa55b6c8b`。下载后独立读取 APK 再确认 417 个 source 文件、210 张 runtime PNG、原始 actions manifest 与中文动作标签均在包内。
- 自动验证只证明构建与契约成立；桌宠触碰区域、双击容错、三档实际尺寸、拖拽落地、横竖屏/锁屏及两种入口切换仍需 REDMI K80 Ultra 真机验收。
- 最终 squash merge SHA 在 PR #13 合并后写入 v26 总账；无需因此重打产品 APK。
