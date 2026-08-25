#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing {label}: {needle}")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
model = read("lib/core/models/autonomous_action.dart")
policy = read("lib/core/autonomy/autonomous_action_policy.dart")
coordinator = read("lib/core/autonomy/autonomous_action_coordinator.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
tests = read("test/autonomous_action_policy_v0347_test.dart")
workflow = read("../.github/workflows/build-apk.yml")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/pet/PetOverlayWindow.kt"
)

require(pubspec, "version: 0.34.7+72", "release version")
require(database, "static const int schemaVersion = 24;", "schema v24")
require(database, "CREATE TABLE IF NOT EXISTS autonomous_action_runs", "durable runs")
for column in (
    "dedupe_key TEXT NOT NULL UNIQUE",
    "state_generation INTEGER NOT NULL",
    "run_token TEXT NOT NULL DEFAULT ''",
    "desire_satisfied_at INTEGER",
    "budget_remaining INTEGER",
):
    require(database, column, f"action column {column}")
require(database, "id = ? AND status = ? AND run_token = ?", "run-token fencing")
require(database, "satisfyOnSuccess", "success-only Desire callback")
require(database, "successful && satisfyOnSuccess != null", "success-only satisfy gate")
require(database, "autonomousActionDiagnosticStats", "action diagnostics query")

for value in (
    "publicWeb",
    "screenObservation",
    "videoUnderstanding",
    "providerUnavailable",
    "budgetExhausted",
    "candidateStored",
    "observationStored",
):
    require(model, value, f"autonomous model {value}")

require(policy, "This policy never creates an intent", "Desire ownership boundary")
require(policy, "Proactive delivery retains its separate", "separate contact gate")
require(
    policy,
    "request.tool == AutonomousToolKind.screenObservation",
    "screen-only lock gate",
)
require(policy, "AutonomousGateReason.screenLocked", "lock screen decision")
require(policy, "AutonomousGateReason.budgetExhausted", "budget guard")
require(policy, "AutonomousGateReason.duplicate", "dedupe guard")
require(coordinator, "requestFromDesire", "Desire-sourced request bridge")
require(coordinator, "DesireIntent intent", "existing Desire Intent input")
require(coordinator, "sha256.convert", "non-plaintext dedupe key")
require(coordinator, "completeSuccess", "successful Outcome bridge")
require(coordinator, "intensity: 0.32", "light tool satisfaction")
require(coordinator, "completeWithoutSatisfaction", "failure/cancel path")

require(diagnostics, "'autonomousActions': autonomousActions", "diagnostic section")
for privacy_key in (
    "autonomousIntentReasonIncluded",
    "autonomousQueryOrUrlIncluded",
    "autonomousScreenOrWebContentIncluded",
):
    require(diagnostics, privacy_key, f"privacy marker {privacy_key}")

require(tests, "locked screen does not block quiet public web work", "lock/web test")
require(tests, "rolling budget exhaustion is a hard loop guard", "budget test")
require(tests, "unconnected provider is explicit", "provider test")

require(
    overlay,
    "cancelAutonomyPlayback(resetToIdle = true)",
    "v0.34.6 lock-resume guardrail",
)
require(workflow, "Build AI Companion v0.34.7+72 APK", "workflow title")
require(
    workflow,
    "python3 tools/validate_v0347_autonomous_action_foundation.py",
    "workflow validator invocation",
)
require(
    workflow,
    "AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK.apk",
    "release APK identity",
)

print("v0.34.7 autonomous action foundation validation passed")
