#!/usr/bin/env python3
"""Static contracts for +222 true Stop and owned backup/restore freeze."""

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


require("pubspec.yaml", "version: 0.41.82+226")
require(
    "lib/core/ai/generation_cancellation.dart",
    "class GenerationSuspendedByRuntimeGateException",
    "generation_suspended_by_runtime_gate",
)
require(
    "lib/core/ai/deepseek_client.dart",
    "http.Client Function()? jsonClientFactory",
    "Future<bool> Function()? abortWhen",
    "cancellationToken.whenCancelled",
    "requestClient.close()",
    "GenerationSuspendedByRuntimeGateException",
)
require(
    "lib/core/ai/durable_generation_runner.dart",
    "final effectiveCancellation = GenerationCancellationToken()",
    "Timer.periodic",
    "latest?.status == 'cancelled_by_user'",
    "effectiveCancellation.cancel()",
    "error is GenerationSuspendedByRuntimeGateException",
    "cancellationFenceTimer.cancel()",
    "suspendGenerationJob",
)
require(
    "lib/features/chat/chat_controller.dart",
    "cancelCurrentGeneration",
    "db.cancelGenerationJobByUser(jobId)",
    "db.isLocalLeaseHeld('chat_turn_lease')",
    "停止请求已经写入，但旧回复连接尚未退出",
    "!await (db ?? AppDatabase.instance).brainWorkAllowed()",
)
require(
    "lib/background_main.dart",
    "abortWhen: () async => !await db.brainWorkAllowed()",
)
require(
    "lib/core/agent/agent_tool_runner.dart",
    "on GenerationSuspendedByRuntimeGateException",
    "suspend the whole turn",
)
require(
    "lib/core/database/app_database.dart",
    "Future<String> acquireTransferFreeze",
    "transfer_lock_owner",
    "Future<bool> ownsTransferFreeze",
    "Future<bool> releaseTransferFreeze",
    "if (owner != token) return false",
    "key == 'transfer_lock' && value != '1'",
    "if (owner.isNotEmpty) return",
)
require(
    "lib/features/transfer/transfer_page.dart",
    "purpose: 'backup_export'",
    "purpose: 'backup_restore'",
    "ownsTransferFreeze",
    "releaseTransferFreeze",
    "阻塞项：",
    "正在整理聊天、记忆与媒体并生成备份文件",
    "正在打开系统保存位置",
)
transfer = read("lib/features/transfer/transfer_page.dart")
backup_start = transfer.index("Future<void> _backupExport()")
backup_end = transfer.index("Future<void> _backupImport()", backup_start)
assert "inspectBundle(bundle.filePath)" not in transfer[backup_start:backup_end]
require(
    "lib/core/diagnostics/preflight_diagnostics.dart",
    "stateWriterLeases",
    "recovery_orchestrator_lease_until",
    "chat_turn_lease",
)
require(
    "test/stop_transfer_interlock_v04178_test.dart",
    "streaming provider wait closes immediately when Stop cancels the turn",
    "JSON provider wait closes immediately when Stop cancels the turn",
    "background provider wait stops when transfer freeze closes the gate",
    "durable Stop and transfer freeze use cross-runtime fences",
)
require(
    "docs/TEST_CHECKLIST.md",
    "v0.41.78+222 停止与备份互锁真机验收增量",
    "停止旧回复后立即发送新消息",
    "阻塞项",
)
require(
    ".github/workflows/build-apk.yml",
    "agent/v04182-cedar-state-machine-e2e",
    "AI-Companion-v0.41.82-226-Cedar-State-Machine-E2E-APK",
    "validate_v04178_stop_transfer_interlock.py",
)
require(
    "AI_Companion_当前总账.md",
    "v0.41.81+225",
    "停止与备份互锁",
    "transfer_lock_owner",
    "TRUE DEVICE PENDING",
)

print("v0.41.81+225 Stop/transfer interlock validation passed.")
