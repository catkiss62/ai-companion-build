import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/mcp/cedar_toy_activity.dart';
import '../../core/platform/android_bridge.dart';

/// Optional presentation shell for Cedar Toy activity state. The MCP runner
/// and durable session do not depend on this widget, so the experiment can be
/// removed without changing game behavior or saved progress.
class CedarToyActivityWindow extends StatefulWidget {
  const CedarToyActivityWindow({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<CedarToyActivityWindow> createState() =>
      _CedarToyActivityWindowState();
}

class _CedarToyActivityWindowState extends State<CedarToyActivityWindow> {
  final store = CedarToyActivityStore(AppDatabase.instance);
  Timer? _refreshTimer;
  CedarToyActivityState? _state;
  CedarGameSession? _session;
  String _viewingGameId = '';
  bool _loading = true;
  bool _minimized = false;
  Offset _offset = const Offset(16, 72);
  double _width = 350;
  double _height = 430;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = await store.loadState();
    final selected = state.sessions[_viewingGameId] ?? state.activeSession;
    if (!mounted) return;
    setState(() {
      _state = state;
      _session = selected;
      _viewingGameId = selected?.gameId ?? '';
      _loading = false;
    });
  }

  Future<void> _togglePaused(CedarGameSession session) async {
    if (session.phase == CedarActivityPhase.paused) {
      await store.resume();
    } else {
      await store.pause();
    }
    await _refresh();
  }

  void _move(DragUpdateDetails details, Size area) {
    final height = _minimized ? 58.0 : _height;
    setState(() {
      _offset = Offset(
        (_offset.dx + details.delta.dx)
            .clamp(0.0, (area.width - _width).clamp(0.0, area.width))
            .toDouble(),
        (_offset.dy + details.delta.dy)
            .clamp(0.0, (area.height - height).clamp(0.0, area.height))
            .toDouble(),
      );
    });
  }

  void _resize(DragUpdateDetails details, Size area) {
    setState(() {
      _width = (_width + details.delta.dx)
          .clamp(270.0, (area.width - _offset.dx).clamp(270.0, 520.0))
          .toDouble();
      _height = (_height + details.delta.dy)
          .clamp(260.0, (area.height - _offset.dy).clamp(260.0, 680.0))
          .toDouble();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final area = constraints.biggest;
          _width = _width
              .clamp(270.0, area.width.clamp(270.0, 520.0))
              .toDouble();
          _height = _height
              .clamp(260.0, area.height.clamp(260.0, 680.0))
              .toDouble();
          final visibleHeight = _minimized ? 58.0 : _height;
          final safeOffset = Offset(
            _offset.dx
                .clamp(0.0, (area.width - _width).clamp(0.0, area.width))
                .toDouble(),
            _offset.dy
                .clamp(0.0, (area.height - visibleHeight).clamp(0.0, area.height))
                .toDouble(),
          );
          _offset = safeOffset;
          return Stack(
            children: [
              Positioned(
                left: safeOffset.dx,
                top: safeOffset.dy,
                width: _width,
                height: visibleHeight,
                child: Material(
                  elevation: 20,
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) => _move(details, area),
                        child: SizedBox(
                          height: 58,
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.sports_esports_rounded),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _session == null
                                      ? 'Cedar Toy 游戏厅'
                                      : _session!.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: _minimized ? '展开' : '最小化',
                                onPressed: () =>
                                    setState(() => _minimized = !_minimized),
                                icon: Icon(_minimized
                                    ? Icons.open_in_full_rounded
                                    : Icons.minimize_rounded),
                              ),
                              IconButton(
                                tooltip: '关闭活动窗',
                                onPressed: widget.onClose,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_minimized) ...[
                        const Divider(height: 1),
                        Expanded(child: _body(context)),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (details) => _resize(details, area),
                            child: const SizedBox(
                              width: 42,
                              height: 32,
                              child: Icon(Icons.drag_handle_rounded, size: 21),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final session = _session;
    final state = _state;
    if (session == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '还没有正在进行的游戏。\n在聊天里说“去游戏厅看看”就可以开始。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      children: [
        if (state != null && state.sessions.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in state.sessions.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      selected: item.gameId == session.gameId,
                      label: Text(item.displayName),
                      onSelected: (_) => setState(() {
                        _viewingGameId = item.gameId;
                        _session = item;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (state?.execution != null) ...[
          Card(
            child: ListTile(
              leading: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              title: Text('正在执行 ${state!.execution!.action}'),
              subtitle: Text(state!.execution!.gameId),
            ),
          ),
        ],
        if (state?.queuedSwitches.isNotEmpty == true) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: Text('接下来切换到 ${state!.queuedSwitches.first.targetGameId}'),
              subtitle: const Text('当前原子动作完成后读取目标游戏指南'),
            ),
          ),
        ],
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            Chip(label: Text(session.phase.label)),
            Chip(label: Text(session.mode.label)),
            if (session.nextActor == 'user' || session.nextActor == 'shared')
              const Chip(
                avatar: Icon(Icons.person_rounded, size: 17),
                label: Text('轮到你'),
              ),
          ],
        ),
        if (session.waitingReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(session.waitingReason),
        ],
        if (session.lastOutcome.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('最近进展', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          SelectableText(
            session.lastOutcome,
            maxLines: 12,
          ),
        ],
        if (session.events.isNotEmpty &&
            session.events.last.imageData.isNotEmpty) ...[
          const SizedBox(height: 10),
          _activityImage(session.events.last.imageData),
        ],
        if (session.viewerUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => AndroidBridge.instance
                .openExternalHttpsUrl(session.viewerUrl),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('打开游戏返回的查看页'),
          ),
        ],
        if (state?.activeGameId == session.gameId &&
            session.phase.continuable &&
            session.phase != CedarActivityPhase.awaitingInvitation &&
            session.phase != CedarActivityPhase.waitingUser) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _togglePaused(session),
            icon: Icon(session.phase == CedarActivityPhase.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded),
            label: Text(session.phase == CedarActivityPhase.paused
                ? '继续游戏活动'
                : '暂停自主游戏'),
          ),
        ],
        if (session.events.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('活动记录', style: Theme.of(context).textTheme.labelLarge),
          for (final event in session.events.reversed.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                event.contentKinds.contains('image')
                    ? Icons.image_rounded
                    : Icons.bolt_rounded,
                size: 19,
              ),
              title: Text(event.summary, maxLines: 3),
              subtitle: event.action.isEmpty ? null : Text(event.action),
            ),
        ],
        if (state?.notices.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text('跨游戏提醒', style: Theme.of(context).textTheme.labelLarge),
          for (final notice in state!.notices.reversed.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined, size: 19),
              title: Text('${notice.sourceGameId} → ${notice.targetGameId}'),
              subtitle: Text('建议动作：${notice.suggestedAction}'),
            ),
        ],
      ],
    );
  }

  Widget _activityImage(String data) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(data),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
