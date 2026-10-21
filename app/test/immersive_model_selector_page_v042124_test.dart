import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_model_selection.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/immersive/immersive_room_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  for(final configured in [false,true]) {
    testWidgets('small screen and large text show only configured model choices: $configured', (tester) async {
      await tester.runAsync(() async {
        final db = await AppDatabase.createForTesting(databaseFactoryFfi);
        final longModel = '[A]glm-5.3-flash-${List.filled(6,'long-model-').join()}1';
        FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'first-test',
          if(configured) 'aiwangyou_gemini_api_key':'second-test',
          if(configured) 'aiwangyou_final_reply_model':longModel});
        await db.setSetting('deepseek_model','first-model');
        if(configured) await db.setSetting('creative_work_model','work-model');
        tester.view.physicalSize=const Size(360,740); tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        try {
          await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(
            data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.6)),child:child!),
            home:ImmersiveRoomLobbyPage(repository:ImmersiveRoomRepository(db),
              secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()))));
          for(var i=0;i<100&&find.text('first-model').evaluate().isEmpty;i++) {
            await Future<void>.delayed(const Duration(milliseconds:20));await tester.pump();
          }
          expect(find.text('新建房间'),findsOneWidget);
          expect(tester.takeException(),isNull);
          await tester.tap(find.text('first-model'));await tester.pumpAndSettle();
          expect(find.text('第一通道'),findsOneWidget);
          expect(find.text('第二通道'),configured?findsOneWidget:findsNothing);
          expect(find.text('作品模型'),configured?findsOneWidget:findsNothing);
          if(configured) {
            expect(find.text(longModel),findsOneWidget);
            await tester.ensureVisible(find.text(longModel));await tester.tap(find.text(longModel));
            await tester.pumpAndSettle();
            expect(await db.getSetting(ImmersiveModelSelection.settingKey),'second');
            expect(find.text(longModel),findsOneWidget);
          }
          expect(tester.takeException(),isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await Future<void>.delayed(const Duration(milliseconds:30));
          await db.closeForTesting();
        }
      });
    });
  }
}
