import 'dart:convert';
import 'dart:io';
import '../lib/features/system/official_memory_exam_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/core/ai/deepseek_client.dart';
import '../lib/core/ai/memory_extractor.dart';
import '../lib/core/desire/desire_engine.dart';
import '../lib/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/core/database/app_database.dart';
import '../lib/core/memory/local_semantic_index.dart';
import '../lib/features/system/memory_benchmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('original exam uses declared +08 wall clock and private resumable storage',() async {
    const page=OfficialMemoryExamPage();
    expect(page.key,isNull);
    expect(OfficialMemoryExam.wallClock('2026-01-07T19:10:01+08:00'),DateTime(2026,1,7,19,10,1));
    final dir=await Directory.systemTemp.createTemp('resume-exam-');
    try {
      final index=LocalSemanticIndex(enabled:false);
      final first=await AppDatabase.simulation(databaseFactoryFfi,index,directory:dir);
      await first.setSetting('fixed_exam_last_turn','5');
      await first.close();
      final reopened=await AppDatabase.simulation(databaseFactoryFfi,index,directory:dir);
      expect(await reopened.getSetting('fixed_exam_last_turn'),'5');
      final separate=await AppDatabase.simulation(databaseFactoryFfi,index);
      expect(await separate.getSetting('fixed_exam_last_turn'),isNull);
      await reopened.close();await separate.close();
    } finally {await dir.delete(recursive:true);}
  });
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
  test('from-zero replay uses real source ownership and charges only its run recorder', () async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'test-only'});
    final db = await AppDatabase.simulation(databaseFactoryFfi,LocalSemanticIndex(enabled:false));
    final events = <Map<String,Object?>>[];
    final client = DeepSeekClient(runCostRecorder:(e) async { events.add(e); },
      client:MockClient((request) async => http.Response(jsonEncode({
        'choices':[{'message':{'content':'{}'},'finish_reason':'stop'}],
        'usage':{'prompt_tokens':15,'completion_tokens':2,'prompt_cache_hit_tokens':0,'prompt_cache_miss_tokens':15},
      }),200,headers:{'content-type':'application/json; charset=utf-8'})));
    try {
      final when = MemoryBenchmark.anchor;
      final u = ChatMessage(id:'u',role:'user',content:'我看到了第十集。',createdAt:when);
      final a = ChatMessage(id:'a',role:'assistant',content:'记下了。',createdAt:when.add(const Duration(seconds:1)));
      await db.insertMessage(u);
      await db.insertMessage(a);
      await MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db)).extractSimulationTurn(u,a);
      expect(events.where((e)=>e['lane']=='memory_extraction' && e['usage'] is Map),isNotEmpty);
      expect(await db.getSetting('last_memory_error'),'');
      expect(await (await db.database).query('post_turn_jobs'),isEmpty);
      final ordered=MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db));
      await ordered.ingestExamTurn(u,a);
      final calls=events.length;
      await ordered.ingestExamTurn(u,a);
      expect(events,hasLength(calls));
      expect((await (await db.database).query('post_turn_jobs')).single['status'],'done');
    } finally { client.close(); await db.close(); }
  });
}
