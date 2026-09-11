#!/usr/bin/env python3
"""Static contracts for +209 refresh, error, rules, media and phone fixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    assert any(
        version in read("pubspec.yaml")
        for version in ("version: 0.41.65+209", "version: 0.41.66+210")
    )
    assert any(
        label in read("lib/core/agent/agent_self_reader.dart")
        for label in (
            "static const buildLabel = 'v0.41.65+209';",
            "static const buildLabel = 'v0.41.66+210';",
        )
    )

    app = read("lib/app.dart")
    chat_page = read("lib/features/chat/chat_page.dart")
    more = read("lib/features/more/companion_more_page.dart")
    require(app, "void _openMore()", "onOpenMore: _openMore")
    require(
        chat_page,
        "subtitle: '浏览全部功能分类。'",
        "widget.onOpenMore?.call();",
        "回复已截断，仍确认保留？",
        "保留这段回复",
        "_confirmRegenerateLatestReply",
    )
    assert "pushNamed('/settings')" not in chat_page
    require(more, "按功能查找陪伴、关系、能力、手机感知与数据设置。")
    assert any(
        label in more
        for label in (
            "AI Companion · v0.41.65+209",
            "AI Companion · v0.41.66+210",
        )
    )
    assert "先按稳定职责分开入口" not in more
    assert "这次不换皮肤" not in more

    database = read("lib/core/database/app_database.dart")
    chat_controller = read("lib/features/chat/chat_controller.dart")
    immersive_repo = read("lib/core/immersive/immersive_room_repository.dart")
    immersive_controller = read("lib/core/immersive/immersive_room_controller.dart")
    require(
        database,
        "restartLatestCompletedReply",
        "user_regenerated_completed_reply",
        "message_ref_count - 1",
    )
    require(chat_controller, "regenerateLatestReply", "restartLatestCompletedReply")
    require(
        immersive_repo,
        "removeLatestAssistantForRegeneration",
        "summarized_message_count",
    )
    require(immersive_controller, "regenerateLatestReply", "latestAssistantMessageId")

    presentation = read("lib/core/presentation/generation_presentation_policy.dart")
    overlay_dart = read("lib/core/platform/background_chat_command_server.dart")
    overlay_kotlin = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
    )
    require(presentation, "isErrorNotice", "text.contains('Gemini')")
    require(overlay_dart, "'notice_is_error':", "'notice': controller.notice ?? ''")
    require(overlay_kotlin, "noticeIsError", "Color.rgb(255, 135, 145)")

    rules = read("lib/core/rules/rule_layer_content_v04155_user_defaults.dart")
    defaults = read("lib/core/rules/rule_layer_defaults.dart")
    prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
    require(
        rules,
        "非性交行为（例如口交、乳交等）不要求 AI 角色与用户同步高潮",
        "[【色情描写强化模块】（世界级专业水准 · 零容错执行）",
    )
    assert "重要：色情模块，一定要认真执行" not in rules
    require(defaults, "legacyEditableRuleLayerSha256V04165IntimacyCleanup")
    require(
        prompt,
        "正文中的叙述、动作与神态直接书写",
        "禁止用全角或半角圆括号包裹",
    )

    storage = read("lib/core/storage/media_blob_storage.dart")
    attachment_storage = read("lib/core/storage/message_attachment_storage.dart")
    require(
        storage,
        "final originalSha = await contentSha256(original);",
        "id: originalSha",
        "if (await target.exists())",
        "内容寻址媒体发生哈希冲突",
    )
    require(
        attachment_storage,
        "final blob = await blobStorage.store(",
        "final canonical = await AppDatabase.instance.mediaBlobById(blob.id);",
        "blobId: canonical.id",
    )

    phone = read("lib/core/phone/simulated_phone_repository.dart")
    policy = read("lib/core/phone/simulated_phone_policy.dart")
    notes = read("lib/core/phone/simulated_note_generator.dart")
    require(
        phone,
        "Random.secure().nextInt",
        "latestDailyContinuity(limit: 30)",
        "random_daily_continuity:",
        "DeepSeekSimulatedNoteGenerator",
    )
    assert "noteText(" not in phone + policy
    require(notes, "自由挑一个真实细节或心绪", "不是新的记忆、人格结论或学习证据")
    require(
        policy,
        "thought.strength >= 0.48",
        "value >= 0.34",
        "value >= baseline - 0.03",
    )

    runner = read("lib/core/ai/durable_generation_runner.dart")
    assert runner.count("if (selectedSticker != null) selectedSticker.attachment") == 1

    print("v0.41.65 refresh, settings, phone, media and immersive contracts passed")


if __name__ == "__main__":
    main()
