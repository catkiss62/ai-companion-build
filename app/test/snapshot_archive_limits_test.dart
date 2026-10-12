import 'package:ai_companion_localfirst/core/sync/snapshot_archive_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const limits = SnapshotArchiveLimits();

  test('capacity boundaries accept exact maxima without allocating large files', () {
    limits.validateArchiveBytes(limits.maxArchiveBytes);
    limits.validatePayload(
      stateBytes: limits.maxStateBytes,
      manifestBytes: limits.maxManifestBytes,
      bundledFileBytes: limits.maxBundledFileBytes,
      expandedBytes: limits.maxStateBytes + limits.maxManifestBytes +
          limits.maxBundledFileBytes,
      entryCount: limits.maxArchiveEntries,
    );
  });

  test('ZIP capacity rejects an empty or one-byte-oversized archive', () {
    for (final bytes in [0, -1, limits.maxArchiveBytes + 1]) {
      expect(() => limits.validateArchiveBytes(bytes), throwsFormatException);
    }
  });

  test('state, manifest, bundled bytes and entry limits fail closed', () {
    for (final values in [
      [limits.maxStateBytes + 1, 1, 0, 2],
      [1, limits.maxManifestBytes + 1, 0, 2],
      [1, 1, limits.maxBundledFileBytes + 1, 2],
      [1, 1, 0, limits.maxArchiveEntries + 1],
      [0, 1, 0, 2],
      [1, 0, 0, 2],
    ]) {
      expect(() => limits.validatePayload(
        stateBytes: values[0],
        manifestBytes: values[1],
        bundledFileBytes: values[2],
        expandedBytes: values[0] + values[1] + values[2],
        entryCount: values[3],
      ), throwsFormatException);
    }
  });

  test('expanded bytes must include the entire payload and fit its own bound', () {
    for (final expanded in [1, limits.maxExpandedBytes + 1]) {
      expect(() => limits.validatePayload(
        stateBytes: 1, manifestBytes: 1, bundledFileBytes: 0,
        expandedBytes: expanded, entryCount: 2,
      ), throwsFormatException);
    }
  });
}
