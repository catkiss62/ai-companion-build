#!/usr/bin/env python3
"""Validate the v0.38.1 adult-relationship capability and media fixes."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: {message}: missing {needle!r}")


def reject(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: {message}: found {needle!r}")


pubspec = read("pubspec.yaml")
prompt = read("lib/core/ai/prompt_builder.dart")
router = read("lib/core/ai/nsfw_context_router.dart")
layers = read("lib/core/rules/rule_layer_service.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
personality = read("lib/core/personality/personality_catalog.dart")
desire_policy = read("lib/core/desire/desire_core_policy.dart")
desire_engine = read("lib/core/desire/desire_engine.dart")
portrait = read("lib/widgets/chat_portrait_stage.dart")
sound = read("lib/core/tts/emotion_sound_service.dart")
chat = read("lib/features/chat/chat_page.dart")
database = read("lib/core/database/app_database.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")

if not any(
    version in pubspec
    for version in (
        "version: 0.38.1+100",
        "version: 0.38.2+101",
        "version: 0.38.3+102",
        "version: 0.38.4+103",
        "version: 0.38.5+104",
        "version: 0.38.6+105",\n        "version: 0.38.7+106",
    )
):
    raise SystemExit("FAIL: unsupported post-v0.38.1 version")
require(prompt, "恋爱中的暧昧玩笑、欲望、调情与露骨亲密都是正常表达能力", "adult capability")
reject(prompt, ".where((d) => d != DriveKey.libido || nsfwActive)", "libido prompt gate")
reject(prompt, "mode == PromptGenerationMode.proactive ? false", "proactive adult-depth gate")
require(router, "This classifier never grants permission", "depth-only router")
require(router, "brief erotic jokes", "daily erotic play")
require(layers, "'daily' => true", "daily layer must stay loaded")
require(desire_policy, "bool intimacyAllowed = true", "libido default")
reject(desire_engine, "final intimacyAllowed = activeSession != null", "Session desire gate")
require(rules, "Session 只保存场景连续性，成人路由只决定描写深度", "Session contract")
reject(rules, "【成人关系边界】", "old adult boundary doctrine")
reject(rules, "【进入条件】", "old intimacy gate")
reject(personality, "成人表达受亲密 Session 控制", "special-style Session gate")
require(portrait, "child: Stack(\n                      fit: StackFit.expand", "portrait/effect composite")
require(sound, "double _volume = 0.15", "sound service default")
require(sound, "?? 0.15", "sound parse fallback")
require(chat, "double _emotionSoundVolume = 0.15", "chat sound default")
require(database, "emotion_sound_volume_default_v0381_applied", "volume migration")
require(database, "...legacyEditableRuleLayerSha256V0380.entries", "prompt migration")
require(defaults, "legacyEditableRuleLayerSha256V0380", "v0.38.0 prompt hashes")

print("v0.38.1 adult relationship capability validation passed.")
