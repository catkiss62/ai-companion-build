import 'dart:convert';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import 'creative_contract.dart';
import 'creative_workspace.dart';

class CreativeStore {
  CreativeStore(this.db);
  final AppDatabase db;
  static String key(String id) => '${CreativeContract.metaPrefix}$id';
  Future<Map<String, dynamic>> get(String id) async => CreativeContract.decode(await db.getSetting(key(id)));

  Future<List<Map<String, dynamic>>> list({bool pendingOnly = false}) async {
    final handle = await db.database;
    final keys = await handle.query('settings', columns: ['key'],
        where: pendingOnly ? 'key LIKE ? AND (value LIKE ? OR value LIKE ? OR value LIKE ?)' : 'key LIKE ?',
        whereArgs: ['${CreativeContract.metaPrefix}%', if (pendingOnly) ...['%"status":"queued"%', '%"status":"building"%', '%"status":"checking"%']]);
    final works = <Map<String, dynamic>>[];
    for (final row in keys) {
      final work = CreativeContract.decode(await db.getSetting(row['key'] as String));
      if (work.isNotEmpty && work['status'] != 'deleted' &&
          (!pendingOnly || CreativeContract.active.contains(work['status']))) works.add(work);
    }
    works.sort((a, b) => (b['updated'] as int).compareTo(a['updated'] as int));
    return works;
  }

  Future<bool> write(Map<String, dynamic> before, Map<String, dynamic> after,
      {Map<String, String> extra = const {}, BrainWorkFence? fence}) async {
    final owned = fence ?? await db.captureBrainWorkFence();
    if (owned == null) return false;
    final id = after['id'] as String;
    return db.setSettingsAtomically({key(id): jsonEncode(after), ...extra},
        expectedSettings: {key(id): before.isEmpty ? '' : jsonEncode(before)}, workFence: owned);
  }

  Future<Map<String, dynamic>> commission({required bool deepThinking,
      required String requestId, required String messageId, required String brief,
      required String requestQuote, required String latestText, String workId = '',
      String userMessageId = '', String interaction = 'unspecified'}) async {
    if (!deepThinking || requestId.isEmpty || messageId.isEmpty ||
        requestQuote.trim().isEmpty || !latestText.contains(requestQuote) || brief.trim().isEmpty) {
      throw const FormatException('本轮未授权制作；需要在深度思考中明确委托');
    }
    final id = workId.isEmpty ? CreativeContract.hash(requestId).substring(0, 24) : workId;
    final before = await get(id);
    if (before['request_id'] == requestId) return before;
    if (workId.isNotEmpty && (before.isEmpty || before['status'] == 'deleted')) {
      throw const FormatException('找不到要修改的作品');
    }
    if (CreativeContract.active.contains(before['status'])) {
      throw const FormatException('这件作品正在制作，请先停止或等它完成');
    }
    final after = <String, dynamic>{...before,
      'schema': 1, 'id': id, 'request_id': requestId, 'message_id': messageId,
      'user_message_id': userMessageId, 'request_quote': CreativeContract.clip(requestQuote, 2000),
      'original_request': CreativeContract.clip(latestText, 12000),
      'interaction': {'companion', 'local'}.contains(interaction) ? interaction : 'unspecified',
      'brief': CreativeContract.clip(brief, 8000), 'title': before['title'] ?? '新的小作品',
      'intro': before['intro'] ?? '', 'status': 'queued', 'attempts': 0,
      'updated': DateTime.now().millisecondsSinceEpoch,
      'model': await db.getSetting('creative_work_model') ?? 'deepseek-flash',
      'effort': await db.getSetting('creative_work_effort') ?? 'max',
      'note': '等待后台制作', 'draft': workId.isEmpty ? '' : before['draft'] ?? '', 'errors': <Object?>[],
      'retry_at': 0, 'agent_step': 0, 'agent_trace': <Object?>[],
      'model_turns': 0, 'tool_calls': 0, 'committed_mutations': 0, 'late_result_dropped': 0, 'preempt': '',
      'versions': before['versions'] ?? <Object?>[],
    };
    // A revision gets a fresh execution context but keeps the actual project.
    // Explicit resume below also retains pending tool receipts.
    var nextWorkspace = '';
    if (workId.isNotEmpty) {
      final previous = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
      if (previous.isNotEmpty) {
        final next = CreativeWorkspace.create(id, requestId);
        next['files'] = CreativeWorkspace.files(previous);
        CreativeWorkspace.validate(next, id);
        nextWorkspace = jsonEncode(next);
      }
    }
    if (!await write(before, after, extra: {CreativeWorkspace.key(id): nextWorkspace})) throw const BrainWorkInvalidated();
    return after;
  }

  Future<String> originalRequest(Map<String, dynamic> work) async {
    final saved = (work['original_request'] ?? work['request_quote']) as String? ?? '';
    if (saved.isNotEmpty) return saved;
    // +339 cards can reference the assistant message rather than the user.
    // Resolve only that exact turn, never inject the whole recent conversation.
    final handle = await db.database;
    final anchor = await handle.query('messages', columns: ['role', 'content', 'created_at'],
      where: 'id = ?', whereArgs: [work['user_message_id'] ?? work['message_id']], limit: 1);
    if (anchor.isEmpty) return '';
    if (anchor.first['role'] == 'user') return CreativeContract.clip(anchor.first['content'], 12000);
    final user = await handle.query('messages', columns: ['content'],
      where: 'role = ? AND created_at <= ?', whereArgs: ['user', anchor.first['created_at']],
      orderBy: 'created_at DESC', limit: 1);
    return user.isEmpty ? '' : CreativeContract.clip(user.first['content'], 12000);
  }

  Future<void> stop(String id) async {
    final before = await get(id);
    if (before.isEmpty) return;
    await write(before, {...before, 'status': 'paused', 'note': '已暂停', 'preempt': 'user_stop'});
  }

  Future<void> resume(String id, {required bool deepThinking}) async {
    if (!deepThinking) throw const FormatException('开启深度思考后才能继续制作');
    final before = await get(id);
    if (!{'paused', 'failed'}.contains(before['status'])) return;
    final agent = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
    if (agent.isNotEmpty) { agent['failures'] = 0; agent['next_at'] = 0; }
    await write(before, {...before, 'status': 'queued', 'attempts': 0, 'retry_at': 0, 'preempt': '',
      'model': await db.getSetting('creative_work_model') ?? before['model'] ?? 'deepseek-flash',
      'effort': await db.getSetting('creative_work_effort') ?? before['effort'] ?? 'max',
      'updated': DateTime.now().millisecondsSinceEpoch, 'note': '等待继续制作'},
      extra: {if (agent.isNotEmpty) CreativeWorkspace.key(id): jsonEncode(agent)});
  }

  Future<void> delete(String id) async {
    final before = await get(id);
    if (before.isEmpty) return;
    final stateKey = '${CreativeContract.playPrefix}$id';
    await write(before, {'schema': 1, 'id': id, 'status': 'deleted',
      'request_id': before['request_id'], 'message_id': before['message_id'],
      'updated': DateTime.now().millisecondsSinceEpoch}, extra: {stateKey: '', CreativeWorkspace.key(id): ''});
    await collectUnusedSources();
  }

  Future<Map<String, Object?>> diagnostics() async {
    final works = await list();
    return {'feature': 'creative_work', 'worker': 'tool_agent_v1',
      'continuation_owner': 'creative_worker_lease_until', 'usage_lane': 'creative_build',
      'works': works.take(20).map((work) => {
      'id': work['id'], 'status': work['status'], 'attempts': work['attempts'],
      'execution_id': work['request_id'], 'trigger_source': work['trigger_source'],
      'phase': work['status'], 'planning_rounds': work['model_turns'],
      'tool_calls': work['tool_calls'], 'committed_mutations': work['committed_mutations'],
      'continuation_requested': CreativeContract.active.contains(work['status']),
      'terminal': !CreativeContract.active.contains(work['status']),
      'preempt': work['preempt'], 'late_write': work['late_result_dropped'],
      'agent_step': work['agent_step'], 'retry_at': work['retry_at'],
      'has_draft': (work['draft'] as String? ?? '').isNotEmpty,
      'has_published': (work['current'] as String? ?? '').isNotEmpty,
      'trace': (work['agent_trace'] as List? ?? []).whereType<Map>().map((event) => {
        for (final field in ['at', 'kind', 'code', 'tool', 'ok', 'files', 'finish_reason',
          'content_characters', 'reasoning_characters', 'argument_characters',
          'tool_count', 'elapsed_ms', 'input_tokens', 'output_tokens'])
          if (event.containsKey(field)) field: event[field],
      }).toList(),
    }).toList()};
  }

  Future<void> collectUnusedSources() async {
    // Same transaction as the reference scan, so a concurrent publish cannot
    // lose its source. Tombstones fence network completions after deletion.
    final handle = await db.database;
    await handle.transaction((txn) async {
      if (!await BrainWorkFence.workAllowed(txn)) return;
      final rows = await txn.query('settings', columns: ['key', 'value'],
        where: 'key LIKE ? OR key LIKE ?', whereArgs: [
          '${CreativeContract.metaPrefix}%', '${CreativeContract.playPrefix}%']);
      final keep = <String>{};
      for (final row in rows) {
        final data = CreativeContract.decode(row['value'] as String?);
        for (final field in ['draft', 'current', 'version']) {
          if (data[field] is String) keep.add(data[field] as String);
        }
        keep.addAll((data['versions'] as List? ?? []).whereType<String>());
      }
      final sources = await txn.query('settings', columns: ['key'], where: 'key LIKE ?',
          whereArgs: ['${CreativeContract.sourcePrefix}%']);
      for (final row in sources) {
        final key = row['key'] as String;
        if (!keep.contains(key.substring(CreativeContract.sourcePrefix.length))) {
          await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
        }
      }
    });
  }
}
