import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/chat/chat_quick_settings_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('Material3 chat visuals save and reload depth controls',
      (tester) async {
    await tester.runAsync(() async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> waitFor(bool Function() ready) async {
        for (var attempt = 0; attempt < 50 && !ready(); attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        expect(ready(), isTrue);
      }

      Future<void> openPage(String key) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ChatVisualSettingsPage(
            key: ValueKey(key),
            database: db,
            onEditPortrait: () async {},
          ),
        ));
        await waitFor(() => find.text('角色聊天舞台').evaluate().isNotEmpty);
      }

      final depth = find.widgetWithText(SwitchListTile, '立体背景');
      final strength = find.byWidgetPredicate(
          (widget) => widget is Slider && widget.min == .2 && widget.max == 1);

      await openPage('initial');
      expect(tester.widget<SwitchListTile>(depth).value, isFalse);
      expect(strength, findsNothing);
      await tester.ensureVisible(depth);
      await tester.tap(depth);
      await tester.pump();
      expect(await db.getSetting('chat_background_depth'), '1');
      expect(tester.widget<Slider>(strength).value, .55);

      await tester.ensureVisible(strength);
      final sliderRect = tester.getRect(strength);
      await tester.tapAt(sliderRect.centerRight - const Offset(48, 0));
      await tester.pump();
      final selectedStrength = tester.widget<Slider>(strength).value;
      expect(selectedStrength, greaterThan(.55));
      expect(await db.getSetting('chat_background_depth_strength'),
          selectedStrength.toStringAsFixed(2));

      await openPage('reopened');
      expect(tester.widget<SwitchListTile>(depth).value, isTrue);
      expect(tester.widget<Slider>(strength).value, selectedStrength);

      final stage = find.widgetWithText(SwitchListTile, '角色聊天舞台');
      await tester.ensureVisible(stage);
      await tester.tap(stage);
      await tester.pump();
      expect(depth, findsNothing);
      expect(await db.getSetting('chat_background_depth'), '1');
      await tester.tap(stage);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(depth).value, isTrue);
      expect(tester.widget<Slider>(strength).value, selectedStrength);

      await tester.ensureVisible(depth);
      await tester.tap(depth);
      await tester.pump();
      expect(await db.getSetting('chat_background_depth'), '0');
      await openPage('disabled');
      expect(tester.widget<SwitchListTile>(depth).value, isFalse);
      expect(strength, findsNothing);
      expect(await db.getSetting('chat_background_depth_strength'),
          selectedStrength.toStringAsFixed(2));
      expect(tester.takeException(), isNull);
    });
  });
}
