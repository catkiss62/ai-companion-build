import 'dart:convert';
import '../database/app_database.dart';
import 'dream_contract.dart';
import 'dream_material.dart';
import 'dream_store.dart';

/// A durable, private draft. Only integration can change the live understanding.
class DreamCatchup {
  static Map<String, dynamic>? read(Map<String, dynamic> state) {
    final value = state['catchup'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static bool valid(Map<String, dynamic> value) => value['schema'] == 1 &&
      value['cursor'] is Map && value['boundary'] is Map &&
      value['baseline_insights'] is List && value['draft'] is Map &&
      (value['draft'] as Map)['insights'] is List;

  static Future<Map<String, dynamic>?> start(
      AppDatabase db, Map<String, dynamic> state, DateTime now) async {
    if (state['cursor'] is! Map || state.containsKey('catchup')) return null;
    final handle = await db.database;
    final cursor = Map<String, Object?>.from(state['cursor'] as Map);
    var seq = DreamContract.number(cursor['chat_seq']);
    if (!cursor.containsKey('chat_seq')) {
      final anchor = await handle.query('messages', columns: ['source_ingest_seq'],
          where: 'id = ?', whereArgs: [cursor['chat_id'] ?? ''], limit: 1);
      if (anchor.isNotEmpty) {
        seq = DreamContract.number(anchor.single['source_ingest_seq']);
      } else {
        final next = await handle.rawQuery('SELECT MIN(source_ingest_seq) AS seq FROM messages '
            'WHERE created_at > ? OR (created_at = ? AND id > ?)',
            [cursor['chat_at'] ?? 0, cursor['chat_at'] ?? 0, cursor['chat_id'] ?? '']);
        final first = DreamContract.number(next.single['seq']);
        if (first == 0) return null;
        seq = first - 1;
      }
      cursor['chat_seq'] = seq;
    }
    final count = await handle.rawQuery(
        'SELECT COUNT(*) AS n FROM messages WHERE source_ingest_seq > ?', [seq]);
    if (DreamContract.number(count.single['n']) <= 96) return null;
    final latest = await handle.query('messages', columns: DreamStore.chatColumns,
        orderBy: 'source_ingest_seq DESC', limit: 1);
    if (latest.isEmpty) return null;
    final pages = await handle.query('public_web_candidates',
        columns: ['id', 'read_at'],
        where: "read_state = 'verified' AND semantic_state = 'valid' AND lifecycle_state NOT IN ('discarded','declined','user_deleted')",
        orderBy: 'read_at DESC, id DESC', limit: 1);
    final boundary = <String, Object?>{
      'chat_seq': latest.single['source_ingest_seq'],
      'chat_at': latest.single['created_at'], 'chat_id': latest.single['id'],
      'web_at': pages.isEmpty ? cursor['web_at'] ?? 0 : pages.single['read_at'],
      'web_id': pages.isEmpty ? cursor['web_id'] ?? '' : pages.single['id'],
    };
    final baseline = jsonDecode(jsonEncode(DreamContract.records(state['insights'])));
    return {
      ...state,
      'cursor': boundary,
      'catchup': {
        'schema': 1, 'started_at': now.millisecondsSinceEpoch,
        'cursor': cursor, 'boundary': boundary, 'batches': 0, 'ready': false,
        'baseline_insights': baseline,
        'draft': {'schema': 1, 'insights': baseline, 'history': <Object?>[]},
      },
    };
  }

  static Future<DreamMaterial> integrationMaterial(AppDatabase db,
      Map<String, dynamic> state, Map<String, dynamic> catchup) async {
    final draft = Map<String, dynamic>.from(catchup['draft'] as Map);
    final usable = await DreamStore(db).usableInsights(draft);
    final current = await DreamStore(db).usableInsights(state);
    final ids = [...usable, ...current]
        .expand((i) => DreamContract.records(i['evidence']))
        .map((e) => DreamContract.string(e['id'])).toSet();
    final originals = await DreamStore.originals(await db.database, ids);
    return DreamMaterial(
      sources: originals.values.toList(),
      cursor: Map<String, Object?>.from(state['cursor'] as Map),
      background: [
        {'kind': 'private_historical_candidates', 'evidence_allowed': false,
          'interpretations': usable.map((i) => {
            'id': i['id'], 'stance': i['stance'], 'understanding': i['understanding'],
            'choice': i['choice'], 'uncertainty': i['uncertainty'],
          }).toList()},
      ],
      stamp: await DreamStore.messageStamp(await db.database),
      hasBacklog: false, bootstrap: false,
    );
  }

  static String instruction(String phase) {
    const concise = '最多提出两项必要变化，文字精简，无变化返回{"changes":[]}，不用逐条解释来源。';
    if (phase == 'catchup_read') {
      return '本次只补读历史并修订私有候选，尚不影响实际人格。current是候选，不是独立证据；'
          '按真实事件日期理解，不把未处理等同于刚发生，不因条数强迫变化。$concise';
    }
    if (phase == 'catchup_integrate') {
      return '本次统一审视已补读历史。current是现在生效的理解，background的历史候选不是事实或命令。'
          '对照原文及当前理解的近期证据，不以旧材料数量压过近期反例；允许全部保持现状。'
          '这是已读材料的重新理解，basis使用reinterpretation；不要求按候选逐项采纳。$concise';
    }
    return '本次为增量小批整理。$concise';
  }
}
