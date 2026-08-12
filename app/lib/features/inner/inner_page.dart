import 'package:flutter/material.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/database/app_database.dart';
import '../../core/grounding/grounding_engine.dart';
import '../../core/grounding/grounding_snapshot.dart';
import '../../core/self/ai_self_reflection_engine.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/desire/proactive_engine.dart';
import '../../core/desire/self_drive_engine.dart';
import '../../core/desire/thought_lifecycle_engine.dart';
import '../../core/desire/thought_consolidation_engine.dart';
import '../../core/desire/proactive_rhythm_engine.dart';
import '../../core/models/conversation_summary.dart';
import '../../core/models/desire_state.dart';
import '../../core/models/thought.dart';
import '../../core/models/thought_lifecycle_event.dart';
import '../../core/models/relationship_event.dart';
import '../../core/models/unfinished_thread.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/memory/memory_maintenance_engine.dart';
import '../../core/relationship/relationship_assimilator.dart';
import '../memory/memory_page.dart';
import '../relationship/relationship_page.dart';
import '../reference/reference_library_page.dart';
import '../settings/rule_layers_page.dart';

class InnerPage extends StatefulWidget {
  const InnerPage({super.key});

  @override
  State<InnerPage> createState() => _InnerPageState();
}

class _InnerPageState extends State<InnerPage> {
  final db = AppDatabase.instance;
  late final DesireEngine desire = DesireEngine(db);
  late final SelfDriveEngine selfDrive = SelfDriveEngine(db: db, desire: desire);
  late final ThoughtLifecycleEngine thoughtLifecycle = ThoughtLifecycleEngine(db: db);
  late final ThoughtConsolidationEngine thoughtConsolidation = ThoughtConsolidationEngine(db);
  late final ProactiveRhythmEngine proactiveRhythm = ProactiveRhythmEngine(db: db, lifecycle: thoughtLifecycle);
  late final MemoryMaintenanceEngine memoryMaintenance = MemoryMaintenanceEngine(db);
  late final RelationshipAssimilator relationshipAssimilator =
      RelationshipAssimilator(db: db);
  DesireSnapshot? snapshot;
  GroundingSnapshot? grounding;
  List<DesireIntent> desireCandidates = const [];
  List<CompanionThought> thoughts = const [];
  List<UnfinishedThread> threads = const [];
  List<ConversationSummary> summaries = const [];
  List<ThoughtLifecycleEvent> lifecycleEvents = const [];
  List<RelationshipEvent> relationshipEvents = const [];
  ProactiveRhythmProfile rhythmProfile = ProactiveRhythmProfile.neutral();
  Map<String, int> stats = const {};
  bool busy = false;
  String? result;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    snapshot = await db.loadDesire();
    grounding = await GroundingEngine(db).capture();
    thoughts = await db.activeThoughts(limit: 30);
    desireCandidates = desire.previewCandidates(snapshot!, thoughts).take(4).toList();
    threads = await db.activeUnfinishedThreads(limit: 10);
    summaries = await db.recentConversationSummaries(limit: 3);
    lifecycleEvents = await db.recentThoughtLifecycleEvents(limit: 12);
    relationshipEvents = await db.recentRelationshipEvents(limit: 10);
    rhythmProfile = await proactiveRhythm.profile();
    stats = await db.memoryStats();
    if (mounted) setState(() {});
  }

  Future<void> _tick() async {
    setState(() => busy = true);
    await desire.tick();
    await _refresh();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _selfDrive() async {
    setState(() {
      busy = true;
      result = '正在从本地记忆/未完成话题形成一次自发念头…';
    });
    final created = await selfDrive.maybeGenerate(forceForDebug: true);
    result = created ? '已形成一条本地自发念头。' : '当前没有足够资料形成自发念头。';
    await _refresh();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _selfReflect() async {
    setState(() {
      busy = true;
      result = '正在用真实长期历史做一次 AI Self 整理…';
    });
    final ai = DeepSeekClient();
    try {
      final reflected = await AiSelfReflectionEngine(
        db: db,
        client: ai,
        desire: desire,
      ).maybeReflect(force: true);
      result = reflected ? '已形成/强化 AI Self。' : '这次没有足够证据形成新的 AI Self。';
    } catch (e) {
      result = e.toString();
    } finally {
      ai.close();
      await _refresh();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _maintainMemory() async {
    setState(() {
      busy = true;
      result = '正在执行一次本地记忆淡化/归档检查…';
    });
    final r = await memoryMaintenance.maybeRun(force: true);
    result = '检查 ${r.checked} 条 · 自动归档 ${r.archived} 条 · 平均保留度 ${r.averageRetention.toStringAsFixed(2)}';
    await _refresh();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _assimilateRelationship() async {
    setState(() {
      busy = true;
      result = '正在把尚未内化的关系事件转成 Thought/Desire…';
    });
    final count = await relationshipAssimilator.assimilatePending();
    result = '本次内化 $count 个关系事件。';
    await _refresh();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _advanceThoughtLifecycle() async {
    setState(() {
      busy = true;
      result = '正在推进 Thought 生命周期…';
    });
    await thoughtLifecycle.advance(forceForDebug: true);
    await _refresh();
    if (mounted) {
      setState(() {
        busy = false;
        result = 'Thought 生命周期已推进一次。';
      });
    }
  }

  Future<void> _consolidateThoughts() async {
    setState(() {
      busy = true;
      result = '正在执行 Thought 长期去重…';
    });
    final r = await thoughtConsolidation.maybeRun(force: true);
    await _refresh();
    if (mounted) {
      setState(() {
        busy = false;
        result = '扫描 ${r.scanned} 条 Thought，合并 ${r.merged} 条重复/同主题记录。';
      });
    }
  }

  Future<void> _testProactive() async {
    setState(() {
      busy = true;
      result = '正在让她进行一次主动联系判断…';
    });
    final ai = DeepSeekClient();
    try {
      final decision = await ProactiveEngine(
        db: db,
        desireEngine: desire,
        ai: ai,
        android: AndroidBridge.instance,
      ).evaluate(forceForDebug: true);
      result = decision.sent
          ? '已主动发送：${decision.message?.content}\n类型=${decision.intentKind?.zhLabel ?? '未知'} · 投递=${decision.deliveryStyle?.zhLabel ?? '未知'} · Gate=${decision.gateScore.toStringAsFixed(2)}'
          : '没有发送：${decision.reason}\nGate=${decision.gateScore.toStringAsFixed(2)}';
    } catch (e) {
      result = e.toString();
    } finally {
      ai.close();
      await _refresh();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('她的内心 · v0.31.1 Grounded Desire Core', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('当前保留数值与数据库状态方便调试；正式视觉层以后可以隐藏这些工程细节。'),
        const SizedBox(height: 16),
        ...DriveKey.values.map((drive) {
          final value = s.drives[drive] ?? 0;
          final baseline = s.baselines[drive] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(drive.zhLabel)),
                Expanded(child: LinearProgressIndicator(value: value)),
                const SizedBox(width: 8),
                SizedBox(width: 74, child: Text('${value.toStringAsFixed(2)} / ${baseline.toStringAsFixed(2)}')),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        Text('当前意图：${s.lastIntent ?? '暂无'} · 驱动=${s.lastIntentDrive ?? '无'} · 分数=${s.lastIntentScore?.toStringAsFixed(2) ?? '无'}'),
        Text('上次满足：${s.lastSatisfiedAction ?? '暂无'} · ${s.lastSatisfiedAt?.toLocal().toString() ?? '尚未发生'}'),
        Text('上次 wildcard：${s.lastWildcardAt?.toLocal().toString() ?? '尚未发生'}'),
        if (grounding != null) ...[
          const SizedBox(height: 8),
          Text('现实锚点：${grounding!.nowLocal.toString().substring(0, 16)} · ${grounding!.daypart.zhLabel}'),
          Text('对话状态：${grounding!.conversationState} · pending=${grounding!.pendingUserTurn ? '是' : '否'} · 最后用户消息已回答=${grounding!.lastUserAnswered ? '是' : '否'}'),
          Text('用户上次发言后：AI ${grounding!.assistantMessagesSinceLastUser} 条 / 主动 ${grounding!.proactiveMessagesSinceLastUser} 条'),
        ],
        if (desireCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('当前召唤力（前4，仅调试）：'),
          ...desireCandidates.map((candidate) => Text(
                '${candidate.drive.zhLabel} → ${candidate.wantAction} · ${candidate.score.toStringAsFixed(2)} · 来源=${candidate.reasonSource}',
              )),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _tick,
                icon: const Icon(Icons.favorite_border),
                label: const Text('心跳一次'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _selfDrive,
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('自发念头'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : _selfReflect,
          icon: const Icon(Icons.self_improvement),
          label: const Text('整理 AI Self'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _assimilateRelationship,
                icon: const Icon(Icons.favorite),
                label: const Text('内化关系事件'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _maintainMemory,
                icon: const Icon(Icons.hourglass_bottom),
                label: const Text('记忆淡化检查'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _advanceThoughtLifecycle,
                icon: const Icon(Icons.loop),
                label: const Text('推进 Thought 生命周期'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _testProactive,
                icon: const Icon(Icons.notifications_active),
                label: const Text('测试主动找我'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : _consolidateThoughts,
          icon: const Icon(Icons.merge_type),
          label: const Text('Thought 长期去重'),
        ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(result!),
          ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('Memory Brain', style: Theme.of(context).textTheme.titleLarge)),
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MemoryPage()),
                );
                await _refresh();
              },
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('记忆库'),
            ),
          ],
        ),
        Text(
          '长期记忆 ${stats['memories'] ?? 0} · 阶段摘要 ${stats['summaries'] ?? 0} · 近日连续性 ${stats['daily_continuity'] ?? 0} · 未完成 ${stats['threads'] ?? 0} · 念头 ${stats['thoughts'] ?? 0} · 环境摘要 ${stats['perceptions'] ?? 0} · 关系事件 ${stats['relationship_events'] ?? 0} · 参考资料 ${stats['references'] ?? 0}',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RelationshipPage()),
            );
            await _refresh();
          },
          icon: const Icon(Icons.timeline),
          label: const Text('关系连续性 / 临时 Session'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReferenceLibraryPage()),
                  );
                  await _refresh();
                },
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const Text('本地参考资料库'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RuleLayersPage()),
                  );
                  await _refresh();
                },
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('六层行为规则'),
              ),
            ),
          ],
        ),
        if (threads.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('未完成话题', style: Theme.of(context).textTheme.titleMedium),
          ...threads.map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.title),
                subtitle: Text('${t.detail}${t.topicKey.isEmpty ? '' : '\ntopic=${t.topicKey}'}'),
                trailing: Text(t.importance.toStringAsFixed(2)),
              )),
        ],
        if (summaries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('最近阶段摘要', style: Theme.of(context).textTheme.titleMedium),
          ...summaries.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('• ${s.summary}'),
              )),
        ],
        if (relationshipEvents.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Relationship Event 原始诊断', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('这些数值只用于开发诊断，不会显示在日常“你们之间”页面。'),
          ...relationshipEvents.take(8).map((e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.summary),
                subtitle: Text('${e.kind} · valence=${e.valence.toStringAsFixed(2)} · internalized=${e.internalizedAt != null}'),
                trailing: Text(e.intensity.toStringAsFixed(2)),
              )),
        ],
        const Divider(height: 32),
        Text('Thought Pool', style: Theme.of(context).textTheme.titleLarge),
        if (thoughts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('还没有念头。聊天、未完成话题和自我驱动都会逐步产生。'),
          )
        else
          ...thoughts.map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.text),
                subtitle: Text('${t.lifecycleState} · ${t.kind} · ${t.driveKey} · ${t.source} · fed=${t.fedCount} · action=${t.actionCount} · merged=${t.mergedCount} · resurfaced=${t.resurfacedCount}${t.topicKey.isEmpty ? '' : ' · topic=${t.topicKey}'}${t.isSnoozed ? ' · snoozed' : ''}'),
                trailing: Text(t.strength.toStringAsFixed(2)),
              )),
        const Divider(height: 28),
        Text('主动联系节奏学习', style: Theme.of(context).textTheme.titleMedium),
        Text(
          '样本 ${rhythmProfile.sampleCount} · 回应率 ${(rhythmProfile.responseRate * 100).round()}% · 90分钟内回应 ${(rhythmProfile.quickResponseRate * 100).round()}% · 中位回应 ${rhythmProfile.medianLatencyMinutes.round()} 分钟 · 时机修正 ${rhythmProfile.timingAdjustment.toStringAsFixed(3)} · 主题修正 ${rhythmProfile.topicAdjustment.toStringAsFixed(3)} · 总修正 ${rhythmProfile.thresholdAdjustment.toStringAsFixed(3)}',
        ),
        Text(
          '当前节奏情境：${rhythmProfile.currentHourBucket} / ${rhythmProfile.currentActivityContext} · 时间样本权重 ${rhythmProfile.timingSampleWeight.toStringAsFixed(2)} · 活动样本权重 ${rhythmProfile.activitySampleWeight.toStringAsFixed(2)}',
        ),
        if (lifecycleEvents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('最近 Thought 生命周期事件', style: Theme.of(context).textTheme.titleMedium),
          ...lifecycleEvents.take(8).map((e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.eventType),
                subtitle: Text(e.detail),
              )),
        ],
      ],
    );
  }
}
