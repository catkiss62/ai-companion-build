#!/usr/bin/env python3
"""One-shot CI reconciliation for the oversized UTF-8 project ledger."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise AssertionError(f"expected one ledger anchor, found {text.count(old)}")
    return text.replace(old, new, 1)


text = LEDGER.read_text(encoding="utf-8")

replacements = (
    (
        "| 有效构建 head / tree | v0.41.55+198 最终 Actions head `c15c9d6ac5e1e30e57ef439ec080e2d07f87ab3e` / 构建时完整总账 tree `fa4b5d28f943260cc50ec47a7e5efd92200ca649`；不含用户附件、诊断、备份、密钥、RoBERTa 或原始 Genie APK，私有 Genie 只由 CI 从 Draft 资产恢复并裁剪 |",
        "| 有效构建 head / tree | 最后已验证构建仍为 +198 Actions head `c15c9d6ac5e1e30e57ef439ec080e2d07f87ab3e`；+199 本地实现提交为 `6feeeb28003f3115d095f14128a2189fe55310fd` / tree `b65d421ddc8562aa8379ee09eddb14b39eb60474`，尚待推送与 Actions。提交不含用户附件、诊断、备份、密钥、RoBERTa、原始 Genie APK 或 APK Artifact；私有 Genie 仍只由 CI 从 Draft 资产恢复并裁剪 |",
    ),
    (
        "| App / 数据库 | 当前本地修复目标为 `0.41.55+198 / schema 57 / Snapshot protocol 5`；当前真机包为 `0.41.55+197`。不升 schema，复用外语版本表；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
        "| App / 数据库 | 当前窄修目标为 `0.41.55+199 / schema 57 / Snapshot protocol 5`；当前真机包为 `0.41.55+198`。只补齐日语 JNI 的上游 C++ 运行库依赖，不升 schema；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
    ),
    (
        "| 当前总状态 | +197 为 `TRUE DEVICE PARTIAL`，仅日语失败；+198 已完成日语原生装载闭环、顶部语言选择、不变调变速和 200% 音量增益，最终 run 817 全绿且 APK 已上传。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`；日语真机恢复与音高/增益体感仍必须由用户覆盖安装后确认 |",
        "| 当前总状态 | +198 顶栏语言选择、不变调变速、200% 音量增益及中英文保持正常，但日语因 APK 缺 `libc++_shared.so` 而 `UnsatisfiedLinkError`，状态为 `TRUE DEVICE PARTIAL`。+199 已实现同一上游 APK 的精确 C++ runtime 打包、哈希校验与 ELF 依赖闭包门，本地 75 个可运行源码 validator 全绿；另 3 项只因本地未恢复 417 桌宠、LingChat effects 和没有 `kotlinc` 未运行。当前严格为 `IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING`，不得写成日语已修复 |",
    ),
    (
        "| 当前下一步 | **v0.41.55+198 真机验收**：覆盖安装 Draft APK，首先选“日”后点喇叭验证首次与第二次日语；再确认顶栏只有“语言 中 日 EN”、点语言不会立即出声、底部语音说明已消失；最后对比 0.75×/1.0×/1.5× 音高是否保持，并渐进测试 100–200% 音量。如日语仍失败，导出新脱敏诊断，新版 `diagnosticCode` 应能给出具体异常类型 |",
        "| 当前下一步 | **推送 +199 并完成 Actions/APK 交付**：将实现与第二次总账提交推送到 `agent/v04155-genie-direct-port-lazy-language`，监测完整 Actions；若源码、Kotlin/AIDL、Flutter、Release、固定签名、私有载荷哈希或 ELF 闭包任一失败则窄修后重跑。全绿后回填 run、Artifact、Draft APK 大小与 SHA，再交由用户验证首次/第二次日语及中英文不回归 |",
    ),
    (
        "| 当前证据 | +196 新报告 `2026-09-09T15:00:03Z`：`available/initialized=true`，多次出现 `audio_playback/audio_complete`，与用户确认中英文出声一致；当前会话没有新的 `initialize_frontend_ja/prepare_frontend_ja`，故日语失败发生在原生前端之前。一次主动停止后子进程在 `generation_cancelled` 退出（约 2.52 GB PSS）但随后自动恢复并继续播放。源码确认 TTS 状态每次 `_safeNotify()` 都会落入 ChatPage 无条件 `_scrollToLatest()`；Genie 固定核心七文件仍与 `5380a53` 逐字一致，但伴侣播放层使用逐段 WAV/新 AudioTrack + 200ms gap，未与原版连续 AudioTrack 完全对齐 |",
        "| 当前证据 | +198 新脱敏报告 `2026-09-10T01:00:07Z` 来自 build 198/schema 57：日语 `frontend_switch_failed code=UnsatisfiedLinkError language=ja`，后续生成因前端为空出现 `NullPointerException`；中英文播放链仍存在。独立下载 run 817 Artifact 后，`readelf -d` 证明 `libopenjtalk_native.so` 的首个 `DT_NEEDED` 为 `libc++_shared.so`，而 +198 APK 的 `lib/arm64-v8a/` 只有 app、Dart/Flutter、Genie/OpenJTalk/ORT 共 7 库且没有 C++ shared runtime。JNI 导出类名与六个 OpenJTalk C 符号均匹配，故根因已从“泛化装载失败”收敛为确定的依赖缺包 |",
    ),
)

for old, new in replacements:
    text = replace_once(text, old, new)

marker = "## 近期详细记录与全局索引（按需检索）\n\n"
section = """### 2026-09-10 v0.41.55+199 日语 C++ 运行库依赖闭包（IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING）

1. 用户覆盖安装 +198 后再次确认日语不能播放，并提供新的脱敏诊断。报告来自 `0.41.55+198 / schema 57`，首次保留了具体错误类型：`frontend_switch_failed code=UnsatisfiedLinkError language=ja`；随后生成路径因日语前端未建立而出现 `NullPointerException`。这排除了按钮、外语改写、日语分段、声学模型和播放参数作为首个失败点。
2. 已从 run 817 Artifact 独立下载 +198 成品 APK，只做本地 ELF/ZIP 静态取证，不提交 APK或诊断。`libgenie_frontend.so` 导出的四个 `Java_com_catkiss62_geniettsbenchmark_NativeJapaneseFrontend_*` JNI 函数与 Kotlin 包名一致，对 `openjtalk_native_create/phonemize_with_prosody/free/get/destroy` 的引用也都能在 `libopenjtalk_native.so` 中解析；两库本身的配对没有错。
3. 根因是依赖闭包遗漏：`readelf -d libopenjtalk_native.so` 明确列出 `DT_NEEDED: libc++_shared.so`，但 +198 APK 的 arm64 库清单没有 `libc++_shared.so`。+198 工作流只从验证 APK 提取 OpenJTalk 和 JNI bridge，两者的字节一致校验无法证明它们的传递依赖已随包携带，因此 CI 绿灯没有覆盖真机动态链接条件。
4. +199 已按锁定范围实现：工作流从同一私有 Genie v0.6.4 验证 APK 原样提取并打包 `libc++_shared.so`，恢复 manifest 将它纳入大小/SHA，clean baseline 和最终 APK 必需库均要求存在；成品门用 `readelf -d` 解析 OpenJTalk 与 JNI bridge 的全部 `DT_NEEDED`，除 Android 系统库外必须在 APK 的 arm64 库集合中解析。版本只升 build number 198→199，schema 57、Snapshot protocol 5、Prompt/规则/世界书、翻译缓存、TTS 队列、语速、音量、UI 和中英文路径均未改。
5. 两次总账已执行：任务前提交 `df4e407` 锁定根因、范围与不可回退项；实现提交 `6feeeb28003f3115d095f14128a2189fe55310fd` / tree `b65d421ddc8562aa8379ee09eddb14b39eb60474`。本地工作流 YAML、Python compileall、总账合同、v0.41.55 专项、版本兼容与其余可运行源码合同均通过，完整工作流列表为 75 passed / 3 environment-only unavailable；三项分别依赖 CI 才恢复的 417 桌宠包、LingChat effects 和 `kotlinc`。`git diff --check` 通过。本地未声称 Flutter/Kotlin/Release 已通过。
6. 下一步按持续授权推送当前分支并运行完整 Actions。只有 CI 与 Draft APK 均成功才提升为 `CI PASSED / APK READY`；日语首次/二次真正出声仍须用户真机确认。

"""
text = replace_once(text, marker, marker + section)

LEDGER.write_text(text, encoding="utf-8")
print("build 199 ledger reconciliation prepared")
