#!/usr/bin/env python3
"""Static contract checks for v0.34.4 overlay recovery and redacted diagnostics."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT.parent / ".github" / "workflows" / "build-apk.yml"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
)
database = read("lib/core/database/app_database.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
ledger = read("docs/PROJECT_TASK_LEDGER.md")
workflow = WORKFLOW.read_text(encoding="utf-8")

require(overlay, [
    "WindowManager.addView() returns before isAttachedToWindow becomes",
    "mainHandler.postDelayed({",
    "updateOverlayTouchHealth()",
    "CompanionRuntimeState.noteOverlayCoverRecoveryResult(",
    "}, INPUT_RECOVERY_SETTLE_MS)",
    "CompanionRuntimeState.noteTaskRemoved(this)",
    "CompanionRuntimeState.noteTrimMemory(this, level)",
    "CompanionRuntimeState.noteBackgroundBrainReady(this)",
    "CompanionRuntimeState.noteBackgroundBrainFailure(",
], "settled overlay recovery and lifecycle telemetry")

recovery_start = overlay.index("private fun scheduleCoverRecovery(")
recovery_end = overlay.index("private fun scheduleCoverRecoveryRetry(", recovery_start)
recovery = overlay[recovery_start:recovery_end]
ensure = recovery.index("ensureOverlayHealth(")
settle = recovery.index("mainHandler.postDelayed({", ensure)
health = recovery.index("val healthy =", settle)
result = recovery.index("noteOverlayCoverRecoveryResult(", health)
assert ensure < settle < health < result

require(runtime, [
    'KEY_SERVICE_ACTIVE_MARKER = "service_active_marker"',
    'KEY_SERVICE_UNCLEAN_RESTART_COUNT = "service_unclean_restart_count"',
    "possibleUncleanRestartCount",
    "lastPossibleUncleanRestartAt",
    "processAgeMs",
    "serviceUptimeMs",
    "backgroundBrainFailureCount",
], "redacted background survival telemetry")

require(database, [
    "Future<Map<String, Object?>> somaticDiagnosticStats()",
    "latestUserEvaluation",
    "latestAssistantEvaluation",
    "no_completed_action_match",
    "eventNarrativeIncluded",
    "messageBodiesIncluded",
], "directional Somatic observability")

require(diagnostics, [
    "'somaticObservability': somaticDiagnostics",
    "'somatic_ai_to_self'",
    "'transientSystemCoverRecovery': transientCoverRecovery",
    "'possibleRecoveryLoop': possibleRecoveryLoop",
    "'selfHealsPerCoverSession'",
    "'backgroundContinuity'",
    "'possibleUncleanRestartCount'",
    "'batteryOptimizationIgnored'",
    "'contentsIncluded': false",
], "redacted diagnostic report")

for forbidden in (
    "SELECT content FROM messages",
    "SELECT narrative FROM somatic_events",
    "SELECT action FROM somatic_events",
    "SELECT part FROM somatic_events",
):
    assert forbidden not in database

require(ledger, [
    "每小时最多 6 次",
    "锁屏只暂停屏幕识图，不暂停自主联网",
    "电池优化白名单",
    "X / Telegram",
], "approved autonomy roadmap")

require(workflow, [
    "python3 tools/validate_v0344_overlay_recovery_diagnostics.py",
], "workflow keeps v0.34.4 regression contract")

print("v0.34.4 settled overlay recovery, background survival and Somatic diagnostics validated")
