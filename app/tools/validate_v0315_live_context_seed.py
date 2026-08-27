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
    assert tuple(map(int, version.groups())) >= (0, 31, 5, 47)
    database = read("lib/core/database/app_database.dart")
    schema = re.search(r"static const int schemaVersion = (\d+);", database)
    assert schema and int(schema.group(1)) >= 20

    refresher = read("lib/core/perception/current_device_context_refresher.dart")
    for token in [
        "class CurrentDeviceContextRefresher",
        "await android.getPerceptionState()",
        "await android.getRecentUsage(minutes: 90)",
        "await db.syncAwarenessObservations(",
        "current_context_last_refresh_reason",
        "current_context_current_activity",
        "if (!await db.brainWorkAllowed()) return null;",
    ]:
        assert token in refresher, token
    for forbidden in [
        "applyExperience(",
        "feedThought(",
        "PresenceIntelligence",
        "streamChat(",
        "insertPerceptionSnapshot(",
    ]:
        assert forbidden not in refresher, forbidden

    prompt = read("lib/core/ai/prompt_builder.dart")
    for token in [
        "CurrentDeviceContextRefresher(",
        "prompt_proactive",
        "prompt_user_turn",
        "用户是成年男性",
        "男朋友与长期恋爱对象",
    ]:
        assert token in prompt, token
    assert prompt.index("CurrentDeviceContextRefresher(") < prompt.index(
        "final awareness = await db.activeAwarenessObservations"
    )

    engine = read("lib/core/perception/perception_engine.dart")
    assert "contextRefresher.refresh(" in engine
    assert "_integrateIntoInnerState(" in engine
    assert engine.index("contextRefresher.refresh(") < engine.index(
        "_integrateIntoInnerState("
    )

    diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
    for token in [
        "'currentContext': {",
        "'available':",
        "'lastRefreshReason':",
        "'currentActivityClass':",
        "'rawPackageOrTextIncluded': false",
        "'desireAdvancedByRefresh': false",
    ]:
        assert token in diagnostics, token

    defaults = read("lib/core/rules/rule_layer_defaults.dart")
    for token in [
        "RuleLayerDefault('01_relationship'",
        "用户是成年男性",
        "不是服务者、客服或无条件服从者",
        "RuleLayerDefault('03_personality_seed'",
        "可以不同意、拒绝、纠正、追问、保留意见",
        "可以真实地不高兴、吃醋、恼火或暂时冷一点",
        "这只是性格种子，不是不可改变的人设卡",
    ]:
        assert token in defaults, token
    relationship_start = defaults.index("RuleLayerDefault('01_relationship'")
    daily_start = defaults.index("RuleLayerDefault('02_daily'")
    assert "locked: true" in defaults[relationship_start:daily_start]
    seed_start = defaults.index("RuleLayerDefault('03_personality_seed'")
    intimacy_start = defaults.index("RuleLayerDefault('04_intimacy_core'")
    assert "locked: false" in defaults[seed_start:intimacy_start]

    service = read("lib/core/rules/rule_layer_service.dart")
    assert "if (!layer.enabled && !layer.locked) continue;" in service
    page = read("lib/features/settings/rule_layers_page.dart")
    assert "layer.enabled || layer.locked" in page
    assert "onChanged: layer.locked" in page
    assert any(
        token in page
        for token in (
            "初始人格种子可以编辑、关闭",
            "初始性格种子仍可单独编辑、关闭和还原",
        )
    )

    rule_test = read("test/rule_layer_defaults_test.dart")
    for token in [
        "expectedKeys",
        "'01_relationship'",
        "'03_personality_seed'",
        "expect(defaultRuleLayers.length, expectedKeys.length)",
        "expect(byKey['03_personality_seed']!.locked, isFalse)",
    ]:
        assert token in rule_test, token
    assert "expect(defaultRuleLayers.length, 6)" not in rule_test

    # Upgrade-safe INSERT OR IGNORE keeps all user-edited existing layers and
    # only adds the two new keys on the first +47 launch.
    seed_sql = database[database.index("Future<void> _seedRuleLayers"):]
    assert "ConflictAlgorithm.ignore" in seed_sql

    # Historical baselines plus the explicitly audited v0.39.5 TTS upgrade.
    # The current version-specific validator owns the new behavior contract.
    frozen = {
        "lib/core/tts/tts_sentence_segmenter.dart":
            "e81eddb131e6ba905c86bf37fa0c94edb0aa6b1e519bfb8e68670b15c028436b",
        "android/app/src/main/jniLibs/arm64-v8a/libbertvits2.so":
            "a6f11da0df792a82820b833f1b6951078179d16c4e15dd8a6abc18d52d227f08",
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

    # Keep the stable release checklist assertion; mutable handoff/status ledgers
    # are governed by the evergreen root ledger and may be retired.
    body = read("docs/TEST_CHECKLIST.md")
    assert "v0.31.5" in body
    assert "schema v20" in body
    assert "CurrentDeviceContextRefresher" in read(
        "docs/PROACTIVE_GROUNDING_v0.31.1.md"
    )

    print("v0.31.5 Live Context & Self Seed static validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
