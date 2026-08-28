from pathlib import Path
import sqlite3


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text()
HEALTH = (ROOT / "lib/core/diagnostics/provider_health.dart").read_text()
REPORT = (ROOT / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()
WEB = (ROOT / "lib/core/autonomy/public_web_discovery_engine.dart").read_text()
TOOLS = (ROOT / "lib/core/agent/agent_tool_runner.dart").read_text()
CHAT = (ROOT / "lib/features/chat/chat_controller.dart").read_text()
ALBUM = (ROOT / "lib/core/phone/companion_album_discovery_engine.dart").read_text()
PUBSPEC = (ROOT / "pubspec.yaml").read_text()
WORKFLOW = (ROOT.parent / ".github/workflows/build-apk.yml").read_text()


def require(text: str, token: str, label: str) -> None:
    assert token in text, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.40.2+130", "app version")
require(DB, "static const int schemaVersion = 39;", "schema version")
require(DB, "if (oldVersion < 39)", "v39 migration")
require(DB, "CREATE TABLE IF NOT EXISTS provider_health_events", "health table")
require(DB, "LIMIT 500", "bounded health rows")
require(DB, "Duration(days: 14)", "bounded health age")

table = DB.split("CREATE TABLE IF NOT EXISTS provider_health_events", 1)[1].split("''');", 1)[0]
for forbidden in (
    "query",
    "url",
    "image_path",
    "image_bytes",
    "caption",
    "summary",
    "raw_error",
    "error_detail",
    "candidate_id",
):
    assert forbidden not in table, f"sensitive health column found: {forbidden}"

connection = sqlite3.connect(":memory:")
connection.execute("CREATE TABLE provider_health_events" + table)
columns = {row[1] for row in connection.execute("PRAGMA table_info(provider_health_events)")}
assert "primary_error_category" in columns
assert "fallback_error_category" in columns
assert "created_at" in columns
connection.close()

export_section = DB.split("Future<Map<String, Object?>> exportAll()", 1)[1].split(
    "Future<void> importAll", 1
)[0]
assert "provider_health_events" not in export_section

for source, label in ((WEB, "autonomous search"), (TOOLS, "user-turn search")):
    require(source, "ProviderHealth.webSearchEvent", label)
    require(source, "ProviderHealth.webCompactionEvent", label + " compaction")

require(CHAT, "context: 'chat_image'", "chat vision telemetry")
require(ALBUM, "context: 'album_discovery'", "album telemetry")
require(ALBUM, "primaryProvider: 'qwen_vision'", "Qwen remains album vision provider")
assert "deepseek-v4-flash-vision" not in ALBUM.lower()
assert "deepseek-v4-flash-vision" not in CHAT.lower()

require(REPORT, "'providerHealth': providerHealth", "health report section")
require(REPORT, "'providerHealthRawErrorIncluded': false", "raw error privacy")
require(REPORT, "'lastErrorCategory'", "categorized legacy error")
assert "'lastError':\n              await db.getSetting('agnes_compaction_last_error')" not in REPORT
require(HEALTH, "safeErrorCategory", "category whitelist")
require(HEALTH, "safeProvider", "provider whitelist")
require(WORKFLOW, "name: Build AI Companion v0.40.2+130 APK (Provider Diagnostics)", "workflow name")
require(WORKFLOW, "agent/v0402-provider-diagnostics", "workflow branch")
require(WORKFLOW, "AI-Companion-v0.40.2-130-Provider-Diagnostics-APK", "workflow artifact")

print("v0.40.2 provider diagnostics validation passed")
