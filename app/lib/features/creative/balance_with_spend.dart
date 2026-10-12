import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/daily_balance_spend.dart';
import '../../core/storage/secure_config.dart';

class BalanceWithSpend extends StatefulWidget {
  const BalanceWithSpend({super.key, required this.balance});
  final Future<String> balance;
  @override
  State<BalanceWithSpend> createState() => _BalanceWithSpendState();
}
class _BalanceWithSpendState extends State<BalanceWithSpend> {
  String label = '今日：读取中…';
  String detail = '正在读取账户余额记录';
  String? recordedBalance;
  Timer? timer;
  int _loadRevision = 0;
  @override
  void initState() { super.initState(); _load(); timer = Timer.periodic(const Duration(seconds: 10), (_) => _load()); }
  Future<void> _load() async {
    final revision = ++_loadRevision;
    try {
      // display() persists its successful reading before resolving this future.
      // The initial value therefore does not wait ten seconds for a second tick.
      await widget.balance;
      if (!mounted || revision != _loadRevision) return;
      final key = (await SecureConfig.instance.readDeepSeekApiKey() ?? '').trim();
      final value = await DailyBalanceSpend.today(AppDatabase.instance,
        DailyBalanceSpend.account(key));
      final currentKey = (await SecureConfig.instance.readDeepSeekApiKey() ?? '').trim();
      if (!mounted || revision != _loadRevision || currentKey != key) return;
      setState(() {
        label = value.label; detail = value.detail; recordedBalance = value.balanceLabel;
      });
    } catch (_) {
      if (mounted && revision == _loadRevision) setState(() {
        label = '今日：待记录'; detail = '暂时无法读取账户余额记录，请稍后重试。';
        recordedBalance = null;
      });
    }
  }
  @override
  void didUpdateWidget(covariant BalanceWithSpend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.balance, widget.balance)) _load();
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(future: widget.balance,
    builder: (_, snapshot) => Wrap(spacing: 12, runSpacing: 4, children: [
      Text(snapshot.data != null &&
          (snapshot.data!.startsWith('DeepSeek 余额：¥') || snapshot.data!.startsWith('DeepSeek 余额：\$'))
          ? recordedBalance ?? snapshot.data! : snapshot.data ?? 'DeepSeek 余额：查询中…'),
      InkWell(onTap: () => showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('今日消耗'), content: Text(detail),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))])), child: Text(label)),
    ]));
}
