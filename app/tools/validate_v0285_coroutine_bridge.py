#!/usr/bin/env python3
from __future__ import annotations

import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'android/app/src/main/assets/legacy_tts/runtime/runtime_01.jar'
LEGACY = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt'
ENGINE = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt'
BRIDGE = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt'
PROVIDER = ROOT / 'lib/core/tts/tts_provider.dart'
NATIVE_PROVIDER = ROOT / 'lib/core/tts/native_tts_provider.dart'
CHECKPOINT = ROOT / 'lib/features/system/real_device_checkpoint_page.dart'


def dex_fields_and_methods(data: bytes, target: str) -> tuple[set[str], set[str]]:
    u4 = lambda o: struct.unpack_from('<I', data, o)[0]
    string_ids_off = u4(60)
    type_ids_size, type_ids_off = u4(64), u4(68)
    field_ids_size, field_ids_off = u4(80), u4(84)
    method_ids_size, method_ids_off = u4(88), u4(92)

    def uleb(off: int) -> tuple[int, int]:
        result = 0
        shift = 0
        while True:
            b = data[off]
            off += 1
            result |= (b & 0x7F) << shift
            if b < 0x80:
                return result, off
            shift += 7

    def get_string(i: int) -> str:
        off = u4(string_ids_off + 4 * i)
        _, off = uleb(off)
        end = data.index(b'\0', off)
        return data[off:end].decode('utf-8', 'replace')

    types = [get_string(u4(type_ids_off + 4 * i)) for i in range(type_ids_size)]
    fields: set[str] = set()
    for i in range(field_ids_size):
        class_idx, _type_idx, name_idx = struct.unpack_from('<HHI', data, field_ids_off + 8 * i)
        if types[class_idx] == target:
            fields.add(get_string(name_idx))
    methods: set[str] = set()
    for i in range(method_ids_size):
        class_idx, _proto_idx, name_idx = struct.unpack_from('<HHI', data, method_ids_off + 8 * i)
        if types[class_idx] == target:
            methods.add(get_string(name_idx))
    return fields, methods


def main() -> int:
    with zipfile.ZipFile(RUNTIME) as zf:
        dex = zf.read('classes.dex')
    empty_fields, _ = dex_fields_and_methods(dex, 'Lkotlin/coroutines/EmptyCoroutineContext;')
    _, continuation_methods = dex_fields_and_methods(dex, 'Lkotlin/coroutines/Continuation;')
    assert 'INSTANCE' in empty_fields, empty_fields
    assert {'getContext', 'resumeWith'} <= continuation_methods, continuation_methods

    legacy = LEGACY.read_text(encoding='utf-8')
    # v0.28.5 must not look up Kotlin singleton/static marker names at runtime.
    for forbidden in [
        'LEGACY_EMPTY_CONTEXT_CLASS',
        'LEGACY_INTRINSICS_CLASS',
        'getField("INSTANCE")',
        'getCOROUTINE_SUSPENDED',
        'Class.forName(',
    ]:
        assert forbidden not in legacy, forbidden
    for required in [
        'createEmptyCoroutineContext',
        'LEGACY_COROUTINE_CONTEXT_CLASS',
        'called.parameterCount == 0 && called.returnType == contextType',
        'called.parameterCount == 1 && called.returnType == Void.TYPE',
        'isCoroutineSuspended',
        'decodeLegacyResult',
        'diagnoseWavBase64',
        'markDiagnosticStage("coroutine_context")',
        'markDiagnosticStage("continuation_proxy")',
    ]:
        assert required in legacy, required

    engine = ENGINE.read_text(encoding='utf-8')
    for required in [
        'fun diagnose(): Map<String, Any>',
        'runtime.diagnoseWavBase64(DIAGNOSTIC_TEXT)',
        'riff != "RIFF" || wave != "WAVE"',
        'runtime.markDiagnosticStage("wav_header")',
        '"diagnosticTrace" to runtime.diagnosticTrace()',
    ]:
        assert required in engine, required

    bridge = BRIDGE.read_text(encoding='utf-8')
    assert '"diagnose" -> submit(generationWorker, result, "tts_diagnose_failed")' in bridge

    provider = PROVIDER.read_text(encoding='utf-8')
    assert 'Future<TtsStatus> diagnose();' in provider
    assert 'final List<String> diagnosticTrace;' in provider
    native_provider = NATIVE_PROVIDER.read_text(encoding='utf-8')
    assert "invokeMapMethod<Object?, Object?>('diagnose')" in native_provider

    checkpoint = CHECKPOINT.read_text(encoding='utf-8')
    assert 'TTS 分阶段桥接诊断' in checkpoint
    assert '运行分阶段诊断' in checkpoint
    assert "'wav_header' => 'RIFF/WAVE 校验'" in checkpoint

    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert any(v in pubspec for v in ['version: 0.28.5+33', 'version: 0.29.0+34', 'version: 0.29.1+35', 'version: 0.30.0+36', 'version: 0.30.1+37', 'version: 0.30.2+38', 'version: 0.30.3+39', 'version: 0.31.0+40'])

    print('v0.28.5 coroutine/ClassLoader bridge invariant retained in current source.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
