import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/daily_spend.dart';

class BalanceWithSpend extends StatefulWidget {
  const BalanceWithSpend({super.key, required this.balance});
  final Future<String> balance;
  @override
  State<BalanceWithSpend> createState() => _BalanceWithSpendState();
}
class _BalanceWithSpendState extends State<BalanceWithSpend> {
  String label = '今日：—';
  String detail = '正在读取本 App 用量';
  Timer? timer;
  @override
  void initState() { super.initState(); _load(); timer = Timer.periodic(const Duration(seconds: 10), (_) => _load()); }
  Future<void> _load() async {
    final value = await DailySpend.today(AppDatabase.instance);
    if (mounted) setState(() { label = value.label; detail = value.detail; });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(future: widget.balance,
    builder: (_, snapshot) => Wrap(spacing: 12, runSpacing: 4, children: [
      Text(snapshot.data ?? 'DeepSeek 余额：查询中…'),
      InkWell(onTap: () => showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('今日消耗'), content: Text(detail),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))])), child: Text(label)),
    ]));
}
