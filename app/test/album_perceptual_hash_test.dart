import 'package:ai_companion_localfirst/core/phone/album_perceptual_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance compares all 64 perceptual bits', () {
    expect(
      AlbumPerceptualHash.distance(
        '0000000000000000',
        '0000000000000000',
      ),
      0,
    );
    expect(
      AlbumPerceptualHash.distance(
        '0000000000000000',
        'ffffffffffffffff',
      ),
      64,
    );
    expect(AlbumPerceptualHash.distance('bad', 'hash'), isNull);
  });

  test('near duplicate threshold accepts five changed bits, rejects six', () {
    expect(
      AlbumPerceptualHash.isNearDuplicate(
        '0000000000000000',
        '000000000000001f',
      ),
      isTrue,
    );
    expect(
      AlbumPerceptualHash.isNearDuplicate(
        '0000000000000000',
        '000000000000003f',
      ),
      isFalse,
    );
  });
}
