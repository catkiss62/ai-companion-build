import 'dart:convert';

import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../phone/calendar_reminder_store.dart';
import '../platform/android_bridge.dart';
import '../tts/tts_service.dart';

/// Receipts for irreversible actions live in SQLite, independently of the
/// editable workspace transcript. Audio dispatch is claimed once. Reminder receipts identify individual items.
class WorkHostActions {
  WorkHostActions(
    this.db,
    this.order,
    this.thread,
    this.allowed,
    this.token, {
    this.goal = '',
    this.relatedOrders = const [],
  });
  final String goal;
  final List<String> relatedOrders;

  Future<WorkHostActions> forTask(List<String> tasks, int index) async {
    final ids = [for (var i = 0; i < tasks.length; i++) '$order-part-${i+1}'];
    final actions = allowed.intersection(requested(tasks[index]));
    final child = WorkHostActions(db, ids[index], thread, actions, token,
        goal: tasks[index], relatedOrders: [order, ...ids]);
    // Old multi-part orders shared a key. Only reuse receipts uniquely attributable
    // to this part; leave original data intact for an interrupted upgrade.
    for (final action in actions) {
      final oldKey = 'work_action_${order}_$action';
      final key = 'work_action_${ids[index]}_$action';
      final raw = await db.getSetting(oldKey);
      if (raw == null || raw.isEmpty || (await db.getSetting(key) ?? '').isNotEmpty) continue;
      final eligible = [for (var i=0;i<tasks.length;i++) if (requested(tasks[i]).contains(action)) i];
      final original = jsonDecode(raw) as Map;
      final audio = action == 'speak' || action == 'ring';
      final mine = <Map>[];
      for (final item in audio ? [original] : _records(original)) {
        var owners = eligible;
        if (eligible.length > 1) {
          final title = item['target_title'] ?? item['entry']?['title'];
          if (title is String && title.isNotEmpty) {
            owners = eligible.where((i) {
              final scope = _scope(tasks[i],action,{title});
              return scope.targets.any((t) => t.contains(title)) && !scope.excluded.contains(title);
            }).toList();
          }
          if (owners.length != 1) {
            throw WorkDeliveryFailure('旧版的操作回执无法唯一归属到子任务，请核对后重新指定');
          }
        }
        if (owners.single == index) mine.add(item);
      }
      if (mine.isNotEmpty) {
        final ok=await db.setSettingsAtomically({key:jsonEncode(audio ? mine.single : {'items':mine})},
            expectedSettings:{key:'',oldKey:raw});
        if (!ok && (await db.getSetting(key) ?? '').isEmpty) {
          throw WorkDeliveryFailure('旧版操作回执已更新，请继续任务重新核对');
        }
      }
    }
    return child;
  }

  final AppDatabase db;
  final String order;
  final String thread;
  final Set<String> allowed;
  final GenerationCancellationToken token;
  final _verifiedIds = <String, Set<String>>{};
  final confirmed = <String>{};
  String? lastError;

  static const name = 'work_host_action';
  static const labels = {
    'remind': '设置提醒',
    'reschedule': '修改提醒',
    'cancel': '取消提醒',
    'speak': '朗读',
    'ring': '响铃',
  };
  static final _clauses = RegExp(
    r'[，,。；;！!……\n]|(?:并且|然后|但是|同时|并|再)(?=(?:请|帮我|把|将|取消|撤销|删除|关闭|保留|修改|调整|不要|别))',
  );
  static final _quoted = RegExp(r'「[^」]*」|“[^”]*”|"[^"]*"|《[^》]*》');
  static String _maskTitles(String text) =>
      text.replaceAllMapped(_quoted, (m) => 'Ｘ' * m[0]!.length);

  static Iterable<String> _instructionParts(String text) sync* {
    var start = 0;
    for (final delimiter in _clauses.allMatches(_maskTitles(text))) {
      yield text.substring(start, delimiter.start);
      start = delimiter.end;
    }
    yield text.substring(start);
  }

  static final _withdrawal = RegExp(
    r'(?:别|不要|不用|不必|无需|不再|不)(?:再)?(取消|撤销|删除|关闭|改动|修改|调整|改期|改|提醒|设置|朗读|响铃)',
  );

  static Set<String> requested(String goal) {
    final actions = _positiveActions(goal);
    for (final action in ['cancel', 'reschedule', 'remind']) {
      if (actions.contains(action)) {
        final scope = _scope(goal, action, const {});
        if (scope.hasExclusions && scope.targets.isEmpty) actions.remove(action);
      }
    }
    return actions;
  }

  static Set<String> _positiveActions(String goal) {
    final result = <String>{};
    final instruction = goal
        .replaceAll(RegExp(r'「[^」]*」|“[^”]*”|"[^"]*"|《[^》]*》'), 'Ｘ')
        .replaceAll(RegExp(r'(?:别|不要)忘(?:了|记)?'), '记得');
    for (final part in instruction.split(_clauses)) {
      final withdrawal = _withdrawal.firstMatch(part);
      if (withdrawal?[1] == '朗读') result.remove('speak');
      if (withdrawal?[1] == '响铃') result.remove('ring');
      if (RegExp(
        r'不要|不用|不必|无需|不想|禁止|不(?:取消|撤销|删除|关闭|改动|修改|调整|设置|建立|朗读|响铃|播放|提醒)|(?<!分)(?<!特)别(?!人|的|处|名|致)',
      ).hasMatch(part))
        continue;
      final afterTask = RegExp(
        r'(?:整理|完成|整理完|做完|保存|交付)(?:之后|以后|后)(?:请|再|就)?(响铃|响一声|响一下|朗读|读给我)',
      ).firstMatch(part);
      if (afterTask != null &&
          !RegExp(r'网页|按钮|演示|举例|比如|如果|假设|怎么|能否|[？?]').hasMatch(part)) {
        result.add(afterTask.group(1)!.startsWith('响') ? 'ring' : 'speak');
      }
      if (RegExp(
        r'网页|按钮|代码|示例|文档|教程|HTML|html|模拟|演示|测试题|看看|查一下|查查|查找|查询|查看|列出|总结|整理|分析|能否实现|功能介绍',
      ).hasMatch(part))
        continue;
      if (RegExp(r'怎么|如何|是否|能不能|为什么|支持|哪些|解释|讨论|只查|[?？]').hasMatch(part))
        continue;
      if (RegExp(
        r'(取消|撤销|删除|关闭).{0,12}(提醒|闹钟)|(提醒|闹钟).{0,10}(取消|删除|关掉)',
      ).hasMatch(part)) {
        result.add('cancel');
      } else if (RegExp(
        r'(提醒|闹钟).{0,16}(改到|改成|推迟|提前|改为)|(修改|推迟|提前|调整).{0,10}(提醒|闹钟)',
      ).hasMatch(part)) {
        result.add('reschedule');
      } else if (RegExp(r'提醒我|叫醒我|(帮我|设|建|加|安排).{0,8}(提醒|闹钟)').hasMatch(part)) {
        result.add('remind');
      }
      final delayed = RegExp(
        r'到时|届时|点钟|明天|分钟|小时|每天|闹钟|闹铃|[零一二三四五六七八九十两0-9]+[点时]',
      ).hasMatch(part);
      if (!delayed &&
          RegExp(r'朗读|念给我|读给我|读出来|用语音(说|读|念|播)|播报一下').hasMatch(part))
        result.add('speak');
      if (!delayed && RegExp(r'响铃|响一声|响一下|播放.{0,4}(提示音|铃声)').hasMatch(part))
        result.add('ring');
    }
    return result;
  }

  Map<String, Object?> get tool => {
    'type': 'function',
    'function': {
      'name': name,
      'description':
          '执行本轮明确要求的本机操作，各条提醒分别调用。提醒使用手机本地日期时间 YYYY-MM-DDTHH:mm。一项任务中相同操作重试复用原回执。即时语音和提示音只能立即播放，需等待其他交付时先完成那些步骤。先区分每个目标的要求、保留对象和后续改口。只对仍需执行的目标调用；已撤回和保留项不调用。同名无法区分时说明需要澄清的那一项。点名修改或取消时 target 传入原提醒标题；仅指代最近一条时省略。',
      'parameters': {
        'type': 'object',
        'properties': {
          'action': {'type': 'string', 'enum': allowed.toList()},
          'text': {'type': 'string', 'description': '提醒标题或本次朗读文本'},
          'target': {'type': 'string', 'description': '要修改或取消的原提醒标题'},
          'local_time': {
            'type': 'string',
            'description': '建立/改期必填，使用用户发起任务时的本地时间推算',
          },
        },
        'required': ['action'],
        'additionalProperties': false,
      },
    },
  };

  Future<List<Map<String, Object?>>> verifyExisting() async {
    final verified = <Map<String, Object?>>[];
    for (final action in allowed) {
      final raw = await db.getSetting('work_action_${order}_$action') ?? '';
      if (raw.isEmpty) continue;
      try {
        if (action == 'speak' || action == 'ring') {
          verified.add(await execute({'action': action}));
        } else {
          final records = _records(jsonDecode(raw) as Map);
          for (final item in records) {
            verified.add(await _reminder(action, const {}, verifying: item));
          }
        }
      } catch (error) {
        token.throwIfCancelled();
        if (error is FormatException) throw WorkDeliveryFailure(error.message);
        rethrow;
      }
    }
    return verified;
  }

  Future<Map<String, Object?>> execute(Map args) async {
    final action = args['action'];
    if (action is! String || !allowed.contains(action))
      throw const FormatException('本次任务没有要求这项操作');
    token.throwIfCancelled();
    if (!await db.brainWorkAllowed()) throw StateError('当前设备暂停工作');
    if (action != 'ring' && action != 'speak') return _reminder(action, args);
    final key = 'work_action_${order}_$action';
    final raw = await db.getSetting(key) ?? '';
    final receipt = raw.isEmpty ? null : jsonDecode(raw) as Map;
    if (action == 'ring' || action == 'speak') {
      if (receipt == null) {
        final text = args['text'];
        if (action == 'speak' &&
            (text is! String || text.trim().isEmpty || text.length > 1000)) {
          throw const FormatException('请提供 1000 字以内的朗读文本');
        }
        token.throwIfCancelled();
        final claimed = await db.setSettingsAtomically({
          key: '{"state":"dispatching"}',
        }, guardKey: key);
        if (!claimed) throw const FormatException('该播放已在处理中');
        if (token.isCancelled) {
          await db.setSetting(key, '');
          token.throwIfCancelled();
        }
        // Once handed to audio, even loss of the process or the reply cannot
        // establish that no sound was emitted. A resume must not replay it.
        final played = action == 'ring'
            ? (await AndroidBridge.instance
                      .previewCompanionNotificationSound())['played'] ==
                  true
            : await TtsService(db: db).speak(
                text as String,
                manual: true,
                ownerId: 'work-$order',
                canContinue: () async =>
                    !token.isCancelled && await db.brainWorkAllowed(),
              );
        await db.setSetting(
          key,
          jsonEncode({'state': played ? 'done' : 'unconfirmed'}),
        );
        if (!played) throw const FormatException('未确认播放成功，继续任务时不会自动重播');
      } else if (receipt['state'] != 'done') {
        throw const FormatException('上次播放结果未确认，若需重播请明确重新发起');
      }
    }
    confirmed.add(action);
    return {
      'action': action,
      'display': '${labels[action]}已核实',
      'reused': receipt != null,
    };
  }

  static List<Map> _records(Map receipt) => receipt['items'] is List
      ? (receipt['items'] as List).cast<Map>().toList()
      : [receipt];

  List<String> get _creationClauses => goal
      .split(RegExp(r'[，,。；;！!\n]|以及|并且'))
      .where(
        (part) =>
            requested(part).contains('remind') ||
            requested(goal).contains('remind') &&
                RegExp(
                  r'^\s*(?:再|然后|另外)?(?:今天|明天|后天)?(?:上午|下午|早上|晚上)?[零一二三四五六七八九十两0-9]+(?:点|时|[:：]\d\d).+',
                ).hasMatch(part) &&
                !RegExp(r'不要|别|取消').hasMatch(part),
      )
      .toList();

  static List<Set<String>> _names(String subject, Set<String> knownTitles) {
    String unquote(String s) => s.trim().replaceFirst(RegExp(r'^[「“"]'), '')
        .replaceFirst(RegExp(r'[」”"]$'), '').trim();
    Set<String> aliases(String title) => {
      unquote(title),
      unquote(title.replaceFirst(RegExp(r'的?(?:提醒|闹钟)$'), '')),
      unquote(title.replaceFirst(RegExp(r'^(?:提醒|闹钟)\s*'), '')),
    };
    final whole = aliases(subject);
    if (whole.any(knownTitles.contains) ||
        RegExp(r'^[「“"].+[」”"](?:的?(?:提醒|闹钟))?$').hasMatch(subject)) return [whole];
    return subject.split(RegExp(r'、|以及|和|与')).map(aliases).toList();
  }

  static ({List<Set<String>> targets, Set<String> excluded, bool hasExclusions, bool unresolved})
      _scope(String goal, String action, Set<String> knownTitles) {
    final targets = <Set<String>>[], excluded = <String>{};
    var hasExclusions = false, unresolved = false;
    for (final raw in _instructionParts(goal)) {
      final clause = raw.trim()
          .replaceFirstMapped(RegExp(r'^(?:请)?(别|不要|不用)把(.+?)(取消|撤销|删除|关闭|改动|修改|调整)(了)?$'),
              (m) => '${m[1]}${m[3]}${m[2]}')
          .replaceFirstMapped(RegExp(r'^(.+?(?:提醒|闹钟))(?:请)?保留$'), (m) => '保留${m[1]}')
          .replaceFirst(RegExp(r'^(?:但|不过|然后|再|请|算了)[，, ]*'), '');
      // Mask quotation contents while locating verbs; keep offsets for exact titles.
      final visible = _maskTitles(clause);
      final neg = _withdrawal.firstMatch(visible);
      final keep = RegExp(r'^(?:请)?保留').firstMatch(visible);
      final negative = neg != null || keep != null;
      String subject;
      if (negative) {
        final kind = switch (neg?[1]) {
          '取消' || '撤销' || '删除' || '关闭' => 'cancel',
          '改动' || '修改' || '调整' || '改期' || '改' => 'reschedule',
          '提醒' || '设置' => 'remind',
          _ => '',
        };
        if (neg != null ? kind != action : action == 'remind') continue;
        final match = neg ?? keep!;
        final after = clause.substring(match.end).trim()
            .replaceFirst(RegExp(r'^我'), '').replaceFirst(RegExp(r'了$'), '');
        final before = clause.substring(0,match.start).trim()
            .replaceFirst(RegExp(r'^(?:把|将)'), '')
            .replaceFirst(RegExp(r'(?:那个|这个|这条|那条)$'), '');
        subject = (after.isNotEmpty ? after : before)
            .split(RegExp(r'改到|改成|改为|推迟到|提前到')).first.trim();
        hasExclusions = true;
        // Resolve the protected title against the actual reminders or explicit targets.
        // A longer exact title wins over a title contained inside it.
        final titles = {...knownTitles, for (final t in targets) ...t}
            .where((t) => t.isNotEmpty && t != '提醒' && t != '闹钟').toSet();
        final parts = _names(subject, knownTitles);
        final resolved = <String>{};
        for (final aliases in parts) {
          final exact = titles.intersection(aliases);
          final matched = exact.isNotEmpty ? exact : titles.where((t) => aliases.any((a) => a.contains(t))).toSet();
          resolved.addAll(matched.where((t) => !matched.any((longer) => longer != t && longer.contains(t))));
        }
        if (resolved.isNotEmpty) {
          for (final title in resolved) {
            final names = _names(title, {title}).single;
            excluded.addAll(names);
            targets.removeWhere((t) => t.any(names.contains));
          }
          continue;
        }
        subject = subject.replaceAll(RegExp(r'(?:暂时|暂且|先|目前|现在|那个|那条|这个|这条)+$'), '');
        if (RegExp(r'^(?:都|全部|所有|一律|这些|两个|这两个|任何)?(?:的)?(?:提醒|闹钟)?$').hasMatch(subject)) {
          targets.clear();
          excluded.clear();
          unresolved = false;
          continue;
        }
        if (knownTitles.isNotEmpty && action != 'remind' &&
            RegExp(r'那个|这个|那条|这条|前者|后者|其中|另一个|上一个').hasMatch(clause)) unresolved = true;
      } else {
        final createShort = action == 'remind' && targets.isNotEmpty &&
            RegExp(r'^(?:今天|明天|后天)?(?:上午|下午|早上|晚上)?[零一二三四五六七八九十两0-9]+(?:点|时|[:：]\d\d)').hasMatch(clause);
        if (!_positiveActions(clause).contains(action) && !createShort) continue;
        subject = clause.split(RegExp(r'改到|改成|改为|推迟到|提前到')).first.trim()
            .replaceFirst(RegExp(r'^(?:(?:请|帮我|麻烦|把|将|取消|撤销|删除|关闭|修改|调整|一下|掉)\s*)+'), '')
            .replaceFirst(RegExp(r'(?:取消|撤销|删除|关掉|一下|掉|了)+$'), '').trim();
        if (action == 'remind') {
          subject = subject.replaceFirst(RegExp(r'^.*(?:提醒我|叫醒我)'), '');
          if (createShort) subject = subject.replaceFirst(RegExp(r'^.*?(?:点|时|[:：]\d\d)'), '');
        }
      }
      for (final aliases in _names(subject, knownTitles)) {
        final identifiers = aliases.where((a) => a.isNotEmpty && a != '提醒' && a != '闹钟').toSet();
        if (negative) {
          excluded.addAll(identifiers);
          targets.removeWhere((t) => t.any(identifiers.contains));
        } else {
          excluded.removeAll(identifiers);
          targets.add(aliases);
        }
      }
    }
    return (targets: targets, excluded: excluded, hasExclusions: hasExclusions, unresolved: unresolved);
  }

  Future<String> _target(List<Set<String>> subjects, List entries, String latest, Map args) async {
    final owned = <Map>[];
    for (final item in entries.whereType<Map>()) {
      final id = item['id'];
      if (id is! String || !id.startsWith('work-')) continue;
      if (await db.getSetting('work_reminder_thread_$id') == thread ||
          id == latest) {
        owned.add(item);
      } else {
        final authority = await db.getSetting(
          'work_order_authority_${id.substring(5)}',
        );
        if (authority != null &&
            authority.isNotEmpty &&
            (jsonDecode(authority) as List).first == thread)
          owned.add(item);
      }
    }
    final target = args['target'];
    final matches = owned.where((item) =>
        (goal.trim().isEmpty || subjects.any((s) => s.contains(item['title']))) &&
        (target == null || target == item['title'])).toList();
    if ((target != null || subjects.length == 1) && matches.length == 1) {
      return matches.single['id'] as String;
    }
    final recentReference = RegExp(
      r'^(?:刚才|刚刚|刚设好?|上次|最近|最新|最后)?的?(?:上一个|最后一个|那个|这个|那条|上一条|这条)?的?$',
    );
    final generic = goal.trim().isEmpty || subjects.length == 1 && subjects.single.any(recentReference.hasMatch);
    if (target != null || !generic) {
      throw const FormatException('未能唯一确定本会话中点名的提醒，请核对原提醒标题');
    }
    if (latest.isEmpty || !owned.any((e) => e['id'] == latest))
      throw const FormatException('没有可定位的最近提醒');
    return latest;
  }

  Future<Map?> _effectiveReminderEntry(String action, String id, Map? original) async {
    // A cancellation is terminal for a reminder ID. Old saves use the same IDs
    // and can recover the final state without timestamps or a new journal.
    for (final later in [if (action != 'cancel') 'cancel', if (action == 'remind') 'reschedule']) {
      for (final owner in {order,...relatedOrders}) {
        final raw = await db.getSetting('work_action_${owner}_$later');
        if (raw == null || raw.isEmpty) continue;
        final recorded = _records(jsonDecode(raw) as Map).where((r) => r['id'] == id).lastOrNull;
        if (recorded != null) return recorded['entry'] as Map?;
      }
    }
    return original;
  }

  Future<Map<String, Object?>> _reminder(
    String action,
    Map args, {
    Map? verifying,
  }) async {
    token.throwIfCancelled();
    if (!await db.brainWorkAllowed()) throw StateError('当前设备暂停工作');
    const calendarKey = CalendarReminderStore.settingKey;
    final key = 'work_action_${order}_$action';
    final latestKey = 'work_last_reminder_$thread';
    final prior = await db.getSetting(latestKey) ?? '';
    final savedRaw = await db.getSetting(key) ?? '';
    final items = savedRaw.isEmpty
        ? <Map>[]
        : _records(jsonDecode(savedRaw) as Map);
    final raw = await db.getSetting(calendarKey) ?? '';
    final entries = raw.isEmpty ? <dynamic>[] : jsonDecode(raw) as List;
    final clauses = action == 'remind' ? _creationClauses : const <String>[];
    final declared = action == 'remind'
        ? RegExp(
            r'([1-9]\d?|[一二两三四五六七八九十])(?:个|条|项)(?:不同的)?提醒',
          ).firstMatch(goal)?.group(1)
        : null;
    final explicitCount = declared == null
        ? null
        : int.tryParse(declared) ??
              '零一二三四五六七八九十'.indexOf(declared.replaceAll('两', '二'));
    final scope = _scope(goal, action, {
      for (final entry in entries.whereType<Map>()) if (entry['title'] is String) entry['title'] as String,
      for (final receipt in items) if (receipt['target_title'] is String) receipt['target_title'] as String,
    });
    final targets = scope.targets;
    final protectedIds = {
      for (final e in entries.whereType<Map>()) if (scope.excluded.contains(e['title'])) e['id'],
      for (final e in items) if (scope.excluded.contains(e['target_title'])) e['id'],
    };
    if (scope.unresolved) throw const FormatException('尚不能确定要求保留的是哪条提醒');
    if (scope.hasExclusions && targets.isEmpty) throw const FormatException('这项提醒操作已撤回');
    final count = action == 'remind' && !scope.hasExclusions ? explicitCount ?? clauses.toSet().length :
        targets.map((s) => (s.toList()..sort()).join('|')).toSet().length;
    final multiple = count > 1;
    final text = args['text'] is String
        ? (args['text'] as String).trim()
        : null;
    final time = args['local_time'];
    final matching = items.where((e) {
      if (action != 'remind') {
        final target = args['target'];
        if (target == null) return !multiple;
        if (e['target_title'] == null && e['entry'] == null && !multiple) {
          // Older single-target cancellation receipts stored only the ID.
          return targets.length == 1 && targets.single.contains(target);
        }
        return target == e['target_title'] || target == e['entry']?['title'];
      }
      if (!multiple) return true;
      final entry = e['entry'];
      if (entry is! Map || entry['title'] != text || time is! String)
        return false;
      final date = DateTime.tryParse(time);
      return date != null &&
          entry['year'] == date.year &&
          entry['month'] == date.month &&
          entry['day'] == date.day &&
          entry['hour'] == date.hour &&
          entry['minute'] == date.minute;
    });
    final receipt = verifying ?? matching.firstOrNull;
    final id =
        receipt?['id'] as String? ??
        (action == 'remind'
            ? (items.isEmpty
                  ? 'work-$order'
                  : 'work-$order-${items.length + 1}')
            : await _target(targets, entries, prior, args));
    final index = entries.indexWhere((e) => e is Map && e['id'] == id);
    final targetTitle = index >= 0 ? entries[index]['title'] : null;
    final requestedTitle = action == 'remind' ? text : args['target'];
    if (protectedIds.contains(id) || [requestedTitle, targetTitle, receipt?['target_title'], receipt?['entry']?['title']].any(scope.excluded.contains)) {
      throw const FormatException('本轮要求保留这条提醒');
    }
    if (action == 'remind' && scope.hasExclusions && verifying == null &&
        !targets.any((names) => names.contains(text))) {
      throw const FormatException('请使用本轮明确要求创建的提醒标题');
    }
    Map? entry;
    if (receipt != null) {
      entry = receipt['entry'] as Map?;
      final effective = await _effectiveReminderEntry(action, id, entry);
      if (effective == null
          ? index >= 0
          : index < 0 || jsonEncode(entries[index]) != jsonEncode(effective)) {
        throw const FormatException('提醒随后已被更改或移除，请确认新的目标');
      }
      if (entry != null && verifying == null) {
        final date = time is String ? DateTime.tryParse(time) : null;
        if (text != null && entry['title'] != text ||
            time != null &&
                (date == null ||
                    entry['year'] != date.year ||
                    entry['month'] != date.month ||
                    entry['day'] != date.day ||
                    entry['hour'] != date.hour ||
                    entry['minute'] != date.minute))
          throw const FormatException('该提醒已有不同的已核实回执');
      }
    } else {
      if (action != 'remind' && index < 0)
        throw const FormatException('原提醒已被移除');
      if (action == 'cancel') {
        entries.removeAt(index);
      } else {
        final date = time is String ? DateTime.tryParse(time) : null;
        if (time is! String ||
            !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d$').hasMatch(time) ||
            date == null ||
            !date.isAfter(DateTime.now()) ||
            date.toIso8601String().substring(0, 16) != time) {
          throw const FormatException('提醒需要明确且尚未到达的本地日期和时间');
        }
        final title = text ?? (index >= 0 ? entries[index]['title'] : null);
        if (title is! String || title.isEmpty || title.length > 120)
          throw const FormatException('提醒需要简短标题');
        if (action == 'remind' && multiple &&
            (items.length >= count ||
                !goal.contains(title) ||
                explicitCount == null &&
                    clauses.where((p) => p.contains(title)).length <=
                        items
                            .where((i) => i['entry']?['title'] == title)
                            .length)) {
          throw const FormatException('请逐条使用原任务中的提醒标题与时间');
        }
        entry = {
          ...CalendarReminder(
            id: id,
            title: title,
            year: date.year,
            month: date.month,
            day: date.day,
            hour: date.hour,
            minute: date.minute,
            yearly: false,
          ).toJson(),
        };
        if (index < 0) {
          entries.add(entry);
        } else {
          entries[index] = entry;
        }
      }
      items.add({'id': id, 'entry': entry, if (targetTitle != null) 'target_title': targetTitle});
      token.throwIfCancelled();
      final saved = await db.setSettingsAtomically(
        {
          calendarKey: jsonEncode(entries),
          latestKey: id,
          key: jsonEncode({'items': items}),
          'work_reminder_thread_$id': thread,
        },
        expectedSettings: {key: savedRaw, calendarKey: raw, latestKey: prior},
      );
      if (!saved) throw const FormatException('提醒列表刚被修改，请继续任务重新核对');
    }
    if (!await CalendarReminderStore(db).sync())
      throw const FormatException('事项已保存，系统响铃安排尚未核实');
    final verified = _verifiedIds.putIfAbsent(action, () => <String>{})..add(id);
    if (!multiple || verified.length >= count) confirmed.add(action);
    return {
      'action': action,
      'id': id,
      if (entry != null) 'title': entry['title'],
      'display': '${labels[action]}已核实',
      'reused': receipt != null,
    };
  }
}

/// A known unmet deliverable that an independent sibling can work past.
class WorkDeliveryFailure extends StateError {
  WorkDeliveryFailure(super.message);
}
