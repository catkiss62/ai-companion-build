"""Boundary gate paired with production import/restore and Flutter channel tests."""
from pathlib import Path
app = Path(__file__).resolve().parents[1]
read = lambda p: (app / p).read_text()
profile = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/Live2DProfiles.kt')
assert 'deepseek-avatar' in profile and 'generation != epoch' in profile
repo = read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiModelRepository.kt')
for item in ('Live2DProfiles.directory(profile)', 'Live2DProfiles.index(profile)', 'GB18030',
             'deepseekModel(staging)', 'singleModel', 'rollbackPendingImport'):
    assert item in repo, item
native = read('android/app/src/main/kotlin/com/aicompanion/localfirst/PortableCompanionState.kt')
for item in ('raw.keys == fields.keys || raw.keys == allFields.keys', 'values.containsKey(group)',
             'deepseek_stage', 'deepseek_appearance', 'Live2DProfiles.restored(context)'):
    assert item in native, item
model = read('android/app/src/main/java/com/catkiss/senlive2dcompanion/DeepseekAvatarModel.java')
assert 'CaicaiIdleMotion' not in model and 'ParamAngleX3' not in model
assert model.count('physics.evaluate(model,delta)') == 1
assert 'mouthOwner.active' in model and 'MOUTH.contains' in model
assert 'model.getParameterMinimumValue' in model and 'model.getParameterDefaultValue' in model
assert 'set("Clothes3",0); set("Clothes5",0)' in model
texture = read('android/app/src/main/java/com/catkiss/senlive2dcompanion/NativeTextureManager.java')
assert 'inSampleSize' not in texture and 'ARGB_8888' in texture
assert '16_666_667L' in read('android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiCompanionView.java')
assert (app / 'test/dual_live2d_profiles_v042154_test.dart').is_file()
assert (app / 'android/app/src/test/java/com/catkiss/senlive2dcompanion/CaicaiProfileIsolationTest.kt').is_file()
print('Dual Live2D boundaries, original textures and independent import/restore wired')
