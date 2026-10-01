// Standalone process used by snapshot_process_recovery_test.dart. It imports
// only the production filesystem journal plus real SQLite, never Flutter UI.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/storage/snapshot_directory_swap.dart';
import 'package:ai_companion_localfirst/core/storage/snapshot_restore_journal.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args[0]);
  final cut = args[1];
  Future<void> checkpoint(String step) async {
    if (cut != step) return;
    stdout.writeln('KILL_READY');
    await stdout.flush();
    await Completer<void>().future;
  }
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(p.join(root.path, 'state.db'));
  await db.execute('PRAGMA journal_mode=WAL');
  await db.execute('PRAGMA synchronous=FULL');
  await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
  Future<void> setting(String key, String value) => db.insert('settings',
    {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace,
  ).then((_) {});
  await setting('fixture_state', 'old');
  await setting('snapshot_recovery_pending_v1', 'restore-test');
  await setting('snapshot_restore_lease_v1', 'dead-process:lease|9999999999999');
  final source = await Directory(p.join(root.path, 'source')).create();
  await File(p.join(source.path, 'data')).writeAsString('new', flush: true);
  final plans = <PreparedDirectorySwap>[];
  for (final name in ['existing', 'previously_absent']) {
    final target = Directory(p.join(root.path, name));
    if (name == 'existing') {
      await target.create();
      await File(p.join(target.path, 'data')).writeAsString('old', flush: true);
    }
    plans.add(await PreparedDirectorySwap.prepare(
      sourceDirectory: source, targetDirectory: target,
      expectedPaths: ['data'], validatePath: (value) => value, token: 'restore-test',
    ));
  }
  final prefs = File(p.join(root.path, 'preferences.json'));
  await prefs.writeAsString('{"stage":"old","config":"old"}', flush: true);
  final log = SnapshotRestoreJournal(root);
  final record = <String, dynamic>{
    'version': 1, 'id': 'restore-test', 'freezeOwner': '',
    'swaps': plans.map((plan) => plan.recoveryRecord).toList(),
    'portable': {
      'previousPreferences': {'stage': 'old', 'config': 'old'},
      'preferences': {'stage': 'new', 'config': 'new'},
    },
  };
  await log.write(record);
  await checkpoint('afterJournal');
  await plans.first.activate(afterPreviousMoved: () => checkpoint('afterFirstRename'));
  await checkpoint('afterFirstTree');
  await plans.last.activate();
  await prefs.writeAsString('{"stage":"new","config":"old"}', flush: true);
  await checkpoint('partialPreferences');
  await prefs.writeAsString('{"stage":"new","config":"new"}', flush: true);
  if (cut == 'duringRollback') {
    await PreparedDirectorySwap.recover(
      Map<String, dynamic>.from(plans.first.recoveryRecord), committed: false,
      afterTargetRemoved: () => checkpoint('duringRollback'),
    );
  }
  await db.transaction((txn) async {
    await txn.insert('settings', {'key': 'fixture_state', 'value': 'new'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('settings', {'key': 'snapshot_restore_commit_v1', 'value': 'restore-test'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await checkpoint('insideDatabase');
  });
  await checkpoint('afterDatabase');
  await PreparedDirectorySwap.recover(
      Map<String, dynamic>.from(plans.first.recoveryRecord), committed: true);
  await checkpoint('duringCleanup');
  await log.recoverDirectories(record, committed: true);
  await setting('snapshot_recovery_pending_v1', '');
  // A completed operation whose journal deletion was interrupted must never
  // replay stale settings over a later user's preference change.
  await prefs.writeAsString('{"stage":"user-change","config":"new"}', flush: true);
  await checkpoint('afterConsistentMarker');
  throw StateError('unknown crash checkpoint: $cut');
}
