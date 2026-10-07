import 'dart:async';
import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../core/platform/android_bridge.dart';
import '../core/phone/calendar_reminder_followup.dart';
import '../core/phone/calendar_reminder_state.dart';

/// App-wide entry: native alarm records remain reachable after clearing notices
/// or leaving the alarm activity. Sending messages still belongs to one DB lease.
class CalendarReminderHost extends StatefulWidget {
  const CalendarReminderHost({super.key, required this.child});
  final Widget child;
  @override State<CalendarReminderHost> createState() => _CalendarReminderHostState();
}
class _CalendarReminderHostState extends State<CalendarReminderHost> with WidgetsBindingObserver {
  StreamSubscription<void>? _events;
  final _opened = <String>{};
  List<CalendarReminderOccurrence> _pending = [];
  bool _refreshing = false;
  bool _again = false;
  @override void initState() {
    super.initState();WidgetsBinding.instance.addObserver(this);
    _events=AndroidBridge.instance.calendarReminderChanges.listen((_) => unawaited(_refresh()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }
  Future<void> _refresh() async {
    if (_refreshing) { _again=true;return; }
    _refreshing=true;
    try {
      final raw=await AndroidBridge.instance.calendarReminderState();
      if(raw==null || !mounted) return;
      final state=await CalendarReminderStateStore.read(await AppDatabase.instance.database);
      final pending=state.records.where((e) => e.unconfirmed).toList();
      if(!mounted) return;
      setState(() => _pending=pending);
      unawaited(CalendarReminderFollowup(AppDatabase.instance).deliverOne().catchError((Object _) {}));
      final ringing=pending.where((e) => e.status=='ringing' && !_opened.contains(e.occurrence)).firstOrNull;
      if(ringing!=null && WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed) {
        _opened.addAll(pending.where((e) => e.status=='ringing').map((e) => e.occurrence));
        await AndroidBridge.instance.openCalendarReminderCard(ringing.occurrence);
      }
    } catch (_) { /* A system alarm remains independent of this optional surface. */ }
    finally {
      _refreshing=false;
      if(_again && mounted) { _again=false;unawaited(_refresh()); }
    }
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this);unawaited(_events?.cancel());super.dispose(); }
  @override Widget build(BuildContext context) => Stack(children:[
    widget.child,
    if(_pending.isNotEmpty) Positioned(top:0,right:12,child:SafeArea(child:Material(
      color:Theme.of(context).colorScheme.surfaceContainerHigh,borderRadius:BorderRadius.circular(18),elevation:6,
      child:TextButton.icon(onPressed:() => AndroidBridge.instance.openCalendarReminderCard(),
        icon:const Icon(Icons.alarm),label:Text('待办提醒 · ${_pending.length} 条待确认')),
    ))),
  ]);
}
