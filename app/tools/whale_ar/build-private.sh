#!/usr/bin/env bash
# Build the private, redistributable runtime input. Supply a clean AR source at
# fa4ce7f, extracted EasyAR SDK, package-bound license, Android jar, renderer
# API jar, verified source motions directory and destination ZIP.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=$(realpath "$1"); sdk=$(realpath "$2"); license=$(realpath "$3"); android=$(realpath "$4")
api=$(realpath "$5"); motions=$(realpath "$6"); destination=$(realpath -m "$7")
[[ $(git -C "$src" rev-parse HEAD) = fa4ce7f538310690a22dbea88dd461e24731ca50 ]]
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
git -C "$src" archive HEAD app/src | tar -x -C "$work"
(cd "$work" && git apply --no-index "$here/host-theme.patch")
mkdir -p "$work/classes" "$work/provided"
aar="$sdk/variants/Community/Android/EasyAR.aar"
unzip -p "$aar" classes.jar >"$work/easyar.jar"
java -m jdk.compiler/com.sun.tools.javac.Main -source 8 -target 8 -cp "$android" -d "$work/provided" "$here/../../android/app/src/main/java/dev/littlewhale/ar/CompanionArStyle.java"
java -m jdk.compiler/com.sun.tools.javac.Main -source 8 -target 8 -cp "$android:$api:$work/provided:$work/easyar.jar" -d "$work/classes" \
    "$sdk/samples/Community/Android/HelloARMotionTracking/app/src/main/java/cn/easyar/samples/helloarmotiontracking/BGRenderer.java" \
    "$work"/app/src/easyar/java/dev/littlewhale/ar/*.java
python3 - "$work" "$aar" "$license" "$motions" "$src/docs/yuchat-motion-files.tsv" "$destination" <<'PY'
import csv, hashlib, sys, zipfile
from pathlib import Path
work, aar, license, motions, inventory, destination = map(Path, sys.argv[1:])
def put(archive, name, content):
    entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    archive.writestr(entry, content, compress_type=zipfile.ZIP_DEFLATED)
jar = work / 'runtime.jar'
with zipfile.ZipFile(jar, 'w') as out, zipfile.ZipFile(work / 'easyar.jar') as vendor:
    for name in sorted(vendor.namelist()):
        if name.endswith('.class'):
            put(out, name, vendor.read(name))
    for file in sorted((work / 'classes').rglob('*.class')):
        put(out, file.relative_to(work / 'classes').as_posix(), file.read_bytes())
clips = 'kay_pickup ual2_walk_carry_loop grabbed jitabata locomotion_walk locomotion_left locomotion_right idle_normal_both_550 kay_idle_a ual2_idle_foldarms_loop hands_back_reserved_both_560 tilt_reserved_head_616 calm_reserved_both_729 think_reserved_both_643 sigh_reserved_both_696 wave_normal_right_661'.split()
with inventory.open(encoding='utf8') as stream:
    hashes = {row['动作 ID']: row['SHA-256'] for row in csv.DictReader(stream, delimiter='\t')}
with zipfile.ZipFile(destination, 'w') as out, zipfile.ZipFile(aar) as vendor:
    put(out, 'runtime.jar', jar.read_bytes())
    put(out, 'jniLibs/arm64-v8a/libEasyAR.so', vendor.read('jni/arm64-v8a/libEasyAR.so'))
    put(out, 'assets/easyar-license.txt', license.read_bytes())
    for clip in clips:
        data = (motions / (clip+'.vrma')).read_bytes()
        if hashlib.sha256(data).hexdigest() != hashes[clip]:
            raise ValueError('动作文件不符: '+clip)
        put(out, 'assets/motions/'+clip+'.vrma', data)
PY
