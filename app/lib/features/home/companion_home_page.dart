import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/continuity/daily_continuity_presentation.dart';
import '../../core/models/interaction_session.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/relationship/relationship_presentation.dart';
import '../relationship/relationship_page.dart';
import 'companion_home_state.dart';

class CompanionHomePage extends StatefulWidget {
  const CompanionHomePage({
    super.key,
    required this.onOpenChat,
  });

  final VoidCallback onOpenChat;

  @override
  State<CompanionHomePage> createState() => _CompanionHomePageState();
}

class _CompanionHomePageState extends State<CompanionHomePage>
    with WidgetsBindingObserver {
  late final CompanionHomeRepository repository =
      CompanionHomeRepository(AppDatabase.instance);

  CompanionHomeSnapshot? snapshot;
  Timer? refreshTimer;
  bool loading = true;
  bool refreshing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_refresh(silent: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '暂时没能刷新她的状态，请下拉再试。';
      });
    } finally {
      refreshing = false;
    }
  }

  Future<void> _openTransfer() async {
    await Navigator.of(context).pushNamed('/transfer');
    if (mounted) await _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (loading && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = snapshot;
    final care = data?.currentCare;
    final continuity = data?.recentContinuity;
    final relationshipMoment = data?.recentRelationshipMoment;
    final proactive = data?.latestProactiveMessage;
    final unfinished = data?.unfinishedThread;
    final session = data?.activeSession;
    final perception = data?.latestPerception;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _Header(data: data),
          const SizedBox(height: 18),
          if (data != null)
            _PresenceCard(
              data: data,
              onOpenTransfer: _openTransfer,
            ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.onOpenChat,
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text('去找她'),
            ),
          ),
          if (care != null) ...[
            const SizedBox(height: 18),
            _HomeSection(
              eyebrow: care.label,
              icon: Icons.auto_awesome_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RelationshipPage()),
              ),
              child: Text(
                care.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ],
          if (continuity != null) ...[
            const SizedBox(height: 12),
            _HomeSection(
              eyebrow: data?.activeBrain == true && data?.transferLocked != true
                  ? '${DailyContinuityPresentation.dayLabel(continuity)}还在延续'
                  : '上次同步留下的连续性',
              icon: Icons.timeline_rounded,
              trailing: continuity.isFinalized
                  ? const Text('已整理')
                  : const Text('今天'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RelationshipPage()),
              ),
              child: Text(
                DailyContinuityPresentation.compactSummary(continuity),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ],
          if (relationshipMoment != null) ...[
            const SizedBox(height: 12),
            _HomeSection(
              eyebrow: '你们最近留下的',
              icon: Icons.favorite_outline_rounded,
              trailing: Text(_relativeTime(relationshipMoment.createdAt)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RelationshipPage()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relationshipMoment.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    relationshipMoment.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          if (proactive != null) ...[
            const SizedBox(height: 12),
            _HomeSection(
              eyebrow: '最近她主动来找你',
              icon: Icons.notifications_active_outlined,
              trailing: Text(_relativeTime(proactive.createdAt)),
              onTap: widget.onOpenChat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proactive.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ProactiveIntentKind.fromKey(
                      proactive.proactiveIntent,
                    ).zhLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
          if (unfinished != null) ...[
            const SizedBox(height: 12),
            _HomeSection(
              eyebrow: '她还记着这件事',
              icon: Icons.bookmark_added_outlined,
              onTap: widget.onOpenChat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unfinished.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unfinished.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: 12),
            _HomeSection(
              eyebrow: '你们正在继续',
              icon: Icons.favorite_border_rounded,
              child: _SessionSummary(session: session),
            ),
          ],
          if (perception != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '她最近一次感知这台设备：${_relativeTime(perception.occurredAt)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final CompanionHomeSnapshot? data;

  @override
  Widget build(BuildContext context) {
    final active = data?.activeBrain == true && data?.transferLocked != true;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.tertiaryContainer,
              ],
            ),
          ),
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('她', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                active ? '和你一起继续今天' : '同一个她，只是现在在另一台设备上',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresenceCard extends StatelessWidget {
  const _PresenceCard({
    required this.data,
    required this.onOpenTransfer,
  });

  final CompanionHomeSnapshot data;
  final VoidCallback onOpenTransfer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = data.transferLocked
        ? Icons.sync_rounded
        : data.activeBrain
            ? Icons.radio_button_checked_rounded
            : Icons.devices_other_rounded;
    return Card(
      margin: EdgeInsets.zero,
      color: data.activeBrain && !data.transferLocked
          ? scheme.primaryContainer.withAlpha(87)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.presenceTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.presenceDetail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (!data.activeBrain || data.transferLocked) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onOpenTransfer,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('设备接管'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.eyebrow,
    required this.icon,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final String eyebrow;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (trailing != null) trailing!,
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final InteractionSession session;

  String get label => RelationshipPresentation.sessionKindLabel(session.kind);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · ${session.title}', style: Theme.of(context).textTheme.titleMedium),
        if (session.premise.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            session.premise,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ],
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inSeconds < 45) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  final local = time.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}
