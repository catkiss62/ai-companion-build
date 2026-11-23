#!/usr/bin/env bash
# Complete and sign the CI base using the package-bound Sense license and the
# private runtime inputs. No SDK, author VRM or signing credential is published.
# Arguments: CI base APK, pinned AR 0.25 source, extracted SDK, host license,
# AR packaging tools, character-api.jar, verified motions directory, output APK.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
base=$(realpath "$1"); src=$(realpath "$2"); sdk=$(realpath "$3"); license=$(realpath "$4")
tools=$(realpath "$5"); api=$(realpath "$6"); motions=$(realpath "$7"); out=$(realpath -m "$8")
: "${APK_SIGNER_JAR:?}" "${AI_COMPANION_KEYSTORE_PATH:?}" "${AI_COMPANION_KEY_PASSWORD_FILE:?}"
[[ $(git -C "$src" rev-parse HEAD) = fa4ce7f538310690a22dbea88dd461e24731ca50 ]]
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/overlay/src" "$work/provided"
cp -R "$src/app" "$work/overlay/src/"
mkdir "$work/overlay/src/scripts"
cp "$src/scripts/package-easyar.sh" "$work/overlay/src/scripts/"
cp -R "$src/docs" "$work/overlay/src/"
(cd "$work/overlay/src" && git apply --no-index "$here/host-theme.patch")
java -m jdk.compiler/com.sun.tools.javac.Main -source 8 -target 8 -cp "$tools/android.jar" -d "$work/provided" "$here/../../android/app/src/main/java/dev/littlewhale/ar/CompanionArStyle.java"
cp "$api" "$work/character-api.jar"
jar uf "$work/character-api.jar" -C "$work/provided" .
ln -s "$motions" "$work/motions"
cp "$base" "$work/base.apk"
export LD_LIBRARY_PATH="$tools/lib64:${LD_LIBRARY_PATH:-}"
bash "$work/overlay/src/scripts/package-easyar.sh" "$sdk" "$license" "$tools" "$work/base.apk" "$work/complete.apk"
java -jar "$APK_SIGNER_JAR" sign --ks "$AI_COMPANION_KEYSTORE_PATH" --ks-key-alias ai-companion-private-test-v1 \
  --ks-pass "file:$AI_COMPANION_KEY_PASSWORD_FILE" --v4-signing-enabled false --out "$out" "$work/complete.apk"
"$tools/zipalign" -c -P 16 4 "$out"
java -jar "$APK_SIGNER_JAR" verify --print-certs "$out" >"$work/final.cert"
java -jar "$APK_SIGNER_JAR" verify --print-certs "$base" >"$work/base.cert"
diff <(grep 'certificate SHA-256 digest:' "$work/base.cert") <(grep 'certificate SHA-256 digest:' "$work/final.cert")
"$tools/aapt" dump badging "$out" | grep -F "name='com.aicompanion.localfirst'"
cmp "$license" <(unzip -p "$out" assets/easyar-license.txt)
