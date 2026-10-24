import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/platform/background_chat_command_server.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
import 'package:ai_companion_localfirst/widgets/immersive_lobby_controls.dart';

class _Chat extends ChatController {
  _Chat(AppDatabase db) : super(db: db, externalRecoveryOrchestrator: true);
  @override Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/background_commands');
  const codec = StandardMethodCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Map> send(String id) async {
    final reply = Completer<Map>();
    await messenger.handlePlatformMessage(channel.name,
      codec.encodeMethodCall(MethodCall('sendMessage', {'text': '消息', 'request_id': id})),
      (ByteData? bytes) { reply.complete(codec.decodeEnvelope(bytes!) as Map); });
    return reply.future;
  }

  for (final scenario in ['busy_reject', 'existing_idle', 'existing_busy']) {
    final busy = scenario != 'existing_idle';
    final exists = scenario != 'busy_reject';
    test('native bridge reports actual acceptance and stable identity; scenario=$scenario', () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      final chat = _Chat(db);
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      messenger.setMockMethodCallHandler(const MethodChannel('ai_companion/system'), (_) async => null);
      try {
        if (busy) {
          chat.sending = true;
        }
        if (exists) {
          await db.createGenerationTurn(user: ChatMessage(id: 'stable', role: 'user',
            content: '消息', createdAt: DateTime.now()), assistantMessageId: 'a',
            model: 'deepseek-flash', reasoningEffort: 'high');
        }
        BackgroundChatCommandServer(db: db, controller: chat).start();
        final result = await send('stable');
        expect(result['accepted'], exists);
        expect(result['ok'], exists);
        expect(result['request_id'], 'stable');
        if (!exists) expect(result['error'], isNotEmpty);
        final rows = await (await db.database).query('generation_jobs');
        expect(rows.length, exists ? 1 : 0);
        if (exists) {
          expect((await send('stable'))['accepted'], true);
          expect((await (await db.database).query('generation_jobs')).length, 1);
        }
      } finally {
        channel.setMethodCallHandler(null);
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(const MethodChannel('ai_companion/system'), null);
        chat.dispose();
        await db.closeForTesting();
      }
    });
  }
  for (final width in [320.0, 360.0, 800.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('lobby controls fit width=$width text scale=$scale', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SizedBox(
            width: width - 32, child: ImmersiveLobbyControls(
              model: TextButton(onPressed: () {}, child: const Row(mainAxisSize: MainAxisSize.min,
                children: [Flexible(child: Text('一个名称很长的模型-v4-flash', maxLines: 1,
                  overflow: TextOverflow.ellipsis)), Icon(Icons.expand_more)])),
              onBackground: () {}, onCreate: () {})))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(find.text('背景图')).dx,
          lessThan(tester.getTopLeft(find.text('一个名称很长的模型-v4-flash')).dx));
        expect(find.text('新建房间'), findsOneWidget);
      });
    }
  }
}
