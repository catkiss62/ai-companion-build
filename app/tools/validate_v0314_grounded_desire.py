#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def digest(relative: str) -> str:
    return hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()


def main() -> int:
    version = re.search(
        r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$",
        read("pubspec.yaml"),
        re.MULTILINE,
    )
    assert version is not None
    assert tuple(map(int, version.groups())) >= (0, 31, 4, 46)
    db = read("lib/core/database/app_database.dart")
    schema = re.search(r"static const int schemaVersion = (\d+);", db)
    assert schema and int(schema.group(1)) >= 20
    for token in [
        "CREATE TABLE messages_v20",
        "INSERT INTO messages_v20",
        "DROP TABLE messages",
        "ALTER TABLE messages_v20 RENAME TO messages",
        "row.remove('provider_reasoning')",
        "row.remove('companion_voice')",
    ]:
        assert token in db, token

    retired_path = ROOT / "lib/core/ai/companion_voice_protocol.dart"
    retired_test = ROOT / "test/companion_voice_protocol_v0312_test.dart"
    assert not retired_path.exists()
    assert not retired_test.exists()
    runtime_text = "\n".join(
        read(relative)
        for relative in [
            "lib/core/ai/durable_generation_runner.dart",
            "lib/core/desire/proactive_engine.dart",
            "lib/features/chat/chat_controller.dart",
            "lib/features/chat/chat_page.dart",
            "lib/features/settings/settings_page.dart",
            "lib/widgets/reasoning_panel.dart",
            "lib/core/models/chat_message.dart",
            "lib/core/diagnostics/preflight_diagnostics.dart",
        ]
    )
    for forbidden in [
        "CompanionVoiceProtocol", "companion_voice_preview",
        "companion_voice_final", "streamingCompanionVoice",
        "providerReasoning", "伴侣式内心与回应",
    ]:
        assert forbidden not in runtime_text, forbidden

    runner = read("lib/core/ai/durable_generation_runner.dart")
    assert "onDelta?.call(delta);" in runner
    assert "reasoningContent: generated.reasoning" in runner
    assert "content: generated.content" in runner

    policy = read("lib/core/desire/desire_core_policy.dart")
    for token in [
        "baselineHalfLifeMinutes = 120.0 * 24.0 * 60.0",
        "currentBaseline +",
        "(anchor - currentBaseline) * pullback",
        "drive == DriveKey.libido && !intimacyAllowed",
        "action: 'wildcard_share'",
        "wildcardCooldown = Duration(hours: 6)",
        "normalStrong",
        "tension >= 0.52",
    ]:
        assert token in policy, token
    for forbidden in ["AppDatabase", "DateTime.now()", "Random(", "dart:io"]:
        assert forbidden not in policy, forbidden

    prompt = read("lib/core/ai/prompt_builder.dart")
    for token in [
        "长期性格倾向：",
        "THOUGHT_DATA source=",
        "不注入 Thought 原文",
        "_temperamentSummary",
        "d != DriveKey.libido || intimacySessionActive",
    ]:
        assert token in prompt, token
    assert "${t.text}" not in prompt
    assert ": ${t.text}" not in prompt

    proactive = read("lib/core/desire/proactive_engine.dart")
    for token in [
        "intimacyAllowed: intimacyAllowed",
        "这里只提供结构化线索，不注入 Thought 原文",
        "ProactiveReasoningGroundingGuard.evaluate(",
        "REALITY GROUNDING CORRECTION · ONE RETRY",
        "await desireEngine.satisfyIntent(",
    ]:
        assert token in proactive, token
    assert "CompanionVoice" not in proactive

    tests = read("test/desire_core_policy_v031_test.dart")
    for token in [
        "libido cannot become an action outside an explicit intimacy session",
        "learned temperament slowly pulls back toward its original anchor",
        "wildcard becomes a real pressure-release action and respects cooldown",
        "1000 deterministic ticks stay bounded and do not self-excite",
    ]:
        assert token in tests, token

    # TTS/runtime/accessibility remain byte-frozen. Overlay UI may evolve, but
    # its HyperOS input-recovery contract remains guarded below.
    frozen = {
        "lib/core/tts/tts_sentence_segmenter.dart":
            "8ee58af4cfab2e03bf3d80f527a777bab9a3790d75370ffe0760dfc4fe8906d8",
        "android/app/src/main/jniLibs/arm64-v8a/libbertvits2.so":
            "a599d482539fdbe01ccd82a9c688d0dce574c19dd681b15fd580185890e65792",
        "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt":
            "b29ca1b48de73508bb393c71c63c1165a65649ccabc1fe712a3aaef7b18a6e2a",
        "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt":
            "663f11b090ca543fbd7bceac68793781d60246fa2c30e31d5337db82eb618a03",
    }
    for relative, expected in frozen.items():
        assert digest(relative) == expected, relative

    overlay = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
    )
    for token in [
        "inputRecoveryInProgress",
        "CompanionRuntimeState.setOverlayRecoveryInProgress(true)",
        "COVER_RECOVERY_MAX_ATTEMPTS = 3",
        "window_visibility_suppressed",
        "window_visibility_restored",
        "rebuildInputChannel = CompanionRuntimeState.consumeOverlayInputSuspect()",
    ]:
        assert token in overlay, token

    for relative in ["docs/HANDOFF.md", "docs/PROJECT_TASK_LEDGER.md"]:
        body = read(relative)
        assert "v0.31.4+46" in body or "v0.31.4" in body
        assert "schema v20" in body
        assert "wildcard_share" in body

    print("v0.31.4 Grounded Desire Growth static validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
