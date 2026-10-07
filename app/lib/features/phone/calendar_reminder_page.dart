import 'dart:async';
import '../../core/phone/calendar_reminder_state.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/phone/calendar_reminder_store.dart';
import '../../core/platform/android_bridge.dart';

class CalendarReminderPage extends StatefulWidget {
  const CalendarReminderPage({super.key, this.store});
  final CalendarReminderStore? store;

  @override
  State<CalendarReminderPage> createState() => _CalendarReminderPageState();
}

class _CalendarReminderPageState extends State<CalendarReminderPage> with WidgetsBindingObserver {
  late final store = widget.store ?? CalendarReminderStore(AppDatabase.instance);
  StreamSubscription<void>? _events;
  Map<String, Object?> presentation = {};
  List<CalendarReminderOccurrence> pending = [];
  List<CalendarReminder> entries = const [];
  bool precise = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = AndroidBridge.instance.calendarReminderChanges.listen((_) => _load());
    _load();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) { if(state == AppLifecycleState.resumed) _load(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this);unawaited(_events?.cancel());super.dispose(); }

  Future<void> _load() async {
    final loaded = await store.load();
    final exact = await AndroidBridge.instance.canScheduleExactReminders();
    await store.sync(loaded);
    final permissions = await AndroidBridge.instance.calendarReminderPresentationStatus();
    final runtime = await CalendarReminderStateStore.read(await store.db.database);
    if (!mounted) return;
    setState(() {
      entries = loaded;
      precise = exact;
      presentation = permissions;
      pending = runtime.records.where((e) => e.unconfirmed).toList();
      loading = false;
    });
  }

  Future<void> _edit([CalendarReminder? old]) async {
    final title = TextEditingController(text: old?.title ?? '');
    var date = old == null ? DateTime.now() :
        DateTime(old.year, old.month, old.day);
    var timed = old?.timed ?? false;
    var repeat = old?.repeat ?? 'once';
    var enabled = old?.enabled ?? true;
    final weekdays = {...?old?.weekdays};
    String? error;
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
              if (repeat == 'once' || repeat == 'yearly') ListTile(
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
              DropdownButtonFormField<String>(
                value: repeat,
                decoration: const InputDecoration(labelText: '重复'),
                items: const [DropdownMenuItem(value:'once',child:Text('仅一次')),
                  DropdownMenuItem(value:'daily',child:Text('每天')),
                  DropdownMenuItem(value:'weekly',child:Text('自定义星期')),
                  DropdownMenuItem(value:'yearly',child:Text('每年'))],
                onChanged: (value) => refresh(() { repeat=value ?? 'once';error=null; }),
              ),
              if(repeat == 'weekly') Wrap(spacing:4,children:List.generate(7,(index) => FilterChip(
                label:Text('周${'一二三四五六日'[index]}'),selected:weekdays.contains(index+1),
                onSelected:(selected) => refresh(() { if(selected) { weekdays.add(index+1); } else { weekdays.remove(index+1); } error=null; }),
              ))),
              SwitchListTile(title:const Text('启用'),value:enabled,onChanged:(v) => refresh(() => enabled=v)),
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
              if (error != null) Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final value = title.text.trim();
                if (value.isEmpty) return;
                if (repeat == 'weekly' && weekdays.isEmpty) { refresh(() => error='请至少选择一个星期');return; }
                if (enabled && timed && repeat == 'once' &&
                    !DateTime(date.year, date.month, date.day, time.hour, time.minute)
                        .isAfter(DateTime.now())) { refresh(() => error='请选择未来的提醒时间');return; }
                Navigator.pop(context, CalendarReminder(
                  id: old?.id ?? const Uuid().v4(),
                  title: value,
                  year: date.year,
                  month: date.month,
                  day: date.day,
                  yearly: repeat == 'yearly',
                  recurrence: repeat,
                  weekdays: weekdays.toList()..sort(),
                  enabled: enabled,
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
        if(presentation['fullScreen'] == false) ListTile(
          leading:const Icon(Icons.lock_clock),title:const Text('允许锁屏全屏提醒'),
          subtitle:const Text('用于锁屏时显示确认卡片'),
          onTap:() => AndroidBridge.instance.openCalendarReminderPresentationSettings('fullScreen')),
        if(presentation['overlay'] == false) ListTile(
          leading:const Icon(Icons.picture_in_picture_alt),title:const Text('允许提醒悬浮窗'),
          subtitle:const Text('使用其他应用时也能看到确认卡片'),
          onTap:() => AndroidBridge.instance.openCalendarReminderPresentationSettings('overlay')),
        if(pending.isNotEmpty) ListTile(leading:const Icon(Icons.alarm),
          title:Text('${pending.length} 条提醒待确认'),subtitle:Text(pending.first.title),
          onTap:() => AndroidBridge.instance.openCalendarReminderCard()),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('响铃声音'),
          subtitle: const Text('在系统中选择代办响铃提醒的声音'),
          onTap: () => AndroidBridge.instance.openReminderSoundSettings(),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('按手机本地时间提醒，最长响铃 5 分钟。到点她会发起事项提醒；确认表示已收到。响铃及结束后 10 分钟内暂停普通主动聊天。'),
        ),
        Expanded(child: entries.isEmpty
          ? const Center(child: Text('还没有代办事项，点击右上角添加。'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final scheduled = entry.nextOccurrence(DateTime.now());
                return ListTile(
                  title: Text(entry.title),
                  subtitle: Text('${entry.repeat == 'once' || entry.repeat == 'yearly' ? '${entry.dateLabel} · ' : ''}${entry.repeatLabel}'
                      '${entry.timed ? ' · ${entry.hour!.toString().padLeft(2, '0')}:${entry.minute!.toString().padLeft(2, '0')} 响铃' : ' · 全天'}'
                      '${!entry.enabled ? '\n已停用' : scheduled != null ? '\n下次：${scheduled.month}月${scheduled.day}日 ${scheduled.hour.toString().padLeft(2,'0')}:${scheduled.minute.toString().padLeft(2,'0')}' : entry.timed ? '\n原定时间已过 · 完成情况未知' : ''}'),
                  onTap: () => _edit(entry),
                  trailing: Row(mainAxisSize:MainAxisSize.min,children:[
                    Switch(value:entry.enabled,onChanged:(enabled) async {
                      final next=entries.map((e) => e.id==entry.id ? e.withEnabled(enabled) : e).toList();
                      await store.save(next);if(mounted) setState(() => entries=next);
                    }),
                    IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(entry),
                  )]),
                );
              },
            )),
      ]),
  );
}
