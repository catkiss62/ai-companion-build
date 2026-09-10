#!/usr/bin/env python3
"""One-shot CI reconciliation for the successful build-199 handoff."""

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
        "| 有效构建 head / tree | 最后已验证构建仍为 +198 Actions head `c15c9d6ac5e1e30e57ef439ec080e2d07f87ab3e`；+199 本地实现提交为 `6feeeb28003f3115d095f14128a2189fe55310fd` / tree `b65d421ddc8562aa8379ee09eddb14b39eb60474`，尚待推送与 Actions。提交不含用户附件、诊断、备份、密钥、RoBERTa、原始 Genie APK 或 APK Artifact；私有 Genie 仍只由 CI 从 Draft 资产恢复并裁剪 |",
        "| 有效构建 head / tree | +199 Actions head `7c5a8b20ec826e4b88d1ec02ac06ef34e125c18c` / tree `32b08e3e134638ab0c4f2ca9d46903e08d7b6e4b` 已验证；构建后的 oversized-ledger 协调提交为 `f55bd216258e25d59a10bd4415207ce2be3f6f2b`，只回填总账并自删 one-shot 脚本，不改变本次 APK 源码。提交不含用户附件、诊断、备份、密钥、RoBERTa、原始 Genie APK 或 APK Artifact；私有 Genie 仍只由 CI 从 Draft 资产恢复并裁剪 |",
    ),
    (
        "| App / 数据库 | 当前窄修目标为 `0.41.55+199 / schema 57 / Snapshot protocol 5`；当前真机包为 `0.41.55+198`。只补齐日语 JNI 的上游 C++ 运行库依赖，不升 schema；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
        "| App / 数据库 | 当前测试包为 `0.41.55+199 / schema 57 / Snapshot protocol 5`。只补齐日语 JNI 的上游 C++ 运行库依赖并修正沉浸对白显示判定，不升 schema；旧聊天、规则手改、图库、Memory、Thought、Desire、网页候选与行为账本原样保留 |",
    ),
    (
        "| 最终 CI | +198 run [`34404388142`](https://github.com/catkiss62/ai-companion-build/actions/runs/34404388142)（817）完整成功：总账协调、私有资源恢复、源码门、Kotlin/AIDL、Flutter analyze、`709/709` Flutter tests、Release APK、固定签名与完整实包均通过 |",
        "| 最终 CI | +199 run [`34426118627`](https://github.com/catkiss62/ai-companion-build/actions/runs/34426118627)（820）完整成功：总账协调、私有资源恢复、源码门、Kotlin/AIDL、Flutter analyze、`709/709` Flutter tests、Release APK、固定签名、完整实包及 OpenJTalk ELF 依赖闭包均通过 |",
    ),
    (
        "| 测试 APK | `AI-Companion-v0.41.55-198-Genie-Direct-Port-Lazy-Language-APK.apk`，537,179,972 bytes |",
        "| 测试 APK | `AI-Companion-v0.41.55-199-Genie-Direct-Port-Lazy-Language-APK.apk`，537,586,696 bytes |",
    ),
    (
        "| APK SHA-256 | `2d709918b919783e01c883c87361f05926a61d42a64eb2f8b2e0b5ed235b2e41`；与 Draft 资产服务端 digest 一致 |",
        "| APK SHA-256 | `8fdcfd6675bf0db1fdec45cbdf3a8eaf126743671faa4290ebe790f48876cb68`；与 Draft 资产服务端 digest 一致 |",
    ),
    (
        "| Artifact / Release | Artifact [`10125147779`](https://github.com/catkiss62/ai-companion-build/actions/runs/34404388142/artifacts/10125147779)，ZIP 530,322,821 bytes / digest `cd138146051929064b80575b7dc958a9de29380ea76577275c06929da883ffef`；[Draft Release](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-269d791cf3eed8541cb8) 未发布，`main` 未合并 |",
        "| Artifact / Release | Artifact [`10132997234`](https://github.com/catkiss62/ai-companion-build/actions/runs/34426118627/artifacts/10132997234)，ZIP 530,728,973 bytes / digest `9158957404278f45bb2303794dccaec9942c521b65e966360de512bc494137ad`；[Draft Release](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-e70cf2358cf6386e16b6) 未发布，`main` 未合并 |",
    ),
    (
        "| 当前总状态 | +198 顶栏语言选择、不变调变速、200% 音量增益及中英文保持正常，但日语因 APK 缺 `libc++_shared.so` 而 `UnsatisfiedLinkError`，状态为 `TRUE DEVICE PARTIAL`。+199 已实现同一上游 APK 的精确 C++ runtime 打包、哈希/ELF 依赖闭包门，并将沉浸对白着色从旧 `“”` 切换到当前生成合同 `「」`；本地静态与专项合同通过。当前严格为 `IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING`，不得写成日语或显示已真机修复 |",
        "| 当前总状态 | +198 顶栏语言选择、不变调变速、200% 音量增益及中英文保持正常，但日语因 APK 缺 `libc++_shared.so` 而 `UnsatisfiedLinkError`，状态为 `TRUE DEVICE PARTIAL`。+199 已把同一上游 APK 的精确 C++ runtime 打包进成品，哈希/ELF 依赖闭包门已在 run 820 通过，并将沉浸对白着色从旧 `“”` 切换到当前生成合同 `「」`；完整 CI 与 Draft APK 已就绪。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，不得写成日语或显示已真机修复 |",
    ),
    (
        "| 当前下一步 | **统一推送 +199 并完成 Actions/APK 交付**：日语依赖闭包与沉浸 `「」` 着色均已实现；将代码、测试、工作流与第二次总账推送到 `agent/v04155-genie-direct-port-lazy-language`，监测完整 Actions。任一源码、Kotlin/AIDL、Flutter、Release、固定签名、私有载荷哈希或 ELF 闭包失败则窄修重跑；全绿后回填 run、Artifact、Draft APK 大小与 SHA |",
        "| 当前下一步 | **覆盖安装 +199 并做窄范围真机 smoke**：先测日语首次播放与停止后第二次播放，再复测中文/英语；沉浸房间分别生成段首 `「对白」` 与含 `“弯引号”` 的旁白，确认前者使用所选对白色、后者保持白色。若日语仍失败则导出新脱敏诊断；若全部正常即可将 +199 提升为 `TRUE DEVICE PASSED` |",
    ),
    (
        "### 2026-09-10 v0.41.55+199 日语 C++ 运行库依赖闭包（IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING）",
        "### 2026-09-10 v0.41.55+199 日语 C++ 运行库依赖闭包（CI PASSED / APK READY / TRUE DEVICE PENDING）",
    ),
    (
        "6. 下一步按持续授权推送当前分支并运行完整 Actions。只有 CI 与 Draft APK 均成功才提升为 `CI PASSED / APK READY`；日语首次/二次真正出声仍须用户真机确认。",
        "6. 已按持续授权推送到 `agent/v04155-genie-direct-port-lazy-language`，不合并 `main`、不发布正式 Release。Actions run [`34426118627`](https://github.com/catkiss62/ai-companion-build/actions/runs/34426118627)（820）完整成功：源码与历史合同、Kotlin/AIDL、Flutter analyze、`709/709` Flutter tests、arm64 Release、固定测试签名、Genie/桌宠/LingChat/塔罗实包与摘要均通过；成品检查明确输出 `OpenJTalk ELF dependency closure is complete in the release APK.`。日语首次/二次真正出声仍须用户真机确认。",
    ),
    (
        "8. 本地已通过 v0.41.28/v0.41.29 沉浸与呈现静态合同、v0.41.55 专项、总账 validator、one-shot ledger 重放逐字比对、Python 语法与 `git diff --check`。当前容器没有 Dart/Flutter，`action_tint_text_test.dart` 的 widget 真执行、Flutter analyze/tests 与 Release APK 必须由 Actions 证明，不提前标绿。",
        "8. 本地已通过 v0.41.28/v0.41.29 沉浸与呈现静态合同、v0.41.55 专项、总账 validator、one-shot ledger 重放逐字比对、Python 语法与 `git diff --check`。run 820 已补齐本地不可用的真实 Dart widget、Flutter analyze/tests、Kotlin 与 Release APK 验证，沉浸 `「」` 着色和 `“”` 不着色合同已由自动化证明；视觉结果仍保留真机边界。\n9. 最终 Draft APK 为 `AI-Companion-v0.41.55-199-Genie-Direct-Port-Lazy-Language-APK.apk`，537,586,696 bytes，SHA-256 `8fdcfd6675bf0db1fdec45cbdf3a8eaf126743671faa4290ebe790f48876cb68`。Artifact `10132997234` 为 530,728,973-byte ZIP，digest `9158957404278f45bb2303794dccaec9942c521b65e966360de512bc494137ad`；Draft Release 保持未发布，`main` 未合并。当前状态严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`。",
    ),
)

for old, new in replacements:
    text = replace_once(text, old, new)

LEDGER.write_text(text, encoding="utf-8")
print("build 199 final CI ledger reconciliation prepared")
