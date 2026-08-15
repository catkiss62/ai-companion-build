#!/usr/bin/env python3
"""Static contract checks for v0.33.8 pet semantic autonomy D3.2."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


assert "version: 0.33.8+63" in read("pubspec.yaml")

snapshot = read("lib/core/platform/pet_autonomy_snapshot.dart")
server = read("lib/core/platform/background_chat_command_server.dart")
require(
    snapshot,
    [
        "required DesireSnapshot desire",
        "required List<CompanionThought> thoughts",
        "required bool brainWorkAllowed",
        "thought.canDriveIntentAt(instant)",
        "'dominant_drive': dominantDrive",
        "'thought_strength': thoughtStrength",
    ],
    "Dart read-only visual projection",
)
assert "thought.text" not in snapshot
require(
    server,
    [
        "case 'petAutonomySnapshot':",
        "db.loadDesire()",
        "db.activeThoughtMetadata(limit: 16)",
        "db.brainWorkAllowed()",
    ],
    "background command bridge",
)

policy = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAutonomyPolicy.kt")
pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt")
service = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
require(
    policy,
    [
        "MIN_MICRO_IDLE_MS = 12_000L",
        "MIN_SEMANTIC_IDLE_MS = 45_000L",
        "SLEEP_IDLE_MS = 180_000L",
        '"curiosity" -> PetAutonomyDecision("WALKING"',
        '"reflection", "duty" -> PetAutonomyDecision("THINKING"',
        'PetAutonomyDecision("HAPPY"',
        'actionId = "YAWNING"',
    ],
    "pure semantic policy",
)
assert "Random" not in policy
require(
    pet,
    [
        "private val autonomyTick",
        "private val autonomousWalkTick",
        "conversationCue == PetConversationPolicy.IDLE",
        "setAutonomySuppressed",
        "queueAfterCurrent(\"SLEEPING\")",
        "AUTONOMOUS_WALK_DURATION_MS = 2_200L",
        "cancelAutonomyPlayback(resetToIdle = true)",
    ],
    "native cadence and arbiter",
)
require(
    service,
    [
        '"petAutonomySnapshot"',
        "PET_AUTONOMY_POLL_MS = 30_000L",
        'chatExpanded || generationActive || ttsPhase != "idle"',
    ],
    "service polling and synthesis silence",
)
require(
    skin,
    [
        'actions["YAWNING"]',
        'durationMs = 1_200L',
        "daily_transition_00.png",
        "sleepy_yawn.png",
        "val frames = listOf(transition, yawn, yawn, transition)",
    ],
    "composed PNG yawn",
)
assert "walk_side_stand" not in policy + pet + skin
for removed in ("falling_airborne_v2", '"BOUNCING"', "floorContact"):
    assert removed not in pet + skin, removed

dart_tests = read("test/pet_autonomy_snapshot_test.dart")
kotlin_tests = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
require(dart_tests, ["without exposing its text", "standby brain disables"], "Dart tests")
require(kotlin_tests, ["queueSleepAfter", 'assertEquals("THINKING"'], "Kotlin tests")

doc = read("docs/PET_SEMANTIC_AUTONOMY_D3_2_v0.33.8.md")
require(
    doc,
    [
        "Desire、Thought、视觉 mood 与空闲时长",
        "daily_transition_00 → sleepy_yawn → sleepy_yawn → daily_transition_00",
        "不使用 `walk_side_stand`",
        "不使用 `falling_v2`",
    ],
    "D3.2 design record",
)

workflow = read("../.github/workflows/build-apk.yml")
require(
    workflow,
    [
        "Build AI Companion v0.33.8+63 APK",
        "python3 tools/validate_v0338_pet_semantic_autonomy.py",
        "AI-Companion-v0.33.8-63-Pet-Semantic-Autonomy-D3-2-APK",
    ],
    "workflow",
)

print(
    "v0.33.8 D3.2 validated: durable-state projection, deterministic cadence, "
    "priority arbiter, composed PNG yawn, bounded walking, and restored falling contract."
)
