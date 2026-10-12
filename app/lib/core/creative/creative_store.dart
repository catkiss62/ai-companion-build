import 'dart:convert';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import 'creative_contract.dart';
import 'creative_workspace.dart';
import 'creative_autonomy_policy.dart';
import 'creative_share.dart';
import 'creative_facts.dart';

class CreativeStore {
  CreativeStore(this.db);
  final AppDatabase db;
  static String key(String id) => '${CreativeContract.metaPrefix}$id';
  Future<Map<String, dynamic>> get(String id) async => CreativeContract.decode(await db.getSetting(key(id)));

  Future<List<Map<String, dynamic>>> list({bool pendingOnly = false, bool includePrivate = false}) async {
    final handle = await db.database;
    final keys = await handle.query('settings', columns: ['key'],
        where: pendingOnly ? 'key LIKE ? AND (value LIKE ? OR value LIKE ? OR value LIKE ?)' : 'key LIKE ?',
        whereArgs: ['${CreativeContract.metaPrefix}%', if (pendingOnly) ...['%"status":"queued"%', '%"status":"building"%', '%"status":"checking"%']]);
    final works = <Map<String, dynamic>>[];
    for (final row in keys) {
      final work = CreativeContract.decode(await db.getSetting(row['key'] as String));
      if (work.isNotEmpty && work['status'] != 'deleted' &&
          (includePrivate || CreativeAutonomyPolicy.visible(work)) &&
          (!pendingOnly || CreativeContract.active.contains(work['status']))) works.add(work);
    }
    works.sort((a, b) => (b['updated'] as int).compareTo(a['updated'] as int));
    return works;
  }

  Future<List<Map<String, dynamic>>> forMessage(String messageId) async {
    final receipt = CreativeContract.decode(await db.getSetting('${CreativeContract.receiptPrefix}$messageId'));
    if (receipt.isNotEmpty) {
      final work = await get(receipt['work_id'] as String);
      if (!CreativeAutonomyPolicy.visible(work)) return [];
      final completed = receipt['completed'] == true ||
          (work['request_id'] is String && receipt['request_id'] == work['request_id'] && work['completed_request'] == work['request_id']) ||
          (!receipt.containsKey('request_id') && work['message_id'] == messageId && work['status'] == 'ready');
      return [{...work, 'card_kind': receipt['kind'], 'delivered_version': receipt['version'],
        'record_completed': completed}];
    }
    // Legacy cards retain their existing association without inventing messages.
    return (await list()).where((w) => w['message_id'] == messageId || w['completion_message_id'] == messageId)
        .map((w) => {...w, 'card_kind': w['completion_message_id'] == messageId ? 'delivered' : 'progress',
          'record_completed': w['status'] == 'ready'}).toList();
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
    if (workId.isNotEmpty && !CreativeAutonomyPolicy.visible(before)) {
      throw const FormatException('找不到要修改的作品');
    }
    if (CreativeContract.active.contains(before['status'])) {
      throw const FormatException('这件作品正在制作，请先停止或等它完成');
    }
    final after = <String, dynamic>{...before,
      'schema': 1, 'id': id, 'origin': 'commission', 'visibility': 'shared',
      'request_id': requestId, 'message_id': messageId,
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
    after.remove('completion_message_id');
    after.remove('completed_request');
    after.remove('completed_at');
    final previousReceiptKey = '${CreativeContract.receiptPrefix}${before['message_id']}';
    final previousReceipt = CreativeContract.decode(await db.getSetting(previousReceiptKey));
    if (!await write(before, after, extra: {CreativeWorkspace.key(id): nextWorkspace,
      '${CreativeContract.noticePrefix}$id': '',
      if (before['message_id'] is String && (before['message_id'] as String).isNotEmpty && before['message_id'] != messageId)
        previousReceiptKey: jsonEncode({...previousReceipt, 'message_id': before['message_id'],
          'work_id': id, 'version': previousReceipt['version'] ?? before['current'] ?? '', 'kind': 'progress',
          'request_id': before['request_id'],
          'completed': previousReceipt['completed'] == true ||
            (before['request_id'] is String && before['completed_request'] == before['request_id']) || before['status'] == 'ready'}),
      if (before['completion_message_id'] is String)
        '${CreativeContract.receiptPrefix}${before['completion_message_id']}': jsonEncode({'message_id': before['completion_message_id'],
          'work_id': id, 'version': before['current'] ?? '', 'kind': 'delivered'}),
      '${CreativeContract.receiptPrefix}$messageId': jsonEncode({'message_id': messageId,
        'work_id': id, 'version': '', 'kind': 'progress', 'request_id': requestId, 'completed': false})})) throw const BrainWorkInvalidated();
    return after;
  }

  Future<String> originalRequest(Map<String, dynamic> work) async {
    if (CreativeAutonomyPolicy.autonomous(work)) return '';
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
    if (!CreativeAutonomyPolicy.visible(before)) return;
    await write(before, {...before, 'status': 'paused', 'note': '已暂停', 'preempt': 'user_stop'});
  }

  Future<void> resume(String id, {bool privatePermission = false}) async {
    final before = await get(id);
    if ((!privatePermission && !CreativeAutonomyPolicy.visible(before)) ||
        !{'paused', 'failed'}.contains(before['status'])) return;
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
    if (!CreativeAutonomyPolicy.visible(before)) return;
    final stateKey = '${CreativeContract.playPrefix}$id';
    await write(before, {'schema': 1, 'id': id, 'status': 'deleted',
      'request_id': before['request_id'], 'message_id': before['message_id'],
      'updated': DateTime.now().millisecondsSinceEpoch}, extra: {stateKey: '', CreativeWorkspace.key(id): '',
        '${CreativeContract.noticePrefix}$id': '', '${CreativeContract.playTracePrefix}$id': ''});
    await collectUnusedSources();
  }


  Future<void> setAutonomyEnabled(bool enabled) async {
    // Compare-and-swap keeps rapid overlapping toggles from sharing an epoch.
    while (true) {
      final raw = await db.getSetting(CreativeAutonomyPolicy.epochKey) ?? '';
      final epoch = int.tryParse(raw) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (await db.setSettingsAtomically({CreativeAutonomyPolicy.enabledKey: enabled ? '1' : '0',
        CreativeAutonomyPolicy.epochKey: '${now > epoch ? now : epoch + 1}'},
        expectedSettings: {CreativeAutonomyPolicy.epochKey: raw})) return;
    }
  }

  Future<void> resumeAutonomous() async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return;
    final state = CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey));
    if (state.isNotEmpty) {
      CreativeAutonomyPolicy.validateState(state);
      await db.setSettingsAtomically({CreativeAutonomyPolicy.stateKey: jsonEncode({...state, 'suspended': false}),
        CreativeAutonomyPolicy.attemptKey: ''});
    }
    for (final work in await list(includePrivate: true)) {
      if (!CreativeAutonomyPolicy.autonomous(work) || work['preempt'] == 'self_retired') continue;
      if (work['status'] == 'ready' && work['preempt'] == 'import') {
        await write(work, {...work, 'preempt': '', 'share_after': 0});
      } else if (work['status'] == 'paused' || work['status'] == 'failed') {
        await resume(work['id'] as String, privatePermission: true);
      }
    }
  }

  /// Only called by the private inspiration owner after grounded review.
  Map<String, dynamic> autonomousWork(Map<String, dynamic> idea, DateTime at,
      {required String model, required String effort}) {
    final request = 'autonomous:${idea['id']}';
    final id = CreativeContract.hash(request).substring(0, 24);
    return {'schema': 1, 'id': id, 'origin': 'autonomous', 'visibility': 'private',
      'idea_id': idea['id'], 'request_id': request, 'message_id': '', 'original_request': '',
      'motive': idea['motive'], 'brief': idea['brief'], 'evidence': idea['evidence'],
      'interaction': 'unspecified', 'title': '小作品', 'intro': '', 'status': 'queued',
      'attempts': 0, 'updated': at.millisecondsSinceEpoch, 'model': model, 'effort': effort,
      'note': '等待空闲制作', 'draft': '', 'errors': <Object?>[], 'retry_at': 0,
      'agent_step': 0, 'agent_trace': <Object?>[], 'model_turns': 0, 'tool_calls': 0,
      'committed_mutations': 0, 'late_result_dropped': 0, 'preempt': '', 'versions': <String>[]};
  }

  Future<List<Map<String, dynamic>>> shareCandidates(DateTime now) async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return [];
    return (await list(includePrivate: true)).where((w) => CreativeShare.eligible(w, now)).take(2).toList();
  }

  Future<CreativeShare?> claimShare(String id, DateTime now) async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return null;
    final work = await get(id);
    if (!CreativeShare.eligible(work, now)) return null;
    final fence = await db.captureBrainWorkFence(settingKeys: [
      CreativeAutonomyPolicy.enabledKey, CreativeAutonomyPolicy.epochKey]);
    if (fence == null || fence.expectedSettings[CreativeAutonomyPolicy.enabledKey] != '1') return null;
    // WAIT and failed writing leave it private; don't buy the same decision on every heartbeat.
    final next = {...work, 'share_after': now.add(const Duration(hours: 2)).millisecondsSinceEpoch};
    if (!await write(work, next, fence: fence)) return null;
    return CreativeShare(next, fence.expectedSettings[CreativeAutonomyPolicy.epochKey] ?? '');
  }

  static const requestContract = '深度思考只决定本轮能否接受新的制作或修改委托。'
      '一旦委托已登记，工作 Agent 使用独立工作模型和思考力度持续制作；关闭聊天深度思考、继续普通聊天不会取消制作。'
      '已有任务只能依据下面的实际记录说明进度，不得要求用户重新打开深度思考或重新委托才能继续。'
      '用户明确暂停、删除、配置错误或达到自动恢复上限才可能暂停；原因以记录为准。';

  Future<String> chatContext({String query = '', String userMessageId = '', bool relevantOnly = false}) async {
    final facts = await CreativeFacts(db).prompt(query: query, userMessageId: userMessageId, relevantOnly: relevantOnly);
    return facts.isEmpty ? '' : '$requestContract\n$facts';
  }

  Future<Map<String, Object?>> diagnostics() async {
    final works = await list();
    final delivery = <Object?>[];
    final play = <Object?>[];
    for (final work in works.take(20)) {
      final id = work['id'] as String;
      final notice = CreativeContract.decode(await db.getSetting('${CreativeContract.noticePrefix}$id'));
      if (notice.isNotEmpty) delivery.add({'id': id, 'feature': 'creative_completion',
        'execution_id': notice['request_id'], 'trigger_source': 'work_finish',
        'continuation_owner': 'creative_delivery_lease_until', 'usage_lane': 'creative_completion_final',
        'planning_rounds': 0, 'tool_calls': 0, 'committed_mutations': notice['status'] == 'delivered' ? 1 : 0,
        'continuation_requested': notice['status'] == 'pending', 'terminal': notice['status'] != 'pending',
        for (final field in ['status', 'phase', 'attempts', 'failures', 'next_at', 'model_calls', 'provider_failure', 'error', 'preempt', 'late_write'])
          if (notice.containsKey(field)) field: notice[field]});
      final trace = CreativeContract.decode(await db.getSetting('${CreativeContract.playTracePrefix}$id'));
      if (trace.isNotEmpty) play.add({'id': id, 'events': trace['events']});
    }
    return {'feature': 'creative_work', 'worker': 'tool_agent_v1',
      'completion_delivery': delivery, 'interaction_events': play,
      'ui': CreativeContract.decode(await db.getSetting('creative_ui_trace_v1')),
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
