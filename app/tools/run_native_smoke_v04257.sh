#!/usr/bin/env bash
# Keep the emulator alive until the production galaxy render is captured.
set -uo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
chmod +x "${task_root}/app/android/gradlew"
cd "${task_root}/app/android" || exit 1
if ./gradlew -p ../tools/caicai_smoke connectedDebugAndroidTest --stacktrace; then
  test_status=0
else
  test_status=$?
fi
preview_dir="${task_root}/app/tools/caicai_smoke/build/outputs/androidTest-results/galaxy-preview"
mkdir -p "${preview_dir}"
adb pull /sdcard/Android/data/com.catkiss.senlive2dcompanion.smoke/files/memory-galaxy-640-render.png \
  "${preview_dir}/memory-galaxy-640-render.png" || true
exit "${test_status}"
