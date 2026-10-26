import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'core/database/app_database.dart';
import 'core/storage/secure_config.dart';
import 'integrations/qq_private/qq_private_config.dart';
import 'integrations/qq_private/qq_readonly_context.dart';
import 'integrations/qq_private/qq_runtime.dart';
import 'integrations/qq_private/qq_store.dart';

Future<void> runQqPrivateBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  const native=MethodChannel('ai_companion/qq_private_runtime');
  QqRuntime? coordinator;QqGateway? gateway;var stopped=false;
  final ownerToken=QqPrivateConfig.randomId();
  Future<void> clearOwnedFlag() async {
    await AppDatabase.instance.setSettingsAtomically({'qq_master_enabled_v2':'0'},expectedSettings:{'qq_master_owner_v2':ownerToken});
  }
  Future<void> status(String kind,String code) async {
    try {await native.invokeMethod<void>('status',{'kind':kind,'code':code});} catch(_) {}
  }
  Future<bool> allowed() async=>!stopped && await native.invokeMethod<bool>('enabled')==true &&
    await QqReadOnlyContext.readMain((ctx) async=>await ctx.allowed() && await ctx.setting('qq_master_enabled_v2')=='1');
  native.setMethodCallHandler((call) async {
    if(call.method=='shutdown') {stopped=true;await clearOwnedFlag();await coordinator?.stop();await gateway?.stop();}
  });
  try {
    final c=await QqPrivateConfig.read();
    if(c.appId.isEmpty || c.secret.isEmpty || c.namespace.isEmpty) throw StateError('config_missing');
    final store=QqStore(AppDatabase.instance);
    // Open/upgrade through the host before the protocol receives any handle.
    await store.db.database;
    if(stopped) return;
    await store.db.setSettingsAtomically({'qq_master_enabled_v2':'1','qq_master_owner_v2':ownerToken});
    final api=QqApi(appId:c.appId,secret:c.secret);
    final runtime=QqRuntime(store:store,api:api,secure:SecureConfig.instance,config:c,allowed:allowed,
      status:(code)=>unawaited(status('task',code)));
    coordinator=runtime;
    final support=await getApplicationSupportDirectory();
    final namespace=sha256.convert(utf8.encode('${c.appId}:${c.namespace}')).toString();
    final legacy=QqJournal(File('${support.path}/qq_private_v1/$namespace.json'));
    try {await legacy.open();await runtime.importLegacy(legacy.rows);} catch(_) {await status('task','legacy_history_failed');}
    gateway=QqGateway(api,onMessage:runtime.accept,
      onGroupMessage:(event)=>runtime.accept(event,group:true),
      onStatus:(code)=>unawaited(status('connection',code)));
    if(stopped) {await runtime.stop();await gateway.stop();return;}
    await runtime.start();await gateway.run();
  } catch(_) {
    await status('connection','startup_failed');
    try {await native.invokeMethod<void>('failed');} catch(_) {}
  } finally {try {await clearOwnedFlag();} catch(_) {} await coordinator?.stop();await gateway?.stop();native.setMethodCallHandler(null);}
}
