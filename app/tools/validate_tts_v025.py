#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA = 'b72ebc8544de88ee368946d2ac824ea1641377ddbe6e2da378d4112c379a9671'
MANIFEST = ROOT / 'docs/TTS_RUNTIME_MANIFEST_v0.39.5.json'


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
    if data.get('source_sha256') != SOURCE_SHA:
        fail('upgraded TTS source SHA mismatch')
    if len(data.get('assets', {})) != 27:
        fail('expected 27 packaged TTS assets (20 model/preprocess + 7 runtime/pinyin)')
    if len(data.get('native_libraries', {})) != 5:
        fail('expected 5 native TTS libraries')
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
    # v0.41.18 moved the shared TTS controls out of the historical monolithic
    # settings page.  Keep validating the real control surface instead of
    # pinning the contract to the retired file location/copy.
    settings = (ROOT / 'lib/features/chat/chat_quick_settings_pages.dart').read_text()

    expected = {
        'golden': ['GOLDEN_APK_SHA256', 'TOTAL_ARTIFACTS = 32', 'b72ebc8544de'],
        'verifier': ['sha256AndSize', 'fingerprint mismatch', 'checked == TtsGoldenBaseline.TOTAL_ARTIFACTS'],
        'legacy': ['verifyArtifacts()', 'meju_tts_v395_b72ebc85', 'buildRuntimeJarWithPinyin', 'language_zh', 'generateWavBytes', 'validateWav', 'target.setReadOnly()'],
        'engine': ['fun verifyArtifacts()', 'integrity.state', 'artifactCount', 'speechGeneration', 'speechLock'],
        'bridge': ['"verifyArtifacts"', 'tts_verify_failed', '"generate"', '"playAudio"', 'generationWorker', 'playbackWorker'],
        'provider': ["invokeMapMethod<Object?, Object?>('verifyArtifacts')", "invokeMethod<Uint8List>('generate'", "invokeMethod<void>('playAudio'"],
        'service': ['implements TtsQueueService', 'Future<TtsStatus> verifyArtifacts()', 'generatePrepared', 'playPrepared', 'Future<void> _recordError'],
        'queue': ['final TtsQueueService service', 'waitUntilIdle()', 'generation-ahead', 'interSentenceGap = const Duration(milliseconds: 200)'],
        'chat': ['if (delta.reasoning.isNotEmpty)', 'if (delta.content.isNotEmpty)', 'ttsPlayback.addDelta(delta.content)'],
        'settings': ['正在校验本地 TTS 资源', "label: const Text('校验资源')"],
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


def compare_golden_apk(source: Path, manifest: dict) -> None:
    del manifest
    if sha_file(source) != SOURCE_SHA:
        fail('supplied complete package differs from the recorded upgraded TTS source')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--golden-apk', type=Path)
    args = ap.parse_args()
    manifest = load_manifest()
    check_source_payload(manifest)
    print('[OK] 32 packaged TTS artifacts match the v0.39.5 upgraded runtime manifest')
    check_no_shell()
    print('[OK] HTML/WebView/JS shell excluded from AI Companion TTS')
    check_wiring()
    print('[OK] integrity/cache/cancel/error-isolation wiring present')
    check_test_sources()
    print('[OK] deterministic Dart queue/integrity test sources present')
    if args.golden_apk:
        compare_golden_apk(args.golden_apk, manifest)
        print('[OK] source package matches the user-supplied upgraded TTS archive')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
