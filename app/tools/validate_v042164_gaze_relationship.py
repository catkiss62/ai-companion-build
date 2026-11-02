"""Wiring/ownership gate; behavioral proof is JVM, Android and Flutter regression."""
import re
from pathlib import Path

app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
version = re.search(r'^version: (\S+)', read('pubspec.yaml'), re.M).group(1)
assert f"buildLabel = 'v{version}'" in read('lib/core/agent/agent_self_reader.dart')
java = 'android/app/src/main/java/com/catkiss/senlive2dcompanion/'
model = read(java+'DeepseekAvatarModel.java')
assert 'gaze.capture(mvp.getArray(),eyeWhites,width,viewportHeight)' in model
assert 'Part49' in model and 'Part141' in model
assert 'footProbe.capture' in model and 'motionTuning=' in model
assert model.count('physics.evaluate') == 1
assert 'v[i]+=dx' not in model and 'v[i+1]+=dy' not in model
probe = read(java+'DeepseekFootProbe.java')
assert 'visible_leg_bounds_lower' in probe and 'legAfterTilt=' in probe
assert '.write(' not in probe and 'setParameter' not in probe
assert 'surfaceWidth,sceneHeight(),surfaceHeight' in read(java+'SenRenderer.java')
page = read('lib/features/relationship/relationship_page.dart')
for token in ['Timer.periodic', 'Duration(seconds: 12)', 'AppLifecycleState.resumed',
              'removeObserver(this)', 'refreshTimer?.cancel()', 'if (refreshing) return']:
    assert token in page, token
assert 'retire' not in page and 'resolveThread' not in page
assert 'relationship_refresh_v042164_test.dart' in (app.parent/'.github/workflows/system-logic-validation.yml').read_text()
print('v042164 gaze, read-only probe, version and relationship refresh wiring passed')
