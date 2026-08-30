import 'package:ai_companion_localfirst/core/sync/snapshot_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary backup accepts the valid initial generation zero', () {
    expect(SnapshotArchiveKind.backup.acceptsSourceGeneration(0), isTrue);
    expect(SnapshotArchiveKind.backup.acceptsSourceGeneration(1), isTrue);
    expect(SnapshotArchiveKind.backup.acceptsSourceGeneration(-1), isFalse);
  });

  test('takeover still requires a reserved positive generation', () {
    expect(SnapshotArchiveKind.takeover.acceptsSourceGeneration(0), isFalse);
    expect(SnapshotArchiveKind.takeover.acceptsSourceGeneration(1), isTrue);
  });

  test('snapshot manifest describes plaintext backup honestly', () {
    expect(SnapshotArchiveKind.backup.manifestEncryption, 'none');
    expect(
      SnapshotArchiveKind.takeover.manifestEncryption,
      'nearby_transport_or_manual_aes_gcm',
    );
  });
}
