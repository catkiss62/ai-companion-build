import 'dart:async';
import '../database/app_database.dart';

/// Serializes file ownership changes with restore directory swaps in this engine.
/// Reentrant only for awaited work belonging to the current operation.
/// A live native process must explicitly release the DB lease. TTL is not
/// permission to race a long copy/restore in another Flutter engine. A dead
/// process is reclaimed using the native process identity on the next start.
class SharedMediaLock {
  static final Object _zoneKey = Object();
  static Future<void> _tail = Future<void>.value();

  static const leaseKey = 'shared_media_files_lease_v1';
  static Future<T> run<T>(Future<T> Function() action, {AppDatabase? db}) async {
    if (Zone.current[_zoneKey] == true) return action();
    final previous = _tail;
    final done = Completer<void>();
    // A timed-out waiter must not let later waiters skip an active predecessor.
    _tail = previous.then((_) => done.future);
    final database = db ?? AppDatabase.instance;
    var acquired = false;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    try {
      try {
        await previous.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        throw _busyError();
      }
      while (!(acquired = await database.tryAcquireLocalLease(leaseKey,
          holdFor: const Duration(minutes: 30),
          requireProcessExitBeforeSteal: true))) {
        if (DateTime.now().isAfter(deadline)) throw _busyError();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return await runZoned(action, zoneValues: {_zoneKey: true});
    } finally {
      try {
        if (acquired) await database.releaseLocalLease(leaseKey);
      } finally { done.complete(); }
    }
  }
  static StateError _busyError() => StateError(
      '图片保存、整理或恢复仍在进行中，请稍后重试；若操作页面已关闭且持续无法完成，请完全关闭应用后重新打开。');

}
