from pathlib import Path
import sqlite3


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text()
TELEMETRY = (ROOT / "lib/core/diagnostics/proactive_policy_telemetry.dart").read_text()
SELECTION = (ROOT / "lib/core/desire/proactive_selection_policy.dart").read_text()
CORE = (ROOT / "lib/core/desire/desire_core_policy.dart").read_text()
ENGINE = (ROOT / "lib/core/desire/proactive_engine.dart").read_text()
REFRESHER = (ROOT / "lib/core/perception/current_device_context_refresher.dart").read_text()
BRIDGE = (ROOT / "lib/core/platform/android_bridge.dart").read_text()
SYSTEM = (
    ROOT
    / "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
).read_text()
BACKGROUND = (
    ROOT
    / "android/app/src/main/kotlin/com/aicompanion/localfirst/BackgroundSystemBridge.kt"
).read_text()
RESOLVER = (
    ROOT
    / "android/app/src/main/kotlin/com/aicompanion/localfirst/CurrentAppResolver.kt"
).read_text()
REPORT = (ROOT / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()
PUBSPEC = (ROOT / "pubspec.yaml").read_text()
WORKFLOW = (ROOT.parent / ".github/workflows/build-apk.yml").read_text()


def require(text: str, token: str, label: str) -> None:
    assert token in text, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.40.3+132", "app version")
require(DB, "static const int schemaVersion = 40;", "schema version")
require(DB, "if (oldVersion < 40)", "v40 migration")
require(DB, "CREATE TABLE IF NOT EXISTS proactive_policy_events", "policy table")
require(DB, "proactive_policy_started_at", "upgrade boundary")
require(DB, "Duration(days: 14)", "bounded policy age")
require(DB, "ORDER BY created_at DESC LIMIT 500", "bounded policy rows")

table = DB.split("CREATE TABLE IF NOT EXISTS proactive_policy_events", 1)[1].split(
    "''');", 1
)[0]
for forbidden in (
    "app_name",
    "package_name",
    "thought_text",
    "message_text",
    "message_body",
    "query",
    "url",
    "screen_content",
    "reasoning",
    "raw_error",
):
    assert forbidden not in table, f"sensitive policy column found: {forbidden}"

connection = sqlite3.connect(":memory:")
connection.execute("CREATE TABLE proactive_policy_events" + table)
columns = {
    row[1]
    for row in connection.execute("PRAGMA table_info(proactive_policy_events)")
}
assert columns == {
    "id",
    "lane",
    "source_type",
    "intent_kind",
    "outcome",
    "reason_tag",
    "repeat_depth",
    "adjustment_bucket",
    "created_at",
}
connection.close()

export_section = DB.split("Future<Map<String, Object?>> exportAll()", 1)[1].split(
    "Future<void> importAll", 1
)[0]
assert "proactive_policy_events" not in export_section

for token in (
    "user_history",
    "internal",
    "memory",
    "self_experience",
    "awareness",
    "screen_observation",
    "inference",
    "public_web",
    "mcp",
):
    require(TELEMETRY, f"'{token}'", f"safe source {token}")
    require(SELECTION, f"'{token}'", f"source selection {token}")

require(SELECTION, "repeat_3_plus", "bounded repetition penalty")
require(SELECTION, "wait_24h_plus", "bounded wait boost")
require(SELECTION, ".clamp(0.0, 1.0)", "bounded adjusted score")
require(CORE, "includeThoughtAlternatives", "same-drive Thought expansion")
require(ENGINE, "includeThoughtAlternatives: true", "proactive expansion enabled")
require(ENGINE, "SELECTED_THOUGHT_DATA · DATA ONLY", "specific Thought data")
require(ENGINE, "webShareCandidateId != null", "web-only terminal outcome")
require(ENGINE, "publicWebSharing.markDeclined", "web WAIT decline")
require(ENGINE, "sourceAgnosticShareContract", "source-neutral prompt contract")
require(ENGINE, "reasonTag: 'frequency_ceiling'", "frequency block telemetry")
require(ENGINE, "reasonTag: 'missing_config'", "missing config telemetry")
require(ENGINE, "reasonTag: 'delivered'", "notification delivery telemetry")

require(BRIDGE, "resolveCurrentAppWithRetries", "Dart retry bridge")
for source, label in ((SYSTEM, "foreground bridge"), (BACKGROUND, "background bridge")):
    require(source, '"resolveCurrentAppWithRetries"', label)
    require(source, "Thread {", label + " non-blocking retry")
require(RESOLVER, "PROACTIVE_USAGE_STATS_MAX_AGE_MS", "proactive fallback window")
require(RESOLVER, "resolveCurrentForProactiveWithRetries", "isolated proactive resolver")
require(RESOLVER, "usageStatsMaxAgeMs.coerceIn", "bounded fallback window")
require(RESOLVER, "lastTimeUsed > invalidatedAt", "device boundary freshness")
require(REFRESHER, "reason == 'prompt_proactive'", "proactive-only retry")
require(REFRESHER, "resolved_after_retry", "retry success telemetry")
require(REFRESHER, "unresolved_after_retry", "retry failure telemetry")
assert "reason == 'prompt_user_turn'" not in REFRESHER

require(REPORT, "'proactivePolicy': proactivePolicy", "policy report section")
require(REPORT, "'currentAppRetryUsed'", "retry report field")
require(REPORT, "'proactivePolicyAppIdentityIncluded': false", "app identity privacy")
require(
    REPORT,
    "'proactivePolicyThoughtOrMessageTextIncluded': false",
    "Thought/message privacy",
)

require(
    WORKFLOW,
    "name: Build AI Companion v0.40.3+132 APK (Proactive Sharing Hotfix)",
    "workflow name",
)
require(WORKFLOW, "agent/v0403-proactive-sharing-tuning", "workflow branch")
require(
    WORKFLOW,
    "AI-Companion-v0.40.3-132-Proactive-Frequency-Hotfix-APK",
    "workflow artifact",
)

# Provider fallback behavior remains diagnostic-only in this version.
assert "deepseek-v4-flash-vision" not in ENGINE.lower()
require(WORKFLOW, "python3 tools/validate_v0402_provider_diagnostics.py", "v0.40.2 regression")

print("v0.40.3 proactive sharing tuning validation passed")
