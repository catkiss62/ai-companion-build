#!/usr/bin/env bash
# Reconstruct the public portion of the embedded ARM64 runtime from the exact
# tested revision. The optional first argument is its verified CI base APK.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dest="$here/../../android/app/generated/whale-ar"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ar="$work/ar"
checkout() {
  git init -q "$1"
  git -C "$1" fetch -q --depth=1 "$2" "$3"
  git -C "$1" checkout -q --detach FETCH_HEAD
}
checkout "$ar" https://github.com/catkiss62/little-whale-ar.git fa4ce7f538310690a22dbea88dd461e24731ca50
up="$ar/upstream"
checkout "$up" https://github.com/Olsc/Android_ORB-SLAM2s.git 913d2c13ec300e9aaa148a45de2b14a5de805f63
base="${1:-$work/base.apk}"
if [[ $# == 0 ]]; then
  candidate='unsigned-candidate-0.25.0-arm64'
  if curl --max-time 100 -fsSL --retry 1 "https://nightly.link/catkiss62/little-whale-ar/actions/runs/45249654548/$candidate.zip" -o "$work/base.zip" &&
     unzip -p "$work/base.zip" unsigned-candidate-0.25.0-arm64.apk > "$base" &&
     echo "7f1102783a79058426e93e3093d3c3c6d2e260541caed06784665ccb6dcefc61  $base" | sha256sum -c --status; then
    :
  else
    git -C "$up" remote add origin https://github.com/Olsc/Android_ORB-SLAM2s.git
    (cd "$ar" && bash scripts/prepare.sh && bash scripts/build-voices.sh &&
       cd viewer && npm ci && npm run build)
    (cd "$ar" && bash upstream/gradlew --max-workers=3 :app:assembleRelease)
    base="$ar/app/build/outputs/apk/release/app-release-unsigned.apk"
  fi
else
  echo "7f1102783a79058426e93e3093d3c3c6d2e260541caed06784665ccb6dcefc61  $base" | sha256sum -c
fi
for patch in visual-recovery palm-preview table-orbit; do
  if ! git -C "$up" apply --reverse --check "$ar/scripts/$patch.patch" 2>/dev/null; then
    git -C "$up" apply "$ar/scripts/$patch.patch"
  fi
done
git -C "$ar" apply "$here/host-theme.patch"
out="$work/generated"
mkdir -p "$out"/{java/com/orb/slam2s/graphics,res/raw,aidl,jniLibs/arm64-v8a}
cp -R "$ar/app/src/main/java/." "$up/MenthaAR/src/main/java/." "$up/MenthaAR-SDK/src/main/java/." "$out/java/"
cp -R "$up/MenthaAR-SDK/src/main/aidl/." "$out/aidl/"
cp -R "$up/app/src/main/java/com/orb/slam2s/camera" "$out/java/com/orb/slam2s/"
for name in AspectGLSurfaceView DisplayCorrection GLPassThroughRenderer GLPointCloudRenderer GLUtils; do
  cp "$up/app/src/main/java/com/orb/slam2s/graphics/$name.java" "$out/java/com/orb/slam2s/graphics/"
done
sed -i 's/import com.orb.slam2s.R;/import com.aicompanion.localfirst.R;/' "$out/java/com/orb/slam2s/graphics/"*.java
cp "$up/app/src/main/res/raw/"*shader* "$out/res/raw/"
unzip -q "$base" 'assets/viewer/*' 'assets/voices/*' 'assets/hand_landmarker.task' -d "$out"
for lib in libMenthaAR_Engine.so libglb_renderer.so; do
  unzip -p "$base" "lib/arm64-v8a/$lib" > "$out/jniLibs/arm64-v8a/$lib"
done
test "$(find "$out/assets/voices" -name '*.wav' | wc -l)" -ge 210
mkdir -p "$dest"
cp -R "$out/." "$dest/"
