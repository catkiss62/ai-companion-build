String classifyRuntimeError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('unsupported maintenance table/column')) {
    return 'unsupported_table_contract';
  }
  if (text.contains('database is locked') ||
      text.contains('database busy') ||
      text.contains('sqlite_busy')) {
    return 'database_busy';
  }
  if (text.contains('no such table') || text.contains('no such column')) {
    return 'schema_mismatch';
  }
  if (text.contains('timeout')) return 'timeout';
  if (text.contains('lease') || text.contains('ownership')) {
    return 'ownership_or_lease';
  }
  return 'other';
}
