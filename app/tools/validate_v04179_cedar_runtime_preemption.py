#!/usr/bin/env python3
"""Static cross-module contracts for +223 Cedar runtime preemption."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    base = REPO if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    missing = [token for token in tokens if token not in text]
    assert not missing, f"{path}: missing {missing}"


require("pubspec.yaml", "version: 0.41.81+225")
require(
    "lib/core/ai/deepseek_client.dart",
    "Duration requestTimeout = const Duration(seconds: 120)",
    ".timeout(requestTimeout)",
    "cancellationToken.whenCancelled",
)
require(
    "lib/core/database/app_database.dart",
    "Future<bool> setSettingsAtomically",
    "String? guardKey",
    "if (current != expectedGuardValue) return false",
    "cancel-foreground-chat-",
    "cancel-transfer-",
)
require(
    "lib/core/mcp/cedar_toy_activity.dart",
    "executionFenceSettingKey",
    "required String executionId",
    "Future<void> cancelExecution",
    "Future<void> suspendForSwitch",
    "Future<void> resumeAfterSwitchIfNeeded",
    "cancel-stale-",
    "executionId: executionId",
)
require(
    "lib/core/mcp/cedar_toy_autonomy_engine.dart",
    "class CedarContinuationGatePolicy",
    "DesireCorePolicy.circadianFatigueFloor",
    "DesireCorePolicy.fatigueRestScore",
    "strongestGameThought",
    "class _CedarExecutionScope",
    "const Duration(milliseconds: 200)",
    "db.isLocalLeaseHeld('chat_turn_lease')",
    "store.isExecutionCurrent(executionId)",
    "requestTimeout: const Duration(seconds: 30)",
    "cedar_toy_action_lease_until",
    "preempted_",
)
autonomy = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
retry_start = autonomy.index("static bool isRetryable")
retry_end = autonomy.index("static String errorCategory", retry_start)
retry_policy = autonomy[retry_start:retry_end]
assert "error is! TimeoutException" in retry_policy
assert "FinalReplyFailurePolicy.isTransient" in retry_policy
require(
    "lib/core/maintenance/recovery_orchestrator.dart",
    "_continueCedarOutsideLease",
    "await db.releaseLocalLease(_orchestratorLease)",
    "await proactive.continueCedarActivityIfDue(now: now)",
)
require(
    "lib/features/settings/cedar_toy_settings_page.dart",
    "_setRuntimeSwitch",
    "store.suspendForSwitch()",
    "store.resumeAfterSwitchIfNeeded()",
)
require(
    "lib/features/transfer/transfer_page.dart",
    "'cedar_toy_action_lease_until'",
)
require(
    "lib/core/sync/snapshot_service.dart",
    "'cedar_toy_action_lease_until': '0'",
    "'cedar_toy_execution_fence_v1': 'restored'",
)
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "'cedar_toy_action_lease_until'",
    "lastPreemptReason",
    "continuationGate",
)
require(
    "test/cedar_runtime_preemption_v04179_test.dart",
    "late-night fatigue defers a committed unattended game",
    "Cedar JSON cancellation closes a blocked planner immediately",
    "a provider timeout is not retried inside the same Cedar cycle",
    "execution identity survives state serialization",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.79+223 Cedar 运行时抢占、开关与夜间节律真机验收增量",
    "rest_wins",
    "cedar_toy_action_lease_until",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04181-cedar-background-agent-tools",
    "AI-Companion-v0.41.81-225-Cedar-Background-Agent-Tools-APK",
    "validate_v04179_cedar_runtime_preemption.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "Cedar 运行时抢占、开关与夜间节律",
    "TRUE DEVICE PENDING",
)

print("v0.41.81+225 Cedar runtime-preemption validation passed.")
