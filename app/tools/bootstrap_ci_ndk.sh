#!/usr/bin/env bash
# Keep the app's pinned Genie NDK and Flutter plugins' NDK unchanged. A failed
# SDK download must never be reused as an installed package on the next retry.
set -euo pipefail

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:?Android SDK root is required}}"
sdk_manager="${CI_NDK_SDKMANAGER:-${sdk_root}/cmdline-tools/latest/bin/sdkmanager}"
stage=''
trap 'if [[ -n "$stage" ]]; then rm -rf -- "$stage"; fi' EXIT

valid_ndk() {
  local directory="$1" revision="$2"
  [[ -f "$directory/source.properties" ]] &&
    grep -Fqx "Pkg.Revision = $revision" "$directory/source.properties" &&
    [[ -x "$directory/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]] &&
    "$directory/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" --version >/dev/null 2>&1
}

for revision in 27.2.12479018 28.2.13676358; do
  target="${sdk_root}/ndk/${revision}"
  if valid_ndk "$target" "$revision"; then
    echo "NDK $revision already verified."
    continue
  fi
  installed=false
  for attempt in 1 2 3; do
    stage=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ai-companion-ndk-${revision}.XXXXXX")
    if [[ -d "$sdk_root/licenses" ]]; then
      cp -a "$sdk_root/licenses" "$stage/licenses"
    fi
    echo "Installing NDK $revision, attempt $attempt/3 (fresh SDK staging directory)."
    if timeout "${CI_NDK_INSTALL_TIMEOUT_SECONDS:-180}" "$sdk_manager" \
        --sdk_root="$stage" --install "ndk;$revision" &&
        valid_ndk "$stage/ndk/$revision" "$revision"; then
      mkdir -p "$sdk_root/ndk"
      # Only this explicitly requested, invalid package may be replaced.
      rm -rf -- "$target"
      mv "$stage/ndk/$revision" "$target"
      installed=true
    fi
    rm -rf -- "$stage"
    stage=''
    if [[ "$installed" == true ]]; then
      echo "NDK $revision revision and executable verified."
      break
    fi
    if [[ "$attempt" != 3 ]]; then sleep "${CI_NDK_RETRY_DELAY_SECONDS:-5}"; fi
  done
  if [[ "$installed" != true ]]; then
    echo "NDK $revision could not be installed and verified after 3 attempts." >&2
    exit 1
  fi
done
