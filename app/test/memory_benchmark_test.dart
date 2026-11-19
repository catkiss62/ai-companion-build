import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/database/app_database.dart';
import '../lib/core/memory/local_semantic_index.dart';
import '../lib/features/system/memory_benchmark.dart';
import '../lib/features/system/memory_benchmark_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('two open simulations do not share messages or settings; closed simulation fails closed', () async {
    final a = await AppDatabase.simulation(databaseFactoryFfi,LocalSemanticIndex(enabled:false));
    final b = await AppDatabase.simulation(databaseFactoryFfi,LocalSemanticIndex(enabled:false));
    try {
      await a.setSetting('isolation_marker','A');
      expect(await b.getSetting('isolation_marker'),isNull);
      await a.close();
      await expectLater(a.database,throwsStateError);
      expect(await b.getSetting('isolation_marker'),isNull);
    } finally {await a.close();await b.close();}
  });
  test('all eight fixed questions use actual prompt construction on an isolated database', () async {
    const widget = MemoryBenchmarkPage();
    expect(widget.key,isNull);
    final dir = await Directory.systemTemp.createTemp('bench-test-');
    try {
      final run = MemoryBenchmark(original:true,answers:false,progress:(_){},directory:dir,
        factory:databaseFactoryFfi,originalRunner:()async=>'{"acceptance":{"passed":true}}');
      final result = await run.run();
      expect(result['state'],'completed',reason:result.toString());
      expect(result['rows'],hasLength(8));expect(result['known_cny'],0);
      expect((result['rows'] as List).where((e)=>e['negative']==true),hasLength(2));
      expect((result['memories'] as List).isNotEmpty,isTrue);
      expect(jsonDecode(await File('${dir.path}/report.json').readAsString())['state'],'completed');
      expect(dir.listSync().whereType<Directory>(),isEmpty);
    } finally {await dir.delete(recursive:true);}
  });
}
