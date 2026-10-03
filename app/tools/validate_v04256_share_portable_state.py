"""Wiring/inventory guard; behavioral roundtrip, rollback and motion tests run in CI."""
from pathlib import Path
import re
app=Path(__file__).resolve().parents[1]
read=lambda path:(app/path).read_text()
activity=read('lib/core/mcp/cedar_toy_activity.dart')
assert "leisure('every5', '5轮回复', 5)" in activity
assert "fast('every1', '1轮回复', 1)" in activity
assert "spectate('every10', '10轮回复', 10)" in activity
assert 'soloStepGap => const Duration(minutes: 2)' in activity
assert re.search(r'completedPlayRounds:\s*state\.completedPlayRounds\s*\+', activity)
assert 'CedarSoloEpisodePolicy.isStateChangingAction(action)' in activity
share=read('lib/core/mcp/cedar_live_share_policy.dart')
assert '.take(6)' not in share
for token in ('intervalElapsed', 'noteDelivered', 'refreshPending', 'isResultReport',
              'sharedThrough', 'deliveredRound', 'shareRounds'):
    assert token in share,token
assert 'completeJson(' not in share and 'streamChat(' not in share
engine=read('lib/core/mcp/cedar_toy_autonomy_engine.dart')
assert re.search(r'CedarLiveSharePolicy\(db\)\s*\.offer\(updated,', engine)
assert '真实推进了一步。${updated.lastOutcome}' not in engine
proactive=read('lib/core/desire/proactive_engine.dart')
assert proactive.count('.deliveryAllowed(')>=3
commit=proactive.index('final commitBlock = await db.commitProactiveMessageIfCurrent')
assert proactive.index('await CedarLiveSharePolicy(db).noteDelivered(',commit)>commit
assert 'messageId: message.id' in proactive
ui=read('lib/features/chat/cedar_toy_activity_window.dart')
assert 'Row(' in ui and 'Expanded(' in ui and 'width: double.infinity' in ui
chat=read('lib/features/chat/chat_page.dart')
assert chat.index("title: '记住事项'")<chat.index("title: '代办提醒'")
assert 'const RememberedUserFactsPage()' in chat
snapshot=read('lib/core/sync/snapshot_service.dart')
for token in ("'protocol_version': 7",'protocolVersion > 7',
              'portableStorage.exportTo', 'PortableCompanionStorage.validatePayload',
              'portableStorage.prepare', '_restoreCoordinator.install('):
    assert token in snapshot,token
coordinator=read('lib/core/sync/snapshot_restore_coordinator.dart')
assert 'await portable?.rollback()' in coordinator
assert 'await portable?.commit()' in coordinator
storage=read('lib/core/storage/portable_companion_storage.dart')
for token in ('followLinks: false', 'entity is Link', 'safePath', 'sha256.bind',
              'PreparedDirectorySwap.prepare', 'validateSnapshotDirectory',
              'native.finish(snapshot, commit: false)'):
    assert token in storage,token
assert re.search(r'replacePortableSettings\(\s*previousConfig!', storage)
secure=read('lib/core/storage/secure_config.dart')
allow=secure.split('static const portableKeys',1)[1].split('};',1)[0]
for secret in ('_apiKeyName','_cedarToyTokenName','_openRouterApiKeyName','_weatherApiKeyName',
               '_visionApiKeyName','_agnesApiKeyName','_tavilyApiKeyName','_aiWangYouApiKeyName'):
    assert secret not in allow,secret
assert '_storage.readAll(' not in secure
# Every durable user table remains covered. The six exceptions are transient
# migration/runtime/diagnostic tables and must never confer device ownership.
database=read('lib/core/database/app_database.dart')
created=set(re.findall(r'CREATE TABLE(?: IF NOT EXISTS)? (\w+)',database))
export=database.split('Future<Map<String, Object?>> exportAll()',1)[1].split('// Read the whole',1)[0]
exported=set(re.findall(r"'([a-z_]+)'",export.split('const tables',1)[1]))
assert created-exported=={'maintenance_runs','memory_retrieval_audit','messages_v20',
                         'proactive_policy_events','provider_health_events','transfer_receipts'}
pat=read('android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiHeadPat.java')
assert 'EASTER_EGG_SECONDS = 2.8f' in pat and 'age < EASTER_EGG_SECONDS) return false' in pat
host=read('android/app/src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt')
assert 'if(!inside && !patTriggered)' in host
rate=read('android/app/src/main/java/com/catkiss/senlive2dcompanion/CaicaiRootTiltSmoother.java')
assert 'DEFAULT_MAX_DEGREES_PER_SECOND = 25f' in rate
assert 'Math.min(.05f, deltaSeconds)' in rate
model=read('android/app/src/main/java/com/catkiss/senlive2dcompanion/SenLive2DModel.java')
assert model.count('rootTiltSmoother.update(rootTilt, frameDelta)')==2
for test in ('cedar_share_rounds_v04256_test.dart','portable_snapshot_v04256_test.dart'):
    assert (app/'test'/test).is_file()
assert (app/'tools/caicai_smoke/src/androidTest/java/com/catkiss/senlive2dcompanion/CaicaiInteractionCadenceSmokeTest.java').is_file()
assert re.search(r'^version: 0.42.(?:56\+300|57\+301|58\+302|59\+303|60\+304|61\+305|62\+306|63\+307|64\+308|65\+309|66\+310|67\+311|68\+312)$',read('pubspec.yaml'),re.M)
print('v0.42.56 rounds, lower-leg tilt, held pat, sidebar and v7 portable inventory wired')
