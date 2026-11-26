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
  });
  final String goal;
  final AppDatabase db;
  final String order;
  final String thread;
  final Set<String> allowed;
  final GenerationCancellationToken token;
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
  static Set<String> requested(String goal) {
    final result = <String>{};
    final instruction = goal
        .replaceAll(RegExp(r'「[^」]*」|“[^”]*”|"[^"]*"|《[^》]*》'), '…')
        .replaceAll(RegExp(r'(?:别|不要)忘(?:了|记)?'), '记得');
    for (final part in instruction.split(RegExp(r'[，,。；;！!\n]'))) {
      final withdrawal = RegExp(
        r'(?:别|不要|不用|不必|无需|不再|不)(?:再)?(取消|撤销|删除|改动|修改|调整|提醒|设置|朗读|响铃)',
      ).firstMatch(part);
      if (withdrawal != null) {
        final verb = withdrawal[1];
        result.remove(switch (verb) {
          '取消' || '撤销' || '删除' => 'cancel',
          '改动' || '修改' || '调整' => 'reschedule',
          '朗读' => 'speak',
          '响铃' => 'ring',
          _ => 'remind',
        });
      }
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
          '执行本轮明确要求的本机操作，各条提醒分别调用。提醒使用手机本地日期时间 YYYY-MM-DDTHH:mm。一项任务中相同操作重试复用原回执。即时语音和提示音只能立即播放，需等待其他交付时先完成那些步骤。点名修改或取消时 target 传入原提醒标题；仅指代最近一条时省略。',
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
        if (error is FormatException) throw StateError(error.message);
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

  Future<String> _target(List entries, String latest, Map args) async {
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
    final matches = owned
        .where(
          (item) =>
              (item['title'] as String).isNotEmpty &&
              goal.contains(item['title'] as String),
        )
        .toList();
    final target = args['target'];
    if (matches.length == 1 &&
        (target == null || target == matches.single['title']))
      return matches.single['id'] as String;
    final subject = goal
        .split(RegExp(r'改到|改成|改为|推迟到|提前到'))
        .first
        .replaceAll(
          RegExp(r'请|帮我|把|将|取消|撤销|删除|关闭|提醒|闹钟|设置|建立|修改|调整|一下|掉|了|[。！!\s]'),
          '',
        );
    final generic = RegExp(
      r'^(?:刚才|刚刚|刚设好?|上次|最近|最新|最后)?(?:的)?(?:上一个|最后一个|那个|这个|那条|上一条|这条)?(?:的)?$',
    ).hasMatch(subject);
    if (matches.isNotEmpty || target != null || !generic) {
      throw const FormatException('未能唯一确定本会话中点名的提醒，请核对原提醒标题');
    }
    if (latest.isEmpty || !owned.any((e) => e['id'] == latest))
      throw const FormatException('没有可定位的最近提醒');
    return latest;
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
    final count = explicitCount ?? clauses.toSet().length;
    final multiple = count > 1;
    final text = args['text'] is String
        ? (args['text'] as String).trim()
        : null;
    final time = args['local_time'];
    final matching = items.where((e) {
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
            : await _target(entries, prior, args));
    final index = entries.indexWhere((e) => e is Map && e['id'] == id);
    Map? entry;
    if (receipt != null) {
      entry = receipt['entry'] as Map?;
      if (action == 'cancel'
          ? index >= 0
          : index < 0 || jsonEncode(entries[index]) != jsonEncode(entry)) {
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
        if (multiple &&
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
      items.add({'id': id, 'entry': entry});
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
    if (!multiple || items.length >= count) confirmed.add(action);
    return {
      'action': action,
      'id': id,
      if (entry != null) 'title': entry['title'],
      'display': '${labels[action]}已核实',
      'reused': receipt != null,
    };
  }
}
