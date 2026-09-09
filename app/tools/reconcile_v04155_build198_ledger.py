#!/usr/bin/env python3
"""One-shot CI bridge for the project ledger, which exceeds connector blob limits."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"


def replace_once(text: str, old: str, new: str) -> str:
    if new in text:
        return text
    if text.count(old) != 1:
        raise AssertionError(f"ledger source contract changed: {old[:48]}")
    return text.replace(old, new, 1)


text = LEDGER.read_text(encoding="utf-8")
text = replace_once(
    text,
    "更新时间：2026-09-09（Asia/Tokyo）",
    "更新时间：2026-09-10（Asia/Tokyo）",
)
text = replace_once(
    text,
    "| App / 数据库 | 当前本地修复目标为 `0.41.55+197 / schema 57 / Snapshot protocol 5`；上一真机包为 `0.41.55+196`。不升 schema，复用外语版本表；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
    "| App / 数据库 | 当前本地修复目标为 `0.41.55+198 / schema 57 / Snapshot protocol 5`；当前真机包为 `0.41.55+197`。不升 schema，复用外语版本表；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
)
text = replace_once(
    text,
    "| 当前总状态 | +197 已合入 TTS 反馈窄修、用户备份规则 05/06/07、造梗 50%、LLM 年龄边界清理与沉浸对白 `「」` 修复。run 813 暴露的两条旧测试期待和特殊风格三处遗漏年龄暗示已最小修正并用精确哈希保守迁移；run 814 全绿且 APK 已上传。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`；+196 的中英文出声只证明前一包，不得代替 +197 的日语、交互、连续播放、规则与沉浸真机验收 |",
    "| 当前总状态 | +197 run 814 全绿且 APK 已上传；用户真机确认除日语外，其余 TTS 交互、连续播放、规则和沉浸修复均正常。新脱敏报告证明日语在进入 OpenJTalk 前即由隔离服务以 `not_initialized / operation_failed` 拒绝，未出现 `initialize_frontend_ja`、`prepare_frontend_ja` 或 `infer_ja`；+197 因此为 `CI PASSED / APK READY / TRUE DEVICE PARTIAL`。+198 已完成本地实现：日语原生装载闭环、顶部语言选择、不变调变速和 200% 音量增益；当前为 `IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING` |",
)
text = replace_once(
    text,
    "| 当前下一步 | **v0.41.55+197 真机验收**：从 Draft Release 覆盖安装 +197，先验证日语首次/二次播放；再验证语言按钮只切换不立刻朗读、合成省略号可停止、点播放和 TTS 状态变化不改变滚动位置、长回复连续播放无固定 200ms 空洞；最后检查默认/升级后的规则 05/06/07、造梗 50%、DeepSeek 实际注入无年龄门，以及沉浸对白统一使用 `「」`。如有失败，导出新的脱敏诊断后按单一症状窄修 |",
    "| 当前下一步 | **v0.41.55+198 日语装载与播放调节窄修**：从已真机通过三语的 Genie v0.6.4 私有 APK 同时恢复字节一致的 `libopenjtalk_native.so` 与 `libgenie_frontend.so`，Release 构建跳过本地 JNI 重编译并校验两库 SHA，消除当前只复制底层库、重编 JNI 适配库的运行差异；语言选择移到顶部 NSFW 左侧并只显示“语言 中 日 EN”，删除聊天面板底部语音语言说明；语速改由 AudioTrack `PlaybackParams(speed, pitch=1)` 做不变调时间伸缩，移除 PCM 重采样；TTS 音量范围扩到 200%，超过 100% 用与 AudioTrack 会话绑定的 LoudnessEnhancer 增益 |",
)

heading = "### 2026-09-10 v0.41.55+198 日语原生装载、不变调变速与顶部语言选择"
if heading not in text:
    marker = "\n## 近期详细记录与全局索引（按需检索）\n"
    if text.count(marker) != 1:
        raise AssertionError("ledger detail insertion marker changed")
    detail = r'''

### 2026-09-10 v0.41.55+198 日语原生装载、不变调变速与顶部语言选择（IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING）

1. 用户真机确认 +197 除日语外其他测试均正常，并要求下一包把语音语言移到顶部 `NSFW` 左侧，只保留“语言 中 日 EN”，删除聊天面板右下方“中文语音 / 日语或英语语音＋中文对照”说明；同时指出当前语速通过重采样导致慢速变厚、快速变尖，要求只变速不变音调，并把 TTS 音量滑杆上限提高到 100% 以上。
2. 新脱敏报告 `2026-09-09T19:49:45Z` 来自 +197/schema 57，不含聊天、Memory、附件、密钥或原始错误文本。报告中中文/英文存在大量 `audio_playback/audio_complete`；日语首先出现 `frontend_switch_failed code=not_initialized stage=operation_failed language=ja`，随后多次 `initialize_failed` 同码，且始终没有 `initialize_frontend_ja`、`prepare_frontend_ja`、`infer_ja` 或对应子进程退出。由调用顺序可知失败发生在 `NativeJapaneseFrontend` 构造期的原生库装载，而非日语翻译、分段、词典释放、OpenJTalk 音素转换或声学推理。
3. 本地实现已将工作流改为从同一份真机验证过的 Genie v0.6.4 APK 同时提取 `libopenjtalk_native.so` 和 `libgenie_frontend.so`，Release 以 `skipGenieNativeBuild=true` 停止重编译 JNI 桥，并在成品 APK 中按大小与 SHA-256 逐一反查。这是对 +197 唯一剩余原生字节差异的窄修，不改 Genie 七个锁定核心文件、词典或分段。
4. 语言选择已从聊天面板底部移至顶栏 `NSFW` 左侧，实际可见文字只为“语言 中 日 EN”；点击会停止旧语音并保存后续朗读语言，但不立即合成或播放。旧底部语音语言状态条已删除；外语消息内容自身的中文对照仍保留。
5. 语速已删除会同步改变音高的 PCM 线性重采样，改为单一连续 `AudioTrack` 上的 `PlaybackParams(speed, pitch=1.0)`，保留原有一秒 PCM 预填充、后段预生成队列、中止和 drain 语义。TTS 音量范围扩展为 0–200%；100% 以下走 AudioTrack 音量，超出部分用同一 audio session 的 `LoudnessEnhancer` 施加最高约 +6.02 dB 增益并在播放结束时释放。
6. 运行诊断新增脱敏 `diagnosticCode`，保留真实异常类型而不导出错误原文或路径，避免下次只看到笼统 `not_initialized`。版本已升为 `0.41.55+198`，schema 57 和 Snapshot protocol 5 不变；新增播放参数边界测试与专项静态合同。本地环境无 Flutter/Dart SDK，Kotlin/Dart 真实编译、全量测试和 APK 仍须 Actions 证明，当前不得写成 CI 通过或真机通过。
'''
    text = text.replace(marker, marker + detail, 1)

LEDGER.write_text(text, encoding="utf-8")
