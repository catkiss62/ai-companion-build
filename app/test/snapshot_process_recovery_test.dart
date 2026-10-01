import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/core/storage/snapshot_restore_journal.dart';
import 'package:ai_companion_localfirst/core/sync/snapshot_restore_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Preferences extends PortableCompanionStorage {
  _Preferences(this.root);
  final Directory root;
  @override
  Future<void> recover(Map<String, dynamic> record, {required bool committed}) =>
      File(p.join(root.path, 'preferences.json')).writeAsString(
        jsonEncode(record[committed ? 'preferences' : 'previousPreferences']),
        flush: true,
      ).then((_) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const committedCuts = {'afterDatabase', 'duringCleanup', 'afterConsistentMarker'};
  for (final cut in [
    'afterJournal', 'afterFirstRename', 'afterFirstTree', 'partialPreferences',
    'insideDatabase', 'duringRollback', ...committedCuts,
  ]) {
    test('SIGKILL at $cut recovers a coherent state on next process start', () async {
      final root = await Directory.systemTemp.createTemp('snapshot-kill-');
      AppDatabase? db;
      Process? child;
      try {
        child = await Process.start('dart', [
          'run', 'tools/snapshot_crash_child.dart', root.path, cut,
        ]);
        final errors = child.stderr.transform(utf8.decoder).join();
        await child.stdout.transform(utf8.decoder).transform(const LineSplitter())
            .firstWhere((line) => line == 'KILL_READY')
            .timeout(const Duration(seconds: 45));
        expect(child.kill(ProcessSignal.sigkill), isTrue);
        expect(await child.exitCode, isNot(0));
        // Dart's native-asset hooks legitimately print progress to stderr.
        final childErrors = (await errors).replaceAll('Running build hooks...', '').trim();
        expect(childErrors, isEmpty);
        db = await AppDatabase.createForTesting(databaseFactoryFfi,
            path: p.join(root.path, 'state.db'), reopenExisting: true);
        final journal = SnapshotRestoreJournal(root);
        final recovery = SnapshotRestoreCoordinator(db, _Preferences(root), journal: journal);
        expect(await recovery.recoverIfPending(), isTrue);
        expect(await recovery.recoverIfPending(), isTrue); // idempotent startup
        final committed = committedCuts.contains(cut);
        expect(await db.getSetting('fixture_state'), committed ? 'new' : 'old');
        expect(await File(p.join(root.path, 'existing', 'data')).readAsString(),
            committed ? 'new' : 'old');
        expect(await Directory(p.join(root.path, 'previously_absent')).exists(), committed);
        final prefs = jsonDecode(await File(p.join(root.path, 'preferences.json')).readAsString());
        expect(prefs['stage'], cut == 'afterConsistentMarker' ? 'user-change' : committed ? 'new' : 'old');
        expect(prefs['config'], committed ? 'new' : 'old');
        expect(await journal.read(), isNull);
        expect(await db.getSetting(SnapshotRestoreCoordinator.pendingKey), '');
        expect(await db.brainWorkAllowed(), isTrue);
      } finally {
        child?.kill(ProcessSignal.sigkill);
        await db?.closeForTesting();
        await root.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 60)), skip: Platform.isWindows);
  }
}
