import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_companion/caicai_live2d');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidPortableBackend backend;
  late int revision;
  late List<MethodCall> calls;
  bool failApply = false;
  bool failFinish = false;

  setUp(() {
    backend = AndroidPortableBackend();
    revision = CaicaiLive2DService.revision.value;
    calls = [];
    failApply = false;
    failFinish = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'portableBegin') {
        return {'token': 'lease', 'live2dDirectory': '/test/models', 'preferences': {}};
      }
      if (call.method == 'portableApply' && failApply) {
        throw PlatformException(code: 'PARTIAL_NATIVE_APPLY');
      }
      if (call.method == 'portableFinish' && failFinish) {
        throw PlatformException(code: 'NATIVE_FINISH_FAILED');
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('read-only export commits and releases the lease without stage reload', () async {
    final snapshot = await backend.begin(exporting: true);
    await backend.finish(snapshot, commit: true);
    expect(calls.map((c) => c.method), ['portableBegin', 'portableFinish']);
    expect(calls.first.arguments, {'exporting': true});
    expect(calls.last.arguments, {'token': 'lease', 'commit': true});
    expect(CaicaiLive2DService.revision.value, revision);
  });
  test('failed export or unapplied restore releases without stage reload', () async {
    final snapshot = await backend.begin();
    await backend.finish(snapshot, commit: false);
    expect(CaicaiLive2DService.revision.value, revision);
    expect(calls.last.method, 'portableFinish');
  });
  test('successful applied restore refreshes installed package and calibration', () async {
    final snapshot = await backend.begin();
    await backend.apply(snapshot, {});
    await backend.finish(snapshot, commit: true);
    expect(CaicaiLive2DService.revision.value, revision + 1);
  });
  test('settings-only restore applies calibration without replacing the model index', () async {
    final snapshot = await backend.begin();
    await backend.apply(snapshot, {'caicai_stage': {}}, restoreModels: false);
    await backend.finish(snapshot, commit: true);
    final apply = calls.singleWhere((call) => call.method == 'portableApply');
    expect((apply.arguments as Map)['restoreModels'], false);
    expect(CaicaiLive2DService.revision.value, revision + 1);
  });
  test('rollback after native apply refreshes the restored model', () async {
    final snapshot = await backend.begin();
    await backend.apply(snapshot, {});
    await backend.finish(snapshot, commit: false);
    expect(CaicaiLive2DService.revision.value, revision + 1);
  });
  test('partial apply failure still refreshes after rollback', () async {
    final snapshot = await backend.begin();
    failApply = true;
    await expectLater(backend.apply(snapshot, {}), throwsA(isA<PlatformException>()));
    await backend.finish(snapshot, commit: false);
    expect(CaicaiLive2DService.revision.value, revision + 1);
  });
  test('finish failure after touching native state refreshes and keeps the error', () async {
    final snapshot = await backend.begin();
    await backend.apply(snapshot, {});
    failFinish = true;
    await expectLater(backend.finish(snapshot, commit: false), throwsA(isA<PlatformException>()));
    expect(CaicaiLive2DService.revision.value, revision + 1);
  });
}
