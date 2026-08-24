#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), f"{path} is empty"
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
contract = read("lib/core/emotion/emotion_contract.dart")
episode = read("lib/core/models/emotion_episode.dart")
engine = read("lib/core/emotion/emotion_episode_engine.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
envelope_test = read("test/emotion_contract_test.dart")
episode_test = read("test/emotion_episode_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.37.5+94" in pubspec
assert "static const int schemaVersion = 29;" in database
assert "CREATE TABLE IF NOT EXISTS emotion_episodes" in database
assert "FOREIGN KEY(trigger_message_id) REFERENCES messages(id) ON DELETE CASCADE" in database
assert "UNIQUE(trigger_message_id, category)" in database
assert database.count("'emotion_episodes',") >= 4
assert "insertEmotionEpisodeIfAbsent" in database
assert "applyEmotionRepair" in database
assert "intensity = intensity * 0.55" in database

assert r"{0,80}?" in contract
assert "_selfClosing" in contract
assert "empty and whitespace-only envelopes" in envelope_test
assert "<emotion></emotion>" in envelope_test
assert "invalid envelope falls back but never leaks" in envelope_test

assert "class EmotionAppraisalPolicy" in episode
assert "real_user_message" in episode
assert "drive_snapshot" in episode
assert "user_text" not in episode
assert "class EmotionEpisodeEngine" in engine
assert "An apology without an active" in engine
assert "emotionEpisodeById(episodeId)" in engine
assert "不得借此破坏停止/取消、安全、权限、事实核对、数据操作或真实工具结果" in engine
assert "瞬时19类 emotion 信封" in engine

appraise_at = runner.index("emotionEpisodeEngine.appraiseUserTurn")
prompt_at = runner.index("PromptBuilder(db).buildChatMessages")
assert appraise_at < prompt_at
assert "await emotionEpisodeEngine.buildPromptSection" in prompt
assert "context.writeln(emotionEpisodeSection)" in prompt

assert "30 grounded scenarios" in episode_test
assert "expect(cases, hasLength(30))" in episode_test
assert "replay < 3" in episode_test
assert "episode.toDb().containsKey('user_text')" in episode_test

assert "Build AI Companion v0.37.5+94 APK" in workflow
assert "validate_v0375_grounded_emotion_episode.py" in workflow
assert "AI-Companion-v0.37.5-94-Grounded-Emotion-Episode-APK.apk" in workflow
assert "schema advances to 29" in workflow
assert "native 19emo remains absent" in workflow.lower()

print("v0.37.5 grounded emotion episode validation passed")
