import 'dart:convert';

import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../phone/calendar_reminder_store.dart';
import '../platform/android_bridge.dart';
import '../tts/tts_service.dart';

/// Receipts for irreversible actions live in SQLite, independently of the
/// editable workspace transcript. One dispatch of each kind per work order.
class WorkHostActions {
  WorkHostActions(this.db, this.order, this.thread, this.allowed, this.token);
  final AppDatabase db;
  final String order;
  final String thread;
  final Set<String> allowed;
  final GenerationCancellationToken token;
  final confirmed = <String>{};
  String? lastError;

  static const name = 'work_host_action';
  static const labels = {
    'remind': '设置提醒', 'reschedule': '修改提醒', 'cancel': '取消提醒',
    'speak': '朗读', 'ring': '响铃',
  };
  static Set<String> requested(String goal) {
    final result = <String>{};
    final instruction = goal.replaceAll(RegExp(r'「[^」]*」|“[^”]*”|"[^"]*"|《[^》]*》'), '…');
    for (final part in instruction.split(RegExp(r'[，,。；;！!\n]'))) {
      final afterTask = RegExp(r'(?:整理|完成|整理完|做完|保存|交付)(?:之后|以后|后)(?:请|再|就)?(响铃|响一声|响一下|朗读|读给我)').firstMatch(part);
      if (afterTask != null && !RegExp(r'不要|别|不用|网页|按钮|演示|举例|比如|如果|假设|怎么|能否|[？?]').hasMatch(part)) {
        result.add(afterTask.group(1)!.startsWith('响') ? 'ring' : 'speak');
      }
      if (RegExp(r'网页|按钮|代码|示例|文档|教程|HTML|html|模拟|演示|测试题|看看|查一下|查查|查找|查询|查看|列出|总结|整理|分析|能否实现|功能介绍').hasMatch(part)) continue;
      if (RegExp(r'怎么|如何|是否|能不能|为什么|支持|哪些|解释|讨论|不要|不用|不必|无需|别再|别响|别读|不想|只查|[?？]').hasMatch(part)) continue;
      if (RegExp(r'(取消|撤销|删除|关闭).{0,12}(提醒|闹钟)|(提醒|闹钟).{0,10}(取消|删除|关掉)').hasMatch(part)) {
        result.add('cancel');
      } else if (RegExp(r'(提醒|闹钟).{0,16}(改到|改成|推迟|提前|改为)|(修改|推迟|提前|调整).{0,10}(提醒|闹钟)').hasMatch(part)) {
        result.add('reschedule');
      } else if (RegExp(r'提醒我|叫醒我|(帮我|设|建|加|安排).{0,8}(提醒|闹钟)').hasMatch(part)) {
        result.add('remind');
      }
      final delayed = RegExp(r'到时|届时|点钟|明天|分钟|小时|每天|闹钟|闹铃|[零一二三四五六七八九十两0-9]+[点时]').hasMatch(part);
      if (!delayed && RegExp(r'朗读|念给我|读给我|读出来|用语音(说|读|念|播)|播报一下').hasMatch(part)) result.add('speak');
      if (!delayed && RegExp(r'响铃|响一声|响一下|播放.{0,4}(提示音|铃声)').hasMatch(part)) result.add('ring');
    }
    return result;
  }

  Map<String, Object?> get tool => {
    'type': 'function',
    'function': {
      'name': name,
      'description': '执行本轮明确要求的本机操作，每种一次。提醒使用手机本地日期时间 YYYY-MM-DDTHH:mm。一项任务中相同操作重试复用原回执。即时语音和提示音只能立即播放，需等待其他交付时先完成那些步骤。取消或改期针对本会话最近建立的提醒。',
      'parameters': {
        'type': 'object', 'properties': {
          'action': {'type': 'string', 'enum': allowed.toList()},
          'text': {'type': 'string', 'description': '提醒标题或本次朗读文本'},
          'local_time': {'type': 'string', 'description': '建立/改期必填，使用用户发起任务时的本地时间推算'},
        }, 'required': ['action'], 'additionalProperties': false,
      },
    },
  };

  Future<List<Map<String, Object?>>> verifyExisting() async {
    final verified = <Map<String, Object?>>[];
    for (final action in allowed) {
      if ((await db.getSetting('work_action_${order}_$action') ?? '').isEmpty) continue;
      try {
        verified.add(await execute({'action': action}));
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
    if (action is! String || !allowed.contains(action)) throw const FormatException('本次任务没有要求这项操作');
    token.throwIfCancelled();
    if (!await db.brainWorkAllowed()) throw StateError('当前设备暂停工作');
    final key = 'work_action_${order}_$action';
    final raw = await db.getSetting(key) ?? '';
    final receipt = raw.isEmpty ? null : jsonDecode(raw) as Map;
    if (action == 'ring' || action == 'speak') {
      if (receipt == null) {
        final text = args['text'];
        if (action == 'speak' && (text is! String || text.trim().isEmpty || text.length > 1000)) {
          throw const FormatException('请提供 1000 字以内的朗读文本');
        }
        token.throwIfCancelled();
        final claimed = await db.setSettingsAtomically({key: '{"state":"dispatching"}'}, guardKey: key);
        if (!claimed) throw const FormatException('该播放已在处理中');
        if (token.isCancelled) {
          await db.setSetting(key, '');
          token.throwIfCancelled();
        }
        // Once handed to audio, even loss of the process or the reply cannot
        // establish that no sound was emitted. A resume must not replay it.
        final played = action == 'ring'
            ? (await AndroidBridge.instance.previewCompanionNotificationSound())['played'] == true
            : await TtsService(db: db).speak(text as String, manual: true, ownerId: 'work-$order',
                canContinue: () async => !token.isCancelled && await db.brainWorkAllowed());
        await db.setSetting(key, jsonEncode({'state': played ? 'done' : 'unconfirmed'}));
        if (!played) throw const FormatException('未确认播放成功，继续任务时不会自动重播');
      } else if (receipt['state'] != 'done') {
        throw const FormatException('上次播放结果未确认，若需重播请明确重新发起');
      }
    } else {
      await _reminder(action, args, key, receipt);
    }
    confirmed.add(action);
    return {'action': action, 'display': '${labels[action]}已核实', 'reused': receipt != null};
  }

  Future<void> _reminder(String action, Map args, String key, Map? receipt) async {
    const calendarKey = CalendarReminderStore.settingKey;
    final latestKey = 'work_last_reminder_$thread';
    final prior = await db.getSetting(latestKey) ?? '';
    final id = (receipt?['id'] as String?) ?? (action == 'remind' ? 'work-$order' : prior);
    if (id.isEmpty) throw const FormatException('本工作会话没有可以修改的提醒');
    final raw = await db.getSetting(calendarKey) ?? '';
    final entries = raw.isEmpty ? <dynamic>[] : jsonDecode(raw) as List;
    final index = entries.indexWhere((e) => e is Map && e['id'] == id);
    if (receipt != null) {
      if (action == 'cancel' ? index >= 0 : index < 0 || jsonEncode(entries[index]) != jsonEncode(receipt['entry'])) {
        throw const FormatException('提醒随后已被更改或移除，请确认新的目标');
      }
    } else {
      if (action != 'remind' && index < 0) throw const FormatException('原提醒已被移除');
      if (action == 'cancel') {
        entries.removeAt(index);
      } else {
        final time = args['local_time'];
        final date = time is String ? DateTime.tryParse(time) : null;
        if (time is! String || !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d$').hasMatch(time) ||
            date == null || !date.isAfter(DateTime.now()) || date.toIso8601String().substring(0, 16) != time) {
          throw const FormatException('提醒需要明确且尚未到达的本地日期和时间');
        }
        final text = args['text'] ?? (index >= 0 ? entries[index]['title'] : null);
        if (text is! String || text.trim().isEmpty || text.length > 120) throw const FormatException('提醒需要简短标题');
        final entry = CalendarReminder(id: id, title: text.trim(), year: date.year, month: date.month,
            day: date.day, hour: date.hour, minute: date.minute, yearly: false).toJson();
        if (index < 0) { entries.add(entry); } else { entries[index] = entry; }
      }
      final expectedEntry = action == 'cancel' ? null : entries.firstWhere((e) => e['id'] == id);
      token.throwIfCancelled();
      final saved = await db.setSettingsAtomically({
        calendarKey: jsonEncode(entries), latestKey: id,
        key: jsonEncode({'id': id, 'entry': expectedEntry}),
      }, guardKey: key, expectedSettings: {calendarKey: raw, latestKey: prior});
      if (!saved) throw const FormatException('提醒列表刚被修改，请继续任务重新核对');
    }
    // Re-sync the actual calendar after a crash between the database and Android.
    if (!await CalendarReminderStore(db).sync()) throw const FormatException('事项已保存，系统响铃安排尚未核实');
  }
}
