import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_gateway.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/model_dialogue/model_dialogue_page.dart';

const _config=ModelDialogueConfiguration(
  ModelDialogueEndpoint(speaker:'deepseek',endpoint:'https://ds.example/chat',model:'deepseek-test',apiKey:'test'),
  ModelDialogueEndpoint(speaker:'gemini',endpoint:'https://gm.example/chat',model:'gemini-test',apiKey:'test'));
// SSE is UTF-8 on the wire; http.Response otherwise defaults to Latin-1.
http.Response _response(String body,int status) => http.Response.bytes(utf8.encode(body),status,
  headers:const {'content-type':'text/event-stream; charset=utf-8'});

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late ModelDialogueRepository repository;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);repository=ModelDialogueRepository(db);});
  tearDown(() async {await db.closeForTesting();});
  Future<void> waitFor(WidgetTester tester,Finder finder) async {
    for(var n=0;n<150&&finder.evaluate().isEmpty;n++) {
      await Future<void>.delayed(const Duration(milliseconds:20));await tester.pump();
    }
    expect(finder,findsWidgets);
  }
  Future<ModelDialogueRoom> seed() => repository.create(title:'海里的两种想法',topic:'同一个问题，可以有怎样不同的看法？',participants:_config.snapshot);

  testWidgets('lobby creates a private paused room without contacting a model', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home:ModelDialogueLobbyPage(repository:repository,
        configurationLoader:() async=>_config)));
      await waitFor(tester,find.text('还没有试聊房间。'));
      await tester.tap(find.text('创建房间'));await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0),'我的试聊');
      await tester.enterText(find.byType(TextField).at(1),'');
      await tester.tap(find.text('创建'));await tester.pump();
      await waitFor(tester,find.text('开始对谈'));
      expect((await repository.listRooms()).single.title,'我的试聊');
      expect(await repository.messagesForRoom((await repository.listRooms()).single.id),isEmpty);
      expect(find.byType(AndroidView),findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('room renders three speakers, streams body only and uses the supplied background', (tester) async {
    await tester.runAsync(() async {
      final room=await seed();
      var calls=0;
      final gateway=ModelDialogueGateway(DeepSeekClient(streamClientFactory:()=>MockClient((request) async {
        calls++;final text=calls==1?'我想聊聊：同一段经历为什么会有不同理解。':'也许可以先从我们注意到的细节说起。';
        return _response('data: ${jsonEncode({'choices':[{'delta':{'content':jsonEncode({'text':text,'action':'continue'})},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n',200);
      })),retryDelay:Duration.zero);
      final capture=GlobalKey();
      tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(key:capture,child:MaterialApp(home:ModelDialogueRoomPage(
        roomId:room.id,repository:repository,configurationLoader:() async=>_config,gateway:gateway))));
      await waitFor(tester,find.text('开始对谈'));
      await tester.tap(find.text('开始对谈'));await tester.pump();
      await waitFor(tester,find.text('我想聊聊：同一段经历为什么会有不同理解。'));
      // A visible streamed draft is not yet committed; sending is disabled until idle.
      await waitFor(tester,find.text('继续对谈'));
      await tester.enterText(find.byType(TextField),'我也想听听另一种理解。');
      await tester.tap(find.byTooltip('发送'));await tester.pump();
      await waitFor(tester,find.text('也许可以先从我们注意到的细节说起。'));
      await waitFor(tester,find.text('继续对谈'));
      expect(calls,2);expect(find.text('DeepSeek'),findsOneWidget);expect(find.text('Gemini'),findsOneWidget);
      expect(find.text('我也想听听另一种理解。'),findsOneWidget);
      expect(find.textContaining('"action"'),findsNothing);expect(tester.takeException(),isNull);
      final imageWidget=tester.widget<Image>(find.byType(Image).first);
      expect((imageWidget.image as AssetImage).assetName,modelDialogueBackground);
      await tester.pumpAndSettle();
      final boundary=capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image=await boundary.toImage(pixelRatio:1);
      final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
      await Directory('build').create(recursive:true);
      await File('build/model_dialogue_ui.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('small display and large text remain usable with the keyboard open', (tester) async {
    await tester.runAsync(() async {
      final room=await seed();
      tester.view.physicalSize=const Size(360,740);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(
        data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.6),viewInsets:const EdgeInsets.only(bottom:280)),
        child:child!),home:ModelDialogueRoomPage(roomId:room.id,repository:repository,configurationLoader:() async=>_config)));
      await waitFor(tester,find.text('开始对谈'));await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);expect(find.byTooltip('发送'),findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
