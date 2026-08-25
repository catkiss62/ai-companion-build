from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


policy = read("lib/core/phone/simulated_phone_policy.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
page = read("lib/features/phone/simulated_phone_page.dart")
chat = read("lib/features/chat/chat_page.dart")
recovery = read("lib/core/maintenance/recovery_orchestrator.dart")
pubspec = read("pubspec.yaml")

assert any(
    token in pubspec
    for token in ("version: 0.38.8+107", "version: 0.38.9+108")
)
assert "app == SimulatedPhoneAppKind.tarot || phoneEnabled" in policy
assert "if (!await db.brainWorkAllowed()) return;" in repository
assert "if (!await isEnabled()) return;" in repository
assert "await _refreshTarot(current);" in repository
assert "simulated_phone_enabled" in repository
assert "simulated_phone_switch_changed_at" in repository
assert "thought_projection" in repository
assert "desire_thought_projection" in repository
assert "source_thought_id" in repository
assert "thought.text" not in repository
assert "tabs: [Tab(text: '我'), Tab(text: '他')]" in page
assert "关闭更新不会删除历史 · 塔罗牌仍会每天更新" in page
assert "没有真实浏览记录" in page
assert "查手机" in chat
assert "SimulatedPhonePage" in chat
assert "SimulatedPhoneRepository(db).refreshIfDue" in recovery

print("v0.38.8 simulated phone foundation validation passed")
