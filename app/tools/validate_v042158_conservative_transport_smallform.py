"""Wiring gate; transport/cache and avatar behavior run in Flutter/JVM tests."""
from pathlib import Path
app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
model = read('android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekAvatarModel.java')
assert 'prefs.getFloat("smallForm",.55f)' in model
assert 'stage.getFloat("anchorY",.21504237f)' in model
assert 'targetForm=small?smallForm:0f' in model
assert 'model.getParameterMaximumValue(sizeIndex)<.8f' in model  # Actual rig signature unchanged.
native = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
refresh = native.split('fun refreshPreferences()',1)[1].split('fun speechPlayback',1)[0]
assert 'companion.anchorDeepseek' in refresh and 'companion.appearanceDeepseek' in refresh
assert 'restoredAppearance["smallForm"]=.55f' in refresh
assert 'headBox = restored.headBox()' in refresh
transport = read('lib/core/ai/third_channel_transport.dart')
assert 'config.encode()' not in transport
assert 'config.endpoint.toString(), config.apiKey.trim(), network' in transport
assert 'healthTtl = Duration(seconds: 60)' in transport
client = read('lib/core/ai/third_channel_client.dart')
assert 'totalTimeout = const Duration(seconds: 120)' in client
assert 'healthTimeout = const Duration(seconds: 15)' in client
assert 'attempt <= 2' in client and "ThirdChannelFailure('usage_missing')" in client
assert 'healthCached = lease!.recentHealth' in client and 'if (!healthCached)' in client
ui = read('lib/features/settings/settings_category_pages.dart')
assert 'ThirdChannelTestStatus.scope(tested, await _secure.readThirdChannel())' in ui
assert '不保证长正文同样及时' in ui
for workflow in ('build-apk.yml','system-logic-validation.yml'):
    assert 'conservative_third_channel_v042158_test.dart' in (app.parent/'.github/workflows'/workflow).read_text()
print('Conservative third transport and saved DeepSeek small form restoration wired')
