#!/usr/bin/env python3
"""Static contracts for build 206 hybrid final reply and safe drafts."""

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
    provider = read("lib/core/ai/chat_api_provider.dart")
    secure = read("lib/core/storage/secure_config.dart")
    runner = read("lib/core/ai/durable_generation_runner.dart")
    failure = read("lib/core/ai/final_reply_failure_policy.dart")
    database = read("lib/core/database/app_database.dart")
    chat = read("lib/features/chat/chat_controller.dart")
    chat_page = read("lib/features/chat/chat_page.dart")
    immersive = read("lib/core/immersive/immersive_room_controller.dart")
    immersive_page = read("lib/features/immersive/immersive_room_page.dart")
    translation = read("lib/core/ai/message_language_variant_service.dart")

    require(
        provider,
        "https://wy.aiwangyou.cc/v1/chat/completions",
        "[特价]gemini-3.7-flash-0.5",
        "aiWangYouGemini('aiwangyou_gemini', 'Gemini 3.7 Flash（玩游）')",
        "'google': <String, Object?>{",
        "'include_thoughts': thinking",
    )
    assert "'extra_body':" not in provider
    require(
        secure,
        "aiwangyou_gemini_api_key",
        "Future<String?> readApiKey() => readDeepSeekApiKey();",
        "readFinalReplyApiKey",
        "readFinalReplyEndpoint",
    )
    require(
        failure,
        "maxGeminiAttempts = 2",
        "error.statusCode == 429",
        "error.statusCode == 504",
        "retryDelay",
    )
    require(
        runner,
        "generateInternal",
        "generateFinal",
        "FinalReplyFailurePolicy.isTransient",
        "本轮已由 DeepSeek 兜底",
        "FinalReplyIncompleteException",
        "holdGenerationJobForUserDecision",
        "confirmIncompleteDraft",
    )
    require(
        database,
        "awaiting_confirmation",
        "holdGenerationJobForUserDecision",
        "claimGenerationDraftForConfirmation",
        "restartGenerationDraft",
        "'deepseek_model': 'deepseek-v4-flash'",
        "'gemini-3.7-flash'",
    )
    require(
        chat,
        "incompleteReplyDraft",
        "regenerateIncompleteReply",
        "confirmIncompleteReply",
        "dismissNotice",
        "chat_persistent_gemini_fallback_notice",
    )
    require(
        chat_page,
        "重新生成这条回复？",
        "回复已截断，仍确认保留？",
        "Icons.refresh_rounded",
        "child: const Text('保留这段回复')",
    )
    require(
        immersive,
        "readFinalReplyApiKey",
        "_streamFinalRequest",
        "immersive_pending_reply_",
        "regenerateIncompleteReply",
        "confirmIncompleteReply",
        "本轮已由 DeepSeek 兜底",
        "immersive_gemini_fallback_notice_",
    )
    require(
        immersive_page,
        "height: 28",
        "BoxConstraints.tightFor",
        "height: 24",
        "重新生成这条回复？",
    )
    require(
        translation,
        "isPlausibleVariant",
        r"[\u3040-\u30ff\u3400-\u9fff]",
        "for (var attempt = 1; attempt <= 2; attempt++)",
    )
    require(chat, "_hasPlausibleLanguageVariant")
    require(immersive, "_hasPlausibleLanguageVariant")
    print("v0.41.62 hybrid final reply, fallback, safe drafts and TTS guard contracts passed")


if __name__ == "__main__":
    main()
