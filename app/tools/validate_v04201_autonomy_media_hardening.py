#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
    dawn = read("lib/core/desire/proactive_dawn_gate_policy.dart")
    proactive = read("lib/core/desire/proactive_engine.dart")
    arcade = read("lib/core/mcp/cedar_toy_arcade_skill.dart")
    planner = read("lib/core/agent/agent_tool_planner.dart")
    runner = read("lib/core/agent/agent_tool_runner.dart")
    autonomy = read("lib/core/mcp/cedar_toy_autonomy_engine.dart")
    bookkeeper = read("lib/core/mcp/cedar_play_outcome_bookkeeper.dart")
    vision_settings = read("lib/features/settings/settings_category_pages.dart")
    vision_error = read("lib/core/diagnostics/vision_failure_presentation.dart")
    tts = read("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt")
    tts_guard = read("android/app/src/main/kotlin/com/aicompanion/localfirst/ReferenceAudioEchoGuard.kt")
    diagnostics = read("android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt")

    require(
        any(
            version in read("pubspec.yaml")
            for version in (
                "version: 0.42.2+246", "version: 0.42.3+247",
                "version: 0.42.4+248", "version: 0.42.5+249", "version: 0.42.6+250",
            )
        ),
        "version mismatch",
    )
    require("agent/v04201-autonomy-media-hardening" in workflow, "branch trigger missing")
    require("ProactiveNightContactCapPolicy" in dawn, "night contact cap missing")
    require("deliveredProactiveCountAfter" in proactive, "night cap is not wired before generation")
    require("night_contact_ceiling" in proactive, "night cap outcome is not diagnosed")
    require("describesUserOnlyPlay" in arcade, "first-person game statement boundary missing")
    require("CedarToyArcadeSkill.isRelevant(text)" in planner, "planner bypasses Cedar semantic boundary")
    require("CedarPlayOutcomeBookkeeper(db).record" in runner, "foreground Cedar result is not booked")
    require("CedarPlayOutcomeBookkeeper(db).record" in autonomy, "autonomous Cedar result is not booked")
    require("action: 'play_game'" in bookkeeper, "real play satisfaction ledger write missing")
    require("视觉连接测试" in vision_settings, "vision configuration test control missing")
    require("401/403" in vision_error, "vision authorization failure is not explicit")
    require("referenceEchoGuard.assess" in tts, "TTS acoustic echo guard is not wired")
    require("check(!referenceEchoSuspected)" in tts, "suspected reference echo is still playable")
    require("reference_echo_guard.json" in tts_guard, "compact reference signature asset missing")
    require("referenceEchoSuspected" in diagnostics, "TTS echo evidence is stripped from diagnostics")
    require("case.pop('reference_audio', None)" in workflow, "reference WAV removal was weakened")
    require("reference_features" in workflow, "CI does not derive compact echo signatures")
    require("manifest['reference_echo_guard']" in workflow, "echo signature is not retained in APK")

    print("v0.42.1 autonomy, vision and TTS media hardening contract remains preserved")


if __name__ == "__main__":
    main()
