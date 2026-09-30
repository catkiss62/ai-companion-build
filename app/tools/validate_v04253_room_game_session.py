#!/usr/bin/env python3
"""Wiring regression guard; behavior is covered by the Flutter tests."""
from pathlib import Path

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text(encoding="utf-8")
controller = read("lib/core/immersive/immersive_room_controller.dart")
prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
page = read("lib/features/immersive/immersive_room_page.dart")
for removed in ("PlayfulTurnJudge", "PlayfulSelfJudge", "PlayfulBreakthroughJudge",
                ".onTurn(", ".onAssistantTurn("):
    assert removed not in controller, removed
assert controller.count("PlayfulFormStore(db).load()") == 1
assert "_entryFormLoading ??=" in controller and "qFormOverride:" in controller
assert "formSnapshot.prompt" in prompt and "PlayfulFormStore" not in prompt
assert "PlayfulHeatGauge" not in page and "formSnapshot.qForm" in page
for preserved in ("confirmIncompleteReply", "regenerate", "cancellation.throwIfCancelled()"):
    assert preserved in controller, preserved
assert "qFormOverride != null" in read("lib/core/tts/tts_service.dart")
assert "PlayfulFormStore(db).load()" in read("lib/core/tts/tts_service.dart")
assert "ChatEmotionEffectLayer(" in read("lib/features/chat/chat_page.dart")
effect = read("lib/widgets/chat_emotion_effect_layer.dart")
assert "IgnorePointer" in effect and "_playedReply = widget.replyId" in effect
assert "CaicaiLive2DService" not in effect
engine = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
assert "beginPlaySession" in engine and "episode.antiAddictionPresent && sustained" in engine
assert "!episodeAuthorized && !sustained && episode.checkpointPending" in engine
assert "executionId: scope.executionId" in engine
assert "cedarDidWork && !cedarSustainedActive" in read("lib/core/maintenance/recovery_orchestrator.dart")
policy = read("lib/core/mcp/cedar_play_session_policy.dart")
assert "30 * 60 * 1000" in policy and "processEpoch" in policy
assert read("lib/core/sync/snapshot_service.dart").count("'cedar_toy_play_session_v1': ''") == 2
assert "720" in policy and "minutes / 180" in policy
assert "CedarGameAttitudeStore(db).commit" in read("lib/core/ai/durable_generation_runner.dart")
assert "RememberedUserFactsStore(db).load()" in read("lib/core/ai/prompt_builder.dart")
assert "worldBookContext.hasRoleplay" in read("lib/core/ai/prompt_builder.dart")
assert "RememberedUserFactsPage" in read("lib/features/memory/memory_page.dart")
bubble = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
assert "R.drawable.companion_bubble_avatar" in bubble and "clipToOutline = true" in bubble
assert (app / "android/app/src/main/res/drawable-nodpi/companion_bubble_avatar.jpg").is_file()
assert (app / "test/room_game_session_v04253_test.dart").is_file()
assert (app / "test/chat_emotion_effect_layer_test.dart").is_file()
print("v0.42.53 immersive isolation, independent emotion, game sessions and facts wired")
