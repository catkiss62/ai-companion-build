#!/usr/bin/env bash
# Keep the emulator alive until the production galaxy render is captured.
set -uo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
chmod +x "${task_root}/app/android/gradlew"
cd "${task_root}/app/android" || exit 1
adb shell rm -f /data/local/tmp/reminder-compact.png /data/local/tmp/memory-galaxy-640-render.png || exit 1
if ./gradlew -p ../tools/caicai_smoke connectedDebugAndroidTest --stacktrace; then
  test_status=0
else
  test_status=$?
fi
preview_dir="${task_root}/app/tools/caicai_smoke/build/outputs/androidTest-results/galaxy-preview"
mkdir -p "${preview_dir}"
if adb pull /data/local/tmp/memory-galaxy-640-render.png \
    "${preview_dir}/memory-galaxy-640-render.png" && \
    [ -s "${preview_dir}/memory-galaxy-640-render.png" ]; then
  :
elif [ "${test_status}" -eq 0 ]; then
  echo 'Native tests passed but the verified galaxy render PNG was not retained.' >&2
  exit 1
fi
if adb pull /data/local/tmp/reminder-compact.png "${preview_dir}/reminder-compact.png" && [ -s "${preview_dir}/reminder-compact.png" ]; then
  :
elif [ "${test_status}" -eq 0 ]; then
  echo 'Reminder render PNG missing after successful native tests.' >&2
  exit 1
fi
exit "${test_status}"
