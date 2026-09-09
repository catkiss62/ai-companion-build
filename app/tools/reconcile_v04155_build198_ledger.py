#!/usr/bin/env python3
"""One-shot final run-817 evidence update for the oversized project ledger."""

from pathlib import Path


LEDGER = Path(__file__).resolve().parents[2] / "AI_Companion_当前总账.md"
lines = LEDGER.read_text(encoding="utf-8").splitlines()


def replace_line(prefix: str, replacement: str) -> None:
    matches = [index for index, line in enumerate(lines) if line.startswith(prefix)]
    if len(matches) != 1:
        raise AssertionError(f"ledger line contract changed: {prefix}")
    lines[matches[0]] = replacement


replace_line("| 有效构建 head / tree |", "| 有效构建 head / tree | v0.41.55+198 最终 Actions head `c15c9d6ac5e1e30e57ef439ec080e2d07f87ab3e` / 构建时完整总账 tree `fa4b5d28f943260cc50ec47a7e5efd92200ca649`；不含用户附件、诊断、备份、密钥、RoBERTa 或原始 Genie APK，私有 Genie 只由 CI 从 Draft 资产恢复并裁剪 |")
replace_line("| 最终 CI |", "| 最终 CI | +198 run [`34404388142`](https://github.com/catkiss62/ai-companion-build/actions/runs/34404388142)（817）完整成功：总账协调、私有资源恢复、源码门、Kotlin/AIDL、Flutter analyze、`709/709` Flutter tests、Release APK、固定签名与完整实包均通过 |")
replace_line("| APK SHA-256 |", "| APK SHA-256 | `2d709918b919783e01c883c87361f05926a61d42a64eb2f8b2e0b5ed235b2e41`；与 Draft 资产服务端 digest 一致 |")
replace_line("| Artifact / Release |", "| Artifact / Release | Artifact [`10125147779`](https://github.com/catkiss62/ai-companion-build/actions/runs/34404388142/artifacts/10125147779)，ZIP 530,322,821 bytes / digest `cd138146051929064b80575b7dc958a9de29380ea76577275c06929da883ffef`；[Draft Release](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-269d791cf3eed8541cb8) 未发布，`main` 未合并 |")
replace_line("| 当前总状态 |", "| 当前总状态 | +197 为 `TRUE DEVICE PARTIAL`，仅日语失败；+198 已完成日语原生装载闭环、顶部语言选择、不变调变速和 200% 音量增益，最终 run 817 全绿且 APK 已上传。当前严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`；日语真机恢复与音高/增益体感仍必须由用户覆盖安装后确认 |")
replace_line("7. 首轮 run [`34401062408`]", "7. 首轮 run [`34401062408`](https://github.com/catkiss62/ai-companion-build/actions/runs/34401062408)（815）因 GitHub Git Data 接口把 1.38 MB UTF-8 总账截断在 393,216 bytes 而停在源码门，未进入编译，与 TTS 代码无关。恢复完整 ledger blob 后，run 816 完整通过；CI 结果回填又触发了同源复验 run [`34404388142`](https://github.com/catkiss62/ai-companion-build/actions/runs/34404388142)（817），同样通过源码回归、Kotlin/AIDL、Flutter analyze、`709/709` tests、arm64 Release、固定签名、双 JNI 库来源 SHA 与全部私有载荷校验。最终 Draft APK 为 537,179,972 bytes，SHA-256 `2d709918b919783e01c883c87361f05926a61d42a64eb2f8b2e0b5ed235b2e41`；Artifact `10125147779` 与 Draft Release 已就绪。为避免再次重复构建，超大总账协调改为独立 5 分钟文档 job，仅在有界脚本存在时回推 `[skip ci]` 账本提交，不再启动 APK job。状态严格为 `CI PASSED / APK READY / TRUE DEVICE PENDING`，不得提前写成日语真机通过。")

LEDGER.write_text("\n".join(lines) + "\n", encoding="utf-8")
