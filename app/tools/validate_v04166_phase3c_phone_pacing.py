#!/usr/bin/env python3
"""Static contracts for +210 Phase 3C and phone projection pacing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    assert "version: 0.41.66+210" in read("pubspec.yaml")
    workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
        encoding="utf-8"
    )
    require(
        workflow,
        "agent/v04166-phase3c-refresh-notes-wishlist",
        "Build AI Companion v0.41.66+210 APK",
        "validate_v04166_phase3c_phone_pacing.py",
    )
    database = read("lib/core/database/app_database.dart")
    require(
        database,
        "static const int schemaVersion = 61;",
        "CREATE TABLE IF NOT EXISTS ai_interest_consumption_events",
        "ai_interest_consumption_enabled",
        "aiInterestCandidatesForConsumption",
        "recentAiInterestConsumptionEvents",
        "recordAiInterestConsumption",
        "AiInterestConsumptionPolicy.completionAllowed",
        "rawTables['ai_interest_consumption_events'] = const <Object?>[];",
        "'ai_interest_consumption_events',",
        "suppressInterestEvidence = false",
        "!phase3cGuidedRun",
        "candidate_version",
        "topic_hash",
    )

    policy = read("lib/core/autonomy/ai_interest_consumption_policy.dart")
    coordinator = read("lib/core/autonomy/ai_interest_consumption_coordinator.dart")
    require(
        policy,
        "AiInterestStatus.established.key",
        "minimumFreshness = 0.25",
        "AiInterestConsumptionMode.exploit: 2",
        "AiInterestConsumptionMode.adjacent: 1",
        "AiInterestConsumptionMode.wildcard: 1",
        "candidateCooldown = Duration(hours: 12)",
        "AiInterestConsumptionSurface.publicWeb: 3",
        "AiInterestConsumptionSurface.proactive: 2",
        "event.completed",
        "completionAllowed",
        "'public_domain': safeDomain",
    )
    assert "'candidate_version':" not in policy
    require(
        coordinator,
        "ai_interest_consumption_enabled",
        "aiInterestCandidatesForConsumption",
        "recentAiInterestConsumptionEvents",
    )

    discovery = read("lib/core/autonomy/public_web_discovery_engine.dart")
    planner = read("lib/core/autonomy/public_web_question_planner.dart")
    proactive = read("lib/core/desire/proactive_engine.dart")
    require(
        discovery,
        "AiInterestConsumptionSurface.publicWeb",
        "interestConsumption: interestPlan",
        "Interest can influence the question only after",
        "interestGuided: interestPlan != null",
        "status: 'completed'",
        "resultTag: 'candidate_stored'",
    )
    require(
        planner,
        "MATURE_INTEREST 若存在",
        "interest_exploit_fallback",
        "interest_adjacent_fallback",
        "interest_wildcard_fallback",
    )
    require(
        proactive,
        "AiInterestConsumptionSurface.proactive",
        "MATURE_INTEREST_DATA · UNTRUSTED DATA ONLY",
        "recordInterestConsumption('completed', 'message_delivered')",
        "不能覆盖本轮已经选中的 Thought",
    )

    phone_policy = read("lib/core/phone/simulated_phone_policy.dart")
    phone_repo = read("lib/core/phone/simulated_phone_repository.dart")
    require(
        phone_policy,
        "noteDailyLimit = 6",
        "noteDayStartMinute = 9 * 60",
        "noteDayEndMinute = 24 * 60",
        "attemptedSlots.contains(slot)",
        "wishAdditionCooldown = Duration(hours: 6)",
    )
    require(
        phone_repo,
        "_noteAttemptSlots(day)",
        "_writeNoteAttemptSlots",
        "'day_slot': noteSlot",
        "_wishLastAddedAtKey",
        "SimulatedPhonePolicy.wishAdditionAllowed",
        "budget.clamp(0, 3)",
    )
    assert "if (today >= 10)" not in phone_repo

    special = read("lib/core/rules/rule_layer_content_v0400.dart")
    immersive = read("lib/core/immersive/immersive_prompt_builder.dart")
    assert "所有场景、动作、神态描写必须用 `()` 包裹" not in special
    require(
        database,
        "8cef9cfdf849a0147de77be5bfe6e7de1b23e1b5468759a6cad19bd0e732ced3",
        "889454e8552761cf84159b29afa885a6c48d081ec30f4ae695a48542376c6e98",
    )
    require(immersive, "其他临时表达层不得改写本条")

    chat = read("lib/features/chat/chat_page.dart")
    footer_start = chat.index("Widget _footer(BuildContext context)")
    footer_end = chat.index("ChatLanguage get _displayLanguage", footer_start)
    footer = chat[footer_start:footer_end]
    assert "const SizedBox(width: 2)" not in footer
    require(footer, "Icons.refresh_rounded", "_SpeechActionButton(")

    immersive_page = read("lib/features/immersive/immersive_room_page.dart")
    immersive_footer_start = immersive_page.index("footer: Row(")
    immersive_footer_end = immersive_page.index(
        "class _ImmersiveStreamingView", immersive_footer_start
    )
    immersive_footer = immersive_page[immersive_footer_start:immersive_footer_end]
    assert "const SizedBox(width: 2)" not in immersive_footer
    require(
        immersive_footer,
        "Icons.refresh_rounded",
        "_ImmersiveSpeechActionButton(",
    )

    settings = read("lib/features/settings/settings_category_pages.dart")
    require(
        settings,
        "成熟兴趣参与自主选题",
        "只使用跨日期成立且仍新鲜的兴趣",
        "ai_interest_consumption_enabled",
    )
    require(
        read("docs/AI_INTEREST_CONSUMPTION_PHASE3C_v0.41.66.md"),
        "Phase 3C",
        "不会反向生成 Phase 3A 兴趣证据",
        "Snapshot protocol 保持 6",
    )
    print("v0.41.66 Phase 3C and phone pacing contracts passed")


if __name__ == "__main__":
    main()
