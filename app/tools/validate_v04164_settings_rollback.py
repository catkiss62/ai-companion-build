#!/usr/bin/env python3
"""Exact contracts for the +208 rollback to the accepted +206 settings UI."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


def digest(relative: str) -> str:
    return sha256((ROOT / relative).read_bytes()).hexdigest()


assert "version: 0.41.64+208" in read("pubspec.yaml")
assert "static const buildLabel = 'v0.41.64+208';" in read(
    "lib/core/agent/agent_self_reader.dart"
)

# These eight files must remain byte-identical to the accepted +206 source.
expected = {
    "lib/app.dart": "2f2394abdaa8ed12c4b2ef58b2c6953f45213e0df86e5ce34b92542fef36a3d3",
    "lib/features/chat/chat_page.dart": "bb6591a223f2f3288178d1deb0d686dc84bcab9da0732d741d938b712427f769",
    "lib/features/chat/chat_quick_settings_pages.dart": "deb34a379dee234c34d75ff21eb608b3c35473c24c97850aa59d21c42a66832e",
    "lib/features/more/companion_more_page.dart": "a411a1b47831f5f7d4878c6f04ba06bdea58daa0a22fd40911417d81d3069e95",
    "lib/features/settings/settings_category_pages.dart": "127d0c5864b5a565d3370bb9edcbfb547e28b37096bc26f39b537cdbaa312704",
    "lib/features/settings/settings_page.dart": "37794efb81b3d9447f76eda26e8f28bc7587b40113126b466a971d0c1673ab1d",
    "test/settings_information_architecture_test.dart": "8f5b7c8140b74100ee1d54294edf2ec86b088d6adc1fcb94c9035bfabc9e4214",
    "test/ui_information_architecture_v0360_test.dart": "c73d39faa4f8392b498f3b9f4eadd9833ed6141ae345e24a20883eb3e5ee2edc",
}
for path, expected_sha in expected.items():
    assert digest(path) == expected_sha, path

more = read("lib/features/more/companion_more_page.dart")
domains = read("lib/features/more/companion_domains_page.dart")
chat = read("lib/features/chat/chat_page.dart")
for title in ("她", "你们", "能力", "手机感知", "数据与高级"):
    assert title in more, title
for shortcut in ("主动联系", "聊天画面", "语音与情绪", "文字演出"):
    assert f"title: '{shortcut}'" in chat, shortcut
assert "await Navigator.of(pageContext).pushNamed('/settings');" in chat
assert "subtitle: '完整设置将在下一步重新分类。'" in chat
assert "title: '七大规则'" in domains
assert "onTap: () => _push(context, const RuleLayersPage())" in domains

print("v0.41.64 exact +206 settings rollback and Seven Rules reachability passed")
