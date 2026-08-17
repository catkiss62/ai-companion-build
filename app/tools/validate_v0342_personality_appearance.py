#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def file_digest(relative: str) -> str:
    return sha256((ROOT / relative).read_bytes()).hexdigest()


def png_contract(relative: str, size: tuple[int, int], digest: str) -> None:
    data = (ROOT / relative).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", relative
    assert struct.unpack(">II", data[16:24]) == size, relative
    assert data[25] == 6, f"{relative} must remain RGBA"
    assert sha256(data).hexdigest() == digest, relative


pubspec = read("pubspec.yaml")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
grouping = read("lib/core/rules/rule_layer_grouping.dart")
database = read("lib/core/database/app_database.dart")
page = read("lib/features/self/personality_appearance_page.dart")
more = read("lib/features/more/companion_more_page.dart")
rule_page = read("lib/features/settings/rule_layers_page.dart")
tests = read("test/rule_layer_defaults_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.34.6+71" in pubspec
assert "assets/appearance/dafeiyu_reference.webp" in pubspec

for token in (
    "03_personality_seed",
    "半自知",
    "陪伴不是一项工作",
    "不是越相处越顺从",
    "不要为了显得可爱而故意答错",
):
    assert token in defaults, token

for token in (
    "03_appearance_identity",
    "女仆装",
    "鲸鱼尾巴",
    "耳鳍",
    "鲸鱼娘",
    "小鲸鱼",
    "大肥鱼",
    "绝不能主动用它自称",
    "照镜子",
    "locked: true",
):
    assert token in defaults, token

assert "legacyPersonalitySeedV1" in defaults
assert "where: 'key = ? AND content = ?'" in database
assert "whereArgs: [currentPersonality.key, legacyPersonalitySeedV1]" in database
assert "'03_appearance_identity': '03'" in grouping
assert "固定外观与称呼" in grouping

for token in (
    "class PersonalityAppearancePage",
    "可编辑性格种子",
    "保存性格",
    "还原默认性格",
    "长期记忆、关系经历、Desire 和已经形成的 AI Self 不会被删除",
    "assets/appearance/dafeiyu_reference.webp",
    "大肥鱼 · 只由用户调侃",
):
    assert token in page, token

assert "title: '性格与外观'" in more
assert "PersonalityAppearancePage" in more
assert "label: const Text('还原默认')" in rule_page
assert "ships nine independently persisted sections" in tests

appearance = "assets/appearance/dafeiyu_reference.webp"
assert file_digest(appearance) == (
    "f8783e2f468a6b226962b33b34acc26e759416c5ca6175f76138cd7adb5a9c80"
)
asset_root = "android/app/src/main/assets/pets/dafeiyu/source/runtime_overrides/yawning"
png_contract(
    f"{asset_root}/sleepy_yawn_187.png",
    (136, 160),
    "dcbbcba4ad2696849fca65eb7b900b76422a3fec805c244de4bc42ec6dfbd235",
)
png_contract(
    f"{asset_root}/sleepy_yawn_238.png",
    (171, 202),
    "f6659dc54dead83ad0be851496d3cb784c426c518784f64969606b9010d20096",
)
png_contract(
    f"{asset_root}/sleepy_yawn_306.png",
    (222, 261),
    "141a88407f5e54c7da795b0c33b5fd5319689b0382b54f2771bec851ae0fa9df",
)

assert "python3 tools/validate_v0342_personality_appearance.py" in workflow
assert "assets/flutter_assets/assets/appearance/dafeiyu_reference.webp" in workflow
assert "AI-Companion-v0.34.6-71-Lock-Resume-APK" in workflow
print("v0.34.2 personality, appearance self-source, aliases and aligned yawn assets verified")
