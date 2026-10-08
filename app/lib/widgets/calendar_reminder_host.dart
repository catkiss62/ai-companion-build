import 'dart:async';
import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../core/platform/android_bridge.dart';
import '../core/phone/calendar_reminder_followup.dart';

/// App-wide entry: native alarm records remain reachable after clearing notices
/// or leaving the alarm activity. Sending messages still belongs to one DB lease.
class CalendarReminderHost extends StatefulWidget {
  const CalendarReminderHost({super.key, required this.child});
  final Widget child;
  @override State<CalendarReminderHost> createState() => _CalendarReminderHostState();
}
class _CalendarReminderHostState extends State<CalendarReminderHost> with WidgetsBindingObserver {
  StreamSubscription<void>? _events;
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
      // Presentation is an in-place native card attached to MainActivity; this
      // host only schedules contextual delivery, without pushing an Activity.
      unawaited(CalendarReminderFollowup(AppDatabase.instance).deliverOne().catchError((Object _) {}));
    } catch (_) { /* A system alarm remains independent of this optional surface. */ }
    finally {
      _refreshing=false;
      if(_again && mounted) { _again=false;unawaited(_refresh()); }
    }
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this);unawaited(_events?.cancel());super.dispose(); }
  @override Widget build(BuildContext context) => widget.child;
}
