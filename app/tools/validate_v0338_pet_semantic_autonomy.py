#!/usr/bin/env python3
"""Static contract checks for the v0.33.8 pet motion and preview correction."""

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
effects = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetEffectPose.kt")
frame = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetFrameView.kt")
preview = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetPreviewActivity.kt")

require(
    policy,
    [
        "MIN_MICRO_IDLE_MS = 9_000L",
        "MIN_DAILY_IDLE_MS = 30_000L",
        'PetAutonomousMovementPlan("STROLLING", listOf("up", "down"))',
        'PetAutonomousMovementPlan("WALKING", listOf("left", "right"))',
        '"curiosity" -> PetAutonomyDecision("STROLLING"',
        'actionId = if (cadenceBucket % 5L == 0L) "SWEEPING" else "STROLLING"',
    ],
    "pure autonomy and movement policy",
)
assert "Random" not in policy

require(
    pet,
    [
        "private val autonomousMoveTick",
        "DAILY_ACTION_COOLDOWN_MS = 72_000L",
        "AUTONOMOUS_MOVE_MIN_TRAVEL_DP = 96",
        "val centerX = full.left + full.width / 2",
        "val centerY = full.top + full.height / 2",
        'player?.setDirection("down")',
        "conversationCue == PetConversationPolicy.IDLE",
    ],
    "native cadence, movement and half-screen bounds",
)
assert "screenCenter()" not in pet
assert "autonomousWalk" not in pet

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
        'assetId = "idle_front"',
        'effect = "yawn_sway"',
        'actions["STROLLING"]',
        '"left", "right" -> "walk_side_stand"',
        "listOf(sourceFrames[3], sourceFrames[1], sourceFrames[2], sourceFrames[0])",
    ],
    "runtime actions and right-walk phase order",
)
assert "daily_transition_00" not in skin
assert "sleepy_yawn.png" not in skin

require(
    effects,
    [
        'effect) {',
        '"stroll" ->',
        '"yawn_sway" ->',
        "1.9047619f",
    ],
    "procedural pose corrections",
)
for removed in (
    'decoration = "sparkle"',
    'decoration = "crumb"',
    'decoration = "sweep"',
    'decoration = "sleep"',
    'decoration = "dizzy"',
    'decoration = "anger"',
):
    assert removed not in effects, removed

require(
    frame,
    [
        'kind !in setOf("thought", "voice")',
        "previewWindowDp",
        "layer.mirrored",
    ],
    "render whitelist, real preview sizing and mirrored side pose",
)
for removed in ('"sparkle" ->', '"crumb" ->', '"sweep" ->', '"sleep" ->', '"dizzy" ->'):
    assert removed not in frame, removed

require(
    preview,
    [
        "window.setDecorFitsSystemWindows(true)",
        "setPreviewWindowDp(PetOverlaySizing.windowDp",
        'animationPlayer.play(\n                    "STROLLING"',
        'animationPlayer.setDirection("down")',
        "dp(320)",
    ],
    "safe, size-accurate preview controls",
)

for removed in ("falling_airborne_v2", '"BOUNCING"', "floorContact"):
    assert removed not in pet + skin, removed

kotlin_tests = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt"
)
require(
    kotlin_tests,
    [
        "dailyActionsStaySeparateFromBlinkCadence",
        "autonomousMovementUsesTheRequestedModeDirectionTable",
        'assertEquals("WALKING", horizontalEdge?.actionId)',
    ],
    "Kotlin movement contract tests",
)

doc = read("docs/PET_SEMANTIC_AUTONOMY_D3_2_v0.33.8.md")
require(
    doc,
    [
        "散步（STROLLING）",
        "走路（WALKING）",
        "03 → 01 → 02 → 00",
        "实际可活动区域",
        "walk_side_stand",
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
    "v0.33.8 validated: four-way strolling, edge walking, right gait order, "
    "daily actions, safe preview sizing, and restored falling contract."
)
