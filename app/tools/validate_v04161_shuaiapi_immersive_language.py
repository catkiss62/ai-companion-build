#!/usr/bin/env python3
"""Retained build-205 immersive-language and reasoning contracts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, *tokens: str) -> None:
    missing = [token for token in tokens if token not in text]
    assert not missing, f"missing contract tokens: {missing}"


def main() -> None:
    require(read("pubspec.yaml"), "version: 0.41.61+205")
    database = read("lib/core/database/app_database.dart")
    require(
        database,
        "static const int schemaVersion = 60;",
        "if (oldVersion < 60)",
        "_createV60ImmersiveLanguageColumns",
        "'ja_content': \"TEXT NOT NULL DEFAULT ''\"",
        "'ja_segments_json': \"TEXT NOT NULL DEFAULT ''\"",
        "'en_content': \"TEXT NOT NULL DEFAULT ''\"",
        "'en_segments_json': \"TEXT NOT NULL DEFAULT ''\"",
    )

    provider = read("lib/core/ai/chat_api_provider.dart")
    secure = read("lib/core/storage/secure_config.dart")
    provider_test = read("test/chat_api_provider_test.dart")
    require(
        provider,
        "'google': <String, Object?>{",
        "'thinking_config': <String, Object?>{",
        "'include_thoughts': thinking",
    )
    assert "'extra_body':" not in provider
    require(
        secure,
        "readFinalReplyApiKey",
        "readDeepSeekApiKey",
    )
    require(
        provider_test,
        "body?.containsKey('extra_body'), isFalse",
        "body?['google']",
        "body?.containsKey('thinking'), isFalse",
        "body?.containsKey('reasoning_effort'), isFalse",
        "先计算。",
    )

    model = read("lib/core/models/immersive_room.dart")
    repository = read("lib/core/immersive/immersive_room_repository.dart")
    service = read(
        "lib/core/immersive/immersive_message_language_variant_service.dart"
    )
    controller = read("lib/core/immersive/immersive_room_controller.dart")
    page = read("lib/features/immersive/immersive_room_page.dart")
    require(
        model,
        "languageVariants",
        "contentFor(ChatLanguage language)",
        "_languageVariantsFromDb",
    )
    require(
        repository,
        "saveLanguageVariant",
        "ChatSegmentCodec.encode(variant.segments)",
        "where: 'id = ? AND role = ?'",
    )
    require(
        service,
        "_inFlight.putIfAbsent",
        "ChatSegmentCodec.parseAssistantText(latest.content)",
        "await store.saveVariant(variant)",
    )
    require(
        controller,
        "ensureLanguageVariant",
        "ChatLanguage.tryParse(await db.getSetting('tts_language'))",
        "projectedAssistant.contentFor(speechLanguage)",
        "language: speechLanguage",
        "reasoningContent: _allStreamingReasoning",
    )
    require(
        page,
        "_ImmersiveLanguageButton",
        "for (final language in ChatLanguage.values)",
        "show_foreign_replies",
        "_ImmersiveForeignProjection",
        "language: _selectedLanguage",
    )
    require(
        read("test/immersive_message_language_variant_test.dart"),
        "generated once and cached",
        "concurrent immersive language requests share one translation",
        "database row restores both language projections and reasoning",
        "schema-59 immersive rows remain Chinese-only after migration",
        "missing key never saves a fake immersive projection",
    )
    print("v0.41.61 retained immersive language and reasoning contracts passed")


if __name__ == "__main__":
    main()
