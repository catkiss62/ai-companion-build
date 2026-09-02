#!/usr/bin/env python3
"""Validate v0.38.5 portraits, chat avatar, metric rollback and D3 diagnostics."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def vp8x_canvas(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    assert data[:4] == b"RIFF" and data[8:16] == b"WEBPVP8X", path
    flags = data[20]
    width = 1 + int.from_bytes(data[24:27], "little")
    height = 1 + int.from_bytes(data[27:30], "little")
    return width, height, flags


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
chat = read("lib/features/chat/chat_page.dart")
inner = read("lib/features/inner/inner_page.dart")
adapter = read("lib/core/integration/moe_expression_prompt_adapter.dart")
preflight = read("lib/core/diagnostics/preflight_diagnostics.dart")
tests = read("test/moe_expression_prompt_adapter_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in ("version: 0.38.5+104", "version: 0.38.6+105", "version: 0.38.7+106")
)
assert (
    "static const int schemaVersion = 32;" in database
    or "static const int schemaVersion = 33;" in database
)
assert "assets/appearance/chat_avatar.webp" in pubspec

portrait_hashes = {
    "affection.webp": "20ce23a1bbb3aba88b977702a31337d0e6dc4b0a606a3d3141e2b342f2fdc15e",
    "afraid.webp": "dfd7baf703381c811e7031dfb26754d4a841091642b3ce92dfd38dfd64f72369",
    "angry.webp": "370064dda84a5031886930367d62dff951e287ff5bbf85bacc0d255e94b19720",
    "calm.webp": "6476b5d8259255fc14393e8264781d11bc0c1600c00f854ae872e1ec0367165e",
    "confident.webp": "c0da558bc4fd97d40ce5c9aa2535504c3f55ce1094107571e8595e0b553d497e",
    "confused.webp": "1cf4352ed226feb4a5f6dd9198dde8ac99489f4ddd2e7e63e1518d93cde82c6b",
    "crying.webp": "da4c69b995e675868c03c3d6ad4e7ad95820efe37e77657c91118f3b67ff28a8",
    "disgust.webp": "2b43ba5b99135ef8346937bef40df1128a6f2ec0a6c6a6d6a43a2add0ff53b35",
    "embarrassed.webp": "19657054378c4b41840e7ffb675ec1687329826db279b31a00829b0592db2c94",
    "excited.webp": "a09f72485a49f95a3d0231a28abe878408aacc6e67a90951b47e1398fba0f75d",
    "flustered.webp": "280a6a1909f0093426ae9fd87c217854eb8362a0efecc5353210de468d7196e9",
    "happy.webp": "09f28093d19fdf1275e6fbde41b0ce409be4dbae92482d360416123f3998e877",
    "helpless.webp": "d6f963e05de4e13fd4ee990aa0d300258e3ca728a60cff4e2100525ffb3eba9d",
    "nervous.webp": "280a6a1909f0093426ae9fd87c217854eb8362a0efecc5353210de468d7196e9",
    "normal.webp": "93b86a82db61922b8b7486e0f3eaa64e5b1544583b0e9b552784529f22b051f0",
    "playful.webp": "0c54d2d2d6bf371d00f843871ae4af3957db530e7ae6fd05d100376a6313e8c1",
    "serious.webp": "2adbb670636350a8d472e426d64e07175b79162abc88c38d7ea7332510bf0ca8",
    "shy.webp": "cede5a4e4e1afe8fbe25beb5d3dc50d331f5849eaa3daa4d53f2419ce2bb706e",
    "surprised.webp": "15004d5288f2eb68e89041e6c21b69f48d3ad53d94a32b3f2253a8bfa72d8a61",
    "worried.webp": "a489dd90c4d2e36a4716f21fa87348884b2028e9370165d1ed9fbd13c7ffdb2d",
}
portrait_dir = ROOT / "assets/portraits/large_whale"
assert {path.name for path in portrait_dir.glob("*.webp")} == set(portrait_hashes)
for name, expected_hash in portrait_hashes.items():
    path = portrait_dir / name
    assert digest(path) == expected_hash, name
    width, height, flags = vp8x_canvas(path)
    assert (width, height) == (1152, 2048), (name, width, height)
    assert flags & 0x10, f"portrait lost alpha: {name}"
assert (portrait_dir / "nervous.webp").read_bytes() == (
    portrait_dir / "flustered.webp"
).read_bytes()

avatar = ROOT / "assets/appearance/chat_avatar.webp"
assert digest(avatar) == "f5a5eac2c00fa8c15005adea269ed514d778222b8a005ed38693b51b535eda46"
assert vp8x_canvas(avatar)[:2] == (1256, 1256)
assert digest(ROOT / "assets/lingchat/deepseek/avatar.webp") == (
    "68772d09789c9557509dad6ae64472fe0046b5cf35b91abffb5c3f03c2d0cb00"
)
assert digest(ROOT / "assets/appearance/large_whale_mirror.jpg") == (
    "3eb20158a962f129adba4d7f732dd5526a2943d4139eea07078ea82c4b0f2071"
)
assert chat.count("assets/appearance/chat_avatar.webp") >= 2
assert "assets/lingchat/deepseek/avatar.webp" not in chat
assert "String _currentEmotionLabel = '正常';" in chat

for token in (
    "Widget _desireProgressRow({",
    "padding: const EdgeInsets.symmetric(vertical: 5)",
    "SizedBox(width: 64, child: Text(label))",
    "width: 92",
    "return _desireProgressRow(",
    "Widget _moeProgressRow({",
    "padding: const EdgeInsets.symmetric(vertical: 4)",
    "SizedBox(width: 72, child: Text(label))",
    "width: 72",
    "return _moeProgressRow(",
    "fit: BoxFit.scaleDown",
    "maxLines: 1",
    "softWrap: false",
    "'D3 表现：$d3Status'",
    "'调整 D3'",
):
    assert token in inner, token
assert inner.count("Widget _desireProgressRow({") == 1
assert inner.count("Widget _moeProgressRow({") == 1
assert inner.count("LinearProgressIndicator(") == 2
assert "Widget _metricProgressRow({" not in inner
assert "Widget _desireStateCard(" not in inner

for token in (
    "class MoeExpressionPromptTelemetry",
    "moe_expression_prompt_telemetry_v1",
    "status: section.isEmpty ? 'neutral' : 'applied'",
    "status: 'disabled'",
    "status: 'error'",
    "promptBodiesIncluded': false",
    "styleDirectivesIncluded': false",
    "axisOrRecipeNamesIncluded': false",
    "valuesOrThresholdsIncluded': false",
    "messageIdsIncluded': false",
    "catch (_) {\n      return _empty();",
):
    assert token in adapter, token
for token in (
    "'dynamicMoe': {",
    "'promptConsumption': moePromptTelemetry",
    "'primaryPresent': moePlan.primary != null",
    "'secondaryPresent': moePlan.secondary != null",
    "'promptBodiesIncluded': false",
    "'axisOrRecipeNamesIncluded': false",
):
    assert token in preflight, token
assert "D3 telemetry records applied and disabled paths without prompt data" in tests
assert "D3 telemetry fails closed to redacted error counters" in tests

for token in (
    "Build AI Companion v0.38.5+104 APK",
    "validate_v0385_portrait_avatar_metric_diagnostics.py",
    "AI-Companion-v0.38.5-104-Portraits-Avatar-Moe-Diagnostics-APK",
    "v0.38.5-portraits-avatar-moe-diagnostics-test",
    ".ci/v0385-monitor.txt",
):
    assert token in workflow, token

print("v0.38.5 portrait, avatar, metric rollback and D3 diagnostics validation passed")
