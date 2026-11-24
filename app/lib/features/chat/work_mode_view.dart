import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/platform/android_bridge.dart';
import 'work_conversation.dart';

class WhaleTail extends StatelessWidget {
  const WhaleTail({super.key, this.phase, this.size = 30});
  final WorkPhase? phase;
  final double size;
  @override
  Widget build(BuildContext context) {
    final motion = MediaQuery.disableAnimationsOf(context) ? null : phase;
    final asset = switch (motion) {
      null => 'idle.png',
      WorkPhase.idle => 'official.webp',
      WorkPhase.planning => 'wag.webp',
      WorkPhase.tool => 'twist.webp',
      WorkPhase.composing => 'sway.webp',
    };
    return Image.asset(
      'assets/work_mode/$asset',
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.primary,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}

class WorkOrb extends StatefulWidget {
  const WorkOrb({
    super.key,
    required this.phase,
    required this.open,
    required this.toggle,
  });
  final WorkPhase phase;
  final bool open;
  final VoidCallback toggle;
  @override
  State<WorkOrb> createState() => _WorkOrbState();
}

class _WorkOrbState extends State<WorkOrb> {
  Alignment alignment = const Alignment(1, -.25);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const size = 48.0;
      final width = box.maxWidth - size, height = box.maxHeight - size;
      return Align(
        alignment: alignment,
        child: GestureDetector(
          onPanUpdate: (event) {
            if (width <= 0 || height <= 0) return;
            setState(
              () => alignment = Alignment(
                (alignment.x + 2 * event.delta.dx / width)
                    .clamp(-1, 1)
                    .toDouble(),
                (alignment.y + 2 * event.delta.dy / height)
                    .clamp(-1, 1)
                    .toDouble(),
              ),
            );
          },
          onPanEnd: (_) => setState(
            () => alignment = Alignment(alignment.x < 0 ? -1 : 1, alignment.y),
          ),
          child: Material(
            shape: const CircleBorder(),
            elevation: 3,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: IconButton(
              tooltip: widget.open ? '收起工作窗口' : '打开工作窗口',
              onPressed: widget.toggle,
              icon: WhaleTail(phase: widget.phase),
            ),
          ),
        ),
      );
    },
  );
}

class WorkPanel extends StatefulWidget {
  const WorkPanel({
    super.key,
    required this.work,
    required this.input,
    required this.onClose,
    required this.onHistory,
    required this.onNew,
    required this.onSend,
  });
  final WorkConversation work;
  final TextEditingController input;
  final VoidCallback onClose, onHistory, onNew, onSend;
  @override
  State<WorkPanel> createState() => _WorkPanelState();
}

class _WorkPanelState extends State<WorkPanel> {
  final scroll = ScrollController();
  bool following = true;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work, colors = Theme.of(context).colorScheme;
    final rows = [
      ...work.turns,
      if (work.goal.isNotEmpty)
        {
          'goal': work.goal,
          'answer': work.answer,
          'steps': work.steps,
          'status': work.status,
        },
    ];
    if (following)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients && following)
          scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: colors.surface.withValues(alpha: .80),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回聊天',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      '工作模式',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '新对话',
                    onPressed: work.busy ? null : widget.onNew,
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                  IconButton(
                    tooltip: '工作区',
                    onPressed: widget.onHistory,
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) {
                    if (n.dragDetails != null)
                      following = n.metrics.extentAfter < 48;
                    return false;
                  },
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      final steps =
                          (r['steps'] as List?)?.whereType<String>().toList() ??
                          [];
                      final answer = r['answer'] as String? ?? '';
                      final status =
                          r['status'] as String? ??
                          (r['state'] == 'stopped' ? '已停止' : '本轮尚未交付');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SelectableText(r['goal'] as String),
                              ),
                            ),
                            if (steps.isNotEmpty)
                              ExpansionTile(
                                key: PageStorageKey(
                                  'work-$index-${r['id'] ?? r['goal']}',
                                ),
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  answer.isEmpty ? steps.last : '工作过程',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText(steps.join('\n')),
                                  ),
                                ],
                              ),
                            if (answer.isNotEmpty)
                              _WorkText(answer)
                            else if (steps.isEmpty || steps.last != status)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(status),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.input,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '交给小鲸鱼做什么？',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: work.busy ? '停止任务' : '发送工作消息',
                        onPressed: work.busy ? work.stop : widget.onSend,
                        icon: Icon(
                          work.busy ? Icons.stop_rounded : Icons.send_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkText extends StatelessWidget {
  const _WorkText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = <String>{};
    bool code = false;
    final lines = <InlineSpan>[];
    final inline = RegExp(
      r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\((https?://[^\s)]+)\)|(https?://[^\s<>）)]+)',
    );
    for (final line in text.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        code = !code;
        continue;
      }
      if (code) {
        lines.add(
          TextSpan(
            text: '$line\n',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        );
        continue;
      }
      final heading = RegExp(r'^#{1,6}\s+').firstMatch(line);
      final value = line
          .substring(heading?.end ?? 0)
          .replaceFirst(RegExp(r'^[-*] '), '• ');
      int start = 0;
      final spans = <InlineSpan>[];
      for (final m in inline.allMatches(value)) {
        spans.add(TextSpan(text: value.substring(start, m.start)));
        final link = m[4] ?? m[5];
        if (link != null) links.add(link);
        spans.add(
          TextSpan(
            text: m[1] ?? m[2] ?? m[3] ?? link,
            style: TextStyle(
              fontWeight: m[1] != null ? FontWeight.bold : null,
              fontFamily: m[2] != null ? 'monospace' : null,
            ),
          ),
        );
        start = m.end;
      }
      spans.add(TextSpan(text: '${value.substring(start)}\n'));
      lines.add(
        TextSpan(
          children: spans,
          style: heading == null ? null : theme.textTheme.titleMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(children: lines),
          style: theme.textTheme.bodyLarge,
        ),
        for (final url in links)
          TextButton.icon(
            onPressed: () => AndroidBridge.instance.openExternalHttpsUrl(url),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
