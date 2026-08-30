import 'dart:io';

import 'package:ai_companion_localfirst/core/sync/snapshot_cache_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes only stale known snapshot artifacts', () async {
    final root = await Directory.systemTemp.createTemp('snapshot_janitor_test_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final stale = File('${root.path}/ai_companion_received_old.zip');
    final recent = File('${root.path}/ai_companion_manual_recent.zip');
    final unrelated = File('${root.path}/user_photo.zip');
    await stale.writeAsString('old');
    await recent.writeAsString('recent');
    await unrelated.writeAsString('keep');
    final now = DateTime(2026, 8, 30, 12);
    await stale.setLastModified(now.subtract(const Duration(hours: 25)));
    await recent.setLastModified(now.subtract(const Duration(hours: 23)));
    await unrelated.setLastModified(now.subtract(const Duration(days: 20)));

    final removed = await SnapshotCacheJanitor.cleanDirectory(root, now: now);

    expect(removed, 1);
    expect(await stale.exists(), isFalse);
    expect(await recent.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('protects an active path even when stale', () async {
    final root = await Directory.systemTemp.createTemp('snapshot_janitor_active_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final active = Directory('${root.path}/companion_import_active');
    await active.create();
    final now = DateTime.now().add(const Duration(days: 3));

    final removed = await SnapshotCacheJanitor.cleanDirectory(
      root,
      now: now,
      activePaths: {active.path},
    );

    expect(removed, 0);
    expect(await active.exists(), isTrue);
  });
}
