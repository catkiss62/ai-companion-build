import 'package:flutter/material.dart';

import '../../core/diagnostics/preflight_diagnostics.dart';

class PreflightDiagnosticsPage extends StatefulWidget {
  const PreflightDiagnosticsPage({super.key});

  @override
  State<PreflightDiagnosticsPage> createState() => _PreflightDiagnosticsPageState();
}

class _PreflightDiagnosticsPageState extends State<PreflightDiagnosticsPage> {
  final service = PreflightDiagnosticsService();
  PreflightSnapshot? snapshot;
  bool busy = false;
  String note = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run({bool deep = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      note = deep ? '正在做深度自检：会校验 TTS 黄金资源并初始化 JNI/MNN，但不会播放声音。' : '正在读取本机状态…';
    });
    try {
      final result = await service.run(deep: deep);
      if (!mounted) return;
      setState(() {
        snapshot = result;
        note = result.failures == 0
            ? result.warnings == 0
                ? '当前自检没有发现阻断项。'
                : '没有阻断项，但有 ${result.warnings} 个真机条件需要留意。'
            : '发现 ${result.failures} 个阻断项；导出脱敏报告可用于定位。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '自检未能完成：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    final current = snapshot;
    if (current == null || busy) return;
    setState(() {
      busy = true;
      note = '正在生成脱敏诊断报告…';
    });
    try {
      final saved = await service.export(current);
      if (!mounted) return;
      setState(() => note = saved ? '脱敏报告已保存。' : '已取消保存。');
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '报告导出失败：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _clearHistory() async {
    if (busy) return;
    await service.clearNativeHistory();
    if (!mounted) return;
    setState(() => note = '已清除本机脱敏 Native 诊断历史。');
    await _run(deep: snapshot?.deep ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text('真机测试前自检', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '这里只检查 Android/TTS/Nearby/Active Brain 等运行条件。报告不会包含聊天正文、长期记忆、共同经历、参考资料、通知/Accessibility 原文或 API Key。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : () => _run(),
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('快速自检'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : () => _run(deep: true),
                icon: const Icon(Icons.memory_rounded),
                label: const Text('深度自检'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '深度自检会实际执行 37 项 TTS 黄金校验并初始化本地 JNI/MNN；不会合成或播放测试语音。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(note),
        ],
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (current != null) ...[
          const SizedBox(height: 18),
          _SummaryCard(snapshot: current),
          const SizedBox(height: 12),
          ...current.checks.map((check) => _CheckCard(check: check)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('给后续排错用', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text(
                    '如果第一次实机测试某一层失败，保存这份报告再发回即可。设备/关系谱系/状态包 ID 只保留短 SHA-256 指纹，Native 历史最多保留 160 条、30 天。',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : _export,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('保存脱敏诊断报告'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: busy ? null : _clearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('清除 Native 诊断历史'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final PreflightSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ok = snapshot.failures == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ok ? Icons.check_circle_outline : Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ok ? '没有发现源码层可判定的阻断项' : '存在需要先处理的阻断项',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'fail=${snapshot.failures} · warn=${snapshot.warnings} · '
                    '${snapshot.deep ? '深度自检' : '快速自检'} · ${snapshot.createdAt.toLocal()}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.check});

  final PreflightCheck check;

  @override
  Widget build(BuildContext context) {
    final icon = switch (check.level) {
      'pass' => Icons.check_circle_outline_rounded,
      'fail' => Icons.error_outline_rounded,
      'warn' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(check.title),
        subtitle: Text(check.summary),
        trailing: Text(check.level.toUpperCase()),
      ),
    );
  }
}
