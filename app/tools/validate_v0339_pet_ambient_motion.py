#!/usr/bin/env python3
"""Static contract checks for v0.33.9 ambient motion and action variety D3.3."""

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]

def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")

def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")

def png_size(relative: str) -> tuple[int, int]:
    data = (ROOT / relative).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", relative
    return struct.unpack(">II", data[16:24])

assert "version: 0.33.9+64" in read("pubspec.yaml")
policy = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAutonomyPolicy.kt")
pet = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt")
skin = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetSkinManifest.kt")
effects = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetEffectPose.kt")
frame = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetFrameView.kt")
player = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetAnimationPlayer.kt")
visual_docking = read("android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetVisualDocking.kt")
tests = read("android/app/src/test/kotlin/com/aicompanion/localfirst/pet/PetOverlayContractTest.kt")

require(policy, [
    "object PetMobilityPolicy",
    'const val MOBILE = "mobile"',
    'const val STATIONARY = "stationary"',
    "object PetAmbientActionPolicy",
    'repeat(8) { add("STROLLING") }',
    'addAll(stationaryBase)',
    "3_000L + (unit * 4_000L).toLong()",
    "fun nextBlinkDelayMs(randomUnit: Double): Long",
    "4_000L + (unit * 3_000L).toLong()",
    "const val MIN_AMBIENT_IDLE_MS = 3_000L",
    "val continuous2D: Boolean",
    "fun chooseSemantic(",
], "hybrid ambient policy")
require(pet, [
    'sectionLabel("自主行动")',
    'PetMobilityPolicy.MOBILE to "移动"',
    'PetMobilityPolicy.STATIONARY to "原地"',
    'sectionLabel("活动范围")',
    "ambientActionBag",
    "candidates.shuffled(ambientRandom)",
    "nextBlinkAtMs",
    "ambientNonMoveStreak",
    "MAX_NON_MOVE_STREAK = 2",
    "AUTONOMY_TICK_MS = 1_000L",
    "AUTONOMOUS_MOVE_TICK_MS = 16L",
    "AUTONOMOUS_MOVE_SPEED_DP_PER_SECOND = 93.75",
    "syncVisualDocking(layout)",
    "PetVisualDockingPolicy.edges(",
    "updateDockReference(normalized)",
    "player?.returnToIdle(",
    "val angle = ambientRandom.nextDouble() * Math.PI * 2.0",
    "val candidateX = (layout.x + cos(angle) * travel).roundToInt()",
    "val candidateY = (layout.y + sin(angle) * travel).roundToInt()",
    "layout.x + dx / distance * step",
    "layout.y + dy / distance * step",
    "cancelAutonomyPlayback(resetToIdle = true)\n        val normalized = normalizedSize(size)",
    "fun onConfigurationChanged() {\n        cancelAutonomyPlayback(resetToIdle = true)",
], "ambient scheduler, 360-degree motion and discontinuity guards")
assert "maxByOrNull" not in pet
assert "lastDailyActionAtMs" not in pet
assert "if (autonomySnapshot.enabled &&" not in pet

require(skin, [
    "// Preserve the authoring order for both walk directions: 00 -> 01 -> 02 -> 03.",
    "val frames = sourceFrames",
    'actionId in setOf("STROLLING", "WALKING")',
    'val mirrorLeftWalk = action.id == "WALKING" && direction == "right"',
    "if (mirrorLeftWalk) {",
    "mirrored = mirrorLeftWalk",
    'assets["sleepy_yawn_runtime"]',
    '187 to listOf("runtime_overrides/yawning/sleepy_yawn_187.png")',
    '238 to listOf("runtime_overrides/yawning/sleepy_yawn_238.png")',
    '306 to listOf("runtime_overrides/yawning/sleepy_yawn_306.png")',
    'assetId = "sleepy_yawn_runtime"',
], "walk order and normalized yawn asset")
assert "listOf(sourceFrames[3], sourceFrames[1], sourceFrames[2], sourceFrames[0])" not in skin
assert 'return if (direction == "right") "walk_side_right" else defaultAsset' not in skin

asset_root = "android/app/src/main/assets/pets/dafeiyu/source/runtime_overrides/yawning"
assert png_size(f"{asset_root}/sleepy_yawn_187.png") == (136, 160)
assert png_size(f"{asset_root}/sleepy_yawn_238.png") == (171, 202)
assert png_size(f"{asset_root}/sleepy_yawn_306.png") == (222, 261)

require(effects, ['decoration = "dizzy"', '"yawn_sway" ->'], "approved procedural effects")
for removed in ('decoration = "sparkle"', 'decoration = "crumb"', 'decoration = "sweep"', 'decoration = "sleep"'):
    assert removed not in effects, removed
require(frame, [
    'kind !in setOf("thought", "voice", "dizzy")',
    '"dizzy" ->',
    "private fun drawStar(",
], "dizzy star renderer")
for removed in ('"sparkle" ->', '"crumb" ->', '"sweep" ->', '"sleep" ->'):
    assert removed not in frame, removed


require(frame, [
    "setDockReference(bitmap: Bitmap, anchor: PetAnchor)",
    "setDockedVisualEdges(edges: Set<String>)",
    "visibleDockOffset(",
    "if (dockedVisualEdges.isEmpty()) return PetVisibleOffset()",
    "opaqueBounds(bitmap: Bitmap)",
    "transformedVisibleBounds(",
    "PetVisibleEdgeCompensation.offset(",
], "action-agnostic visible-pixel edge anchoring")
assert "EDGE_ANCHORED_ACTIONS" not in frame
assert "layer.actionId !in" not in frame
require(visual_docking, [
    "object PetVisibleEdgeCompensation",
    "reference.left - current.left",
    "reference.right - current.right",
    "reference.top - current.top",
    "reference.bottom - current.bottom",
    "object PetVisualDockingPolicy",
    "add(dockedEdge)",
], "primary and corner edge policy")
require(player, [
    "fun returnToIdle(",
    'switchToState("IDLE", crossfade = true, immediate = false)',
], "smooth locomotion return")

require(tests, [
    "ambientBagStaysAliveWithoutBrainProjectionAndRespectsStationaryMode",
    "desireStateBiasesButDoesNotOwnAmbientChoices",
    "mobilityModeDefaultsToMobileAndPersistsStationaryChoice",
    "autonomousMovementUsesContinuousPathsExceptAtScreenEdges",
    "edgeVisualDockingPinsPrimaryEdgeAndBothAxesAtCorners",
    "visibleEdgeCompensationIsActionAgnosticAndOnlyCorrectsDockedAxes",
], "Kotlin behavioral contracts")

doc = read("docs/PET_AMBIENT_MOTION_D3_3_v0.33.9.md")
require(doc, [
    "移动 / 原地",
    "360°",
    "00 → 01 → 02 → 03",
    "洗牌袋",
    "晕眩星星",
    "3–7 秒",
    "4–7 秒",
    "约 60Hz",
    "完整镜像",
    "可见像素边界",
    "角落双边",
    "全部渲染动作",
], "D3.3 design record")

workflow = read("../.github/workflows/build-apk.yml")
require(workflow, [
    "Build AI Companion v0.33.9+64 APK",
    "python3 tools/validate_v0339_pet_ambient_motion.py",
    "AI-Companion-v0.33.9-64-Pet-Ambient-Motion-D3-3-APK",
], "workflow")

print("v0.33.9 validated: all docked render actions share visible-pixel edge anchoring, with corner locks, smooth 60Hz motion, mirrored right gait, stationary mode, yawn tiers and dizzy stars.")
