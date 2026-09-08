import 'package:ai_companion_localfirst/core/media/safe_public_image_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects supported images from bytes instead of CDN MIME headers', () {
    expect(
      SafePublicImageDownloader.detectSupportedMime(
        const <int>[0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
      ),
      'image/webp',
    );
    expect(
      SafePublicImageDownloader.detectSupportedMime(
        const <int>[0xff, 0xd8, 0xff, 0xe0],
      ),
      'image/jpeg',
    );
    expect(
      SafePublicImageDownloader.detectSupportedMime(
        const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      ),
      'image/png',
    );
    expect(
      SafePublicImageDownloader.detectSupportedMime(
        'GIF89a'.codeUnits,
      ),
      'image/gif',
    );
  });

  test('rejects HTML bodies even when a server calls them images', () {
    expect(
      SafePublicImageDownloader.detectSupportedMime('<html>blocked</html>'.codeUnits),
      isNull,
    );
  });
}
