import '../database/app_database.dart';

/// Narrow proactive-delivery query kept outside the large database source so
/// the night contact boundary can remain independently testable and portable.
extension ProactiveHistoryQueries on AppDatabase {
  Future<int> deliveredProactiveCountAfter(DateTime since) async {
    final connection = await database;
    final rows = await connection.rawQuery(
      'SELECT COUNT(*) AS c FROM proactive_history '
      'WHERE decision = ? AND created_at >= ?',
      <Object?>['sent', since.millisecondsSinceEpoch],
    );
    final value = rows.isEmpty ? null : rows.first['c'];
    return value is num ? value.toInt() : 0;
  }
}
