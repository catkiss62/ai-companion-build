#!/usr/bin/env python3
"""One-shot CI reconciliation for the build-199 immersive tint addendum."""

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
        "| 当前总状态 | +198 顶栏语言选择、不变调变速、200% 音量增益及中英文保持正常，但日语因 APK 缺 `libc++_shared.so` 而 `UnsatisfiedLinkError`，状态为 `TRUE DEVICE PARTIAL`。+199 已实现同一上游 APK 的精确 C++ runtime 打包、哈希校验与 ELF 依赖闭包门，本地 75 个可运行源码 validator 全绿；另 3 项只因本地未恢复 417 桌宠、LingChat effects 和没有 `kotlinc` 未运行。当前严格为 `IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING`，不得写成日语已修复 |",
        "| 当前总状态 | +198 顶栏语言选择、不变调变速、200% 音量增益及中英文保持正常，但日语因 APK 缺 `libc++_shared.so` 而 `UnsatisfiedLinkError`，状态为 `TRUE DEVICE PARTIAL`。+199 已实现同一上游 APK 的精确 C++ runtime 打包、哈希/ELF 依赖闭包门，并将沉浸对白着色从旧 `“”` 切换到当前生成合同 `「」`；本地静态与专项合同通过。当前严格为 `IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING`，不得写成日语或显示已真机修复 |",
    ),
    (
        "| 当前下一步 | **推送 +199 并完成 Actions/APK 交付**：将实现与第二次总账提交推送到 `agent/v04155-genie-direct-port-lazy-language`，监测完整 Actions；若源码、Kotlin/AIDL、Flutter、Release、固定签名、私有载荷哈希或 ELF 闭包任一失败则窄修后重跑。全绿后回填 run、Artifact、Draft APK 大小与 SHA，再交由用户验证首次/第二次日语及中英文不回归 |",
        "| 当前下一步 | **统一推送 +199 并完成 Actions/APK 交付**：日语依赖闭包与沉浸 `「」` 着色均已实现；将代码、测试、工作流与第二次总账推送到 `agent/v04155-genie-direct-port-lazy-language`，监测完整 Actions。任一源码、Kotlin/AIDL、Flutter、Release、固定签名、私有载荷哈希或 ELF 闭包失败则窄修重跑；全绿后回填 run、Artifact、Draft APK 大小与 SHA |",
    ),
    (
        "| 目标 | 保留 +196 已真机成功的独立进程、单串行 Genie 推理与中英文出声；`中/日/EN` 只切换后续朗读语言，点喇叭或下一句自动朗读才出声。规则正文除用户另行要求删除的年龄边界外必须与备份逐字一致；造梗正文逐字一致且概率 50%；沉浸房间不再被内部最终提示强制成 `“”` |",
        "| 目标 | 保留 +196 已真机成功的独立进程、单串行 Genie 推理与中英文出声；`中/日/EN` 只切换后续朗读语言，点喇叭或下一句自动朗读才出声。规则正文除用户另行要求删除的年龄边界外必须与备份逐字一致；造梗正文逐字一致且概率 50%；沉浸房间生成使用 `「」`，并且显示层只给 `「」` 对白着色，`“”` 不着色 |",
    ),
    (
        "| 当前证据 | +198 新脱敏报告 `2026-09-10T01:00:07Z` 来自 build 198/schema 57：日语 `frontend_switch_failed code=UnsatisfiedLinkError language=ja`，后续生成因前端为空出现 `NullPointerException`；中英文播放链仍存在。独立下载 run 817 Artifact 后，`readelf -d` 证明 `libopenjtalk_native.so` 的首个 `DT_NEEDED` 为 `libc++_shared.so`，而 +198 APK 的 `lib/arm64-v8a/` 只有 app、Dart/Flutter、Genie/OpenJTalk/ORT 共 7 库且没有 C++ shared runtime。JNI 导出类名与六个 OpenJTalk C 符号均匹配，故根因已从“泛化装载失败”收敛为确定的依赖缺包 |",
        "| 当前证据 | +198 新脱敏报告 `2026-09-10T01:00:07Z` 来自 build 198/schema 57：日语 `frontend_switch_failed code=UnsatisfiedLinkError language=ja`；成品 ELF 已把根因锁定为缺失 `libc++_shared.so`。新增用户真机反馈指出沉浸 `「」` 没有对白色；源码 `splitNovelDialogueText()` 仍以 `trimmed.startsWith('“')` 判定对白，正好与 +197 已改为 `「」` 的生成合同相反，且现有 widget 测试也冻结了旧弯引号着色，因此显示层根因同样确定 |",
    ),
    (
        "| 完成判据 | 本地静态合同、Dart 测试、Kotlin/AIDL/Flutter analyze 与 Release APK 由 Actions 全绿；真机再分别确认日语首次/二次播放、按钮只切换、点省略号立即停止、播放前后滚动位置不变、长回复段间无固定空洞、中英文不回归；并确认默认/升级后的规则、造梗 50%、DeepSeek 实际注入和沉浸 `「」`。自动化成功不得提前写成真机通过 |",
        "| 完成判据 | 本地静态合同、Dart 测试、Kotlin/AIDL/Flutter analyze 与 Release APK 由 Actions 全绿；沉浸 widget 测试必须证明段首 `「」` 使用所选对白色、段首/段内 `“”` 均为白色旁白。真机再确认日语首次/二次播放、按钮只切换、点省略号立即停止、滚动位置不变、中英文不回归，以及沉浸 `「」` 有色而 `“”` 无色。自动化成功不得提前写成真机通过 |",
    ),
)

for old, new in replacements:
    text = replace_once(text, old, new)

anchor = "6. 下一步按持续授权推送当前分支并运行完整 Actions。只有 CI 与 Draft APK 均成功才提升为 `CI PASSED / APK READY`；日语首次/二次真正出声仍须用户真机确认。\n"
addendum = """7. 推送前用户追加的沉浸着色窄修已完成，提交为 `cc751e74f7a80159756e8513e1c8b916ebf6fdbb` / tree `76cff539a2e02309065403ca98834fa518409ea3`。`splitNovelDialogueText()` 现在只把段首 `「` 判为对白；段首或旁白内部的 `“”` 都保持白色正体，流式未闭合 `「` 从首字符起即着色，同一 `ChatDialogueColorScope` 继续让普通与沉浸共享用户所选浅紫/浅黄/浅粉。存储文本、普通聊天 `ActionTintText`、TTS、Prompt、规则和数据库均未改。
8. 本地已通过 v0.41.28/v0.41.29 沉浸与呈现静态合同、v0.41.55 专项、总账 validator、one-shot ledger 重放逐字比对、Python 语法与 `git diff --check`。当前容器没有 Dart/Flutter，`action_tint_text_test.dart` 的 widget 真执行、Flutter analyze/tests 与 Release APK 必须由 Actions 证明，不提前标绿。
"""
text = replace_once(text, anchor, anchor + addendum)

LEDGER.write_text(text, encoding="utf-8")
print("build 199 immersive-tint ledger reconciliation prepared")
