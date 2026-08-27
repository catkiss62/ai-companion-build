#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

UPGRADED_SIZE = 690_920
UPGRADED_SHA = 'a6f11da0df792a82820b833f1b6951078179d16c4e15dd8a6abc18d52d227f08'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    version = re.search(
        r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$',
        pubspec,
        re.MULTILINE,
    )
    assert version is not None
    assert tuple(map(int, version.groups())) >= (0, 29, 0, 34)

    native = ROOT / 'android/app/src/main/jniLibs/arm64-v8a/libbertvits2.so'
    data = native.read_bytes()
    assert len(data) == UPGRADED_SIZE, len(data)
    assert sha(data) == UPGRADED_SHA
    print('[OK] libbertvits2.so matches the user-validated upgraded local runtime')

    segmenter = (ROOT / 'lib/core/tts/tts_sentence_segmenter.dart').read_text(encoding='utf-8')
    for token in ["c == '。'", "c == '！'", "c == '？'", "c == '；'", "c == '.'", "c == '!'", "c == '?'", "c == ';'"]:
        assert token in segmenter, token
    for forbidden in ["c == '…'", "c == '\\n' &&"]:
        assert forbidden not in segmenter, forbidden
    assert 'maxSafeChunkChars = 72' in segmenter
    assert '_findSafetyBoundary' in segmenter
    print('[OK] A2 punctuation remains primary with a 72-character max-phone safety fallback')

    processor = (ROOT / 'lib/core/tts/tts_text_processor.dart').read_text(encoding='utf-8')
    for token in ["RegExp(r'\\bYuki\\b'", "RegExp(r'<[^>]*>')", "RegExp(r'\\{[^}]*\\}')", "RegExp(r'\\[[^\\]]*\\]')", "RegExp(r'【[^】]*】')"]:
        assert token in processor, token
    assert (
        (
            "RegExp(r'\\([^)]*\\)')" in processor
            and "RegExp(r'（[^）]*）')" in processor
        )
        or "ChatSegmentCodec.parseAssistantText(text)" in processor
    )
    print('[OK] A2 speech-only Yuki/bracket preprocessing preserved')

    queue = (ROOT / 'lib/core/tts/tts_playback_queue.dart').read_text(encoding='utf-8')
    assert 'interSentenceGap = const Duration(milliseconds: 200)' in queue
    assert 'service.generatePrepared(' in queue
    assert 'text,\n          emotion: session.emotion,' in queue
    assert 'service.playPrepared(audio)' in queue
    assert 'audio = await service.generatePrepared(' in queue  # inside independent async task, not playback chain
    assert '_hasPlayableReady(session)' in queue
    assert '_tail = _tail.then' not in queue
    print('[OK] A2 generation-ahead queue replaces serial generate+play tail')

    bridge = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt').read_text(encoding='utf-8')
    engine = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt').read_text(encoding='utf-8')
    for token in ['generationWorker', 'playbackWorker', '"generate"', '"playAudio"']:
        assert token in bridge, token
    assert 'fun generate(text: String' in engine
    assert 'fun playAudio(wav: ByteArray' in engine
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
