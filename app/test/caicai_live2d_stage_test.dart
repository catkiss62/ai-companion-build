import 'package:ai_companion_localfirst/widgets/caicai_live2d_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_companion/caicai_live2d');
  testWidgets('enabled with no ZIP never creates a native platform view, including IME resize', (tester) async {
    var creates = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => {'available': false});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') creates++;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    Widget page(double inset) => MaterialApp(home: MediaQuery(
      data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
      child: const Scaffold(body: CaicaiLive2DStage()),
    ));
    await tester.pumpWidget(page(0));
    await tester.pumpAndSettle();
    expect(find.text('请在 Live2D 设置中导入菜菜模型 ZIP'), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    await tester.pumpWidget(page(300));
    await tester.pumpAndSettle();
    expect(creates, 0);
    CaicaiLive2DService.revision.value++;
    await tester.pumpAndSettle();
    expect(creates, 0);
  });
}
