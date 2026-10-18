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
}
