#!/usr/bin/env python3
"""Static contracts for the v0.39.1 immersive-room polish release."""

from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


rule_source = read("lib/core/rules/rule_layer_content_immersive.dart")


def raw_constant(name: str) -> str:
    start = f"const {name} = r'''"
    return rule_source.split(start, 1)[1].split("''';", 1)[0]


composed_rule_07 = (
    "【小节开始｜immersive_07_global｜沉浸房间全局协议】\n"
    + raw_constant("immersiveRuleGlobal")
    + "\n【小节结束｜immersive_07_global】\n\n"
    + "【小节开始｜immersive_07_nsfw_source｜成人小说参考原文】\n"
    + raw_constant("immersiveNsfwSource")
    + "\n【小节结束｜immersive_07_nsfw_source】"
)
v0391_digest = "daee57ab9980f83135af2875ddcd2141eff235392a688e3e20ec3a16438dd942"
current_digest = sha256(composed_rule_07.encode("utf-8")).hexdigest()
if current_digest != v0391_digest:
    defaults_for_migration = read("lib/core/rules/rule_layer_defaults.dart")
    assert "db84d6249f3ea32ae9e85920105ca0eb869894bd1c24a1a2c7948e9603108612" in defaults_for_migration
    assert "validate_v0399_user_address_viewpoint.py" in read("../.github/workflows/build-apk.yml")
assert "至少500字]" in raw_constant("immersiveNsfwSource")
assert "【口交描写规则】" not in raw_constant("immersiveNsfwSource")
assert "【角色高潮引导】" not in raw_constant("immersiveNsfwSource")
assert "【姿势参考】" not in raw_constant("immersiveNsfwSource")

defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
assert "legacyEditableRuleLayerSha256V0390" in defaults
assert "...legacyEditableRuleLayerSha256V0390.entries" in database

rules_page = read("lib/features/settings/rule_layers_page.dart")
for removed in (
    "和她讨论",
    "_askAiForProposal",
    "revised_content",
    "DeepSeekClient",
):
    assert removed not in rules_page, removed

immersive = read("lib/features/immersive/immersive_room_page.dart")
for token in (
    "width: 2",
    "immersiveRailPink.withValues(alpha: 0.82)",
    "chat_visual_stage_enabled",
    "chat_panel_opacity",
    "chat_background_mode",
    "chat_portrait_set",
    "'affection'",
    "showEffect: false",
    "animate: false",
    "fontSize: 14",
    "NotificationListener<UserScrollNotification>",
    "distance < 8",
    "修改名称",
    "删除房间",
):
    assert token in immersive, token
assert "width: 3" not in immersive

repository = read("lib/core/immersive/immersive_room_repository.dart")
controller = read("lib/core/immersive/immersive_room_controller.dart")
for token in ("Future<void> renameRoom", "Future<void> deleteRoom"):
    assert token in repository, token
assert "'immersive_messages'" in repository
assert "Future<bool> deleteRoom" in controller

chat = read("lib/features/chat/chat_page.dart")
# v0.39.1 used a loose Flexible + Spacer to keep the quick-panel hit target
# content-sized. v0.39.3 replaces that layout with Expanded + left Align so the
# emotion label cannot collapse while the InkWell itself remains content-sized.
assert (
    "const Spacer()" in chat
    or "alignment: Alignment.centerLeft" in chat
)
assert "distance < 8" in chat
assert "_scrollToLatest(animate: true)" not in chat
assert "duration: const Duration(milliseconds: 180)" not in chat

print("v0.39.1 immersive room polish static contracts passed")
