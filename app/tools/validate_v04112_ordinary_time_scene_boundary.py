#!/usr/bin/env python3
"""Static contracts for v0.41.12 ordinary-chat time scene boundaries."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


pubspec = read(APP / "pubspec.yaml")
database = read(APP / "lib/core/database/app_database.dart")
snapshot = read(APP / "lib/core/grounding/grounding_snapshot.dart")
prompt = read(APP / "lib/core/ai/prompt_builder.dart")
immersive = read(APP / "lib/core/immersive/immersive_prompt_builder.dart")
tests = read(APP / "test/grounding_snapshot_test.dart")
docs = read(APP / "docs/ORDINARY_TIME_SCENE_BOUNDARY_v0.41.12.md")
doc_map = read(APP / "docs/DOCUMENTATION_MAP.md")
ledger = read(ROOT / "AI_Companion_当前总账.md")
workflow = read(ROOT / ".github/workflows/build-apk.yml")

assert "version: 0.41.12+151" in pubspec
assert "static const int schemaVersion = 42;" in database

for token in (
    "currentTurnRequiresTransientRecheck",
    "transientSceneRecheckMinutes = 45",
    "longGapMinutes = 120",
    "'cross_day'",
    "'long_gap'",
    "'transient_recheck'",
    "'same_scene'",
    "'currentTurnGapBand': currentTurnGapBand",
):
    assert token in snapshot, token

for token in (
    "上一段普通聊天结束时间",
    "当前普通聊天用户轮次时间",
    "手机预计算间隔分类",
    "OrdinaryChatSceneBoundaryPolicy.promptContract(grounding)",
    "mode == PromptGenerationMode.userTurn",
):
    assert token in prompt, token

for token in (
    "class OrdinaryChatSceneBoundaryPolicy",
    "普通聊天临时现场边界",
    "此刻一律视为 unknown",
    "也不得反向虚构“已经做完”",
    "还在/刚做完/一直在",
    "话题、关系、长期事实与记忆不因这个间隔失效",
):
    assert token in snapshot, token

for token in (
    "15-minute user turn keeps the ordinary short scene available",
    "13:01 to 15:00 rechecks transient activity despite 119-minute gap",
    "120-minute boundary is both long and transient recheck",
    "current explicit still-active text is allowed to override unknown",
    "cross-day user turn records the gap from the previous conversation",
):
    assert token in tests, token

# Immersive continuity must stay on its explicit room/session path.
assert "class ImmersivePromptBuilder" in immersive
assert "普通聊天临时现场边界" not in immersive
assert "currentTurnRequiresTransientRecheck" not in immersive

for token in (
    "under 45 minutes",
    "45–119 minutes",
    "120 minutes or more",
    "do not receive this ordinary-chat expiry contract",
    "Phase 2 reply influence",
):
    assert token in docs, token
assert "ORDINARY_TIME_SCENE_BOUNDARY_v0.41.12.md" in doc_map

for token in (
    "agent/v04112-ordinary-time-scene-boundary",
    "0.41.12+151",
    "Phase 2/3/4",
):
    assert token in ledger, token

for token in (
    "Build AI Companion v0.41.12+151 APK (Ordinary Time Scene Boundary)",
    "agent/v04112-ordinary-time-scene-boundary",
    "AI-Companion-v0.41.12-151-Ordinary-Time-Scene-Boundary-APK",
    "v0.41.12-ordinary-time-scene-boundary-test",
    "validate_v04112_ordinary_time_scene_boundary.py",
):
    assert token in workflow, token

print("v0.41.12 ordinary time scene boundary validation passed")
