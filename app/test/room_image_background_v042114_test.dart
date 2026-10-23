import 'package:ai_companion_localfirst/core/models/room_background_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/widgets/room_image_background.dart';

void main() {
  for (final size in const [Size(360, 640), Size(390, 844), Size(800, 1280)]) {
    testWidgets('immersive background preserves full width at $size and does not shrink with keyboard', (tester) async {
      tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> render(double keyboard) async {
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(size: size, viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: Align(alignment: Alignment.topLeft, child: SizedBox(
            width: size.width, height: size.height - keyboard, child: const RoomImageBackground())))));
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as AssetImage).assetName, immersiveRoomBackground);
        expect(image.fit, BoxFit.contain);
        expect(tester.getSize(find.byType(Image)), Size(size.width,size.width*2048/1000));
        expect(tester.takeException(), isNull);
      }
      await render(0); await render(240);
    });
  }
  testWidgets('free room geometry stays outside screen bounds across keyboard height changes',(tester) async {
    tester.view.physicalSize=const Size(360,640);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    Future<Rect> render(double height) async {
      await tester.pumpWidget(MaterialApp(home:Align(alignment:Alignment.topLeft,
        child:SizedBox(width:360,height:height,child:const RoomImageBackground(
          config:RoomBackgroundConfig(scale:2,x:-3,y:4))))));
      await tester.pumpAndSettle();expect(tester.takeException(),isNull);
      return tester.getRect(find.byType(Image));
    }
    final full=await render(640),keyboard=await render(360);
    expect(full,keyboard);expect(full.width,720);expect(full.left,lessThan(-360));
    expect(full.top,1440);
  });

}
