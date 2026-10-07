import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> fixture({bool depth = false, bool layered = false}) async {
  final bytes = Uint8List(256 * 256 * 4);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final i = (y * 256 + x) * 4;
      final shade = layered ? (y < 128 ? 51 : 230) : 38;
      bytes[i] = depth ? shade : x;
      bytes[i + 1] = depth ? shade : y;
      bytes[i + 2] = depth ? shade : 80;
      bytes[i + 3] = 255;
    }
  }
  final ready = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, 256, 256, ui.PixelFormat.rgba8888,
      ready.complete);
  return ready.future;
}

Future<Uint8List> render(ui.FragmentProgram program, ui.Image room,
    ui.Image depth, double x, double y, double strength) async {
  final shader = program.fragmentShader()
    ..setFloat(0, 256)
    ..setFloat(1, 256)
    ..setFloat(2, 256)
    ..setFloat(3, 256)
    ..setFloat(4, x)
    ..setFloat(5, y)
    ..setFloat(6, strength)
    ..setImageSampler(0, room)
    ..setImageSampler(1, depth);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 256, 256),
      ui.Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
    shader.dispose();
  }
}

int channel(Uint8List image, int x, int y, [int component = 0]) =>
    image[(y * 256 + x) * 4 + component];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compiled shader moves neutral-depth room in both directions',
      (tester) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/room_depth.frag');
      final room = await fixture();
      final depth = await fixture(depth: true);
      try {
        final center = await render(program, room, depth, 0, 0, 1);
        final positive = await render(program, room, depth, 1, 1, 1);
        final negative = await render(program, room, depth, -1, -1, 1);
        final halfCenter = await render(program, room, depth, 0, 0, .55);
        final half = await render(program, room, depth, 1, 1, .55);
        for (var axis = 0; axis < 2; axis++) {
          final origin = channel(center, 128, 128, axis);
          final forward = channel(positive, 128, 128, axis) - origin;
          final backward = origin - channel(negative, 128, 128, axis);
          final smaller = channel(half, 128, 128, axis) -
              channel(halfCenter, 128, 128, axis);
          expect(forward, greaterThanOrEqualTo(8));
          expect(backward, greaterThanOrEqualTo(8));
          expect((forward - backward).abs(), lessThanOrEqualTo(2));
          expect(smaller, inInclusiveRange(4, forward - 1));
        }
        final off = await render(program, room, depth, 1, 1, 0);
        final offReversed = await render(program, room, depth, -1, -1, 0);
        expect(off, orderedEquals(offReversed));
        expect(channel(off, 64, 70), closeTo(64, 1));
        expect(channel(off, 64, 70, 1), closeTo(70, 1));
      } finally {
        room.dispose();
        depth.dispose();
      }
    });
  });

  testWidgets('compiled shader retains depth difference and covered edges',
      (tester) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/room_depth.frag');
      final room = await fixture();
      final depth = await fixture(depth: true, layered: true);
      try {
        final center = await render(program, room, depth, 0, 0, 1);
        final shifted = await render(program, room, depth, 1, 0, 1);
        final far = channel(shifted, 64, 64) - channel(center, 64, 64);
        final near = channel(shifted, 64, 192) - channel(center, 64, 192);
        expect(far, greaterThanOrEqualTo(8));
        expect(near, greaterThanOrEqualTo(far + 2));
        for (final direction in [-1.0, 1.0]) {
          final corner = await render(program, room, depth, direction, direction, 1);
          for (final x in [0, 255]) {
            for (final y in [0, 255]) {
              expect(channel(corner, x, y), inInclusiveRange(1, 254));
              expect(channel(corner, x, y, 1), inInclusiveRange(1, 254));
              expect(channel(corner, x, y, 3), 255);
            }
          }
        }
      } finally {
        room.dispose();
        depth.dispose();
      }
    });
  });
}
