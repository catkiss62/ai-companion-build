import 'package:sqflite/sqflite.dart';

/// Identity captured before asynchronous work. Check it inside the same SQLite
/// transaction as the resulting write, not in a separate preflight query.
class BrainWorkFence {
  const BrainWorkFence({
    required this.identity,
    this.leaseKey,
    this.leaseToken,
    this.expectedSettings = const {},
  });

  final Map<String, String> identity;
  final String? leaseKey;
  final String? leaseToken;
  final Map<String, String> expectedSettings;

  static Future<String> value(DatabaseExecutor db, String key) async {
    final rows = await db.query('settings', columns: ['value'],
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? '' : rows.first['value'] as String? ?? '';
  }

  static Future<bool> workAllowed(DatabaseExecutor db) async =>
      await value(db, 'active_brain') != '0' &&
      await value(db, 'transfer_lock') != '1' &&
      (await value(db, 'snapshot_recovery_pending_v1')).isEmpty;

  Future<bool> matches(DatabaseExecutor db) async {
    if (!await workAllowed(db)) return false;
    for (final entry in {...identity, ...expectedSettings}.entries) {
      // Compare in SQLite so even large settings never enter a CursorWindow.
      final rows = await db.rawQuery(
        "SELECT COALESCE((SELECT COALESCE(value, '') = ? FROM settings "
        'WHERE key = ? LIMIT 1), ?) AS matches',
        [entry.value, entry.key, entry.value.isEmpty ? 1 : 0],
      );
      if (rows.first['matches'] != 1) return false;
    }
    if (leaseKey != null) {
      final raw = await value(db, leaseKey!);
      if (leaseToken == null || !raw.startsWith('$leaseToken|')) return false;
      final expires = int.tryParse(raw.split('|').last) ?? 0;
      if (expires <= DateTime.now().millisecondsSinceEpoch) return false;
    }
    return true;
  }
}

class BrainWorkInvalidated implements Exception {
  const BrainWorkInvalidated();
  @override
  String toString() => '当前状态已切换，旧任务已停止写入。';
}
