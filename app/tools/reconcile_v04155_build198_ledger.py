#!/usr/bin/env python3
"""One-shot CI finalization of build-198 evidence in the oversized ledger."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / "AI_Companion_当前总账.md"
lines = LEDGER.read_text(encoding="utf-8").splitlines()


def replace_line(prefix: str, replacement: str) -> None:
    matches = [index for index, line in enumerate(lines) if line.startswith(prefix)]
    if len(matches) != 1:
        raise AssertionError(f"ledger line contract changed: {prefix}")
    lines[matches[0]] = replacement


replace_line(
    "| 有效构建 head / tree |",
    "| 有效构建 head / tree | v0.41.55+198 Actions head `531f85fd28678006159ec3ba1e4b8ef727482e2e` / 构建时完整总账 tree `583c27601b48d0330bf675ca0c19dd124259118a`；不含用户附件、诊断、备份、密钥、RoBERTa 或原始 Genie APK，私有 Genie 只由 CI 从 Draft 资产恢复并裁剪 |",
)
replace_line(
    "| 最终 CI |",
    "| 最终 CI | +198 run [`34402366714`](https://github.com/catkiss62/ai-companion-build/actions/runs/34402366714)（816）完整成功：总账协调、私有资源恢复、源码门、Kotlin/AIDL、Flutter analyze、`709/709` Flutter tests、Release APK、固定签名与完整实包均通过 |",
)
replace_line(
    "| 测试 APK |",
    "| 测试 APK | `AI-Companion-v0.41.55-198-Genie-Direct-Port-Lazy-Language-APK.apk`，537,179,972 bytes |",
)
replace_line(
    "| APK SHA-256 |",
    "| APK SHA-256 | `63725362a3c29223261bb1fb0932bf999e2983dd9ae3f4f17e7b48ca2fe48c0f`；与 Draft 资产服务端 digest 一致 |",
)
replace_line(
    "| Artifact / Release |",
    "| Artifact / Release | Artifact [`10124367252`](https://github.com/catkiss62/ai-companion-build/actions/runs/34402366714/artifacts/10124367252)，ZIP 530,322,823 bytes / digest `a7db720d6fe48adda2ef76aa24133e6421b397c4460d19bc0a788b76a82eda9f`；[Draft Release](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-125e8889db9780b7f9c4) 未发布，`main` 未合并 |",
)
replace_line(
    "| 当前总状态 |",
    "| 当前总状态 | +197 为 `TRUE DEVICE PARTIAL`，仅日语失败；+198 已完成日语原生装载闭环、顶部语言选择、不变调变速和 200% 音量增益，run 816 全绿且 APK 已上传。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`；日语真机恢复与音高/增益体感仍必须由用户覆盖安装后确认 |",
)
replace_line(
    "| 当前下一步 |",
    "| 当前下一步 | **v0.41.55+198 真机验收**：覆盖安装 Draft APK，首先选“日”后点喇叭验证首次与第二次日语；再确认顶栏只有“语言 中 日 EN”、点语言不会立即出声、底部语音说明已消失；最后对比 0.75×/1.0×/1.5× 音高是否保持，并渐进测试 100–200% 音量。如日语仍失败，导出新脱敏诊断，新版 `diagnosticCode` 应能给出具体异常类型 |",
)

old_heading = "### 2026-09-10 v0.41.55+198 日语原生装载、不变调变速与顶部语言选择（IMPLEMENTED LOCALLY / CI PENDING / TRUE DEVICE PENDING）"
new_heading = "### 2026-09-10 v0.41.55+198 日语原生装载、不变调变速与顶部语言选择（CI PASSED / APK READY / TRUE DEVICE PENDING）"
if lines.count(old_heading) != 1:
    raise AssertionError("build-198 ledger heading contract changed")
lines[lines.index(old_heading)] = new_heading

point6_prefix = "6. 运行诊断新增脱敏 `diagnosticCode`"
matches = [index for index, line in enumerate(lines) if line.startswith(point6_prefix)]
if len(matches) != 1:
    raise AssertionError("build-198 detail contract changed")
index = matches[0]
lines[index] = "6. 运行诊断新增脱敏 `diagnosticCode`，保留真实异常类型而不导出错误原文或路径，避免下次只看到笼统 `not_initialized`。版本为 `0.41.55+198`，schema 57 和 Snapshot protocol 5 不变；新增播放参数边界测试与专项静态合同。"
lines.insert(index + 1, "7. 首轮 run [`34401062408`](https://github.com/catkiss62/ai-companion-build/actions/runs/34401062408)（815）因 GitHub Git Data 接口把 1.38 MB UTF-8 总账截断在 393,216 bytes 而停在源码门，未进入编译，与 TTS 代码无关。随后恢复远端完整 ledger blob，用一次性有界脚本在 Actions 内应用小补丁并以 `[skip ci]` 回推；协调后 head `2dc63b180ad5e2fc79cb9eb8ab6a672fa02e65c1` / tree `583c27601b48d0330bf675ca0c19dd124259118a` 保持历史档案哈希不变。run 816 完整通过源码回归、Kotlin/AIDL、Flutter analyze、`709/709` tests、arm64 Release、固定签名、双 JNI 库来源 SHA 与全部私有载荷校验。APK 为 537,179,972 bytes，SHA-256 `63725362a3c29223261bb1fb0932bf999e2983dd9ae3f4f17e7b48ca2fe48c0f`；Artifact `10124367252` 与 Draft Release 已就绪。状态提升为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，不得提前写成日语真机通过。")

LEDGER.write_text("\n".join(lines) + "\n", encoding="utf-8")
