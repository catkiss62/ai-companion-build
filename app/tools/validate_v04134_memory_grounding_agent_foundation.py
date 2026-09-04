#!/usr/bin/env python3
"""Static contracts for v0.41.34 memory grounding and Agent foundation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
memory_model = read("app/lib/core/models/memory_item.dart")
memory_policy = read("app/lib/core/memory/memory_grounding_policy.dart")
memory_brain = read("app/lib/core/memory/memory_brain.dart")
extractor = read("app/lib/core/ai/memory_extractor.dart")
self_drive = read("app/lib/core/desire/self_drive_engine.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
proactive = read("app/lib/core/desire/proactive_engine.dart")
grounding = read("app/lib/core/grounding/operational_claim_grounding_guard.dart")
proactive_grounding = read("app/lib/core/grounding/proactive_grounding_guard.dart")
registry = read("app/lib/core/agent/agent_tool_registry.dart")
planner = read("app/lib/core/agent/agent_tool_planner.dart")
runner = read("app/lib/core/agent/agent_tool_runner.dart")
phone = read("app/lib/core/phone/simulated_phone_repository.dart")
phone_reader = read("app/lib/core/phone/simulated_phone_reader.dart")
album_engine = read("app/lib/core/phone/companion_album_discovery_engine.dart")
chat = read("app/lib/features/chat/chat_controller.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.34+173" in pubspec
assert "static const int schemaVersion = 47;" in database
assert "buildLabel = 'v0.41.34+173'" in self_reader

for token in (
    "actor_key TEXT NOT NULL DEFAULT 'unknown'",
    "relation_key TEXT NOT NULL DEFAULT ''",
    "object_key TEXT NOT NULL DEFAULT ''",
    "owner_key TEXT NOT NULL DEFAULT 'unknown'",
    "temporal_scope TEXT NOT NULL DEFAULT 'unknown'",
    "_createV47MemoryGroundingColumns",
    "if (table == 'memory_items' && version < 47)",
):
    assert token in database, token
for token in (
    "actorKey",
    "relationKey",
    "objectKey",
    "ownerKey",
    "temporalScope",
):
    assert token in memory_model, token
for token in (
    "last_known_ongoing",
    "current_status=unknown",
    "age_days=",
    "THREAD_GROUNDING",
    "SUMMARY_GROUNDING",
    "想起发生在现在不代表被想起的事件发生在刚才",
):
    assert token in memory_policy, token
assert "MemoryGroundingPolicy.formatForPrompt" in memory_brain
assert "MemoryGroundingPolicy.recalledThoughtText" in self_drive
for token in (
    "actor 只能是 user / ai / shared / external / unknown",
    "object 必须指向完整对象",
    "temporal_scope 只能是 stable / ongoing / event / scheduled / unknown",
    "actorKey: item['actor']",
    "ownerKey: item['owner']",
):
    assert token in extractor, token

for token in (
    "_screenContentClaim",
    "屏幕上最后停在",
    "screen_observation.inspect",
):
    assert token in grounding + read("app/test/operational_claim_grounding_guard_test.dart"), token
assert "ProactiveMemoryTemporalGuard" in proactive_grounding
assert "stale_memory_as_recent_activity" in proactive_grounding
assert "memoryTemporalGuard" in proactive
assert "屏幕显示什么、最后停在哪页" in prompt

for token in (
    "phone.search",
    "phone.read",
    "attachment.save",
    "image.find_and_save",
):
    assert token in registry, token
assert "nativeToolDefinitionsFor(user.content)" in read(
    "app/lib/core/ai/durable_generation_runner.dart"
)
assert "CHAT_LIGHT returns no tool schema" in planner
assert "return const <Map<String, Object?>>[]" in planner
assert "readOnlySnapshot" in phone
for forbidden in ("refreshIfDue(", "markNotesRead(", "markAlbumRead("):
    assert forbidden not in phone_reader, forbidden
for token in (
    "SimulatedPhoneReader(db).search",
    "SimulatedPhoneReader(db).read",
    "_confirmAttachmentSaved",
    "_findAndSaveWebImage",
    "TERMINAL SUCCESS",
):
    assert token in runner, token
assert "saveUserRequestedWebImage" in album_engine
assert "forceSave: true" in album_engine
assert "final shouldSave = observation.albumSave || explicitlyRequested" in chat

for token in (
    "agent/v04134-memory-grounding-agent-foundation",
    "Build AI Companion v0.41.34+173 APK",
    "AI-Companion-v0.41.34-173-Memory-Grounding-Agent-Foundation-APK",
    "validate_v04134_memory_grounding_agent_foundation.py",
):
    assert token in workflow, token
for token in (
    "Memory 2C",
    "4.61 天",
    "行动者—关系—对象—归属",
    "一个 v0.41.34 测试 APK",
):
    assert token in ledger, token

forbidden_repository_names = (
    "AI_Companion_Backup_2026-09-04T17-40-23.aibackup",
    "ai_companion_diagnostics_2026-09-04T17",
)
for path in ROOT.rglob("*"):
    if path.is_file() and ".git" not in path.parts:
        assert path.name not in forbidden_repository_names, path

print("v0.41.34 memory grounding and Agent foundation validation passed")
