#!/usr/bin/env python3
"""Static and binary contracts for the v0.39.5 Meju local-TTS upgrade."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "android/app/src/main"
MANIFEST = ROOT / "docs/TTS_RUNTIME_MANIFEST_v0.39.5.json"
ENGINE = "Lcom/gamedeveloper/urbanfriendshipstory/tts/LocalTTSEngine;"
CONTINUATION = "Lkotlin/coroutines/Continuation;"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
assert manifest["source_sha256"] == "b72ebc8544de88ee368946d2ac824ea1641377ddbe6e2da378d4112c379a9671"
assert manifest["max_phones_zh"] == 300
assert len(manifest["assets"]) == 27
assert len(manifest["native_libraries"]) == 5

for relative, expected in manifest["assets"].items():
    path = MAIN / "assets" / relative
    assert path.is_file(), relative
    assert path.stat().st_size == expected["size"], relative
    assert sha256(path) == expected["sha256"], relative
for name, expected in manifest["native_libraries"].items():
    path = MAIN / "jniLibs/arm64-v8a" / name
    assert path.is_file(), name
    assert path.stat().st_size == expected["size"], name
    assert sha256(path) == expected["sha256"], name

runtime_dir = MAIN / "assets/legacy_tts/runtime"
pinyin_dir = MAIN / "assets/legacy_tts/pinyin"
assert [path.name for path in sorted(runtime_dir.glob("runtime_*.jar"))] == [
    "runtime_01.jar",
    "runtime_02.jar",
]
assert len([path for path in pinyin_dir.iterdir() if path.is_file()]) == 5
assert not (MAIN / "jniLibs/arm64-v8a/libMNN_Vulkan.so").exists()
for old_path in (
    "tts_models/bert/tokenizer.json",
    "tts_models/bv2_model/meju_enc_p.mnn",
    "tts_models/preprocess/dict/jieba.dict.utf8",
):
    assert not (MAIN / "assets" / old_path).exists(), old_path


def dex_engine_methods(data: bytes) -> dict[str, list[list[str]]]:
    u4 = lambda offset: struct.unpack_from("<I", data, offset)[0]
    u2 = lambda offset: struct.unpack_from("<H", data, offset)[0]
    string_ids_off = u4(60)
    type_ids_size, type_ids_off = u4(64), u4(68)
    proto_ids_size, proto_ids_off = u4(72), u4(76)
    method_ids_size, method_ids_off = u4(88), u4(92)

    def uleb(offset: int) -> tuple[int, int]:
        result = 0
        shift = 0
        while True:
            value = data[offset]
            offset += 1
            result |= (value & 0x7F) << shift
            if value < 0x80:
                return result, offset
            shift += 7

    def string(index: int) -> str:
        offset = u4(string_ids_off + 4 * index)
        _, offset = uleb(offset)
        end = data.index(b"\0", offset)
        return data[offset:end].decode("utf-8", "replace")

    types = [string(u4(type_ids_off + 4 * index)) for index in range(type_ids_size)]
    protos: list[list[str]] = []
    for index in range(proto_ids_size):
        _, _, parameters_offset = struct.unpack_from("<III", data, proto_ids_off + 12 * index)
        parameters: list[str] = []
        if parameters_offset:
            count = u4(parameters_offset)
            parameters = [types[u2(parameters_offset + 4 + 2 * item)] for item in range(count)]
        protos.append(parameters)

    result: dict[str, list[list[str]]] = {}
    for index in range(method_ids_size):
        class_index, proto_index, name_index = struct.unpack_from(
            "<HHI", data, method_ids_off + 8 * index
        )
        if types[class_index] == ENGINE:
            result.setdefault(string(name_index), []).append(protos[proto_index])
    return result


methods: dict[str, list[list[str]]] = {}
for runtime in sorted(runtime_dir.glob("runtime_*.jar")):
    with zipfile.ZipFile(runtime) as archive:
        found = dex_engine_methods(archive.read("classes.dex"))
    for name, signatures in found.items():
        methods.setdefault(name, []).extend(signatures)
assert [CONTINUATION] in methods.get("initialize", [])
assert [["Ljava/lang/String;", CONTINUATION]][0] in methods.get("generateTTS", [])
assert [["F", CONTINUATION]][0] in methods.get("setLengthScale", [])
assert [CONTINUATION] in methods.get("release", [])

legacy = read("android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt")
for token in (
    'getField("ZH")',
    'markDiagnosticStage("language_zh")',
    "fun generateWavBytes(text: String): ByteArray",
    "is ByteArray -> value",
    "private fun validateWav(wav: ByteArray)",
    "buildRuntimeJarWithPinyin",
    'PINYIN_ASSET_DIR = "legacy_tts/pinyin"',
    'RUNTIME_CACHE_DIR = "meju_tts_v395_b72ebc85"',
    "private class RuntimeDexClassLoader",
    "findClass(name)",
    "synchronized(this)",
    "internal fun isAlwaysParentFirstClass",
    'LOADER_POLICY = "payload_child_first"',
    "fun failureDiagnosticMetadata(error: Throwable)",
):
    assert token in legacy, token
assert "getClassLoadingLock" not in legacy

engine = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt")
bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt")
verifier = read("android/app/src/main/kotlin/com/aicompanion/localfirst/TtsArtifactVerifier.kt")
provider = read("lib/core/tts/native_tts_provider.dart")
queue = read("lib/core/tts/tts_playback_queue.dart")
segmenter = read("lib/core/tts/tts_sentence_segmenter.dart")
emotion = read("lib/core/tts/emotion_sound_service.dart")
for token in (
    "fun generate(text: String, generation: Long = generationToken()): ByteArray?",
    "fun playAudio(wav: ByteArray",
    "speechGeneration",
    "speechLock",
    "allowing sentence N+1 to infer while sentence N is audible",
    "metadata = runtime.failureDiagnosticMetadata(t)",
):
    assert token in engine, token
diagnostic_store = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/RuntimeDiagnosticStore.kt",
)
for token in ("loaderPolicy", "failureType", "failureTarget"):
    assert token in diagnostic_store, token
assert 'call.argument<ByteArray>("audioData")' in bridge
assert "appContext.assets.open(path).use { true }" in verifier
assert "it.read() >= 0" not in verifier
assert "invokeMethod<Uint8List>('generate'" in provider
assert "Future<void> playAudio(Uint8List wavBytes)" in provider
assert "Map<int, Uint8List?>" in queue
assert "generation-ahead" in queue and "service.playPrepared(audio)" in queue
assert "maxSafeChunkChars = 72" in segmenter and "_findSafetyBoundary" in segmenter
assert "Future<void> play(String wavBase64)" in emotion

queue_test = read("test/tts_playback_queue_test.dart")
segmenter_test = read("test/tts_sentence_segmenter_test.dart")
for token in (
    "A2 generates later sentences while the first sentence is playing",
    "stop invalidates generated/queued audio that has not played",
    "lead-in audio and TTS synthesis run in parallel",
):
    assert token in queue_test, token
assert "exceptional long runs stay below the new engine safety cap" in segmenter_test

pubspec = read("pubspec.yaml")
assert re.search(r"^version: (?:0\.39\.(?:5\+123|6\+124|7\+125|8\+126|9\+127)|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132))$", pubspec, re.MULTILINE)
assert re.search(
    r"static const int schemaVersion = (?:35|36|39|40);",
    read("lib/core/database/app_database.dart"),
)
workflow = read("../.github/workflows/build-apk.yml")
assert any(
    branch in workflow
    for branch in (
        "agent/v0395-meju-tts-runtime-upgrade",
        "agent/v0396-rule02-message-sound",
        "agent/v0397-reasoning-translation-dialogue-boundary",
        "agent/v0399-user-address-viewpoint",
    )
)
assert "python3 tools/validate_v0395_meju_tts_runtime_upgrade.py" in workflow
assert any(
    artifact in workflow
    for artifact in (
        "AI-Companion-v0.39.5-123-Meju-TTS-Runtime-Upgrade-APK",
        "AI-Companion-v0.39.6-124-Rule02-Notification-Sounds-APK",
        "AI-Companion-v0.39.7-125-Reasoning-Translation-Spoken-Line-APK",
        "AI-Companion-v0.39.9-127-User-Address-Viewpoint-APK",
    )
)
for token in (
    "v0.39.8-rule-refresh-immersive-control-parser",
    "AI-Companion-v0.39.8-126-Rule-Refresh-Immersive-Control-Action-Parser-APK.apk",
    "97356942dbf50cc5bd5abb726e9679f3c28316be38bde029d449f8ce57d2e6b8",
    "assets/legacy_tts/pinyin",
):
    assert token in workflow, token
ledger = read("../AI_Companion_当前总账.md")
assert "v0.39.5 新版妹居 TTS 运行时迁移" in ledger

print("v0.39.5 upgraded Meju local-TTS runtime contracts passed")
