#!/usr/bin/env python3
"""Static contracts for v0.39.2 immersive fullscreen/NSFW/stream stability."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 35;" in database
for token in (
    "oldVersion < 35",
    "ADD COLUMN nsfw_active INTEGER NOT NULL DEFAULT 0",
    "ADD COLUMN nsfw_manual_override TEXT NOT NULL DEFAULT ''",
    "ADD COLUMN nsfw_route_source TEXT NOT NULL DEFAULT 'initial'",
):
    assert token in database, token

model = read("lib/core/models/immersive_room.dart")
for token in ("nsfwActive", "nsfwManualOverride", "nsfwRouteSource"):
    assert token in model, token
model_test = read("test/immersive_room_model_test.dart")
assert "legacy room rows default to an isolated daily NSFW route" in model_test
assert "room NSFW route reads independently persisted state" in model_test

repository = read("lib/core/immersive/immersive_room_repository.dart")
for token in (
    "Future<void> setNsfwManualOverride",
    "Future<void> saveNsfwRoute",
    "'nsfw_manual_override': ''",
):
    assert token in repository, token

router = read("lib/core/immersive/immersive_nsfw_router.dart")
for token in (
    "class ImmersiveNsfwRouter",
    "CURRENT_ROUTE=",
    "ImmersiveClimaxEvent",
    "manual == 'off'",
    "fallbackClimaxEvent",
):
    assert token in router, token
assert "nsfw_active" not in router

prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
assert "required bool nsfwActive" in prompt
assert "if (nsfwActive) '04_intimacy_core'" in prompt
assert "if (nsfwActive) 'immersive_07_nsfw_source'" in prompt
assert "if (nsfwActive) '05_intimacy_rendering'" in prompt
assert "if (nsfwActive) '06_intimacy_reference'" in prompt

controller = read("lib/core/immersive/immersive_room_controller.dart")
for token in (
    "nsfwRouter.decide(",
    "repository.saveNsfwRoute(",
    "Future<void> setNsfwActive",
    "Timer(const Duration(milliseconds: 16)",
    "displayReasoning: false",
    "reasoningContent: _allStreamingReasoning",
):
    assert token in controller, token
assert "_safeNotify();\n    }\n    return finishReason;" not in controller

page = read("lib/features/immersive/immersive_room_page.dart")
for token in (
    "Widget _nsfwButton(ImmersiveRoom room)",
    "正在根据当前房间剧情判定",
    "_scrollFrameScheduled",
    "Positioned.fill(",
    "distance < 8",
):
    assert token in page, token
assert "chat_panel_fraction" not in page
if "immersive_panel_fraction" in page:
    assert "_panelFraction" in page
    assert "height: panelHeight" in page
else:
    assert "_panelFraction" not in page
    assert "height: panelHeight" not in page

print("v0.39.2 immersive fullscreen/NSFW/stream contracts passed")
