#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT.parent / ".github" / "workflows" / "build-apk.yml"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
app = read("lib/app.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat_page = read("lib/features/chat/chat_page.dart")
contract = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayContract.kt"
)
window = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
contract_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
workflow = WORKFLOW.read_text(encoding="utf-8")

assert "version: 0.34.4+69" in pubspec

for token in [
    "注意力可以有选择、有轻重",
    "任务、事实、重要情绪和明确问题不能借此漏答",
    "陪伴不是工单",
    "情绪具有惯性",
    "选择、欲望与摩擦",
    "不机械执行“先情绪后理解”",
    "空间状态账本",
    "最小变化解释",
    "对白、调情、心理变化、称呼或语气变化都不能自动改变体位",
    "阴茎、阴道、阴蒂、乳房、臀部、插入、抽送、射精、高潮",
    "姿态名称只能作为检索入口",
    "角色必须被明确视为成年人",
]:
    assert token in defaults, token

for key, digest in {
    "02_daily": "9b0aed2c2fb4fd2412c74fd91f95911be5a6fcf7ce6e683ceb7caab3f97059db",
    "03_behavior": "6c3c7af703ea0efdfb63a4a06d8f289254bba51c834d652ebfdb18e38569474a",
    "04_intimacy_core": "dcabad48f539c11bab4bc3d44f5059a8fbbcdb316b8bc9cee1ff1c80a99f7735",
    "05_intimacy_rendering": "15dd93c44475a9492074f9e35a6d18b860ba3be5db9f946eadbfbc86eae4c377",
    "06_intimacy_reference": "f13b7a5b92ed0fe59c227642acdf37eab47b93820e21d0c03a51b0a7425dbe52",
}.items():
    assert f"'{key}': '{digest}'" in defaults

for token in [
    "legacyEditableRuleLayerSha256V0342.entries",
    "sha256.convert(utf8.encode(stored)).toString()",
    "if (sha256.convert(utf8.encode(stored)).toString() != entry.value)",
    "whereArgs: [entry.key]",
]:
    assert token in database, token

assert "ChatPage(active: index == 1)" in app
assert "const ChatPage({super.key, this.active = false})" in chat_page
assert "!oldWidget.active && widget.active" in chat_page
assert "widget.active &&" in chat_page
assert "controller.acknowledgeOverlayUnread()" in chat_page
assert "Future<void> acknowledgeOverlayUnread()" in controller

for token in [
    "SMALL -> 9",
    "LARGE -> 30",
    "SMALL -> 24",
    "LARGE -> 56",
    "return THINKING",
    "ttsPhase == \"playing\") return TALKING",
]:
    assert token in contract, token
assert "PetOverlaySizing.badgeTopDp(size)" in window
assert "PetOverlaySizing.badgeEndDp(size)" in window
assert "PetOverlaySizing.badgeTopDp(normalized)" in window
assert "PetOverlaySizing.badgeEndDp(normalized)" in window
assert "PetConversationPolicy.THINKING" in contract_test
assert "PetOverlaySizing.badgeTopDp(PetOverlaySizing.LARGE)" in contract_test

assert "Build AI Companion v0.34.4+69 APK (Overlay Recovery and Diagnostics)" in workflow
assert "python3 tools/validate_v0343_lifelike_rules_overlay.py" in workflow
assert "AI-Companion-v0.34.4-69-Overlay-Recovery-Diagnostics-APK" in workflow

print("v0.34.3 lifelike rules, conservative migration, unread acknowledgement, badge placement and reply animation verified")
