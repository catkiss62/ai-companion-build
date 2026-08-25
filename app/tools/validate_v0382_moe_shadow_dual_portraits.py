#!/usr/bin/env python3
"""Validate v0.38.2 D2 shadow state, dual portraits and scroll anchoring."""

from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
visuals = read("lib/core/presentation/chat_visuals.dart")
stage = read("lib/widgets/chat_portrait_stage.dart")
chat = read("lib/features/chat/chat_page.dart")
adapter = read("lib/core/integration/moe_input_adapter.dart")
coordinator = read("lib/core/integration/moe_shadow_coordinator.dart")
repository = read("lib/core/moe/infrastructure/sqlite_moe_repository.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
inner = read("lib/features/inner/inner_page.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in ("version: 0.38.2+101", "version: 0.38.3+102")
)
assert "assets/portraits/large_whale/" in pubspec
assert "assets/appearance/large_whale_mirror.jpg" in pubspec
assert "orElse: () => ChatPortraitSet.largeWhale" in visuals
assert "portraitAssetFor(ChatPortraitSet set)" in visuals
assert "left: .25" in visuals and "size: .25" in visuals
assert "widget.portraitSet.effectAnchor" in stage
assert "chat_portrait_${field}_${set.key}" in chat
assert "_timelineTailKey" in chat and "Scrollable.ensureVisible" in chat

assert "assistant.content" not in adapter
assert "assistant.reasoningContent" not in adapter
assert "completed_assistant_turn" in adapter
assert "relationshipStage" in adapter
assert "advanceEventIfNew" in repository
assert "return db.transaction" in repository
assert "conflictAlgorithm: ConflictAlgorithm.ignore" in repository
assert "MoeShadowCoordinator(db).observeCompletedTurn(assistant)" in runner
assert "reconcileRecentCommittedTurns" in coordinator
assert "萌属性数值 · D2 影子模式" in inner
assert "不参与提示词" in inner

for ui_only in ("小小鲸", "大肥鱼"):
    assert ui_only not in prompt, f"UI-only portrait name leaked into prompt: {ui_only}"

portrait_dir = ROOT / "assets/portraits/large_whale"
portraits = sorted(portrait_dir.glob("*.webp"))
assert len(portraits) == 20, len(portraits)
for image in portraits:
    data = image.read_bytes()
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP", image
    assert len(data) > 100_000, f"unexpectedly small portrait: {image}"

assert (portrait_dir / "nervous.webp").read_bytes() == (
    portrait_dir / "flustered.webp"
).read_bytes()
mirror = ROOT / "assets/appearance/large_whale_mirror.jpg"
assert sha256(mirror.read_bytes()).hexdigest() == (
    "3eb20158a962f129adba4d7f732dd5526a2943d4139eea07078ea82c4b0f2071"
)

assert "validate_v0382_moe_shadow_dual_portraits.py" in workflow
for alternatives in (
    (
        "Build AI Companion v0.38.2+101 APK",
        "Build AI Companion v0.38.3+102 APK",
    ),
    (
        "AI-Companion-v0.38.2-101-Dynamic-Moe-D2-Dual-Portraits-APK",
        "AI-Companion-v0.38.3-102-Moe-D3-Chinese-Reasoning-Normal-Emotion-APK",
    ),
    (
        "v0.38.2-dynamic-moe-d2-dual-portraits-test",
        "v0.38.3-moe-d3-chinese-reasoning-normal-emotion-test",
    ),
):
    assert any(token in workflow for token in alternatives), alternatives

print("v0.38.2 D2 shadow, dual portraits and tail-anchor validation passed")
