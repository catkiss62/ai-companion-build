#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOLDEN_SHA = '63a8c10f5fc097205f7be8649bf9a60974e02714ef550b54eb5bd74bbc58c5e7'
MANIFEST = ROOT / 'docs/TTS_GOLDEN_MANIFEST_v0.25.json'


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def fail(message: str) -> None:
    raise AssertionError(message)


def load_manifest() -> dict:
    data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if data.get('golden_apk_sha256') != GOLDEN_SHA:
        fail('golden manifest APK SHA mismatch')
    if len(data.get('assets', {})) != 31:
        fail('expected 31 packaged TTS assets (22 model + 9 runtime)')
    if len(data.get('native_libraries', {})) != 6:
        fail('expected 6 native TTS libraries')
    return data


def check_source_payload(manifest: dict) -> None:
    main = ROOT / 'android/app/src/main'
    for rel, expected in manifest['assets'].items():
        path = main / 'assets' / rel
        if not path.is_file():
            fail(f'missing TTS asset: {rel}')
        if path.stat().st_size != expected['size'] or sha_file(path) != expected['sha256']:
            fail(f'TTS asset fingerprint mismatch: {rel}')
    for name, expected in manifest['native_libraries'].items():
        path = main / 'jniLibs/arm64-v8a' / name
        if not path.is_file():
            fail(f'missing native TTS library: {name}')
        if path.stat().st_size != expected['size'] or sha_file(path) != expected['sha256']:
            fail(f'native TTS fingerprint mismatch: {name}')


def check_no_shell() -> None:
    forbidden_ext = {'.html', '.htm', '.js'}
    bad = [p.relative_to(ROOT) for p in ROOT.rglob('*') if p.is_file() and p.suffix.lower() in forbidden_ext]
    if bad:
        fail(f'HTML/JS shell leaked into AI Companion: {bad[:5]}')
    tts_sources = '\n'.join(
        p.read_text(encoding='utf-8', errors='ignore')
        for p in [
            ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt',
            ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt',
            ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt',
        ]
    )
    for token in ('WebView', 'JavascriptInterface', 'evaluateJavascript', 'loadUrl("javascript:'):
        if token in tts_sources:
            fail(f'TTS source still depends on historical shell: {token}')


def check_wiring() -> None:
    golden = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/TtsGoldenBaseline.kt').read_text()
    verifier = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/TtsArtifactVerifier.kt').read_text()
    legacy = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/LegacyTtsRuntime.kt').read_text()
    engine = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt').read_text()
    bridge = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsBridge.kt').read_text()
    provider = (ROOT / 'lib/core/tts/native_tts_provider.dart').read_text()
    service = (ROOT / 'lib/core/tts/tts_service.dart').read_text()
    queue = (ROOT / 'lib/core/tts/tts_playback_queue.dart').read_text()
    chat = (ROOT / 'lib/features/chat/chat_controller.dart').read_text()
    settings = (ROOT / 'lib/features/settings/settings_page.dart').read_text()

    expected = {
        'golden': ['GOLDEN_APK_SHA256', 'TOTAL_ARTIFACTS = 37'],
        'verifier': ['sha256AndSize', 'fingerprint mismatch', 'checked == TtsGoldenBaseline.TOTAL_ARTIFACTS'],
        'legacy': ['verifyArtifacts()', 'legacy_tts_v25_63a8c10f', 'cachedValid', 'Runtime copy fingerprint mismatch', 'target.setReadOnly()'],
        'engine': ['fun verifyArtifacts()', 'integrity.state', 'artifactCount', 'speechGeneration', 'speechLock'],
        'bridge': ['"verifyArtifacts"', 'tts_verify_failed', '"generate"', '"playAudio"', 'generationWorker', 'playbackWorker'],
        'provider': ["invokeMapMethod<Object?, Object?>('verifyArtifacts')", "invokeMethod<String>('generate'", "invokeMethod<void>('playAudio'"],
        'service': ['implements TtsQueueService', 'Future<TtsStatus> verifyArtifacts()', 'generatePrepared', 'playPrepared', 'Future<void> _recordError'],
        'queue': ['final TtsQueueService service', 'waitUntilIdle()', 'generation-ahead', 'interSentenceGap = const Duration(milliseconds: 200)'],
        'chat': ['if (delta.reasoning.isNotEmpty)', 'if (delta.content.isNotEmpty)', 'ttsPlayback.addDelta(delta.content)'],
        'settings': ['正在核对本地 TTS 与 MejuTTS v2.7 黄金资源', "label: const Text('校验 TTS')"],
    }
    values = dict(golden=golden, verifier=verifier, legacy=legacy, engine=engine, bridge=bridge,
                  provider=provider, service=service, queue=queue, chat=chat, settings=settings)
    for key, tokens in expected.items():
        for token in tokens:
            if token not in values[key]:
                fail(f'v0.25 TTS wiring missing in {key}: {token}')
    db = (ROOT / 'lib/core/database/app_database.dart').read_text()
    if "'tts_replacements_json': '{\"Yuki\":\"有希\"}'" not in db:
        fail('Yuki -> 有希 default spoken-text replacement regressed')


def check_test_sources() -> None:
    queue_test = (ROOT / 'test/tts_playback_queue_test.dart').read_text()
    for token in (
        'A2 generates later sentences while the first sentence is playing',
        'one generation failure does not poison later speech',
        'stream chunks preserve A2 sentence order',
    ):
        if token not in queue_test:
            fail(f'missing queue/cancel test: {token}')
    status_test = (ROOT / 'test/tts_provider_status_test.dart').read_text()
    if 'golden integrity status decodes from native map' not in status_test:
        fail('missing TTS integrity status test')


def compare_golden_apk(apk: Path, manifest: dict) -> None:
    if sha_file(apk) != GOLDEN_SHA:
        fail('supplied golden APK hash differs from recorded MejuTTS v2.7 baseline')
    main = ROOT / 'android/app/src/main'
    with zipfile.ZipFile(apk) as zf:
        names = set(zf.namelist())
        for rel in sorted(manifest['assets']):
            if rel.startswith('tts_models/'):
                apk_name = 'assets/' + rel
                if apk_name not in names:
                    fail(f'golden APK missing {apk_name}')
                src = (main / 'assets' / rel).read_bytes()
                if src != zf.read(apk_name):
                    fail(f'packaged source differs from golden APK: {rel}')
        for name in sorted(manifest['native_libraries']):
            apk_name = 'lib/arm64-v8a/' + name
            if (main / 'jniLibs/arm64-v8a' / name).read_bytes() != zf.read(apk_name):
                fail(f'native library differs from golden APK: {name}')

        runtime_dir = main / 'assets/legacy_tts/runtime'
        for i in range(1, 10):
            jar = runtime_dir / f'runtime_{i:02d}.jar'
            dex_name = 'classes.dex' if i == 1 else f'classes{i}.dex'
            with zipfile.ZipFile(jar) as rj:
                if rj.read('classes.dex') != zf.read(dex_name):
                    fail(f'runtime_{i:02d}.jar classes.dex differs from golden {dex_name}')
        with zipfile.ZipFile(runtime_dir / 'runtime_01.jar') as rj:
            for name in (
                'pinyin_dict_phrase.txt', 'pinyin_dict_char.txt', 'pinyin_dict_tone.txt',
                'pinyin_dict_phrase_define.txt', 'pinyin_dict_char_define.txt',
                'DebugProbesKt.bin', 'nlp/word_freq_dict.txt', 'nlp/chinese_ts_char.txt',
            ):
                if rj.read(name) != zf.read(name):
                    fail(f'runtime classpath resource differs from golden APK: {name}')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--golden-apk', type=Path)
    args = ap.parse_args()
    manifest = load_manifest()
    check_source_payload(manifest)
    print('[OK] 37 packaged TTS artifacts match v0.25 golden manifest')
    check_no_shell()
    print('[OK] HTML/WebView/JS shell excluded from AI Companion TTS')
    check_wiring()
    print('[OK] integrity/cache/cancel/error-isolation wiring present')
    check_test_sources()
    print('[OK] deterministic Dart queue/integrity test sources present')
    if args.golden_apk:
        compare_golden_apk(args.golden_apk, manifest)
        print('[OK] source TTS payload matches user-supplied MejuTTS v2.7 golden APK')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
