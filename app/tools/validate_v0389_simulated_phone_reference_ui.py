from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


policy = read("lib/core/phone/simulated_phone_policy.dart")
catalog = read("lib/core/phone/tarot_catalog.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
page = read("lib/features/phone/simulated_phone_page.dart")
fetch = read("tools/fetch_tarot_assets.sh")
attribution = read("assets/tarot/rws_major/ATTRIBUTION.md")
pubspec = read("pubspec.yaml")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.16+115" in pubspec
assert "- assets/tarot/rws_major/" in pubspec
assert "class LockScreen" in page
assert "上滑解锁" in page
assert "class ReferenceUnlockControl" in page
assert "static const double slideDistance = 100" in page
assert "drag >= slideDistance" in page
unlock = page[
    page.index("class ReferenceUnlockControl") : page.index(
        "class UnlockSuccessOverlay"
    )
]
assert "onTap:" not in unlock
assert "解锁失败" not in page
assert "软件破解" not in page
assert "RadialGradient" in page
assert "📶  🛜  🔋" in page
assert "class AppIcon" in page
for title in ("相册", "浏览器", "随笔", "心情", "愿望单", "日记", "购物车", "塔罗牌"):
    assert "title: '" + title + "'" in page
for emoji in ("🖼️", "🌐", "📝", "💗", "✨", "📔", "🛒", "🔮"):
    assert emoji in page
assert "class MoodChartPainter" in page
assert "本周心情变化" in page
for metric in ("energy", "closeness", "curiosity", "reserve", "score"):
    assert "'" + metric + "'" in policy
assert "static const int tarotAssetCount = 22;" in policy
assert catalog.count("TarotCardProfile(") == 23
for field in ("theme:", "symbols:", "upright:", "reversed:", "guidance:", "shadow:"):
    assert catalog.count(field) >= 22
assert "card_index" in repository
assert "reversed" in repository
assert "theme" in repository
assert "symbols" in repository
assert "guidance" in repository
assert "shadow" in repository
assert "closing" in repository
assert "await _refreshTarot(current);" in repository
assert "if (!await isEnabled()) return;" in repository
assert any(
    tabs in page
    for tabs in (
        "tabs: [Tab(text: '我'), Tab(text: '他')]",
        "tabs: [Tab(text: '鲸鱼运势'), Tab(text: '为他占卜')]",
    )
)
assert "rws_major:71825eed74683305b139a669b23ca5dc12f76857" in repository
assert "71825eed74683305b139a669b23ca5dc12f76857" in fetch
assert "public domain" in attribution.lower()
hash_lines = re.findall(r"^[0-9a-f]{64}  ar\d{2}\.jpg$", fetch, re.MULTILINE)
assert len(hash_lines) == 22
assert "Restore pinned 22-card Rider-Waite-Smith tarot JPG pack" in workflow
assert "python3 tools/validate_v0389_simulated_phone_reference_ui.py" in workflow
assert "AI-Companion-v0.38.16-115-Action-Segment-Parser-Hotfix-APK" in workflow

print("v0.38.9 simulated phone reference UI validation passed")
