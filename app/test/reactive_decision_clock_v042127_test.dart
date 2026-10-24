import 'dart:io';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_recovery.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_engine.dart';
import 'package:ai_companion_localfirst/core/maintenance/recovery_orchestrator.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
class _Paths extends PathProviderPlatform {
  _Paths(this.path);final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
class _CountingProactive extends ProactiveEngine {
  _CountingProactive(AppDatabase db,DeepSeekClient client):super(db:db,ai:client,
    desireEngine:DesireEngine(db),android:AndroidBridge.instance);
  int local=0, decisions=0;
  @override Future<LocalCompanionHeartbeat?> maintainLocalStateOnly({bool forceForDebug=false,
    Duration perceptionMinInterval=const Duration(minutes:4)})async{
    local++;expect(perceptionMinInterval,const Duration(seconds:90));
    return LocalCompanionHeartbeat(snapshot:await db.loadDesire(),userBusy:false,busyScore:.2);
  }
  @override Future<ProactiveDecision> evaluate({bool forceForDebug=false,String? forcedThoughtIdForDebug,
    Duration perceptionMinInterval=const Duration(minutes:4)})async{
    decisions++;return const ProactiveDecision(sent:false,reason:'counted_decision');
  }
  @override Future<String> continueCedarActivityIfDue({required DateTime now})async=>'waiting';
  @override Future<Duration?> cedarContinuationDelay({required DateTime now})async=>null;
  @override Future<ProactiveDecision> deliverPendingCedarShareIfAny()async=>const ProactiveDecision(sent:false,reason:'no_share');
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('bounded phone wakes restore +365 decision opportunities',()async{
    final files=await Directory.systemTemp.createTemp('decision-clock-');
    final paths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel=MethodChannel('ai_companion/system');
    messenger.setMockMethodCallHandler(channel,(_)async=>null);
    FlutterSecureStorage.setMockInitialValues({});
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);final client=DeepSeekClient();
    try{
      await db.setSetting('post_turn_queue_enabled','0');
      final proactive=_CountingProactive(db,client);
      final orchestrator=RecoveryOrchestrator(db:db,proactive:proactive,
        generationRecovery:DurableGenerationRecovery(db:db,runner:DurableGenerationRunner(db:db,client:client)),
        memoryExtractor:MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db)));
      const key='recovery_orchestrator_next_heartbeat_at';
      final due=DateTime.now().add(const Duration(minutes:20)).millisecondsSinceEpoch.toString();
      await db.setSetting(key,due);
      for(var i=0;i<4;i++){
        await db.setSetting('last_perception_capture_at',DateTime.now().subtract(const Duration(minutes:2)).millisecondsSinceEpoch.toString());
        final cycle=await orchestrator.runOnce(wakeReason:'signal:window_changed');
        expect(cycle.proactiveReason,'counted_decision');
        expect(int.parse((await db.getSetting(key))!), greaterThan(DateTime.now().millisecondsSinceEpoch));
      }
      expect(proactive.local,0);expect(proactive.decisions,4);
      await db.setSetting(key,'0');await orchestrator.runOnce();
      expect(proactive.decisions,5);expect(proactive.local,0);
      expect(int.parse((await db.getSetting(key))!),greaterThan(DateTime.now().millisecondsSinceEpoch));
    }finally{
      client.close();await db.closeForTesting();messenger.setMockMethodCallHandler(channel,null);
      PathProviderPlatform.instance=paths;await files.delete(recursive:true);
    }
  });
}
