import 'package:flutter/material.dart';
import 'work_markdown.dart';

class WorkUsage {
  int input = 0, output = 0, reasoning = 0, hit = 0, miss = 0;
  bool reported = false, cacheReported = false, partialCache = false;
  WorkUsage(Iterable<Map> turns) {
    for (final row in turns) {
      for (final u in (row['usage'] as Map? ?? {}).values.whereType<Map>()) {
        reported = true;
        input += (u['input'] as int?) ?? 0;
        output += (u['output'] as int?) ?? 0;
        reasoning += (u['reasoning'] as int?) ?? 0;
        if (u['hit'] is int && u['miss'] is int) {
          cacheReported = true;
          hit += u['hit'] as int;
          miss += u['miss'] as int;
          if (u['input'] != u['hit'] + u['miss']) partialCache = true;
        } else if ((u['input'] ?? 0) > 0) {
          partialCache = true;
        }
      }
    }
  }
  int get total => input + output + reasoning;
  String? get percent => hit + miss > 0
      ? '${(100 * hit / (hit + miss)).toStringAsFixed(1)}%'
      : null;
  String get cacheLabel => percent == null
      ? '缓存命中未回报'
      : '缓存命中 $percent${partialCache ? "（部分输入）" : ""}';
}

class WorkTurnFooter extends StatelessWidget {
  const WorkTurnFooter(this.row, {super.key, required this.live});
  final Map row;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final usage = WorkUsage([row]);
    final end =
        row['endedAt'] ?? (row['state'] == 'completed' ? row['at'] : null);
    final clock = end is int && !live
        ? DateTime.fromMillisecondsSinceEpoch(end)
        : null;
    final elapsed = row['elapsedMs'];
    final answer = row['answer'];
    const small = TextStyle(fontSize: 12, color: workMuted);
    Widget entry(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: small)),
          Text(value, style: small.copyWith(color: workInk)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          MenuAnchor(
            style: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(workRaised),
            ),
            builder: (_, controller, _) => IconButton(
              tooltip: '本轮用量',
              visualDensity: VisualDensity.compact,
              color: workMuted,
              iconSize: 17,
              icon: const Icon(Icons.storage_rounded),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
            menuChildren: [
              SizedBox(
                width: 270,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                  child: Column(
                    children: [
                      entry(
                        live ? '本轮用量 · 进行中' : '本轮用量',
                        usage.reported ? '${usage.total} tok' : '未回报',
                      ),
                      const Divider(color: workLine),
                      entry(
                        '输入',
                        usage.reported ? '${usage.input} tok' : '未回报',
                      ),
                      entry(
                        usage.partialCache ? '缓存命中（已回报部分）' : '缓存命中',
                        usage.percent ?? '—',
                      ),
                      entry(
                        '未缓存输入',
                        usage.cacheReported ? '${usage.miss} tok' : '未回报',
                      ),
                      entry(
                        '缓存读取',
                        usage.cacheReported ? '${usage.hit} tok' : '未回报',
                      ),
                      entry(
                        '输出',
                        usage.reported ? '${usage.output} tok' : '未回报',
                      ),
                      if (usage.reasoning > 0)
                        entry('另计推理', '${usage.reasoning} tok'),
                      if (elapsed is int)
                        entry(
                          '本轮耗时',
                          '${(elapsed / 1000).toStringAsFixed(1)} 秒',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (clock != null)
            Text(
              '${clock.hour.toString().padLeft(2, "0")}:${clock.minute.toString().padLeft(2, "0")}',
              style: small,
            ),
          if (!live && answer is String && answer.isNotEmpty)
            WorkCopyButton('正文', answer),
        ],
      ),
    );
  }
}

class WorkActivity extends StatefulWidget {
  const WorkActivity(this.label, {super.key});
  final String label;
  @override
  State<WorkActivity> createState() => _WorkActivityState();
}

class _WorkActivityState extends State<WorkActivity>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final text = Text(
      widget.label,
      style: const TextStyle(fontSize: 13, height: 20 / 13, color: workMuted),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: reduced
              ? const Icon(Icons.timelapse, size: 14, color: workAccent)
              : const CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: workAccent,
                ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: reduced
              ? text
              : FadeTransition(
                  opacity: Tween(begin: .68, end: 1.0).animate(pulse),
                  child: text,
                ),
        ),
      ],
    );
  }
}
