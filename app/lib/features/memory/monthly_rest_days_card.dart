import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/memory/monthly_rest_days.dart';

class MonthlyRestDaysCard extends StatefulWidget {
  const MonthlyRestDaysCard(this.db, {super.key});
  final AppDatabase db;
  @override
  State<MonthlyRestDaysCard> createState() => _MonthlyRestDaysCardState();
}

class _MonthlyRestDaysCardState extends State<MonthlyRestDaysCard>
    with WidgetsBindingObserver {
  late DateTime month;
  MonthlyRestDays? saved;
  Set<int> draft = {};
  Timer? rollover;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncMonth(first: true);
  }

  void _syncMonth({bool first = false}) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    rollover?.cancel();
    rollover = Timer(
      DateTime(now.year, now.month + 1).difference(now),
      _syncMonth,
    );
    if (!first && month == current) return;
    setState(() {
      month = current;
      saved = null;
      draft = {};
      busy = false;
      error = null;
    });
    _load(current);
  }

  Future<void> _load(DateTime target) async {
    try {
      final record = await MonthlyRestDays.read(widget.db, target);
      if (mounted && target == month) {
        setState(() {
          saved = record;
          draft = {...?record.days};
          error = null;
        });
      }
    } catch (_) {
      if (mounted && target == month) setState(() => error = '排班读取失败');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncMonth();
  }

  @override
  void dispose() {
    rollover?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    final target = month;
    _syncMonth();
    if (month != target || busy) return;
    final record = MonthlyRestDays(target, clear ? null : draft);
    setState(() => busy = true);
    try {
      await record.save(widget.db);
      if (mounted && month == target) {
        setState(() {
          saved = record;
          draft = {...?record.days};
          error = null;
        });
      }
    } catch (_) {
      if (mounted && month == target) setState(() => error = '保存失败，请重试');
    } finally {
      if (mounted && month == target) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = saved;
    final colors = Theme.of(context).colorScheme;
    final changed =
        record != null &&
        (record.days == null ||
            draft.length != record.days!.length ||
            !draft.containsAll(record.days!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月休息日 · ${month.year}年${month.month}月',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: colors.error)),
            if (record == null && error != null)
              TextButton(onPressed: () => _load(month), child: const Text('重试'))
            else if (record == null)
              const LinearProgressIndicator()
            else ...[
              Text(
                record.days == null
                    ? '排班未知。选好休息日后保存，她就能记住。'
                    : changed
                    ? '有未保存的修改'
                    : '排班已确认 · ${draft.length} 天休息',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in '一二三四五六日'.split(''))
                    Expanded(child: Center(child: Text(d))),
                ],
              ),
              for (
                var week = 0;
                week * 7 < month.weekday - 1 + record.length;
                week++
              )
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _day(
                          week * 7 + col + 2 - month.weekday,
                          record,
                          colors,
                        ),
                      ),
                  ],
                ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy || !changed ? null : () => _save(),
                    child: Text(draft.isEmpty ? '确认本月无休息日' : '保存本月排班'),
                  ),
                  if (record.days != null)
                    TextButton(
                      onPressed: busy ? null : () => _save(clear: true),
                      child: const Text('恢复为排班未知'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _day(int day, MonthlyRestDays record, ColorScheme colors) {
    if (day < 1 || day > record.length) return const SizedBox.shrink();
    final selected = draft.contains(day);
    return Semantics(
      selected: selected,
      button: true,
      label: '${month.month}月$day日',
      child: InkWell(
        onTap: busy
            ? null
            : () => setState(() {
                if (!draft.remove(day)) draft.add(day);
              }),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? colors.primaryContainer : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              color: selected ? colors.onPrimaryContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}
