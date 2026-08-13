#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ORIGINAL_ELF_SIZE = 635_352
ORIGINAL_ELF_SHA = 'a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b'
PADDED_SIZE = 710_848
PADDED_SHA = 'a599d482539fdbe01ccd82a9c688d0dce574c19dd681b15fd580185890e65792'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert any(v in pubspec for v in ['version: 0.29.0+34', 'version: 0.29.1+35', 'version: 0.30.0+36', 'version: 0.30.1+37', 'version: 0.30.2+38', 'version: 0.30.3+39', 'version: 0.31.0+40', 'version: 0.31.1+41', 'version: 0.31.2+42', 'version: 0.31.2+43', 'version: 0.31.2+44', 'version: 0.31.3+45'])

    native = ROOT / 'android/app/src/main/jniLibs/arm64-v8a/libbertvits2.so'
    data = native.read_bytes()
    assert len(data) == PADDED_SIZE, len(data)
    assert sha(data) == PADDED_SHA
    assert sha(data[:ORIGINAL_ELF_SIZE]) == ORIGINAL_ELF_SHA
    assert set(data[ORIGINAL_ELF_SIZE:]) <= {0}
    print('[OK] libbertvits2.so is the verified original 635352-byte A2 ELF plus zero alignment padding')

    segmenter = (ROOT / 'lib/core/tts/tts_sentence_segmenter.dart').read_text(encoding='utf-8')
    for token in ["c == '。'", "c == '！'", "c == '？'", "c == '；'", "c == '.'", "c == '!'", "c == '?'", "c == ';'"]:
        assert token in segmenter, token
    for forbidden in ['softLimit', 'hardLimit', "const candidates = '，,、：: \\n'", "c == '…'", "c == '\\n' &&"]:
        assert forbidden not in segmenter, forbidden
    print('[OK] A2 splitter has no comma/newline/ellipsis/length fallback')

    processor = (ROOT / 'lib/core/tts/tts_text_processor.dart').read_text(encoding='utf-8')
    for token in ["RegExp(r'\\bYuki\\b'", "RegExp(r'\\([^)]*\\)')", "RegExp(r'（[^）]*）')", "RegExp(r'<[^>]*>')", "RegExp(r'\\{[^}]*\\}')", "RegExp(r'\\[[^\\]]*\\]')", "RegExp(r'【[^】]*】')"]:
        assert token in processor, token
    print('[OK] A2 speech-only Yuki/bracket preprocessing preserved')

    queue = (ROOT / 'lib/core/tts/tts_playback_queue.dart').read_text(encoding='utf-8')
    assert 'interSentenceGap = const Duration(milliseconds: 200)' in queue
    assert 'service.generatePrepared(text)' in queue
    assert 'service.playPrepared(audio)' in queue
    assert 'await service.generatePrepared(text)' in queue  # inside independent async task, not playback chain
    assert '_hasPlayableReady(session)' in queue
    assert '_tail = _tail.then' not in queue
    print('[OK] A2 generation-ahead queue replaces serial generate+play tail')

    bridge = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt').read_text(encoding='utf-8')
    engine = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt').read_text(encoding='utf-8')
    for token in ['generationWorker', 'playbackWorker', '"generate"', '"playAudio"']:
        assert token in bridge, token
    assert 'fun generate(text: String' in engine
    assert 'fun playAudio(base64: String' in engine
    assert 'allowing sentence N+1 to infer while sentence N is audible' in engine
    print('[OK] native inference and AudioTrack workers are separated with one serialized MNN generator')

    legacy = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt').read_text(encoding='utf-8')
    assert 'getField("INSTANCE")' not in legacy
    assert 'Class.forName("kotlin.coroutines.EmptyCoroutineContext"' not in legacy
    assert 'getField("COROUTINE_SUSPENDED")' not in legacy
    print('[OK] v0.28.5 legacy coroutine/ClassLoader fix retained')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
