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


def strip_comments_and_strings(text: str) -> str:
    out: list[str] = []
    i = 0
    state = 'code'
    quote = ''
    triple = False
    while i < len(text):
        c = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        if state == 'line':
            if c == '\n':
                state = 'code'; out.append('\n')
            else: out.append(' ')
            i += 1; continue
        if state == 'block':
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
                    if i < len(text): out.append('\n' if text[i] == '\n' else ' '); i += 1
                elif c == quote:
                    out.append(' '); i += 1; state = 'code'
                else:
                    out.append('\n' if c == '\n' else ' '); i += 1
            continue
        if c == '/' and nxt == '/': out.extend('  '); i += 2; state = 'line'; continue
        if c == '/' and nxt == '*': out.extend('  '); i += 2; state = 'block'; continue
        if c in ('\'', '"'):
            quote = c; triple = text.startswith(c * 3, i)
            out.extend('   ' if triple else ' '); i += 3 if triple else 1; state = 'string'; continue
        out.append(c); i += 1
    return ''.join(out)


def check_xml_manifest() -> None:
    main = ROOT / 'android/app/src/main'
    for path in main.rglob('*.xml'):
        ET.parse(path)
    manifest = ET.parse(main / 'AndroidManifest.xml').getroot()
    app = manifest.find('application')
    if app is None: fail('application missing')
    receiver = next((r for r in app.findall('receiver') if r.attrib.get(ANDROID+'name') == '.CompanionReplyReceiver'), None)
    if receiver is None: fail('CompanionReplyReceiver missing')
    if receiver.attrib.get(ANDROID+'exported') != 'false': fail('CompanionReplyReceiver must be non-exported')
    if any(a.attrib.get(ANDROID+'name') == '.OverlayChatActivity' for a in app.findall('activity')):
        fail('old OverlayChatActivity returned')


def check_relative_imports() -> None:
    import_re = re.compile(r"^\s*import\s+['\"]([^'\"]+)['\"]", re.M)
    missing: list[str] = []
    for path in list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')):
        for target in import_re.findall(path.read_text(encoding='utf-8')):
            if target.startswith(('dart:', 'package:')): continue
            if not (path.parent / target).resolve().exists():
                missing.append(f'{path.relative_to(ROOT)} -> {target}')
    if missing: fail('missing relative Dart imports:\n' + '\n'.join(missing))


def check_delimiters() -> None:
    pairs = {')':'(', ']':'[', '}':'{'}
    paths = list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')) + list((ROOT/'android/app/src/main/kotlin').rglob('*.kt'))
    for path in paths:
        clean = strip_comments_and_strings(path.read_text(encoding='utf-8'))
        stack: list[tuple[str,int]] = []
        line = 1
        for ch in clean:
            if ch == '\n': line += 1; continue
            if ch in '([{': stack.append((ch,line))
            elif ch in ')]}':
                if not stack or stack[-1][0] != pairs[ch]: fail(f'delimiter mismatch {path.relative_to(ROOT)}:{line}')
                stack.pop()
        if stack: fail(f'unclosed delimiter {path.relative_to(ROOT)}:{stack[-1][1]}')


def check_adjacent_duplicate_dart_declarations() -> None:
    decl = re.compile(r'^\s*(?:late\s+final|final|var)\s+([A-Za-z_]\w*)\s*(?:=|;)')
    for path in list((ROOT/'lib').rglob('*.dart')) + list((ROOT/'test').rglob('*.dart')):
        prev = None; prev_line = 0
        for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            m = decl.match(line)
            if not m:
                if line.strip() and not line.lstrip().startswith('//'): prev = None
                continue
            name = m.group(1)
            if name == prev and line_no - prev_line <= 2:
                fail(f'adjacent duplicate declaration {path.relative_to(ROOT)}:{line_no} {name}')
            prev, prev_line = name, line_no


def check_version_schema() -> None:
    pub = (ROOT/'pubspec.yaml').read_text(encoding='utf-8')
    if not re.search(r'^version:\s*0\.20\.0\+20\s*$', pub, re.M): fail('pubspec version != 0.20.0+20')
    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    if 'static const int schemaVersion = 14;' not in db: fail('schema != 14')
    for token in (
        "proactive_intent TEXT NOT NULL DEFAULT ''",
        "proactive_delivery TEXT NOT NULL DEFAULT ''",
        "intent_kind TEXT NOT NULL DEFAULT ''",
        "delivery_style TEXT NOT NULL DEFAULT ''",
        'if (oldVersion < 13)',
        'idx_proactive_intent',
        "'proactive_notification_privacy': 'smart'",
        'Old state packages predate proactive presentation metadata',
        'if (oldVersion < 14)',
        'CREATE TABLE IF NOT EXISTS awareness_observations',
        'idx_awareness_active',
        "'awareness_observations'",
    ):
        if token not in db: fail(f'v13/v14 DB token missing: {token}')


def check_intent_model_policy() -> None:
    model = (ROOT/'lib/core/models/proactive_intent.dart').read_text(encoding='utf-8')
    for key in ('gentle_ping','miss_you','followup','share_thought','curiosity','social_share','intimacy_invitation','emotional_reach'):
        if f"'{key}'" not in model: fail(f'intent missing: {key}')
    for key in ('quiet','normal','warm','smart','full','private'):
        if f"'{key}'" not in model: fail(f'delivery/privacy key missing: {key}')
    policy = (ROOT/'lib/core/desire/proactive_presentation.dart').read_text(encoding='utf-8')
    for token in ('DriveKey.libido => ProactiveIntentKind.intimacyInvitation', 'userBusy || rhythm.preferLowPressure', 'sensitiveContext'):
        if token not in policy: fail(f'presentation policy missing: {token}')
    rhythm = (ROOT/'lib/core/desire/proactive_rhythm_engine.dart').read_text(encoding='utf-8')
    for token in ('recentProactiveFeedbackByIntent', '_intentAdjustment', '_intentLowPressure', 'intentAdjustment'):
        if token not in rhythm: fail(f'intent adaptation missing: {token}')


def check_proactive_pipeline() -> None:
    engine = (ROOT/'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    for token in (
        'ProactivePresentationPolicy.classify', 'intentKind: intentKind.key', 'deliveryStyle: deliveryStyle.key',
        "getSetting('proactive_notification_privacy')", 'activeInteractionSession()',
        'ProactivePresentationPolicy.notificationBody', 'postCompanionNotification(',
    ):
        if token not in engine: fail(f'proactive pipeline token missing: {token}')
    msg = (ROOT/'lib/core/models/chat_message.dart').read_text(encoding='utf-8')
    for token in ('proactiveIntent', 'proactiveDelivery', "'proactive_intent'", "'proactive_delivery'"):
        if token not in msg: fail(f'ChatMessage metadata missing: {token}')


def check_notification_quick_reply() -> None:
    kroot = ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst'
    notification = (kroot/'CompanionNotification.kt').read_text(encoding='utf-8')
    for token in (
        'CHANNEL_MESSAGES_GENTLE', 'RemoteInput.Builder', 'CompanionReplyReceiver::class.java',
        'Build.VERSION.SDK_INT >= Build.VERSION_CODES.S', 'PendingIntent.FLAG_MUTABLE',
        '.addAction(replyAction)',
    ):
        if token not in notification: fail(f'notification UX missing: {token}')
    receiver = (kroot/'CompanionReplyReceiver.kt').read_text(encoding='utf-8')
    for token in ('ACTION_NOTIFICATION_REPLY', 'notification-reply:', 'startForegroundService', 'RemoteInput.getResultsFromIntent'):
        if token not in receiver: fail(f'inline reply receiver missing: {token}')
    overlay = (kroot/'OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in ('ACTION_NOTIFICATION_REPLY', 'pendingInlineReplies', 'flushInlineReplies()', 'INLINE_REPLY_MAX_ATTEMPTS', 'START_REDELIVER_INTENT'):
        if token not in overlay: fail(f'inline reply service routing missing: {token}')
    server = (ROOT/'lib/core/platform/background_chat_command_server.dart').read_text(encoding='utf-8')
    if "case 'notificationReply':" not in server or 'requestedMessageId: replyId' not in server:
        fail('notification reply does not reach ChatController with stable id')
    chat = (ROOT/'lib/features/chat/chat_controller.dart').read_text(encoding='utf-8')
    for token in ('String? requestedMessageId', 'messageById(stableMessageId)', 'id: stableMessageId'):
        if token not in chat: fail(f'quick-reply idempotency missing: {token}')


def check_ui() -> None:
    settings = (ROOT/'lib/features/settings/settings_page.dart').read_text(encoding='utf-8')
    for token in ('主动消息通知隐私', 'ProactiveNotificationPrivacy.values', 'proactive_notification_privacy'):
        if token not in settings: fail(f'notification privacy UI missing: {token}')
    chat = (ROOT/'lib/features/chat/chat_page.dart').read_text(encoding='utf-8')
    if 'ProactiveIntentKind.fromKey' not in chat: fail('full chat does not label proactive intent')
    overlay = (ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    if 'proactiveIntentLabel' not in overlay: fail('overlay does not label proactive intent')


def check_companion_home() -> None:
    app = (ROOT/'lib/app.dart').read_text(encoding='utf-8')
    for token in (
        'CompanionHomePage(onOpenChat: _openChat)',
        "label: '她'",
        "label: '聊天'",
        "label: '更多'",
        "'/transfer'",
        "'/system'",
        "'/settings'",
        "'/inner'",
    ):
        if token not in app: fail(f'companion app shell missing: {token}')
    if "label: '内心'" in app or "label: '感知'" in app:
        fail('developer tabs leaked back into daily navigation')

    home_state = (ROOT/'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    for token in (
        'CompanionHomeSnapshot',
        "getSetting('active_brain')",
        "getSetting('transfer_lock')",
        'latestActiveThought()',
        'latestProactiveMessage()',
        'activeUnfinishedThreads(limit: 1)',
        'recentPerceptionSnapshots(limit: 1)',
        'activeInteractionSession()',
        '第二份人生',
    ):
        if token not in home_state: fail(f'home state contract missing: {token}')
    for forbidden in ('DesireEngine(', 'desire.tick(', 'PerceptionEngine(', 'capture(', 'ProactiveEngine('):
        if forbidden in home_state: fail(f'home must remain read-only: {forbidden}')

    home = (ROOT/'lib/features/home/companion_home_page.dart').read_text(encoding='utf-8')
    for token in ('她最近在想', '最近她主动来找你', '她还记着这件事', '她最近一次感知这台设备'):
        if token not in home: fail(f'home presence UI missing: {token}')
    for forbidden in ('LinearProgressIndicator', 'DriveKey.values', 'baseline', 'busyScore'):
        if forbidden in home: fail(f'raw diagnostic HUD leaked into Home: {forbidden}')

    more = (ROOT/'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    for token in ('关系记录', '长期记忆', '参考资料', '手机 / 平板接管', '权限与系统状态', '高级与诊断'):
        if token not in more: fail(f'secondary navigation missing: {token}')

    chat = (ROOT/'lib/features/chat/chat_page.dart').read_text(encoding='utf-8')
    if 'DropdownButton<DeepSeekModelProfile>' in chat:
        fail('model selector still exposed in daily chat top bar')
    if 'ReasoningPanel' not in chat:
        fail('reasoning display was lost during chat simplification')

    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in ('Future<ChatMessage?> latestProactiveMessage()', 'Future<CompanionThought?> latestActiveThought()'):
        if token not in db: fail(f'home DB helper missing: {token}')
    if "lifecycle_state IN ('active','fixation')" not in db or "orderBy: 'updated_at DESC'" not in db:
        fail('latest active Thought query does not use user-facing recency semantics')


def check_reference_library_v019() -> None:
    library = (ROOT/'lib/features/reference/reference_library_page.dart').read_text(encoding='utf-8')
    for token in ('按名称或别名查找', '新增资料', 'ReferenceDocumentPage', 'setReferenceDocumentEnabled'):
        if token not in library: fail(f'Reference Library daily UX missing: {token}')

    detail = (ROOT/'lib/features/reference/reference_document_page.dart').read_text(encoding='utf-8')
    for token in ('完整原文', '检索片段', '重新分块', '编辑完整资料', '删除这份资料', 'showDialog<bool>'):
        if token not in detail: fail(f'Reference document detail UX missing: {token}')

    editor = (ROOT/'lib/features/reference/reference_document_editor_page.dart').read_text(encoding='utf-8')
    for token in ('完整资料原文', '保存修改并重新分块', 'saveReferenceDocumentWithChunks'):
        if token not in editor: fail(f'Reference editor UX missing: {token}')

    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'Future<String> saveReferenceDocumentWithChunks({',
        'return db.transaction((txn) async {',
        'Future<ReferenceDocument?> referenceDocumentById(String id)',
        'Future<List<ReferenceItem>> referenceItemsForDocument(String documentId)',
        "columns: const ['enabled']",
        "'enabled': documentEnabled ? 1 : 0",
    ):
        if token not in db: fail(f'Reference DB consistency missing: {token}')
    upsert = db[db.index('Future<String> upsertReferenceDocument'):db.index('Future<ReferenceDocument?> referenceDocumentById')]
    if 'ConflictAlgorithm.replace' in upsert:
        fail('Reference edit still uses REPLACE and can reset created_at')

    prompt = (ROOT/'lib/core/ai/prompt_builder.dart').read_text(encoding='utf-8')
    if 'referenceLibrary.retrieve(latestUserText, limit: 6)' not in prompt:
        fail('Reference retrieval ceased to be bounded/on-demand')
    reference = (ROOT/'lib/core/reference/reference_library.dart').read_text(encoding='utf-8')
    if 'db.relevantReferenceItems(query, limit: limit)' not in reference:
        fail('Reference Library no longer uses relevance retrieval')

    home_state = (ROOT/'lib/features/home/companion_home_state.dart').read_text(encoding='utf-8')
    if '这里是当前 Active Brain' in home_state or '大脑写入' in home_state:
        fail('developer Active Brain wording leaked into Companion Home')
    more = (ROOT/'lib/features/more/companion_more_page.dart').read_text(encoding='utf-8')
    if '按需检索的 Reference' in more or '同一个 Active Brain' in more:
        fail('developer wording leaked into More daily UI')
    chat = (ROOT/'lib/features/chat/chat_page.dart').read_text(encoding='utf-8')
    if '她主动 ·' in chat or '正在连接她…' in chat:
        fail('full Chat copy not aligned with companion surfaces')
    overlay = (ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in ('text = "她"', 'smallButton("打开")', 'setChatStatus("她正在想…")', '"gentle_ping" -> "轻轻找你"'):
        if token not in overlay: fail(f'overlay companion copy missing: {token}')
    for forbidden in ('text = "AI Companion"', 'smallButton("App")', 'setChatStatus("后台大脑还在启动'):
        if forbidden in overlay: fail(f'developer overlay copy remains: {forbidden}')



def check_awareness_context_v020() -> None:
    model = (ROOT/'lib/core/models/awareness_observation.dart').read_text(encoding='utf-8')
    for token in ('class AwarenessObservation', 'confidence', 'windowStart', 'windowEnd', 'expiresAt', 'dedupeKey', 'sourceFingerprint'):
        if token not in model: fail(f'awareness model missing: {token}')

    interpreter = (ROOT/'lib/core/perception/perception_interpreter.dart').read_text(encoding='utf-8')
    for token in (
        'class PerceptionInterpreter', "'current_activity'", "'recent_activity'", "'app_switching'",
        "'screen_state'", "'availability'", "'notification_pressure'", 'DevicePerceptionState',
        'expiresAt:', 'confidence:', 'sourceFingerprint:',
    ):
        if token not in interpreter: fail(f'local perception interpretation missing: {token}')
    for forbidden in ('private notification text', 'private page text'):
        if forbidden in interpreter: fail(f'test/private raw text leaked into interpreter source: {forbidden}')

    engine = (ROOT/'lib/core/perception/perception_engine.dart').read_text(encoding='utf-8')
    for token in ('getPerceptionState()', 'syncAwarenessObservations(', 'recentDeviceStateEvents()', 'newAccessibilityCount', "source: 'perception/awareness'"):
        if token not in engine: fail(f'perception engine v0.20 path missing: {token}')
    for forbidden in ('accessibilitySnippets', "source: 'perception/accessibility'", 'last_long_usage_package'):
        if forbidden in engine: fail(f'raw external text can still become durable Thought: {forbidden}')

    prompt = (ROOT/'lib/core/ai/prompt_builder.dart').read_text(encoding='utf-8')
    for token in ('activeAwarenessObservations(limit: 6)', '_awarenessSection', '有时会判断错', '不要向用户汇报监控过程'):
        if token not in prompt: fail(f'bounded awareness prompt missing: {token}')
    for forbidden in ('recentDeviceEvents(', '_deviceSection(', '_perceptionSection(', "e['app_package']", 'PerceptionSnapshot'):
        if forbidden in prompt: fail(f'raw perception still reaches ordinary prompt: {forbidden}')

    bridge = (ROOT/'lib/core/platform/android_bridge.dart').read_text(encoding='utf-8')
    for token in ('class DevicePerceptionState', 'getPerceptionState()', 'appCategory'):
        if token not in bridge: fail(f'Dart Android perception bridge missing: {token}')

    kroot = ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst'
    for name in ('SystemBridge.kt', 'BackgroundSystemBridge.kt'):
        text = (kroot/name).read_text(encoding='utf-8')
        for token in ('"getPerceptionState"', 'perceptionState()', 'appCategory(event.packageName)', 'categoryCache'):
            if token not in text: fail(f'{name} local classification/state missing: {token}')

    db = (ROOT/'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    for token in (
        'Future<List<AwarenessObservation>> syncAwarenessObservations({',
        'Future<List<AwarenessObservation>> activeAwarenessObservations({',
        'Future<double?> latestPerceptionBusyScore({',
        'Future<List<Map<String, Object?>>> recentDeviceStateEvents({',
        "if (await setting('transfer_lock') == '1' || await setting('active_brain') == '0')",
        "WHERE dedupe_key = ? AND expires_at > ?",
        "'awareness_observations': await count('awareness_observations')",
        'Current-state awareness from the source device is useful briefly after',
    ):
        if token not in db: fail(f'awareness DB contract missing: {token}')

    proactive = (ROOT/'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    if 'await db.latestPerceptionBusyScore()' not in proactive:
        fail('proactive gate does not reuse bounded perception busy score')
    maintenance = (ROOT/'lib/core/maintenance/long_running_maintenance_engine.dart').read_text(encoding='utf-8')
    if "table: 'awareness_observations'" not in maintenance:
        fail('awareness observations missing long-running hygiene')

def check_true_overlay_regression() -> None:
    kroot = ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst'
    overlay = (kroot/'OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in ('TYPE_APPLICATION_OVERLAY','FLAG_NOT_FOCUSABLE','BACKGROUND_COMMAND_CHANNEL','backgroundDartReady'):
        if token not in overlay: fail(f'true overlay regression: {token}')
    if 'import io.flutter.embedding.android.FlutterView' in overlay: fail('FlutterView returned to Service overlay')
    if (kroot/'OverlayChatActivity.kt').exists(): fail('OverlayChatActivity returned')


def tts_paths() -> list[Path]:
    base = ROOT/'android/app/src/main'
    paths: list[Path] = []
    paths += list((base/'assets/legacy_tts/runtime').glob('runtime_*.jar'))
    paths += [p for p in (base/'assets/tts_models').rglob('*') if p.is_file()]
    paths += [p for p in (base/'jniLibs').rglob('*') if p.is_file()]
    kroot = base/'kotlin/com/aicompanion/localfirst'
    for name in ('LegacyTtsRuntime.kt','NativeTtsBridge.kt','NativeTtsEngine.kt','WavAudioPlayer.kt'):
        paths.append(kroot/name)
    return sorted(paths)


def compare_v019_freeze(baseline_zip: Path | None) -> int:
    if baseline_zip is None:
        return 0
    allowed_changed = {
        'README.md',
        'docs/DEV_STATUS.md',
        'docs/ROADMAP.md',
        'docs/TEST_CHECKLIST.md',
        'lib/core/ai/prompt_builder.dart',
        'lib/core/database/app_database.dart',
        'lib/core/desire/proactive_engine.dart',
        'lib/core/maintenance/long_running_maintenance_engine.dart',
        'lib/core/perception/perception_engine.dart',
        'lib/core/platform/android_bridge.dart',
        'lib/features/inner/inner_page.dart',
        'lib/features/more/companion_more_page.dart',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt',
        'android/app/src/main/kotlin/com/aicompanion/localfirst/BackgroundSystemBridge.kt',
        'pubspec.yaml',
    }
    with zipfile.ZipFile(baseline_zip) as zf:
        file_names = [n for n in zf.namelist() if not n.endswith('/')]
        roots = [n.split('/', 1)[0] for n in file_names if '/' in n]
        if not roots:
            fail('cannot infer v0.19 baseline root prefix')
        prefix = roots[0]
        checked = 0
        for name in file_names:
            if not name.startswith(prefix + '/'):
                continue
            rel = name[len(prefix) + 1:]
            if rel in allowed_changed:
                continue
            current = ROOT / rel
            if not current.exists():
                fail(f'unexpected v0.19 file deletion: {rel}')
            if hashlib.sha256(current.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                fail(f'unexpected change outside v0.20 allowlist: {rel}')
            checked += 1
        return checked


def compare_tts(baseline_zip: Path | None) -> int:
    paths = tts_paths()
    for path in paths:
        if not path.exists(): fail(f'missing TTS file: {path.relative_to(ROOT)}')
    if baseline_zip is None: return len(paths)
    with zipfile.ZipFile(baseline_zip) as zf:
        names = set(zf.namelist())
        candidates = [n.split('/android/app/src/main/',1)[0] for n in names if '/android/app/src/main/' in n]
        if not candidates: fail('cannot infer baseline root prefix')
        prefix = sorted(set(candidates), key=len)[0]
        changed = []; missing = []
        for path in paths:
            rel = path.relative_to(ROOT).as_posix()
            name = f'{prefix}/{rel}'
            if name not in names:
                missing.append(rel); continue
            if hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(zf.read(name)).digest():
                changed.append(rel)
        if changed or missing: fail(f'TTS regression changed={changed} missing={missing}')
    return len(paths)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline-zip', type=Path)
    args = ap.parse_args()
    checks = [
        ('XML/Manifest', check_xml_manifest),
        ('Dart relative imports', check_relative_imports),
        ('Dart/Kotlin delimiters', check_delimiters),
        ('Duplicate Dart declarations', check_adjacent_duplicate_dart_declarations),
        ('Version/schema v14', check_version_schema),
        ('Proactive intent model/policy', check_intent_model_policy),
        ('Proactive pipeline', check_proactive_pipeline),
        ('Notification quick reply', check_notification_quick_reply),
        ('Proactive UX UI', check_ui),
        ('Companion Home / navigation', check_companion_home),
        ('Reference Library / companion copy v0.19', check_reference_library_v019),
        ('Perception Context / daily awareness v0.20', check_awareness_context_v020),
        ('True overlay regression', check_true_overlay_regression),
    ]
    for name, fn in checks:
        fn(); print(f'[OK] {name}')
    frozen = compare_v019_freeze(args.baseline_zip)
    if args.baseline_zip is not None:
        print(f'[OK] v0.19 frozen files byte-identical outside allowlist: {frozen}')
    count = compare_tts(args.baseline_zip)
    print(f'[OK] TTS critical files unchanged: {count}')
    print('v0.20 Perception Context / daily awareness validation passed.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'[FAIL] {exc}', file=sys.stderr)
        raise
