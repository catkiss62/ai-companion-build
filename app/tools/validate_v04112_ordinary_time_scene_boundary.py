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

assert any(
    version in pubspec
    for version in ("version: 0.41.12+151", "version: 0.41.13+152")
)
assert "static const int schemaVersion = 42;" in database

for token in (
    "currentTurnRequiresTransientRecheck",
    "transientSceneRecheckMinutes = 30",
    "longGapMinutes = 120",
    "'cross_day'",
    "'long_gap'",
    "'transient_recheck'",
    "'same_scene'",
    "'currentTurnGapBand': currentTurnGapBand",
    "userSceneGapMinutes",
    "timeBoundaryPromptMode",
):
    assert token in snapshot, token

for token in (
    "上一条真实用户消息时间",
    "当前真实用户消息时间",
    "手机预计算用户现场分类",
    "OrdinaryChatSceneBoundaryPolicy.promptContract(grounding)",
    "普通聊天时间边界 · 本场景首次详细注入",
):
    assert token in prompt, token

for token in (
    "class OrdinaryChatSceneBoundaryPolicy",
    "普通聊天临时现场边界",
    "不能机械延续",
    "明确持续时间",
    "还在/刚做完/一直在",
    "话题、关系、长期事实与记忆不因这个间隔失效",
):
    assert token in snapshot, token

for token in (
    "15-minute user turn keeps the ordinary short scene available",
    "13:00 user scene to 15:00 is long even when interaction gap is 119",
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
    "under 30 minutes",
    "30–119 minutes",
    "120 minutes or more",
    "do not receive this ordinary-chat expiry contract",
    "Phase 2 reply influence",
):
    assert token in docs, token
assert "ORDINARY_TIME_SCENE_BOUNDARY_v0.41.12.md" in doc_map

for token in (
    "agent/v04113-phase01-time-audit-hardening",
    "0.41.13+152",
    "Phase 2/3/4",
):
    assert token in ledger, token

for token in (
    "Build AI Companion v0.41.13+152 APK (Phase 0+1 Time Audit Hardening)",
    "agent/v04113-phase01-time-audit-hardening",
    "AI-Companion-v0.41.13-152-Phase01-Time-Audit-Hardening-APK",
    "v0.41.13-phase01-time-audit-hardening-test",
    "validate_v04113_phase01_time_audit_hardening.py",
):
    assert token in workflow, token

print("v0.41.12 ordinary time scene boundary validation passed")
