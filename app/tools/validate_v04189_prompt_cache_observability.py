#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent


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
require("lib/core/agent/agent_self_reader.dart", ["v0.41.89+233"])
require("test/agent_self_reader_v0416_test.dart", ["build=v0.41.89+233 schema=61"])
require("lib/core/mcp/mcp_http_client.dart", ["'version': '0.41.89'"])
require(
    "../.github/workflows/build-apk.yml",
    [
        "agent/v04189-cedar-temporal-wishlist-cache",
        "AI-Companion-v0.41.89-233-Cedar-Temporal-Wishlist-Cache-APK",
        "v0.41.89-cedar-temporal-wishlist-cache-test",
    ],
)

if "version: 0.41.89+233" not in (ROOT / "pubspec.yaml").read_text(
    encoding="utf-8"
):
    raise SystemExit("pubspec.yaml: v0.41.89+233 version missing")

ledger = (REPOSITORY / "AI_Companion_当前总账.md").read_text(encoding="utf-8")
for token in (
    "IMPLEMENTED LOCALLY / LOCAL STATIC VALIDATION PASSED / CI PENDING / TRUE DEVICE PENDING",
    "recentPromptShapes",
    "工具 schema 的 Map key 做递归确定性排序",
):
    if token not in ledger:
        raise SystemExit(f"current ledger: missing {token}")
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
