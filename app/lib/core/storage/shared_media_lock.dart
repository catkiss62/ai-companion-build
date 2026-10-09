import 'dart:async';
import '../database/app_database.dart';

/// Serializes file ownership changes with restore directory swaps in this engine.
/// Reentrant only for awaited work belonging to the current operation.
class SharedMediaLock {
  static final Object _zoneKey = Object();
  static Future<void> _tail = Future<void>.value();

  static const leaseKey = 'shared_media_files_lease_v1';
  static Future<T> run<T>(Future<T> Function() action, {AppDatabase? db}) async {
    if (Zone.current[_zoneKey] == true) return action();
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    final database = db ?? AppDatabase.instance;
    var acquired = false;
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!(acquired = await database.tryAcquireLocalLease(leaseKey,
          holdFor: const Duration(minutes: 30)))) {
        if (DateTime.now().isAfter(deadline)) throw StateError('图片整理进行中，请稍后重试');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return await runZoned(action, zoneValues: {_zoneKey: true});
    } finally {
      try {
        if (acquired) await database.releaseLocalLease(leaseKey);
      } finally { done.complete(); }
    }
  }
}
