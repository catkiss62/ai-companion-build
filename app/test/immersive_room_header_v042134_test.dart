import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/features/immersive/immersive_room_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('real room title and controls fit width=$width scale=$scale', (tester) async {
        await tester.runAsync(() async {
          final db = await AppDatabase.createForTesting(databaseFactoryFfi);
          final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          const system = MethodChannel('ai_companion/system');
          messenger.setMockMethodCallHandler(system, (_) async => null);
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          try {
            await db.setSetting('chat_visual_stage_enabled', '0');
            final room = await ImmersiveRoomRepository(db).createRoom(
              title: '一个很长的用户房间名称', openingScene: '', inheritCurrentChat: false);
            final controller = ImmersiveRoomController(roomId: room.id, db: db);
            await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
              home: ImmersiveRoomPage(roomId: room.id, controller: controller)));
            for (var i = 0; i < 100 && find.text('NSFW').evaluate().isEmpty; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              await tester.pump();
            }
            await tester.pump();
            expect(find.text('沉浸房间'), findsOneWidget);
            final title = tester.renderObject<RenderParagraph>(find.text('沉浸房间'));
            expect(title.didExceedMaxLines, false);
            final nsfw = tester.getRect(find.text('NSFW'));
            final english = tester.getRect(find.text('EN'));
            expect(english.right, lessThan(nsfw.left));
            expect(nsfw.right, lessThanOrEqualTo(width));
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await Future<void>.delayed(const Duration(milliseconds: 30));
            messenger.setMockMethodCallHandler(system, null);
            await db.closeForTesting();
          }
        });
      });
    }
  }
}
