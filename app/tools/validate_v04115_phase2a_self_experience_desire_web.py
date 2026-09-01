#!/usr/bin/env python3
"""Static contracts for v0.41.15 Phase 2A autonomy foundation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
desire_policy = read("app/lib/core/desire/desire_core_policy.dart")
desire_engine = read("app/lib/core/desire/desire_engine.dart")
self_drive = read("app/lib/core/desire/self_drive_engine.dart")
screen_policy = read("app/lib/core/perception/screen_off_contact_policy.dart")
perception = read("app/lib/core/perception/perception_engine.dart")
web_policy = read("app/lib/core/autonomy/public_web_discovery_policy.dart")
web_appraisal = read("app/lib/core/autonomy/public_web_appraisal_policy.dart")
web_engine = read("app/lib/core/autonomy/public_web_discovery_engine.dart")
guard = read("app/lib/core/grounding/operational_claim_grounding_guard.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
diagnostics = read("app/lib/core/diagnostics/preflight_diagnostics.dart")
snapshot = read("app/lib/core/sync/snapshot_service.dart")
docs = read("app/docs/SELF_EXPERIENCE_DESIRE_WEB_PHASE2A_v0.41.15.md")
doc_map = read("app/docs/DOCUMENTATION_MAP.md")
ledger = read("AI_Companion_当前总账.md")
workflow = read(".github/workflows/build-apk.yml")

assert "version: 0.41.15+154" in pubspec
assert "static const int schemaVersion = 43;" in database
assert "buildLabel = 'v0.41.15+154'" in read(
    "app/lib/core/agent/agent_self_reader.dart"
)

for token in (
    "CREATE TABLE IF NOT EXISTS self_review_candidates",
    "CREATE TABLE IF NOT EXISTS self_experiences",
    "CREATE TABLE IF NOT EXISTS desire_events",
    "upsertSelfReviewCandidate",
    "claimSelfReviewCandidate",
    "finishSelfReviewCandidate",
    "selfExperienceDiagnosticStats",
    "desireEventDiagnosticStats",
    "_recordDesireEventsTxn",
    "source: 'tool:public_web:discover_interest'",
    "source: 'post_turn_model'",
    "source: 'relationship/${currentEvent.kind}'",
    "'self_review_candidates'",
    "'self_experiences'",
    "'desire_events'",
):
    assert token in database, token
for token in (
    "schemaVersion >= 43",
    "schema 43 状态包缺少自我体验表",
    "'self_review_candidates'",
    "'self_experiences'",
    "'desire_events'",
):
    assert token in snapshot, token

for token in (
    "retainedDeviation",
    "(value - baseline)",
    "_applyCoupling(drives, baselines, scale)",
):
    assert token in desire_policy, token
assert "source: source" in desire_engine

for token in (
    "_refreshCandidates",
    "pendingSelfReviewCandidates",
    "claimSelfReviewCandidate",
    "unfinished_thread_reviewed",
    "memory_recalled",
    "source_no_longer_active",
):
    assert token in self_drive, token

for token in (
    "minimumOffDuration = Duration(minutes: 90)",
    "lastPulsedSessionKey == sessionKey",
    "circadianFatigueFloor",
    "treatsScreenOffAsUserFree",
):
    assert token in screen_policy + diagnostics, token
assert "screen_off_contact_window" in perception

for token in (
    "curiosity_explore",
    "reflection_understand",
    "social_material",
    "astronomy",
    "literature",
    "games",
    "recentInterestKeys",
):
    assert token in web_policy, token
assert web_policy.count("_PublicWebTopicSeed(") == 73
for token in ("discard", "hold", "verify", "share_candidate"):
    assert token in web_appraisal, token
for token in ("socialExcess >= 0.12", "socialExcess >= 0.14"):
    assert token in web_appraisal, token
assert "PublicWebAppraisalPolicy.appraise" in web_engine
for token in ("'verify' => 'verify_pending'", "'hold' => 'held'"):
    assert token in database, token

for token in (
    "ungrounded_chat_archive_read",
    "conversation_archive.read",
    "_chatArchiveObject",
):
    assert token in guard, token
for token in ("Memory、Thought 与 Self Experience", "不等于主动打开聊天档案"):
    assert token in prompt, token

for test_file in (
    "test/desire_core_policy_v031_test.dart",
    "test/screen_off_contact_policy_v04115_test.dart",
    "test/public_web_discovery_policy_v0348_test.dart",
    "test/public_web_appraisal_policy_v04115_test.dart",
    "test/operational_claim_grounding_guard_test.dart",
):
    assert (APP / test_file).is_file(), test_file

for token in (
    "SELF_EXPERIENCE_DESIRE_WEB_PHASE2A_v0.41.15.md",
    "Phase 2A",
    "schema 43",
    "screen_off_contact_window",
    "reflection_understand",
    "share_candidate",
):
    assert token in docs + doc_map + ledger, token

for token in (
    "Build AI Companion v0.41.15+154 APK (Phase 2A Self Experience + Desire + Web)",
    "agent/v04115-phase2a-self-experience-desire-web",
    "AI-Companion-v0.41.15-154-Phase2A-Self-Experience-Desire-Web-APK",
    "v0.41.15-phase2a-self-experience-desire-web-test",
    "validate_v04115_phase2a_self_experience_desire_web.py",
):
    assert token in workflow, token

print("v0.41.15 Phase 2A self experience, desire and web validation passed")
