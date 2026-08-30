import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ai_companion_localfirst/core/storage/snapshot_directory_swap.dart';

String _safe(String value) {
  final normalized = value.replaceAll('\\', '/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      normalized.contains('..') ||
      p.posix.normalize(normalized) != normalized) {
    throw FormatException('unsafe path: $value');
  }
  return normalized;
}

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('snapshot_swap_test_');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('rollback restores the exact previous live tree', () async {
    final source = Directory(p.join(sandbox.path, 'source'));
    final target = Directory(p.join(sandbox.path, 'live'));
    await source.create();
    await target.create();
    await File(p.join(source.path, 'new.txt')).writeAsString('new');
    await File(p.join(target.path, 'old.txt')).writeAsString('old');

    final swap = await PreparedDirectorySwap.prepare(
      sourceDirectory: source,
      targetDirectory: target,
      expectedPaths: const ['new.txt'],
      validatePath: _safe,
      token: 'rollback',
    );
    await swap.activate();
    expect(await File(p.join(target.path, 'new.txt')).readAsString(), 'new');
    expect(await File(p.join(target.path, 'old.txt')).exists(), isFalse);

    await swap.rollback();
    expect(await File(p.join(target.path, 'old.txt')).readAsString(), 'old');
    expect(await File(p.join(target.path, 'new.txt')).exists(), isFalse);
  });

  test('commit keeps only the complete incoming tree', () async {
    final source = Directory(p.join(sandbox.path, 'source'));
    final target = Directory(p.join(sandbox.path, 'live'));
    await source.create();
    await target.create();
    await File(p.join(source.path, 'kept.txt')).writeAsString('kept');
    await File(p.join(target.path, 'stale.txt')).writeAsString('stale');

    final swap = await PreparedDirectorySwap.prepare(
      sourceDirectory: source,
      targetDirectory: target,
      expectedPaths: const ['kept.txt', 'declared_missing.txt'],
      validatePath: _safe,
      token: 'commit',
    );
    await swap.activate();
    await swap.commit();

    expect(await File(p.join(target.path, 'kept.txt')).readAsString(), 'kept');
    expect(await File(p.join(target.path, 'stale.txt')).exists(), isFalse);
    expect(
      await File(p.join(target.path, 'declared_missing.txt')).exists(),
      isFalse,
    );
    expect(await swap.backupDirectory.exists(), isFalse);
  });

  test('unsafe expected path aborts preparation without touching live tree',
      () async {
    final source = Directory(p.join(sandbox.path, 'source'));
    final target = Directory(p.join(sandbox.path, 'live'));
    await source.create();
    await target.create();
    await File(p.join(target.path, 'old.txt')).writeAsString('old');

    await expectLater(
      PreparedDirectorySwap.prepare(
        sourceDirectory: source,
        targetDirectory: target,
        expectedPaths: const ['../escape.txt'],
        validatePath: _safe,
        token: 'unsafe',
      ),
      throwsFormatException,
    );
    expect(await File(p.join(target.path, 'old.txt')).readAsString(), 'old');
  });
}
