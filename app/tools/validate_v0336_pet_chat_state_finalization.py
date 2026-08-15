#!/usr/bin/env python3
"""Static contract checks for v0.33.6 pet chat state finalization D3.1.1."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


pubspec = read("pubspec.yaml")
assert "version: 0.33.6+61" in pubspec or "version: 0.33.7+62" in pubspec

bridge = read("lib/core/platform/android_bridge.dart")
controller = read("lib/features/chat/chat_controller.dart")
require(bridge, ["setPetConversationState", "generationActive", "generationPhase", "ttsPhase"], "Dart Android bridge")
require(
    controller,
    [
        "bool _petGenerationActive = false",
        "void _publishPetConversationState()",
        "TtsPlaybackPhase.synthesizing => 'synthesizing'",
        "TtsPlaybackPhase.playing => 'playing'",
        "generationActive: _petGenerationActive",
        "messages = [...messages, result.assistant!]",
        "_petGenerationActive = false",
    ],
    "App chat/TTS publisher",
)

system_bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
service = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
require(system_bridge, ['"setPetConversationState"', "ACTION_SET_PET_CONVERSATION"], "native state channel")
require(
    service,
    [
        "private var appGenerationActive = false",
        'private var appTtsPhase = "idle"',
        "ACTION_SET_PET_CONVERSATION",
        "val generationActive = chatSending || appGenerationActive",
        'appTtsPhase == "playing"',
        "PetConversationPolicy.cueFor(",
    ],
    "merged App/overlay cue",
)

pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt")
skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
physics = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetThrowPhysics.kt")
require(
    pet,
    [
        "private const val PORTRAIT_BOTTOM_MARGIN_DP = 16",
        "dp(windowDp(size) * 8 / 100)",
        "dp(windowDp(size) * 21 / 100)",
    ],
    "pet geometry",
)
if "version: 0.33.6+61" in pubspec:
    require(
        pet,
        ["step.floorContact && !step.settled", '"BOUNCING"'],
        "v0.33.6 two-stage fall",
    )
    require(
        skin,
        [
            'AIRBORNE_V2_ASSET_ID = "falling_airborne_v2"',
            "candidate_e_throw_landing/falling_v2.png",
        ],
        "v0.33.6 airborne asset",
    )
    require(physics, ["val floorContact: Boolean = false"], "v0.33.6 floor contact")
else:
    require(
        pet,
        ['player?.play("FALLING", reason = reason', 'player?.play("LANDING", reason = "pet_overlay_landing"'],
        "v0.33.7 restored fall",
    )
    for removed in ("falling_airborne_v2", '"BOUNCING"', "floorContact"):
        assert removed not in pet + skin + physics, removed

tests = read("android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt")
require(tests, ['PetConversationPolicy.cueFor(false, "idle", "synthesizing")'], "synthesis silence test")

doc = read("docs/PET_CHAT_STATE_FINALIZATION_D3_1_1_v0.33.6.md")
require(doc, ["daily_transition_00", "sleepy_yawn", "D3.2"], "confirmed action ledger")

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.33.7+62 APK",
        "python3 tools/validate_v0336_pet_chat_state_finalization.py",
        "AI-Companion-v0.33.7-62-Pet-Falling-Visual-Rollback-D3-1-2-APK",
    ],
    "workflow",
)

print("v0.33.6+ chat finalization validated: App/overlay cues, synthesis silence, geometry, and current falling contract.")
