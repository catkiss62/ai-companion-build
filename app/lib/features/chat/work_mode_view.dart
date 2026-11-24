import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'work_markdown.dart';
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

class WorkHeader extends StatelessWidget {
  const WorkHeader({
    super.key,
    required this.work,
    required this.input,
    required this.close,
    required this.history,
    required this.create,
  });
  final WorkConversation work;
  final TextEditingController input;
  final VoidCallback close, history, create;

  @override
  Widget build(BuildContext context) {
    final title = work.turns.firstOrNull?['goal'] as String? ?? work.goal;
    return ColoredBox(
      color: workSurface,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              tooltip: '返回聊天',
              onPressed: close,
              icon: const Icon(Icons.arrow_back, color: workMuted, size: 20),
            ),
            Expanded(
              child: Text(
                title.isEmpty ? '工作模式' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: workInk,
                  letterSpacing: 0,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: input,
              builder: (_, value, _) => IconButton(
                tooltip: '新对话',
                onPressed: work.busy || (title.isEmpty && value.text.isEmpty)
                    ? null
                    : create,
                color: workMuted,
                disabledColor: workLine,
                icon: const Icon(Icons.add_comment_outlined, size: 20),
              ),
            ),
            IconButton(
              tooltip: '工作区',
              onPressed: history,
              icon: const Icon(
                Icons.folder_open_outlined,
                color: workMuted,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkPanel extends StatefulWidget {
  const WorkPanel({
    super.key,
    required this.work,
    required this.input,
    required this.focus,
    required this.onSend,
  });
  final WorkConversation work;
  final TextEditingController input;
  final FocusNode focus;
  final VoidCallback onSend;
  @override
  State<WorkPanel> createState() => _WorkPanelState();
}

class _WorkPanelState extends State<WorkPanel>
    with SingleTickerProviderStateMixin {
  late final tabs = TabController(length: 2, vsync: this);
  final scroll = ScrollController();
  bool following = true;
  String lastUpdate = '';

  @override
  void dispose() {
    tabs.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> openFile(String name) async {
    try {
      final text = await widget.work.readDocument(name);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: workSurface,
            appBar: AppBar(
              backgroundColor: workSurface,
              foregroundColor: workInk,
              title: Text(name, style: const TextStyle(fontSize: 16)),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [WorkMarkdown(text)],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取此工作区文件')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final rows = [...work.turns, if (work.goal.isNotEmpty) work.currentTurn];
    final update =
        '${rows.length}/${rows.lastOrNull?['id']}/${work.status}/${work.goal}';
    if (update != lastUpdate) {
      lastUpdate = update;
      if (following)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients && following)
            scroll.jumpTo(scroll.position.maxScrollExtent);
        });
    }
    final total = _reportedTokens(rows);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: ColoredBox(
          color: workSurface.withValues(alpha: .92),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: workAccent,
                  unselectedLabelColor: workMuted,
                  indicatorColor: workAccent,
                  dividerColor: workLine,
                  tabs: const [
                    Tab(height: 39, text: '对话'),
                    Tab(height: 39, text: '轨迹'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs,
                  children: [
                    NotificationListener<ScrollUpdateNotification>(
                      onNotification: (n) {
                        if (n.depth == 0 && n.dragDetails != null)
                          following = n.metrics.extentAfter < 64;
                        return false;
                      },
                      child: ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          final answer = row['answer']?.toString() ?? '';
                          final saved = _receipts(
                            row,
                          ).map((e) => e['saved']).whereType<String>().toSet();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      left: 32,
                                      bottom: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: workRaised,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: SelectableText(
                                      row['goal']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: workInk,
                                        fontSize: 15,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ),
                                if (answer.isNotEmpty)
                                  WorkMarkdown(answer)
                                else
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => tabs.animateTo(1),
                                      icon: const Icon(
                                        Icons.timeline,
                                        size: 16,
                                      ),
                                      label: Text(_status(row)),
                                    ),
                                  ),
                                for (final file in saved)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => openFile(file),
                                      icon: const Icon(
                                        Icons.description_outlined,
                                        size: 17,
                                      ),
                                      label: Text(file),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _TurnTrace(
                        row: rows[rows.length - i - 1],
                        number: rows.length - i,
                        live: i == 0 && work.busy,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: workRaised,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: workLine),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.input,
                          focusNode: widget.focus,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: workAccent,
                          style: const TextStyle(
                            color: workInk,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            hintText: '交给小鲸鱼做什么？',
                            hintStyle: TextStyle(color: workMuted),
                            filled: false,
                            contentPadding: EdgeInsets.fromLTRB(14, 12, 4, 12),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: widget.input,
                        builder: (_, value, _) => IconButton(
                          tooltip: work.busy ? '停止任务' : '发送工作消息',
                          color: workAccent,
                          disabledColor: workMuted.withValues(alpha: .4),
                          onPressed: work.busy
                              ? work.stop
                              : value.text.trim().isEmpty
                              ? null
                              : () {
                                  following = true;
                                  tabs.animateTo(0);
                                  widget.onSend();
                                },
                          icon: Icon(
                            work.busy
                                ? Icons.stop_circle_outlined
                                : Icons.arrow_circle_up,
                            size: 29,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (rows.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${rows.length} 轮对话  ·  ${total == null ? "Token 未回报" : "已回报 $total Token"}',
                        style: const TextStyle(color: workMuted, fontSize: 12),
                      ),
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

String _status(Map row) =>
    row['status']?.toString() ??
    switch (row['state']) {
      'completed' => '已完成',
      'stopped' => '已停止',
      _ => '本轮尚未交付',
    };

List<Map> _receipts(Map row) =>
    (row['receipts'] as List? ?? row['evidence'] as List? ?? const [])
        .whereType<Map>()
        .toList();

int? _reportedTokens(List<Map> rows) {
  int? total;
  for (final row in rows) {
    for (final lane in (row['usage'] as Map? ?? {}).values.whereType<Map>()) {
      total =
          (total ?? 0) +
          (lane['input'] as int? ?? 0) +
          (lane['output'] as int? ?? 0) +
          (lane['reasoning'] as int? ?? 0);
    }
  }
  return total;
}

class _TurnTrace extends StatelessWidget {
  const _TurnTrace({
    required this.row,
    required this.number,
    required this.live,
  });
  final Map row;
  final int number;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final steps = (row['steps'] as List? ?? const []).whereType<String>();
    final receipts = _receipts(row);
    final rounds = row['planningRounds'];
    final usage = row['usage'] as Map? ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 $number 轮 · ${row['goal']}',
            style: const TextStyle(
              color: workInk,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              _status(row),
              if (rounds is int) '规划 $rounds 轮',
              if (receipts.isNotEmpty || rounds != null)
                '工具 ${receipts.length} 次',
            ].join('  ·  '),
            style: const TextStyle(color: workMuted, fontSize: 12),
          ),
          if (receipts.isEmpty)
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  step,
                  style: const TextStyle(color: workMuted, fontSize: 13),
                ),
              ),
          for (final item in receipts) _Receipt(item, live: live),
          for (final lane in usage.entries)
            if (lane.value case final Map u)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  '${lane.key == "commission_final_reply" ? "正文" : "规划"} · 输入 ${u["input"]} / 输出 ${u["output"]}${u["reasoning"] != null ? " / 推理 ${u['reasoning']}" : ""}${u["hit"] != null ? " / 缓存命中 ${u['hit']}" : ""} Token',
                  style: const TextStyle(color: workMuted, fontSize: 12),
                ),
              ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: workLine),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt(this.item, {required this.live});
  final Map item;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final action = switch (item['tool']) {
      'workspace_save' => '保存文档',
      'workspace_read' => '读取文档',
      'github_search_repositories' => '搜索 GitHub',
      'github_read_readme' => '读取 README',
      _ => item['tool']?.toString() ?? '工具回执',
    };
    final target = item['target'] ?? item['query'] ?? item['repository'];
    final result =
        item['error'] ??
        item['saved'] ??
        item['file'] ??
        (item['matches'] != null || item['repositories'] is List
            ? '找到 ${item['matches'] ?? (item['repositories'] as List).length} 个仓库'
            : item['state'] == 'pending'
            ? (live ? '进行中' : '未收到回执')
            : '读取完成');
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item['error'] != null
                ? Icons.error_outline
                : item['state'] == 'pending'
                ? Icons.schedule
                : Icons.check_circle_outline,
            size: 16,
            color: item['error'] != null ? const Color(0xfff1adab) : workAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              [
                action,
                if (target != null && target != '') target,
                result,
              ].join(' · '),
              style: const TextStyle(color: workInk, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
