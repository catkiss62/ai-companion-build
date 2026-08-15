import 'package:flutter/material.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/ai/durable_generation_recovery.dart';
import '../../core/ai/durable_generation_runner.dart';
import '../../core/ai/memory_extractor.dart';
import '../../core/database/app_database.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/desire/proactive_engine.dart';
import '../../core/maintenance/recovery_orchestrator.dart';
import '../../core/models/generation_job.dart';
import '../../core/models/maintenance_run.dart';
import '../../core/models/perception_snapshot.dart';
import '../../core/perception/perception_engine.dart';
import '../../core/platform/android_bridge.dart';

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> with WidgetsBindingObserver {
  final android = AndroidBridge.instance;
  final db = AppDatabase.instance;
  late final DesireEngine desire = DesireEngine(db);
  late final DeepSeekClient client = DeepSeekClient();
  late final PerceptionEngine perception = PerceptionEngine(
    db: db,
    android: android,
    desire: desire,
  );
  late final MemoryExtractor memoryExtractor = MemoryExtractor(
    db: db,
    client: client,
    desireEngine: desire,
  );
  late final ProactiveEngine proactive = ProactiveEngine(
    db: db,
    desireEngine: desire,
    ai: client,
    android: android,
  );
  late final DurableGenerationRunner generationRunner = DurableGenerationRunner(
    db: db,
    client: client,
  );
  late final DurableGenerationRecovery generationRecovery =
      DurableGenerationRecovery(db: db, runner: generationRunner);
  late final RecoveryOrchestrator recovery = RecoveryOrchestrator(
    db: db,
    generationRecovery: generationRecovery,
    memoryExtractor: memoryExtractor,
    proactive: proactive,
  );

  CapabilityStatus? status;
  List<UsageEventInfo> usage = const [];
  List<PerceptionSnapshot> perceptions = const [];
  MaintenanceRun? maintenanceRun;
  Map<String, int> postTurnJobs = const {};
  GenerationJob? generationJob;
  GenerationJob? failedGenerationJob;
  String generationRecoveryError = '';
  int backgroundErrorCount = 0;
  String backgroundError = '';
  String maintenanceError = '';
  String orchestratorState = 'never';
  String orchestratorWakeReason = '';
  String orchestratorError = '';
  int orchestratorCycles = 0;
  DateTime? orchestratorLastCompleted;
  DateTime? orchestratorNextWake;
  DateTime? orchestratorNextHeartbeat;
  bool busy = false;
  String? note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    client.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<DateTime?> _readSettingDate(String key) async {
    final raw = int.tryParse(await db.getSetting(key) ?? '') ?? 0;
    return raw <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> _refresh({bool clearNote = true}) async {
    if (mounted) setState(() => busy = true);
    try {
      await db.ensureReady();
      status = await android.capabilityStatus();
      usage = await android.getRecentUsage(minutes: 60);
      perceptions = await db.recentPerceptionSnapshots(limit: 6);
      maintenanceRun = await db.latestMaintenanceRun();
      postTurnJobs = await db.postTurnJobStats();
      generationJob = await db.blockingGenerationJob();
      failedGenerationJob = await db.failedGenerationNeedingAttention();
      generationRecoveryError =
          await db.getSetting('last_generation_recovery_error') ?? '';
      backgroundErrorCount =
          int.tryParse(await db.getSetting('background_error_count') ?? '') ?? 0;
      backgroundError = await db.getSetting('last_background_error') ?? '';
      maintenanceError =
          await db.getSetting('last_long_running_maintenance_error') ?? '';
      orchestratorState =
          await db.getSetting('recovery_orchestrator_state') ?? 'never';
      orchestratorWakeReason =
          await db.getSetting('recovery_orchestrator_last_wake_reason') ?? '';
      orchestratorError =
          await db.getSetting('recovery_orchestrator_last_error') ?? '';
      orchestratorCycles = int.tryParse(
            await db.getSetting('recovery_orchestrator_cycle_count') ?? '',
          ) ??
          0;
      orchestratorLastCompleted =
          await _readSettingDate('recovery_orchestrator_last_completed_at');
      orchestratorNextWake =
          await _readSettingDate('recovery_orchestrator_next_wake_at');
      orchestratorNextHeartbeat =
          await _readSettingDate('recovery_orchestrator_next_heartbeat_at');
      if (clearNote) note = null;
    } catch (e) {
      note = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _captureNow() async {
    if (!mounted) return;
    setState(() {
      busy = true;
      note = '正在把原始 Android 事件整理成陪伴上下文…';
    });
    try {
      final result = await perception.capture(force: true);
      perceptions = await db.recentPerceptionSnapshots(limit: 6);
      note = result == null ? '没有新的可用感知。' : '已生成一条本地环境摘要。';
    } catch (e) {
      note = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _runRecoveryNow({String reason = 'manual_system_page'}) async {
    if (!mounted) return;
    setState(() {
      busy = true;
      note = '正在运行一次恢复检查…';
    });
    try {
      final result = await recovery.runOnce(
        wakeReason: reason,
        allowProactive: false,
      );
      try {
        await android.wakeBackgroundBrain(reason: '${reason}_followup');
      } catch (_) {}
      note = '恢复检查完成：${result.state}。';
    } catch (e) {
      note = '恢复检查失败：$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await _refresh(clearNote: false);
  }

  Future<void> _retryFailedGeneration() async {
    final job = failedGenerationJob;
    if (job == null || !mounted) return;
    setState(() {
      busy = true;
      note = '正在重新排队上一轮 AI 回复…';
    });
    try {
      final changed = await db.retryFailedGenerationJob(job.id);
      if (!changed) {
        note = '没有重新排队：任务状态已经变化，或当前设备没有写入权限。';
      } else {
        final result = await recovery.runOnce(
          wakeReason: 'manual_generation_retry',
          allowProactive: false,
        );
        try {
          await android.wakeBackgroundBrain(
            reason: 'manual_generation_retry_followup',
          );
        } catch (_) {}
        note = '已重新尝试上一轮回复：${result.state}。';
      }
    } catch (e) {
      note = '重新尝试失败：$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await _refresh(clearNote: false);
  }

  Future<void> _abandonFailedGeneration() async {
    final job = failedGenerationJob;
    if (job == null || !mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('放弃这一轮回复？'),
            content: const Text(
              '用户消息会继续保留在聊天记录中，只是不再要求 AI 为这一轮补生成回复。之后可以继续发送新消息。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认放弃'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      busy = true;
      note = '正在取消失败的回复任务…';
    });
    try {
      final changed = await db.abandonFailedGenerationJob(job.id);
      note = changed ? '已放弃这一轮 AI 回复，可以继续聊天。' : '任务状态已经变化，没有执行取消。';
    } catch (e) {
      note = '取消失败：$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await _refresh(clearNote: false);
  }

  Future<void> _retryFailedPostTurn() async {
    if (!mounted) return;
    setState(() {
      busy = true;
      note = '正在重新排队失败的记忆整理任务…';
    });
    try {
      final count = await db.retryFailedPostTurnJobsManually();
      if (count == 0) {
        note = '没有需要重新排队的记忆整理任务，或当前设备没有写入权限。';
      } else {
        final result = await recovery.runOnce(
          wakeReason: 'manual_post_turn_retry',
          allowProactive: false,
        );
        try {
          await android.wakeBackgroundBrain(
            reason: 'manual_post_turn_retry_followup',
          );
        } catch (_) {}
        note = '已重新排队 $count 个任务，恢复状态：${result.state}。';
      }
    } catch (e) {
      note = '重新整理失败：$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await _refresh(clearNote: false);
  }

  @override
  Widget build(BuildContext context) {
    final s = status;
    final failedPostTurns = postTurnJobs['failed'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Android 感知与悬浮',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: busy ? null : () => _refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('第一次综合真机验收'),
            subtitle: const Text('按顺序验证 TTS、权限/感知、后台/悬浮和手机↔平板顶号'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pushNamed('/checkpoint'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('真机测试前自检'),
            subtitle: const Text('一次检查权限、后台、Active Brain、Nearby 与本地 TTS；可导出脱敏报告'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pushNamed('/preflight'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.pets_outlined),
            title: const Text('桌宠播放器预览'),
            subtitle: const Text('D1 隔离测试：只预览皮肤和动作，不改变当前悬浮球'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: busy
                ? null
                : () async {
                    try {
                      await android.openDesktopPetPreview();
                    } catch (e) {
                      if (mounted) setState(() => note = '桌宠预览打开失败：$e');
                    }
                  },
          ),
        ),
        const SizedBox(height: 8),
        _PermissionTile(
          title: '显示在其他应用上层',
          enabled: s?.overlay ?? false,
          onTap: android.openOverlaySettings,
        ),
        _PermissionTile(
          title: 'App 使用情况访问',
          enabled: s?.usage ?? false,
          onTap: android.openUsageSettings,
        ),
        _PermissionTile(
          title: 'Accessibility 轻视觉',
          enabled: s?.accessibility ?? false,
          onTap: android.openAccessibilitySettings,
        ),
        _PermissionTile(
          title: '通知访问',
          enabled: s?.notificationListener ?? false,
          onTap: android.openNotificationListenerSettings,
        ),
        _PermissionTile(
          title: '发送通知',
          enabled: s?.postNotifications ?? false,
          onTap: () async {
            await android.requestNotificationPermission();
            await _refresh();
          },
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Android 生命周期状态',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '悬浮陪伴：${s?.overlayUserEnabled == true ? '用户已开启' : '用户未开启'} · '
                  '${s?.overlayRunning == true ? '服务运行中' : '服务未运行'} · '
                  '${s?.overlayVisible == true ? '悬浮层可见' : '悬浮层当前不可见'} · '
                  '${s?.overlayChatExpanded == true ? '聊天已展开' : '悬浮球模式'}',
                ),
                Text(
                  '后台大脑：${s?.backgroundBrainReady == true ? 'Engine 已就绪' : 'Engine 未就绪'}',
                ),
                const SizedBox(height: 4),
                Text(
                  '通知监听：${s?.notificationListener == true ? '已授权' : '未授权'} / '
                  '${s?.notificationListenerConnected == true ? '已连接' : '未连接'}',
                ),
                Text(
                  '轻视觉：${s?.accessibility == true ? '已授权' : '未授权'} / '
                  '${s?.accessibilityConnected == true ? '已连接' : '未连接'}',
                ),
                if (s?.accessibility == true &&
                    s?.accessibilityConnected != true)
                  const Text(
                    '轻视觉已授权但未连接：请进入无障碍设置重新开关，并保存脱敏诊断。',
                  ),
                if ((s?.accessibilityLastReason ?? '').isNotEmpty)
                  Text(
                    '轻视觉最近状态：${s!.accessibilityLastReason}'
                    '${s.accessibilityLastDisconnectedAt == null ? '' : ' · ${s.accessibilityLastDisconnectedAt!.toLocal()}'}',
                  ),
                Text(
                  '设备：${s?.screenInteractive == true ? '屏幕亮' : '屏幕灭'} · '
                  '${s?.deviceLocked == true ? '已锁定' : '已解锁'} · '
                  '${s?.appVisible == true ? 'App 可见' : 'App 后台'}',
                ),
                if (s?.lastServiceStart != null)
                  Text('最近服务启动：${s!.lastServiceStart!.toLocal()}'),
                if ((s?.lastServiceReason ?? '').isNotEmpty)
                  Text('最近服务状态原因：${s!.lastServiceReason}'),
              ],
            ),
          ),
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: s?.overlay == true
                    ? () async {
                        await android.startOverlay();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 250),
                        );
                        await _refresh();
                      }
                    : null,
                icon: const Icon(Icons.bubble_chart),
                label: const Text('开启悬浮球'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await android.stopOverlay();
                  await Future<void>.delayed(
                    const Duration(milliseconds: 150),
                  );
                  await _refresh();
                },
                icon: const Icon(Icons.close),
                label: const Text('关闭悬浮球'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: busy ? null : _captureNow,
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Text('立即整理一次环境感知'),
        ),
        const SizedBox(height: 20),
        Text('长期运行诊断', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('恢复调度器：$orchestratorState · cycle=$orchestratorCycles'),
                if (orchestratorLastCompleted != null)
                  Text('最近完成：${orchestratorLastCompleted!.toLocal()}'),
                if (orchestratorNextWake != null)
                  Text('预计下次恢复检查：${orchestratorNextWake!.toLocal()}'),
                if (orchestratorNextHeartbeat != null)
                  Text('预计下次内在心跳：${orchestratorNextHeartbeat!.toLocal()}'),
                if (orchestratorWakeReason.isNotEmpty)
                  Text('最近唤醒原因：$orchestratorWakeReason'),
                if (orchestratorError.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('调度器错误：$orchestratorError'),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : () => _runRecoveryNow(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('立即运行一次恢复检查'),
                  ),
                ),
                const Divider(height: 24),
                Text(
                  '记忆整理队列：pending=${postTurnJobs['pending'] ?? 0} · '
                  'running=${postTurnJobs['running'] ?? 0} · '
                  'retry=${postTurnJobs['retry_wait'] ?? 0} · failed=$failedPostTurns',
                ),
                if (failedPostTurns > 0) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _retryFailedPostTurn,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试失败的记忆整理'),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  generationJob == null
                      ? 'AI 回复恢复任务：无正在等待的任务'
                      : 'AI 回复恢复任务：${generationJob!.status} · '
                          'attempt=${generationJob!.attempts} · '
                          'reason=${generationJob!.resumeReason.isEmpty ? 'normal' : generationJob!.resumeReason}',
                ),
                if (generationJob?.nextRetryAt != null)
                  Text('回复下次重试：${generationJob!.nextRetryAt!.toLocal()}'),
                if (generationRecoveryError.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('最近回复恢复错误：$generationRecoveryError'),
                ],
                if (failedGenerationJob != null) ...[
                  const Divider(height: 24),
                  Text(
                    '上一轮 AI 回复需要人工处理',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'attempt=${failedGenerationJob!.attempts} · model=${failedGenerationJob!.model}',
                  ),
                  if (failedGenerationJob!.lastError.isNotEmpty)
                    Text('原因：${failedGenerationJob!.lastError}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : _retryFailedGeneration,
                        icon: const Icon(Icons.replay),
                        label: const Text('重新尝试这轮回复'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _abandonFailedGeneration,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('放弃这轮回复'),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                Text('后台错误累计：$backgroundErrorCount'),
                if (backgroundError.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('最近后台错误：$backgroundError'),
                ],
                if (maintenanceRun != null) ...[
                  const SizedBox(height: 8),
                  Text('最近长期清理：${maintenanceRun!.completedAt.toLocal()}'),
                  Text(
                    '退休话题 ${maintenanceRun!.retiredThreads} · '
                    '生命周期 ${maintenanceRun!.prunedLifecycle} · '
                    '感知 ${maintenanceRun!.prunedPerceptions} · '
                    '设备事件 ${maintenanceRun!.prunedDeviceEvents}',
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text('长期清理尚未运行。'),
                ],
                if (maintenanceError.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('最近清理错误：$maintenanceError'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('AI 最近获得的环境摘要', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (perceptions.isEmpty)
          const Text('暂无。后台心跳和聊天前都会尝试把原始事件整理成少量本地摘要。')
        else
          ...perceptions.map(
            (p) => Card(
              child: ListTile(
                title: Text(p.summary),
                subtitle: Text(
                  '${p.occurredAt.toLocal()} · busy=${p.busyScore.toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text('最近 1 小时 App 前台原始事件', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (usage.isEmpty)
          const Text('暂无。未授权 Usage Access 时这里会为空。')
        else
          ...usage.reversed.take(20).map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.packageName),
              subtitle: Text('${e.timestamp.toLocal()} · ${e.eventType}'),
            ),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              note!,
              style: TextStyle(
                color: note!.startsWith('已') || note!.startsWith('正在')
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        enabled ? Icons.check_circle : Icons.radio_button_unchecked,
        color: enabled ? Colors.green : null,
      ),
      title: Text(title),
      subtitle: Text(enabled ? '已授权' : '未授权'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
