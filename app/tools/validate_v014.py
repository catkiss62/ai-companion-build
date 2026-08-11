#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def fail(msg: str) -> None:
    raise AssertionError(msg)


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check_xml() -> None:
    for path in (ROOT / 'android' / 'app' / 'src' / 'main').rglob('*.xml'):
        ET.parse(path)


def check_manifest() -> None:
    path = ROOT / 'android/app/src/main/AndroidManifest.xml'
    tree = ET.parse(path)
    root = tree.getroot()
    permissions = root.findall('uses-permission')
    names = {p.attrib.get(ANDROID + 'name') for p in permissions}
    if 'android.permission.RECEIVE_BOOT_COMPLETED' not in names:
        fail('RECEIVE_BOOT_COMPLETED missing')
    by_name = {p.attrib.get(ANDROID + 'name'): p for p in permissions}
    fine = by_name.get('android.permission.ACCESS_FINE_LOCATION')
    if fine is None or fine.attrib.get(ANDROID + 'maxSdkVersion') != '32':
        fail('ACCESS_FINE_LOCATION must remain available through API 32')
    if 'android.permission.NEARBY_WIFI_DEVICES' not in by_name:
        fail('NEARBY_WIFI_DEVICES declaration missing')
    app = root.find('application')
    if app is None:
        fail('application missing')
    receiver = next((r for r in app.findall('receiver') if r.attrib.get(ANDROID+'name') == '.CompanionBootReceiver'), None)
    if receiver is None:
        fail('CompanionBootReceiver missing')
    service = next((s for s in app.findall('service') if s.attrib.get(ANDROID+'name') == '.OverlayBubbleService'), None)
    if service is None or service.attrib.get(ANDROID+'foregroundServiceType') != 'specialUse':
        fail('OverlayBubbleService specialUse declaration missing')


def check_kotlin_patterns() -> None:
    kroot = ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst'
    nearby = (kroot / 'NearbyTransferManager.kt').read_text(encoding='utf-8')
    if nearby.count('Payload.Type.BYTES ->') != 1:
        fail('Nearby Payload.Type.BYTES branch count != 1')
    for token in ('ConcurrentHashMap<String, (Map<String, Any?>) -> Unit>', 'fun addListener(', 'fun removeListener('):
        if token not in nearby:
            fail(f'Nearby multi-listener token missing: {token}')
    for token in ('MAX_NEARBY_PAYLOAD_BYTES', 'update.totalBytes > MAX_NEARBY_PAYLOAD_BYTES', 'client.cancelPayload(update.payloadId)'):
        if token not in nearby:
            fail(f'Nearby incoming payload size guard missing: {token}')

    notification = (kroot / 'NotificationBridgeService.kt').read_text(encoding='utf-8')
    if 'override fun onListenerDisconnected()' not in notification or 'requestRebind(' not in notification:
        fail('NotificationListener rebind path missing')

    accessibility = (kroot / 'AccessibilityBridgeService.kt').read_text(encoding='utf-8')
    for token in ('override fun onServiceConnected()', 'override fun onInterrupt()', 'setAccessibilityConnected(false)'):
        if token not in accessibility:
            fail(f'Accessibility lifecycle token missing: {token}')

    overlay = (kroot / 'OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in (
        'TYPE_APPLICATION_OVERLAY', 'ACTION_SHOW_CHAT', 'ACTION_COLLAPSE_CHAT',
        'FLAG_NOT_FOCUSABLE', 'FLAG_NOT_TOUCH_MODAL', 'FLAG_WATCH_OUTSIDE_TOUCH',
        'class OverlayEditText', 'BACKGROUND_COMMAND_CHANNEL', 'loadOlderMessages',
        'collapseChatOverlay(', 'enterChatInputMode()', 'pendingShowAfterUnlock',
    ):
        if token not in overlay:
            fail(f'true overlay token missing: {token}')
    if 'import io.flutter.embedding.android.FlutterView' in overlay:
        fail('Service overlay must not host FlutterView directly')
    if (kroot / 'OverlayChatActivity.kt').exists():
        fail('transitional OverlayChatActivity still exists')

    companion_notification = (kroot / 'CompanionNotification.kt').read_text(encoding='utf-8')
    for token in ('PendingIntent.getForegroundService', 'OverlayBubbleService.ACTION_SHOW_CHAT'):
        if token not in companion_notification:
            fail(f'notification -> service overlay route missing: {token}')
    if 'PendingIntent.getActivity' in companion_notification:
        fail('message/foreground notification still launches an Activity')

    main_activity = (kroot / 'MainActivity.kt').read_text(encoding='utf-8')
    if 'collapseChatFromVisibleActivity(this)' not in main_activity:
        fail('full app does not collapse the true overlay chat')

    bg = (kroot / 'BackgroundSystemBridge.kt').read_text(encoding='utf-8')
    for token in ('"clearOverlayUnread"', '"setOverlayUnread"', '"incrementOverlayUnread"'):
        if token not in bg:
            fail(f'background system bridge missing overlay command: {token}')

    runtime = (kroot / 'CompanionRuntimeState.kt').read_text(encoding='utf-8')
    if 'overlayChatExpanded' not in runtime:
        fail('runtime diagnostics do not expose overlayChatExpanded')

    tts_engine = (kroot / 'NativeTtsEngine.kt').read_text(encoding='utf-8')
    if tts_engine.count('speechLock.lock()') < 3:
        fail('NativeTtsEngine must serialize initialize/config/release with inference')

    native_store = (kroot / 'NativeEventStore.kt').read_text(encoding='utf-8')
    if 'readSetting(db, "transfer_lock") == "1"' not in native_store:
        fail('native event transfer_lock guard missing')
    if 'readSetting(db, "active_brain") == "0"' not in native_store:
        fail('native event standby guard missing')

    boot = (kroot / 'CompanionBootReceiver.kt').read_text(encoding='utf-8')
    for token in ('ACTION_BOOT_COMPLETED', 'ACTION_MY_PACKAGE_REPLACED', 'isOverlayUserEnabled', 'canDrawOverlays'):
        if token not in boot:
            fail(f'boot restore token missing: {token}')

def check_dart_imports() -> None:
    missing: list[str] = []
    import_re = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.M)
    for path in list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')):
        text = path.read_text(encoding='utf-8')
        for target in import_re.findall(text):
            if target.startswith(('dart:', 'package:')):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                missing.append(f'{path.relative_to(ROOT)} -> {target}')
    if missing:
        fail('missing relative Dart imports:\n' + '\n'.join(missing))



def _strip_comments_and_strings(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    state = 'code'
    quote = ''
    triple = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if state == 'line_comment':
            if c == '\n':
                state = 'code'; out.append('\n')
            else:
                out.append(' ')
            i += 1; continue
        if state == 'block_comment':
            if c == '*' and nxt == '/':
                out.extend('  '); i += 2; state = 'code'
            else:
                out.append('\n' if c == '\n' else ' '); i += 1
            continue
        if state == 'string':
            if triple:
                if text.startswith(quote * 3, i):
                    out.extend('   '); i += 3; state = 'code'; triple = False
                else:
                    out.append('\n' if c == '\n' else ' '); i += 1
            else:
                if c == '\\':
                    out.append(' '); i += 1
                    if i < n:
                        out.append('\n' if text[i] == '\n' else ' '); i += 1
                elif c == quote:
                    out.append(' '); i += 1; state = 'code'
                else:
                    out.append('\n' if c == '\n' else ' '); i += 1
            continue
        # code state
        if c == '/' and nxt == '/':
            out.extend('  '); i += 2; state = 'line_comment'; continue
        if c == '/' and nxt == '*':
            out.extend('  '); i += 2; state = 'block_comment'; continue
        # Dart raw prefix r'...' / r"..." is harmless: consume r as code then string.
        if c in ('\'', '"'):
            quote = c
            triple = text.startswith(c * 3, i)
            if triple:
                out.extend('   '); i += 3
            else:
                out.append(' '); i += 1
            state = 'string'; continue
        out.append(c); i += 1
    return ''.join(out)


def check_delimiter_balance() -> None:
    pairs = {')': '(', ']': '[', '}': '{'}
    for path in list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')) + list((ROOT/'android/app/src/main/kotlin').rglob('*.kt')):
        clean = _strip_comments_and_strings(path.read_text(encoding='utf-8'))
        stack: list[tuple[str, int]] = []
        line = 1
        for ch in clean:
            if ch == '\n': line += 1; continue
            if ch in '([{':
                stack.append((ch, line))
            elif ch in ')]}':
                if not stack or stack[-1][0] != pairs[ch]:
                    fail(f'delimiter mismatch in {path.relative_to(ROOT)} near line {line}: {ch}')
                stack.pop()
        if stack:
            fail(f'unclosed delimiter in {path.relative_to(ROOT)} opened near line {stack[-1][1]}')

def check_version_schema() -> None:
    pub = (ROOT/'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.14\.0\+14\s*$', pub, re.M):
        fail('pubspec version is not 0.14.0+14')
    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    if 'static const int schemaVersion = 11;' not in db:
        fail('v0.14 DB schema must be 11')
    if 'Future<List<ChatMessage>> messagesBefore(' not in db:
        fail('paged history query missing')
    transfer = (ROOT/'lib/features/transfer/transfer_page.dart').read_text(encoding='utf-8')
    if "_restoreStandbyUiState()" not in transfer or "active == '0'" not in transfer:
        fail('transfer standby recovery UI is not restored from durable active_brain state')
    background = (ROOT/'lib/background_main.dart').read_text(encoding='utf-8')
    if background.count('brainWorkAllowed()') < 3:
        fail('background isolate can still write while standby/transfer-locked')
    chat_page = (ROOT/'lib/features/chat/chat_page.dart').read_text(encoding='utf-8')
    if 'if (!mounted) return;' not in chat_page:
        fail('ChatPage async lifecycle callbacks are not mounted-guarded')
    chat_controller = (ROOT/'lib/features/chat/chat_controller.dart').read_text(encoding='utf-8')
    if 'void _safeNotify()' not in chat_controller or 'if (!_disposed) notifyListeners();' not in chat_controller:
        fail('ChatController may notify listeners after disposal')
    perception = (ROOT/'lib/core/perception/perception_engine.dart').read_text(encoding='utf-8')
    if "if (!await db.brainWorkAllowed()) return null;" not in perception:
        fail('PerceptionEngine manual/background capture can mutate standby state')
    memory = (ROOT/'lib/core/ai/memory_extractor.dart').read_text(encoding='utf-8')
    if memory.count('brainWorkAllowed()') < 3:
        fail('MemoryExtractor diagnostics/work are insufficiently guarded')
    rules = (ROOT/'lib/core/rules/rule_layer_defaults.dart')
    if rules.exists():
        text = rules.read_text(encoding='utf-8')
        # implementation may name them by IDs, but there must still be six layer definitions
        count = len(re.findall(r"RuleLayerDefault\('\d{2}_", text))
        if count != 6:
            fail(f'six-layer rule defaults count is {count}, expected 6')


def check_true_overlay_dart_bridge() -> None:
    server = ROOT / 'lib/core/platform/background_chat_command_server.dart'
    if not server.exists():
        fail('background chat command server missing')
    text = server.read_text(encoding='utf-8')
    for token in ("'sendMessage'", "'overlayOpened'", "'loadOlderMessages'", 'ChatController'):
        if token not in text:
            fail(f'background chat server token missing: {token}')
    bg = (ROOT / 'lib/background_main.dart').read_text(encoding='utf-8')
    if 'BackgroundChatCommandServer' not in bg or 'chatCommands.start()' not in bg:
        fail('headless Flutter engine does not register native overlay commands before heartbeat loop')
    bridge = (ROOT / 'lib/core/platform/android_bridge.dart').read_text(encoding='utf-8')
    if 'overlayChatExpanded' not in bridge:
        fail('Dart capability model missing overlayChatExpanded')
    controller = (ROOT / 'lib/features/chat/chat_controller.dart').read_text(encoding='utf-8')
    if 'Future<bool> syncExternalMessages()' not in controller:
        fail('full app cannot observe messages written by persistent overlay engine')


def check_duplicate_declarations() -> None:
    # Conservative guard for accidental pasted duplicate local declarations.
    # Keep this intentionally narrow to avoid false positives across Dart
    # switch-case lexical scopes.
    decl = re.compile(r'^\s*(?:late\s+final|final|var)\s+([A-Za-z_]\w*)\s*(?:=|;)')
    for path in list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')):
        lines = path.read_text(encoding='utf-8').splitlines()
        previous = None
        previous_line = 0
        for index, line in enumerate(lines, start=1):
            m = decl.match(line)
            if not m:
                if line.strip() and not line.lstrip().startswith('//'):
                    previous = None
                continue
            name = m.group(1)
            if previous == name and index - previous_line <= 2:
                fail(f'adjacent duplicate Dart declaration: {path.relative_to(ROOT)}:{index} {name}')
            previous = name
            previous_line = index


def check_durable_generation() -> None:
    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'CREATE TABLE IF NOT EXISTS generation_jobs',
        "run_token TEXT NOT NULL DEFAULT ''",
        'Future<GenerationJob> createGenerationTurn(',
        'Future<GenerationJob?> claimGenerationJob(',
        'checkpointGenerationJob(',
        'completeGenerationJobIfCurrent(',
        "where: 'id = ? AND status = ? AND run_token = ?'",
        'nextRecoverableGenerationJob(',
        'wakeRetryableGenerationJobs()',
        "'generation_jobs',",
    ):
        if token not in db:
            fail(f'durable generation DB token missing: {token}')
    if "row.addAll({\n            row.addAll({" in db:
        fail('duplicate row.addAll regression in importAll')

    runner = (ROOT/'lib/core/ai/durable_generation_runner.dart').read_text(encoding='utf-8')
    for token in (
        'class DurableGenerationRunner',
        'client.streamChat(',
        'checkpointGenerationJob(',
        'completeGenerationJobIfCurrent(',
        "renewLocalLease(\n            'chat_turn_lease'",
        'GenerationSuspendedException',
        'GenerationStreamIncompleteException',
        'runToken: job.runToken',
        'deferGenerationJob(',
    ):
        if token not in runner:
            fail(f'durable generation runner token missing: {token}')

    controller = (ROOT/'lib/features/chat/chat_controller.dart').read_text(encoding='utf-8')
    for token in (
        'createGenerationTurn(',
        'resumePendingGeneration()',
        '_scheduleGenerationRecovery(',
        'recoveringGeneration',
        "holdFor: const Duration(minutes: 3)",
    ):
        if token not in controller:
            fail(f'chat durable-generation token missing: {token}')

    bg = (ROOT/'lib/background_main.dart').read_text(encoding='utf-8')
    for token in ('DurableGenerationRecovery', 'generationRecovery.recoverOne()', 'blockingGenerationJob()'):
        if token not in bg:
            fail(f'background generation recovery token missing: {token}')

    settings = (ROOT/'lib/features/settings/settings_page.dart').read_text(encoding='utf-8')
    if "wakeRetryableGenerationJobs()" not in settings:
        fail('saving device-local API config does not wake retryable generation jobs')
    secure = (ROOT/'lib/core/storage/secure_config.dart').read_text(encoding='utf-8')
    if "uri.scheme != 'http' && uri.scheme != 'https'" not in secure:
        fail('API endpoint validation accepts unsupported schemes')

    snapshot = (ROOT/'lib/core/sync/snapshot_service.dart').read_text(encoding='utf-8')
    if "'chat_turn_lease': '0'" not in snapshot:
        fail('snapshot receiver does not clear source chat lease')

def tts_paths() -> list[Path]:
    base = ROOT/'android/app/src/main'
    result: list[Path] = []
    result += list((base/'assets/legacy_tts/runtime').glob('runtime_*.jar'))
    result += [p for p in (base/'assets/tts_models').rglob('*') if p.is_file()]
    result += [p for p in (base/'jniLibs').rglob('*') if p.is_file()]
    kroot = base/'kotlin/com/aicompanion/localfirst'
    for name in ('LegacyTtsRuntime.kt', 'NativeTtsBridge.kt', 'NativeTtsEngine.kt', 'WavAudioPlayer.kt'):
        result.append(kroot/name)
    return sorted(result)


def compare_tts(baseline_zip: Path | None) -> tuple[int, list[str], int]:
    paths = tts_paths()
    missing_local = [p for p in paths if not p.exists()]
    if missing_local:
        fail('missing local TTS files: ' + ', '.join(map(str, missing_local)))
    if baseline_zip is None:
        return len(paths), [], 0
    changed: list[str] = []
    missing = 0
    with zipfile.ZipFile(baseline_zip) as zf:
        names = set(zf.namelist())
        for p in paths:
            rel = p.relative_to(ROOT).as_posix()
            baseline_name = 'ai_companion_v0_13/' + rel
            if baseline_name not in names:
                missing += 1
                continue
            if sha_bytes(p.read_bytes()) != sha_bytes(zf.read(baseline_name)):
                changed.append(rel)
    if missing or changed:
        fail(f'TTS regression: changed={changed}, missing_in_baseline={missing}')
    return len(paths), changed, missing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-zip', type=Path)
    args = parser.parse_args()
    checks = [
        ('XML', check_xml),
        ('Manifest', check_manifest),
        ('Kotlin lifecycle patterns', check_kotlin_patterns),
        ('Dart relative imports', check_dart_imports),
        ('Dart/Kotlin delimiter balance', check_delimiter_balance),
        ('Duplicate Dart declarations', check_duplicate_declarations),
        ('True-overlay Dart bridge', check_true_overlay_dart_bridge),
        ('Version/schema', check_version_schema),
        ('Durable generation', check_durable_generation),
    ]
    for name, fn in checks:
        fn()
        print(f'[OK] {name}')
    count, changed, missing = compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files: {count}; intentional_changed={len(changed)}; missing={missing}')
    for item in changed:
        print(f'     intentional: {item}')
    print('v0.14 durable-generation/lifecycle validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
