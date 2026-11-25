import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/work_image_reference.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/ai/routed_vision_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/work_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('work image uses the selected work model and only the first channel', () async {
    sqfliteFfiInit();
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'work-first'});
    final config = SecureConfig.forTesting(const FlutterSecureStorage());
    await db.setSetting(RoutedVisionClient.qwenEnabledKey,'1');
    final endpoint = await config.readEndpoint();
    const payload = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB';
    final ref = WorkImageReference('截图.png',base64Decode(payload));
    var calls = 0;
    final text = await ref.observe(db:db, config:config, endpoint:endpoint, goal:'读图上的字',
      model:DeepSeekModelProfile.fromApiName('work-custom'), cancel:GenerationCancellationToken(),
      clientFactory:()=>MockClient((request) async {
        calls++;
        expect(request.url.toString(),endpoint);
        expect(request.headers['Authorization'],'Bearer work-first');
        final body = jsonDecode(request.body) as Map;
        expect(body['model'],'work-custom');
        expect(jsonEncode(body['messages']),contains('data:image/png;base64,$payload'));
        return http.Response.bytes(utf8.encode(jsonEncode({'choices':[{'finish_reason':'stop',
          'message':{'content':jsonEncode({'summary':'日期是周三'})}}]})),200);
      }));
    expect(text,'日期是周三');
    expect(calls,1);
    expect(ref.receipt.keys,unorderedEquals(['name','sha256']));
  });

  testWidgets('copy menu copies the selected words in rendered work prose', (tester) async {
    String? copied;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform,(call) async {
      if(call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      if(call.method == 'Clipboard.hasStrings') return {'value':true};
      return null;
    });
    addTearDown(()=>messenger.setMockMethodCallHandler(SystemChannels.platform,null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child:WorkMarkdown('alpha beta gamma')))));
    await tester.tap(find.byType(SelectableText).first);
    await tester.pump();
    final state = tester.state<EditableTextState>(find.byType(EditableText).first);
    state.userUpdateTextEditingValue(state.textEditingValue.copyWith(
      selection: const TextSelection(baseOffset:6,extentOffset:10)),SelectionChangedCause.longPress);
    state.showToolbar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy').last);
    await tester.pump();
    expect(copied,'beta');
  });
}
