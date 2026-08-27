#!/usr/bin/env python3
from __future__ import annotations

import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / 'android/app/src/main/assets/legacy_tts/runtime'
SOURCE = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt'
ENGINE = 'Lcom/gamedeveloper/urbanfriendshipstory/tts/LocalTTSEngine;'
CONT = 'Lkotlin/coroutines/Continuation;'


def dex_engine_methods(data: bytes) -> dict[str, list[list[str]]]:
    u4 = lambda o: struct.unpack_from('<I', data, o)[0]
    u2 = lambda o: struct.unpack_from('<H', data, o)[0]
    string_ids_size, string_ids_off = u4(56), u4(60)
    type_ids_size, type_ids_off = u4(64), u4(68)
    proto_ids_size, proto_ids_off = u4(72), u4(76)
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
    protos: list[list[str]] = []
    for i in range(proto_ids_size):
        _, _, params_off = struct.unpack_from('<III', data, proto_ids_off + 12 * i)
        params: list[str] = []
        if params_off:
            count = u4(params_off)
            params = [types[u2(params_off + 4 + 2 * j)] for j in range(count)]
        protos.append(params)

    found: dict[str, list[list[str]]] = {}
    for i in range(method_ids_size):
        class_idx, proto_idx, name_idx = struct.unpack_from('<HHI', data, method_ids_off + 8 * i)
        if types[class_idx] != ENGINE:
            continue
        found.setdefault(get_string(name_idx), []).append(protos[proto_idx])
    return found


def main() -> int:
    methods: dict[str, list[list[str]]] = {}
    for runtime in sorted(RUNTIME_DIR.glob('runtime_*.jar')):
        with zipfile.ZipFile(runtime) as zf:
            found = dex_engine_methods(zf.read('classes.dex'))
        for name, signatures in found.items():
            methods.setdefault(name, []).extend(signatures)
    assert [CONT] in methods.get('initialize', []), methods.get('initialize')
    assert ['Ljava/lang/String;', CONT] in methods.get('generateTTS', []), methods.get('generateTTS')

    source = SOURCE.read_text(encoding='utf-8')
    assert 'Continuation::class.java' not in source
    assert 'import kotlin.coroutines.' not in source
    for required in [
        'findLegacySuspendMethod',
        'Proxy.newProxyInstance',
        'LEGACY_CONTINUATION_CLASS',
        'LEGACY_COROUTINE_CONTEXT_CLASS',
        'decodeLegacyResult',
    ]:
        assert required in source, required

    print('v0.28.4 legacy coroutine bridge validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
