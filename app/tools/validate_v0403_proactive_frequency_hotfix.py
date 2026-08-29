from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text()
ENGINE = (ROOT / "lib/core/desire/proactive_engine.dart").read_text()
FREQUENCY = (ROOT / "lib/core/models/proactive_frequency.dart").read_text()
MAINTENANCE = (ROOT / "lib/core/maintenance/long_running_maintenance_engine.dart").read_text()
PRUNE_POLICY = (ROOT / "lib/core/models/maintenance_prune_policy.dart").read_text()
CHAT = (ROOT / "lib/features/chat/chat_page.dart").read_text()
REPORT = (ROOT / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()
PUBSPEC = (ROOT / "pubspec.yaml").read_text()
WORKFLOW = (ROOT.parent / ".github/workflows/build-apk.yml").read_text()


def require(text: str, token: str, label: str) -> None:
    assert token in text, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.40.3+132", "hotfix version")
require(DB, "static const int schemaVersion = 40;", "schema remains 40")

for token in (
    "ProactiveFrequencyMode.quiet => 8",
    "ProactiveFrequencyMode.natural => 16",
    "ProactiveFrequencyMode.frequent => 24",
    "ProactiveFrequencyMode.quiet => 2",
    "ProactiveFrequencyMode.natural => 3",
    "ProactiveFrequencyMode.frequent => 4",
    "defaultMode = ProactiveFrequencyMode.natural",
):
    require(FREQUENCY, token, "frequency contract")

require(ENGINE, "frequencyMode.dayLimit", "runtime daily policy")
require(ENGINE, "frequencyMode.twoHourLimit", "runtime short-window policy")
assert "sentToday >= 8" not in ENGINE
assert "sentLastTwoHours >= 2" not in ENGINE

require(DB, "'mode': proactiveFrequency.key", "diagnostic mode")
require(DB, "proactiveFrequency.dayLimit", "diagnostic daily limit")
require(DB, "proactiveFrequency.twoHourLimit", "diagnostic short-window limit")

for table in ("provider_health_events", "proactive_policy_events"):
    require(PRUNE_POLICY, f"'{table}'", f"{table} allowlist")
    require(MAINTENANCE, f"table: '{table}'", f"{table} cleanup")

require(CHAT, "labelText: '主动频率'", "sidebar frequency selector")
require(CHAT, "ProactiveFrequencyMode.values", "three sidebar choices")
require(CHAT, "她仍会按自己的欲望和时机决定", "non-target clarification")

require(REPORT, "id: 'background_recovery'", "background recovery check")
require(REPORT, "'runtimeErrorTextIncluded': false", "runtime error privacy")
require(REPORT, "maintenanceErrorCategory", "redacted maintenance category")
assert "last_long_running_maintenance_error': await" not in REPORT
assert "recovery_orchestrator_last_error': await" not in REPORT

require(
    WORKFLOW,
    "AI-Companion-v0.40.3-132-Proactive-Frequency-Hotfix-APK",
    "hotfix artifact",
)
require(
    WORKFLOW,
    "python3 tools/validate_v0403_proactive_frequency_hotfix.py",
    "hotfix validator",
)

print("v0.40.3 proactive frequency hotfix validation passed")
