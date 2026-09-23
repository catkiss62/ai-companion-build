#!/usr/bin/env python3
"""Lock the v0.42.4 verified TTS profile and redacted tool activity UI."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent


def read(path: str) -> str:
    base = REPOSITORY if path.startswith((".github/", "AI_")) else ROOT
    return (base / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    models = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/BenchmarkModels.kt")
    engine = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/GenieBenchmarkEngine.kt")
    chinese = read("android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/ChineseFrontend.kt")
    runtime = read("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt")
    service = read("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsIsolatedService.kt")
    tts_service = read("lib/core/tts/tts_service.dart")
    settings = read("lib/features/chat/chat_quick_settings_pages.dart")
    database = read("lib/core/database/app_database.dart")
    tool_runner = read("lib/core/agent/agent_tool_runner.dart")
    chat = read("lib/features/chat/chat_page.dart")
    workflow = read(".github/workflows/build-apk.yml")
    ledger = read("AI_Companion_当前总账.md")

    require(
        any(version in read("pubspec.yaml") for version in (
            "version: 0.42.4+248", "version: 0.42.5+249",
        )),
        "version mismatch",
    )
    require("static const int schemaVersion = 61;" in database, "schema changed")
    for token in (
        "object VerifiedRuntimeConfig",
        "val AUTO_AFFINITY",
        "backend = BackendMode.CPU",
        "threads = 0",
        "interOpThreads = 1",
        "executionMode = GraphExecutionMode.SEQUENTIAL",
        "allowSpinning = true",
        'profileId = "auto_affinity_v084"',
    ):
        require(token in models, f"verified profile missing: {token}")
    for token in (
        "setIntraOpNumThreads(config.threads)",
        "setInterOpNumThreads(config.interOpThreads)",
        "setExecutionMode(OrtSession.SessionOptions.ExecutionMode.SEQUENTIAL)",
        'addConfigEntry("session.intra_op.allow_spinning", value)',
        'addConfigEntry("session.inter_op.allow_spinning", value)',
        "OrtSession.SessionOptions.OptLevel.ALL_OPT",
    ):
        require(token in engine, f"acoustic session factory mismatch: {token}")
        require(token in chinese or token == "OrtSession.SessionOptions.OptLevel.ALL_OPT", f"RoBERTa session mismatch: {token}")
    require("BackendMode.CPU -> setIntraOpNumThreads(config.threads)" in engine,
            "AUTO_AFFINITY intra-op zero is being coerced")
    require(runtime.count("VerifiedRuntimeConfig.AUTO_AFFINITY") >= 3,
            "the acoustic and Chinese paths do not share AUTO_AFFINITY")
    require("engine.unloadModels()" in runtime and "chinese?.configure(chineseConfig())" in runtime,
            "runtime profile switch does not rebuild all five sessions")
    require('put("runtimeProfile", runtime.runtimeProfileId)' in service,
            "native status omits runtime profile")
    require("tts_auto_affinity_enabled" in tts_service and "setAutoAffinity" in tts_service,
            "Dart profile persistence is missing")
    require("自动核亲和加速" in settings and "value: _ttsAutoAffinity" in settings,
            "settings toggle is missing")
    require("'tts_auto_affinity_enabled': '0'" in database,
            "auto-affinity must default off")

    for forbidden in (
        "dynamicBlockBase",
        "enableFtzDaz",
        "reuseDecoderInputMap",
        "disableMemoryPattern",
        "sustainedPerformanceMode",
    ):
        require(forbidden not in models and forbidden not in runtime,
                f"failed experiment leaked into production config: {forbidden}")

    require("recentAgentToolOutcomeRecords" in database, "tool history projection missing")
    projection = database[database.index("Future<List<AgentToolOutcomeRecord>> recentAgentToolOutcomeRecords"):]
    projection = projection[:projection.index("Future<bool> agentToolOutcomeEventExists")]
    for forbidden in (
        "reason_tag", "outcome_kind", "error_code", "prompt_data",
        "submitted_arguments", "query_text", "source_url",
    ):
        require(forbidden not in projection.lower(), f"private tool field exposed: {forbidden}")
    require("AgentToolStatus.stopped" in tool_runner and "执行已由用户停止" in tool_runner,
            "user-stopped tool outcome is missing")
    for token in (
        "class _LiveToolActivityPanel",
        "class _ToolActivityHistory",
        "initiallyExpanded: true",
        "工具活动",
        "已停止",
    ):
        require(token in chat, f"tool activity UI missing: {token}")
    require("agent/v04204-tts-affinity-tool-activity" in workflow,
            "workflow branch trigger missing")
    require(
        any(version in workflow for version in ("v0.42.4+248", "v0.42.5+249")),
        "workflow identity mismatch",
    )
    for token in ("TTS 自动核亲和与全工具活动展示", "后续冻结分析：双人格", "后续冻结分析：命运之轮"):
        require(token in ledger, f"ledger analysis missing: {token}")
    require(
        "tools/validate_v04204_tts_affinity_tool_activity.py"
        in read("tools/validation_suite.txt"),
        "validator is not registered",
    )

    print("v0.42.4 TTS auto-affinity and tool activity contract passed")


if __name__ == "__main__":
    main()
