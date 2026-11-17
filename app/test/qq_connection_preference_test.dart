import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_companion_localfirst/features/settings/qq_private_settings_page.dart';

void main() {
  const channel=MethodChannel('ai_companion/qq_private_control');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  testWidgets('missing poll state keeps the last confirmed checkbox without writing false',(tester)async {
    await tester.binding.setSurfaceSize(const Size(900,1800));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    var polls=0,writes=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async {
      if(call.method=='snapshot')return ++polls==1?{'autoReconnect':true,'enabled':true}:null;
      if(call.method=='setAutoReconnect')writes++;
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home:QqPrivateSettingsPage()));await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,true);
    await tester.pump(const Duration(seconds:2));await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,true);expect(writes,0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('old poll finishing after a checkbox action cannot overwrite the newer state',(tester)async {
    await tester.binding.setSurfaceSize(const Size(900,1800));addTearDown(()=>tester.binding.setSurfaceSize(null));
    var polls=0;var preference=false;final old=Completer<Map<String,Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async {
      if(call.method=='snapshot') {
        polls++;if(polls==2)return old.future;
        return {'autoReconnect':preference,'enabled':true};
      }
      if(call.method=='setAutoReconnect')preference=(call.arguments as Map)['enabled']==true;
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home:QqPrivateSettingsPage()));await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds:2));
    tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged!(true);
    await tester.pumpAndSettle();expect(preference,true);
    old.complete({'autoReconnect':false,'enabled':true});await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,true);
    await tester.pumpWidget(const SizedBox());
  });
}
