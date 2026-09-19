#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, needles: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise SystemExit(f"{path}: missing {missing}")


require(
    "lib/core/ai/deepseek_client.dart",
    [
        "class DeepSeekPromptShape",
        "class DeepSeekPromptSegmentShape",
        "final canonicalTools = _canonicalTools(tools)",
        "required this.promptShape",
        "sha256.convert(utf8.encode(value))",
    ],
)
require(
    "lib/core/diagnostics/model_usage_telemetry.dart",
    [
        "'prompt_shape'",
        "'characters': segment.characters",
        "'hash': segment.hash",
        "'characters': event.promptShape.toolCharacters",
    ],
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    [
        "'modelPromptBodiesIncluded': false",
        "'modelPromptSegmentHashesIncluded': true",
        "'recentPromptShapes'",
        "'promptSegmentHashesIncluded': true",
    ],
)
require(
    "test/deepseek_prompt_cache_shape_v04189_test.dart",
    [
        "canonical tool schemas share a body-free prompt shape",
        "expect(requestTools[0], requestTools[1])",
        "isNot('private dynamic value')",
    ],
)

lane_files = {
    "features/settings/settings_category_pages.dart": "provider_connection_test",
    "core/phone/simulated_diary_generator.dart": "simulated_diary",
    "core/phone/simulated_note_generator.dart": "simulated_note",
    "core/phone/simulated_cart_generator.dart": "simulated_cart",
    "core/ai/nsfw_context_router.dart": "chat_intimacy_route",
    "core/ai/message_language_variant_service.dart": "message_translation",
    "core/ai/reasoning_translation_service.dart": "reasoning_translation",
    "core/immersive/immersive_nsfw_router.dart": "immersive_route",
    "core/immersive/immersive_room_controller.dart": "immersive_reply",
    "core/self/ai_self_reflection_engine.dart": "self_reflection",
}
for relative, lane in lane_files.items():
    require(f"lib/{relative}", [f"usageLane: '{lane}'"])

memory = (ROOT / "lib/core/ai/memory_extractor.dart").read_text(encoding="utf-8")
for lane in ("memory_extraction", "personality_evidence_review", "conversation_summary"):
    if f"usageLane: '{lane}'" not in memory:
        raise SystemExit(f"memory_extractor.dart: missing lane {lane}")

require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    [
        "String usageLane = 'cedar_background_plan'",
        "usageLane: 'cedar_game_choice'",
        "usageLane: 'cedar_outcome'",
    ],
)

print("v0.41.89 prompt cache observability validation passed")
