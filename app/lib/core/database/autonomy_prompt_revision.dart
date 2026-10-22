import 'package:sqflite/sqflite.dart';

const autonomyPromptRevisionMarker = 'autonomy_prompt_v042127_applied';

/// Remove the approved default retreat clauses, without replacing them with
/// mandatory defiance, teasing, negative emotion or a fixed interaction script.
String removeDefaultRetreatClauses(String content) => content
    .replaceAll('偶尔得意、顶嘴或短暂闹别扭', '偶尔得意、顶嘴或闹别扭')
    .replaceAll('对方明确拒绝或话题转为认真时自然收住，', '')
    .replaceAll('仍然接住对方真正说的事，认真场合收住脾气，不强行羞辱或替对方决定行动。',
        '不替对方决定行动。')
    .replaceAll('不带恶意地化解对方的进攻。', '回应对方。')
    .replaceAll('严肃、技术、风险与真实痛苦内容不拿来造梗。', '')
    .replaceAll('认真节点会收住；', '');

/// Runs after older default migrations, including after portable restore.
/// Update only exact approved clauses in the target behavior modules/templates;
/// keep surrounding custom prose, identity, activation and probability intact.
Future<void> migrateAutonomyPromptsV042127(Database db) async {
  await db.transaction((txn) async {
    final marker = await txn.query('settings', columns: ['value'],
      where: 'key = ?', whereArgs: [autonomyPromptRevisionMarker]);
    if (marker.isNotEmpty && marker.single['value'] == '1') return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final docs = await txn.query('reference_documents', columns: ['id', 'raw_content'],
      where: "entry_type = 'behavior' AND (name IN (?, ?) OR id = ?)",
      whereArgs: ['性格光谱', '日常对话规则', 'builtin.worldbook.daily_conversation']);
    for (final row in docs) {
      final raw = row['raw_content'] as String? ?? '';
      final revised = removeDefaultRetreatClauses(raw);
      if (raw != revised) await txn.update('reference_documents',
        {'raw_content': revised, 'updated_at': now},
        where: 'id = ? AND raw_content = ?', whereArgs: [row['id'], raw]);
    }
    final layers = await txn.query('rule_layers', columns: ['key', 'content'],
      where: 'key = ?', whereArgs: ['07_base_playful']);
    for (final row in layers) {
      final raw = row['content'] as String? ?? '';
      final revised = removeDefaultRetreatClauses(raw);
      if (raw != revised) await txn.update('rule_layers',
        {'content': revised, 'updated_at': now}, where: 'key = ?', whereArgs: [row['key']]);
    }
    await txn.insert('settings', {'key': autonomyPromptRevisionMarker, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  });
}
