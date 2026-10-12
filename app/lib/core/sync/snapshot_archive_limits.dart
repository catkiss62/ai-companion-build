/// One capacity contract for writing and reading a complete snapshot.
/// These defaults also match Android's independent PortableBackupZipVerifier.
/// A limit rejects the whole operation; it never truncates relationship data.
class SnapshotArchiveLimits {
  const SnapshotArchiveLimits({
    this.maxArchiveBytes = 8 * 1024 * 1024 * 1024,
    this.maxStateBytes = 480 * 1024 * 1024,
    this.maxManifestBytes = 1024 * 1024,
    this.maxBundledFileBytes = 8 * 1024 * 1024 * 1024,
    this.maxExpandedBytes = 9 * 1024 * 1024 * 1024,
    this.maxArchiveEntries = 200000,
  });

  final int maxArchiveBytes;
  final int maxStateBytes;
  final int maxManifestBytes;
  final int maxBundledFileBytes;
  final int maxExpandedBytes;
  final int maxArchiveEntries;

  void validateArchiveBytes(int bytes) {
    if (bytes <= 0 || bytes > maxArchiveBytes) {
      throw const FormatException('状态包文件大小超出可恢复限制');
    }
  }

  void validateStateBytes(int bytes) {
    if (bytes <= 0 || bytes > maxStateBytes) {
      throw const FormatException('state.json 大小超出可恢复限制');
    }
  }

  void validateEntryCount(int count) {
    if (count < 0 || count > maxArchiveEntries) {
      throw const FormatException('状态包文件数量超出可恢复限制');
    }
  }

  void validatePayload({
    required int stateBytes,
    required int manifestBytes,
    required int bundledFileBytes,
    required int expandedBytes,
    required int entryCount,
  }) {
    validateStateBytes(stateBytes);
    validateEntryCount(entryCount);
    if (manifestBytes <= 0 || manifestBytes > maxManifestBytes) {
      throw const FormatException('manifest.json 大小超出可恢复限制');
    }
    if (bundledFileBytes < 0 || bundledFileBytes > maxBundledFileBytes ||
        expandedBytes < stateBytes + manifestBytes + bundledFileBytes ||
        expandedBytes > maxExpandedBytes) {
      throw const FormatException('状态包解压后大小超出可恢复限制');
    }
  }
}
