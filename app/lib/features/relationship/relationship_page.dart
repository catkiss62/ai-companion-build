import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/continuity/daily_continuity_presentation.dart';
import '../../core/models/daily_continuity.dart';
import '../../core/models/interaction_session.dart';
import '../../core/models/unfinished_thread.dart';
import '../../core/relationship/relationship_presentation.dart';
import 'relationship_companion_state.dart';

class RelationshipPage extends StatefulWidget {
  const RelationshipPage({super.key});

  @override
  State<RelationshipPage> createState() => _RelationshipPageState();
}

class _RelationshipPageState extends State<RelationshipPage> {
  final db = AppDatabase.instance;
  late final RelationshipCompanionRepository repository =
      RelationshipCompanionRepository(db);

  RelationshipCompanionSnapshot? snapshot;
  bool loading = true;
  bool refreshing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    if (!silent && mounted) {
      setState(() {
        loading = snapshot == null;
        error = null;
      });
    }
    try {
      final next = await repository.load();
      if (!mounted) return;
      setState(() {
        snapshot = next;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '暂时没能读到你们的关系记录，请稍后再试。';
      });
    } finally {
      refreshing = false;
    }
  }

  Future<void> _endSession() async {
    await db.applyInteractionSessionUpdate(action: 'end');
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (loading && snapshot == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('你们之间')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _IntroCard(
              line: data?.continuityLine ?? '这里保存的是你们真正发生过的事情。',
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (data != null) ...[
              if (data.dailyContinuity.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(
                  title: '最近几天',
                  subtitle: '这是从真实记录压缩出的短期连续性，不是每天自动写一篇日记。',
                ),
                const SizedBox(height: 9),
                _DailyContinuityCard(
                  records: data.dailyContinuity.take(3).toList(),
                  live: data.activeBrain && !data.transferLocked,
                ),
              ],
              if (data.currentCares.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(
                  title: data.activeBrain && !data.transferLocked
                      ? '她现在还放在心上的'
                      : '上次同步时她还放在心上的',
                  subtitle: '这些来自她仍然活跃的长期念头，不是固定性格标签。',
                ),
                const SizedBox(height: 9),
                ...data.currentCares.map(
                  (care) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _CareCard(care: care),
                  ),
                ),
              ],
              if (data.activeSession != null) ...[
                const SizedBox(height: 11),
                _SectionHeader(
                  title: '你们正在继续',
                  subtitle: '临时互动只影响当前场景，不会覆盖现实里的她。',
                ),
                const SizedBox(height: 9),
                _SessionCard(
                  session: data.activeSession!,
                  onEnd: _endSession,
                ),
              ],
              if (data.unfinishedThreads.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(
                  title: '还没说完的事',
                  subtitle: '她以后可以自然把这些话题重新接起来。',
                ),
                const SizedBox(height: 9),
                _ThreadsCard(threads: data.unfinishedThreads.take(4).toList()),
              ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: '共同经历',
                subtitle: '只留下值得长期记住的片段，普通寒暄不会被硬凑成关系节点。',
              ),
              const SizedBox(height: 9),
              if (data.sharedMoments.isEmpty)
                const _EmptyHistoryCard()
              else
                _MomentsTimeline(moments: data.sharedMoments),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer.withAlpha(64),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text('不是好感度', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(line, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 7),
            Text(
              '她对你的了解来自本地保存的共同经历、长期记忆、仍在意的事情和现实时间里的持续相处。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _DailyContinuityCard extends StatelessWidget {
  const _DailyContinuityCard({
    required this.records,
    required this.live,
  });

  final List<DailyContinuityRecord> records;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        child: Column(
          children: [
            for (var i = 0; i < records.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      records[i].quietDay
                          ? Icons.nightlight_outlined
                          : Icons.timeline_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DailyContinuityPresentation.dayLabel(records[i]),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              if (i == 0 && !live)
                                Text(
                                  '上次同步',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                )
                              else if (records[i].isFinalized)
                                Text(
                                  '已整理',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            DailyContinuityPresentation.compactSummary(records[i]),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.48),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i != records.length - 1) const Divider(height: 1, indent: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareCard extends StatelessWidget {
  const _CareCard({required this.care});

  final CompanionCareView care;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(care.label, style: Theme.of(context).textTheme.labelLarge),
                ),
                Text(
                  _relativeTime(care.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(care.text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onEnd});

  final InteractionSession session;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${RelationshipPresentation.sessionKindLabel(session.kind)} · ${session.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (session.premise.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(session.premise, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
            ],
            if (session.boundaries.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '你们约好的边界：${session.boundaries.join('；')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
            if (session.continuityNote.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                session.continuityNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 11),
            FilledButton.tonalIcon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('结束这段临时互动'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadsCard extends StatelessWidget {
  const _ThreadsCard({required this.threads});

  final List<UnfinishedThread> threads;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < threads.length; i++) ...[
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: Text(threads[i].title),
              subtitle: threads[i].detail.trim().isEmpty
                  ? null
                  : Text(
                      threads[i].detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (i != threads.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MomentsTimeline extends StatelessWidget {
  const _MomentsTimeline({required this.moments});

  final List<RelationshipMomentView> moments;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: Column(
          children: [
            for (var i = 0; i < moments.length; i++)
              _MomentRow(
                moment: moments[i],
                showDivider: i != moments.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.moment, required this.showDivider});

  final RelationshipMomentView moment;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            moment.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          _dateLabel(moment.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      moment.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.48),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 19),
      ],
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Text('还没有需要长期留下的共同经历。你们可以从普通聊天开始，重要的事情会慢慢积累。'),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inSeconds < 45) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return _dateLabel(time);
}

String _dateLabel(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '今天';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return '昨天';
  }
  if (local.year == now.year) return '${local.month}月${local.day}日';
  return '${local.year}年${local.month}月${local.day}日';
}
