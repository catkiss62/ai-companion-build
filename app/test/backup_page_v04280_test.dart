import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/transfer/transfer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late Directory root;
  late PathProviderPlatform previousPaths;
  final calls = <String>[];
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup-page-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('active_brain', '1');
    await db.setSetting('transfer_lock', '0');
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'openPlainBackup') return null;
      if (call.method == 'syncCalendarReminders') return true;
      return null;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = previousPaths;
    await db.closeForTesting();
    await root.delete(recursive: true);
  });
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferPage(database: db))));
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 80)); });
    await tester.pumpAndSettle();
  }
  testWidgets('backup entry retains file restore and never starts nearby', (tester) async {
    await show(tester);
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('保存备份'), findsOneWidget);
    expect(find.text('恢复备份'), findsOneWidget);
    expect(find.text('恢复旧版文件夹备份'), findsOneWidget);
    expect(find.text('从本机发送'), findsNothing);
    expect(find.text('本机接收'), findsNothing);
    await tester.tap(find.text('恢复备份'));
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 80)); });
    await tester.pumpAndSettle();
    expect(calls, contains('openPlainBackup'));
    expect(calls.where((x) => x.toLowerCase().contains('nearby')), isEmpty);
    await tester.runAsync(() async {
      expect(await db.getSetting('active_brain'), '1');
      expect(await db.getSetting('transfer_lock'), '0');
    });
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('standby installation can still explicitly recover ownership', (tester) async {
    final before = await tester.runAsync(() async {
      await db.setSetting('active_brain', '0');
      return (await db.transferStateIdentity()).generation;
    });
    await show(tester);
    await tester.tap(find.text('确认另一台已下线，手动接管本机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('另一台已下线，接管'));
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 100)); });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await db.getSetting('active_brain'), '1');
      expect((await db.transferStateIdentity()).generation, before! + 1);
      expect(await db.getSetting('transfer_lock'), '0');
    });
    expect(calls, contains('reconcileOverlayAfterTakeover'));
    expect(calls.where((x) => x.toLowerCase().contains('nearby')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
