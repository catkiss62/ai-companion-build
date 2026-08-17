#!/usr/bin/env python3
"""Static contract checks for v0.33.5 pet/chat action arbitration D3.1."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


assert any(version in read("pubspec.yaml") for version in (
    "version: 0.33.5+60", "version: 0.33.6+61", "version: 0.33.7+62", "version: 0.33.9+64", "version: 0.34.1+66", "version: 0.34.3+68", "version: 0.34.5+70",
))

contract = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayContract.kt"
)
require(
    contract,
    [
        "object PetConversationPolicy",
        'const val IDLE = "idle"',
        'const val THINKING = "thinking"',
        'const val TALKING = "talking"',
        'if (ttsPhase == "playing") return TALKING',
        'return THINKING',
        'THINKING -> "THINKING"',
        'TALKING -> "TALKING"',
    ],
    "pure conversation policy",
)

pet = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)
require(
    pet,
    [
        "private var conversationCue = PetConversationPolicy.IDLE",
        "fun bringToFront(): Boolean",
        "windowManager.removeViewImmediate(view)",
        "windowManager.addView(view, layout)",
        "fun setConversationCue(value: String)",
        "private fun reconcileConversationAction(reason: String)",
        'private val CONVERSATION_ACTIONS = setOf("THINKING", "TALKING")',
        "action.id == \"IDLE\" && phase == PetAnimationPhase.BODY",
        "private const val PORTRAIT_BOTTOM_MARGIN_DP",
    ],
    "pet chat arbitration",
)

frame = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetFrameView.kt"
)
require(
    frame,
    [
        'kind !in setOf("thought", "voice", "dizzy")',
    ],
    "program-drawn decoration whitelist",
)
assert '"anger" ->' not in frame
assert "canvas.drawLine(cx - dp(5f)" not in frame

service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
require(
    service,
    [
        "import com.aicompanion.localfirst.pet.PetConversationPolicy",
        'private var overlayGenerationPhase = "idle"',
        'keepPetAboveChat("chat_open")',
        'keepPetAboveChat("chat_input_enter")',
        'keepPetAboveChat("chat_input_exit")',
        "private fun keepPetAboveChat(reason: String)",
        "pet.bringToFront()",
        "private fun updatePetConversationCue()",
        "PetConversationPolicy.cueFor(",
        "private fun shouldPollGeneration()",
        "private fun shouldPollTts()",
        "PET_TTS_DISCOVERY_MS = 3_000L",
    ],
    "overlay generation/TTS bridge",
)

show_chat = service.split("private fun showChatOverlay", 1)[1].split(
    "private fun collapseChatOverlay", 1
)[0]
assert "setVisible(false)" not in show_chat
assert "chatRoot?.visibility = View.VISIBLE" in show_chat

tests = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
require(
    tests,
    [
        "conversationCueUsesRealGenerationAndPlaybackState",
        'PetConversationPolicy.cueFor(true, "thinking", "idle")',
        'PetConversationPolicy.cueFor(true, "answering", "idle")',
        'PetConversationPolicy.cueFor(false, "idle", "playing")',
    ],
    "conversation policy unit tests",
)

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.34.5+70 APK (Direct Picker Recovery)",
        "python3 tools/validate_v0335_pet_chat_action_arbiter.py",
        "AI-Companion-v0.34.5-70-Direct-Picker-Recovery-APK",
    ],
    "workflow",
)

print(
    "v0.33.5 pet chat D3.1 validated: topmost pet/chat coexistence, durable "
    "THINKING/TALKING cues, transient-action resume, TTS discovery grace, "
    "portrait floor lift, and duplicate anger-X removal."
)
