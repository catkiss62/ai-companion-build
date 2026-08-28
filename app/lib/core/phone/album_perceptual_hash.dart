import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A local 64-bit difference hash used only to avoid keeping visually near-
/// identical album thumbnails. No image body or hash leaves the device through
/// this helper.
class AlbumPerceptualHash {
  const AlbumPerceptualHash._();

  static const int duplicateDistance = 5;

  static Future<String> fromFile(File file) async {
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return '';

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Image? scaled;
    try {
      final imageDescriptor = await ui.ImageDescriptor.encoded(buffer);
      descriptor = imageDescriptor;
      final imageCodec = await imageDescriptor.instantiateCodec();
      codec = imageCodec;
      final decodedImage = (await imageCodec.getNextFrame()).image;
      decoded = decodedImage;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        decodedImage,
        ui.Rect.fromLTWH(
          0,
          0,
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        ),
        const ui.Rect.fromLTWH(0, 0, 9, 8),
        ui.Paint()..filterQuality = ui.FilterQuality.low,
      );
      final picture = recorder.endRecording();
      final scaledImage = await picture.toImage(9, 8);
      scaled = scaledImage;
      picture.dispose();
      final rgba =
          await scaledImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return '';

      var hash = BigInt.zero;
      var bit = 0;
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final left = _luminance(rgba, (y * 9 + x) * 4);
          final right = _luminance(rgba, (y * 9 + x + 1) * 4);
          if (left > right) hash |= BigInt.one << bit;
          bit++;
        }
      }
      return hash.toRadixString(16).padLeft(16, '0');
    } catch (_) {
      return '';
    } finally {
      scaled?.dispose();
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static int? distance(String left, String right) {
    final a = _parse(left);
    final b = _parse(right);
    if (a == null || b == null) return null;
    var different = a ^ b;
    var count = 0;
    while (different != BigInt.zero) {
      different &= different - BigInt.one;
      count++;
    }
    return count;
  }

  static bool isNearDuplicate(String left, String right) {
    final value = distance(left, right);
    return value != null && value <= duplicateDistance;
  }

  static int _luminance(ByteData rgba, int offset) {
    final red = rgba.getUint8(offset);
    final green = rgba.getUint8(offset + 1);
    final blue = rgba.getUint8(offset + 2);
    return red * 299 + green * 587 + blue * 114;
  }

  static BigInt? _parse(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(normalized)) return null;
    return BigInt.tryParse(normalized, radix: 16);
  }
}
