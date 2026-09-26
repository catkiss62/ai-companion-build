import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/phone/calendar_reminder_store.dart';
import '../../core/platform/android_bridge.dart';

class CalendarReminderPage extends StatefulWidget {
  const CalendarReminderPage({super.key});

  @override
  State<CalendarReminderPage> createState() => _CalendarReminderPageState();
}

class _CalendarReminderPageState extends State<CalendarReminderPage> {
  final store = CalendarReminderStore(AppDatabase.instance);
  List<CalendarReminder> entries = const [];
  bool precise = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await store.load();
    final exact = await AndroidBridge.instance.canScheduleExactReminders();
    await store.sync(loaded);
    if (!mounted) return;
    setState(() {
      entries = loaded;
      precise = exact;
      loading = false;
    });
  }

  Future<void> _edit([CalendarReminder? old]) async {
    final title = TextEditingController(text: old?.title ?? '');
    var date = old == null ? DateTime.now() :
        DateTime(old.year, old.month, old.day);
    var timed = old?.timed ?? false;
    var yearly = old?.yearly ?? false;
    var time = TimeOfDay(hour: old?.hour ?? 9, minute: old?.minute ?? 0);
    final result = await showDialog<CalendarReminder>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(old == null ? '添加代办事项' : '编辑代办事项'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '事项，例如生日'),
              ),
              ListTile(
                title: const Text('日期'),
                subtitle: Text(MaterialLocalizations.of(context)
                    .formatMediumDate(date)),
                onTap: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (chosen != null) refresh(() => date = chosen);
                },
              ),
              SwitchListTile(
                title: const Text('每年重复'),
                value: yearly,
                onChanged: (value) => refresh(() => yearly = value),
              ),
              SwitchListTile(
                title: const Text('到点响铃提醒'),
                subtitle: const Text('关闭时是全天事项，她可在当天自然提起'),
                value: timed,
                onChanged: (value) => refresh(() => timed = value),
              ),
              if (timed) ListTile(
                title: const Text('提醒时间'),
                subtitle: Text(time.format(context)),
                onTap: () async {
                  final chosen = await showTimePicker(context: context, initialTime: time);
                  if (chosen != null) refresh(() => time = chosen);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final value = title.text.trim();
                if (value.isEmpty) return;
                if (timed && !yearly &&
                    !DateTime(date.year, date.month, date.day, time.hour, time.minute)
                        .isAfter(DateTime.now())) return;
                Navigator.pop(context, CalendarReminder(
                  id: old?.id ?? const Uuid().v4(),
                  title: value,
                  year: date.year,
                  month: date.month,
                  day: date.day,
                  yearly: yearly,
                  hour: timed ? time.hour : null,
                  minute: timed ? time.minute : null,
                ));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (result == null) return;
    final next = [...entries.where((e) => e.id != result.id), result];
    final scheduled = await store.save(next);
    if (result.timed) {
      await AndroidBridge.instance.requestNotificationPermission();
    }
    if (!mounted) return;
    setState(() => entries = next);
    if (!scheduled) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('事项已保存，但系统响铃尚未安排成功；请稍后重新打开代办提醒检查。')),
    );
  }

  Future<void> _delete(CalendarReminder entry) async {
    final next = entries.where((e) => e.id != entry.id).toList();
    await store.save(next);
    if (mounted) setState(() => entries = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('代办提醒'), actions: [
      IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add), tooltip: '添加事项'),
    ]),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      Column(children: [
        if (!precise) ListTile(
          leading: const Icon(Icons.access_time),
          title: const Text('精确提醒尚未开启'),
          subtitle: const Text('系统可能延迟响铃，点此打开精确闹钟设置。'),
          onTap: () async {
            await AndroidBridge.instance.openExactReminderSettings();
            if (mounted) await _load();
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('响铃声音'),
          subtitle: const Text('在系统中选择代办响铃提醒的声音'),
          onTap: () => AndroidBridge.instance.openReminderSoundSettings(),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('以手机本地日期和时区为准。定时事项响铃最多 5 分钟，停止后她会针对事项主动提醒一次。'),
        ),
        Expanded(child: entries.isEmpty
          ? const Center(child: Text('还没有代办事项，点击右上角添加。'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  title: Text(entry.title),
                  subtitle: Text('${entry.dateLabel}${entry.yearly ? ' · 每年' : ''}'
                      '${entry.timed ? ' · ${entry.hour!.toString().padLeft(2, '0')}:${entry.minute!.toString().padLeft(2, '0')} 响铃' : ' · 全天'}'),
                  onTap: () => _edit(entry),
                  trailing: IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(entry),
                  ),
                );
              },
            )),
      ]),
  );
}
