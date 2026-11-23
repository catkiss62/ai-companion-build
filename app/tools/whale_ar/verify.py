"""Check the final host APK, including the runtime that the CI cache cannot supply."""
import hashlib
import json
from pathlib import Path
import sys
from zipfile import ZipFile

private = Path(__file__).resolve().parents[2] / 'android/app/generated/whale-private'
with ZipFile(sys.argv[1]) as apk:
    names = set(apk.namelist())
    assert not any(name.lower().endswith('.vrm') for name in names)
    for file in [*(private / 'assets').rglob('*'), private / 'jniLibs/arm64-v8a/libEasyAR.so']:
        if file.is_file():
            name = file.relative_to(private).as_posix().replace('jniLibs/', 'lib/', 1)
            assert hashlib.sha256(apk.read(name)).digest() == hashlib.sha256(file.read_bytes()).digest(), name
    assert len([n for n in names if n.startswith('assets/motions/') and n.endswith('.vrma')]) == 16
    voices = json.loads(apk.read('assets/voices/lines.json'))
    assert sum(map(len, voices.values())) == 210
    assert all('assets/voices/' + line['id'] + '.wav' in names for group in voices.values() for line in group)
    assert {'assets/hand_landmarker.task', 'assets/viewer/scene.bundle.js',
            'lib/arm64-v8a/libMenthaAR_Engine.so','lib/arm64-v8a/libmediapipe_tasks_vision_jni.so'} <= names
    required = {b'Ldev/littlewhale/ar/'+n+b';' for n in
                [b'TableActivity', b'EasyLabActivity', b'ImageLabActivity', b'CoreLabActivity']}
    required.add(b'Lcn/easyar/Engine;')
    for name in names:
        if name.startswith('classes') and name.endswith('.dex'):
            data = apk.read(name)
            required = {symbol for symbol in required if symbol not in data}
    assert not required, required
print('Verified 4 AR activities, native trackers, Sense license, 210 voice lines and 16 motions.')
