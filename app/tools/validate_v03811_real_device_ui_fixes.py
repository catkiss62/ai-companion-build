from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing {relative}"
    return path.read_text(encoding="utf-8")


page = read("lib/features/phone/simulated_phone_page.dart")
repository = read("lib/core/phone/simulated_phone_repository.dart")
pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert "version: 0.38.16+115" in pubspec
assert "static const int schemaVersion = 33;" in database

# The real-device narrow layout must allocate the remaining row width to the
# avatar strip instead of letting a Spacer split it into a tall wrapping card.
home_start = page.index("class HomeScreen")
home_end = page.index("class PhoneAppItem", home_start)
home = page[home_start:home_end]
assert "Expanded(\n                      child: Glass(" in home
assert "constraints: const BoxConstraints(maxWidth: 290)" not in home
assert "'Whale Phone',\n                                    maxLines: 1" in home
assert "softWrap: false" in home

# Match phone_system.html: a visible success stage with dark scrim, expanding
# purple recognition ring and check, then lock fade + home fade.
assert "class UnlockSuccessOverlay" in page
assert "Timer(const Duration(milliseconds: 700)" in page
assert "opacity: homeVisible ? 1 : 0" in page
assert "opacity: locked ? 1 : 0" in page
assert "color: Colors.black.withValues(alpha: 0.60)" in page
assert "width: 108" in page and "height: 108" in page
assert "duration: const Duration(milliseconds: 450)" in page
assert "child: const Text('✅'" in page

# The v0.38.12 follow-up intentionally restores a readable plot height after
# real-device feedback showed the compact v0.38.11 strip was too short.
if any(version in pubspec for version in ("version: 0.41.18+157", "version: 0.41.19+158", "version: 0.41.20+159", "version: 0.41.21+160", "version: 0.41.22+161")):
    assert "MoodChartLayout.build" in page
    assert "const chartHeight = 224.0" in page
else:
    assert "final chartHeight = history.length <= 1" in page
    assert "? 184.0" in page and "? 204.0" in page and ": 224.0" in page
scaffold_start = page.index("class PhoneAppScaffold")
scaffold = page[scaffold_start:]
assert "body: SafeArea(" in scaffold
assert "top: false" in scaffold

assert "tabs: const [Tab(text: '鲸鱼运势'), Tab(text: '为他占卜')]" in page or (
    "tabs: [Tab(text: '鲸鱼运势'), Tab(text: '为他占卜')]" in page
)
if any(version in pubspec for version in ("version: 0.41.18+157", "version: 0.41.19+158", "version: 0.41.20+159", "version: 0.41.21+160", "version: 0.41.22+161")):
    assert "entry: widget.self" in page and "entry: widget.user" in page
else:
    assert "TarotReading(entry: self, label: '鲸鱼运势')" in page
    assert "TarotReading(entry: user, label: '为他占卜')" in page

assert "entry.metadata['list_summary'] is String" not in repository
assert "'list_summary': item.$4" not in repository
assert "entry.metadata['list_summary'] as String?" not in page
assert "entry.body,\n                        maxLines: 1" in page

assert "python3 tools/validate_v03811_real_device_ui_fixes.py" in workflow
assert "AI-Companion-v0.38.16-115-Action-Segment-Parser-Hotfix-APK" in workflow
assert "agent/v03816-action-segment-parser-hotfix" in workflow

print("v0.38.11 real-device simulated-phone UI fixes validated")
