#!/usr/bin/env python3
"""Compatibility checks for the v0.33.8 semantic-autonomy bridge."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")

def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")

pubspec = read("pubspec.yaml")
assert "version: 0.33.8+63" in pubspec or "version: 0.33.9+64" in pubspec or "version: 0.34.1+66" in pubspec

snapshot = read("lib/core/platform/pet_autonomy_snapshot.dart")
server = read("lib/core/platform/background_chat_command_server.dart")
service = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
policy = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAutonomyPolicy.kt")
pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt")
skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")

require(snapshot, [
    "required DesireSnapshot desire",
    "required List<CompanionThought> thoughts",
    "required bool brainWorkAllowed",
    "'dominant_drive': dominantDrive",
    "'thought_strength': thoughtStrength",
], "Dart read-only visual projection")
assert "thought.text" not in snapshot
require(server, [
    "case 'petAutonomySnapshot':",
    "db.loadDesire()",
    "db.activeThoughtMetadata(limit: 16)",
    "db.brainWorkAllowed()",
], "background command bridge")
require(service, [
    '"petAutonomySnapshot"',
    "PET_AUTONOMY_POLL_MS = 30_000L",
    'chatExpanded || generationActive || ttsPhase != "idle"',
], "service polling and synthesis silence")
require(policy, [
    "data class PetAutonomySnapshot",
    "fun chooseSemantic(",
    'actionId = "YAWNING"',
    'PetAutonomyDecision("THINKING"',
], "semantic visual consumer")
require(pet, [
    "setAutonomySnapshot",
    "setAutonomySuppressed",
    "conversationCue == PetConversationPolicy.IDLE",
], "overlay arbiter")
require(skin, ['actions["YAWNING"]', 'actions["STROLLING"]'], "runtime actions")
for removed in ("falling_airborne_v2", '"BOUNCING"', "floorContact"):
    assert removed not in pet + skin, removed

print("v0.33.8 compatibility validated: durable Desire/Thought projection remains read-only and TTS-safe.")
