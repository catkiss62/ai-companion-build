import '../../core/agent/work_error.dart';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'work_markdown.dart';
import 'work_html_card.dart';
import 'work_turn_footer.dart';
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
    final usage = WorkUsage(rows);
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
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          final answer = row['answer']?.toString() ?? '';
                          final live = i == rows.length - 1 && work.busy;
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
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff593b78),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: SelectableText(
                                      row['goal']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: workInk,
                                        fontSize: 14,
                                        letterSpacing: 0,
                                        height: 22 / 14,
                                      ),
                                    ),
                                  ),
                                ),
                                if (answer.isNotEmpty)
                                  WorkMarkdown(answer)
                                else
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => tabs.animateTo(1),
                                      child: live
                                          ? WorkActivity(_status(row))
                                          : Text(_status(row), style: _failureStyle(row)),
                                    ),
                                  ),
                                for (final (index, item) in _receipts(row).indexed)
                                  if (item['artifact'] is String)
                                    WorkHtmlCard(key: ValueKey("${row['id']}/${item['artifact']}/$index"),
                                      title: item['title']?.toString() ?? 'HTML 作品',
                                      load: () => work.readHtml(item['artifact'] as String, expectedDigest: item['digest'] as String?)),
                                for(final item in _receipts(row))
                                  if(item['screenshot'] is String && item['digest'] is String)
                                    _ResultPhoto(key:ValueKey("${row['id']}/${item['digest']}"),
                                      load:()=>work.screenshot(item['screenshot'] as String,item['digest'] as String)),
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
                                WorkTurnFooter(row, live: live),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
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
              if (work.draft != null && work.draftBase != null)
                TextButton.icon(
                  icon: const Icon(Icons.edit_document),
                  label: Text('预览修改 · ${work.referenceName}'),
                  onPressed: work.busy ? null : () async {
                    final draft = work.draft!, base = work.draftBase!;
                    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                      title: Text('写回 ${base.name}'),
                      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('原文'), SelectableText(base.text),
                          const Divider(), const Text('写回后的全文'), SelectableText(draft),
                        ]))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('写回原文件')),
                      ],
                    ));
                    if (accepted != true || !context.mounted) return;
                    String message;
                    bool failed = false;
                    try { await work.applyDraft(draft, base); message = '已写回并核对原文件'; }
                    catch (e) { failed = true; message = workErrorReason(e, fallback: '写回失败'); }
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: failed ? const TextStyle(color: _workErrorColor) : null)));
                  },
                ),
              if (work.imageName case final String name)
                Align(alignment:Alignment.centerLeft,child:Padding(padding:const EdgeInsets.symmetric(horizontal:16),
                  child:InputChip(avatar:const Icon(Icons.image_outlined),label:Text(name,maxLines:1,overflow:TextOverflow.ellipsis),
                    deleteButtonTooltipMessage:'移除图片',onDeleted:work.busy || work.choosingReference ? null : work.removeImage))),
              if (work.referenceName != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InputChip(
                      label: Text(work.referenceName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      deleteButtonTooltipMessage: '移除文件引用',
                      onDeleted: work.busy || work.choosingReference ? null : work.removeReference,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: workRaised,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: workLine),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: '引用文本文件（UTF-8，最多 64 KiB，当前会话每轮重读）',
                        color: workAccent,
                        onPressed: work.busy || work.choosingReference ? null : () async {
                          try {
                            await work.chooseReference();
                          } catch (_) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('无法选择文本文件，请重试')),
                            );
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                      ),
                      IconButton(
                        tooltip:'添加图片（第一通道识图）',color:workAccent,icon:const Icon(Icons.image_outlined),
                        onPressed:work.busy || work.choosingReference ? null : () async {
                          try { await work.chooseImage(); }
                          catch(e) {
                            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:Text(workErrorReason(e,fallback:'无法读取这张图片'),style:const TextStyle(color:_workErrorColor))));
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.input,
                          focusNode: widget.focus,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: workAccent,
                          style: const TextStyle(
                            color: workInk,
                            fontSize: 14,
                            letterSpacing: 0,
                            height: 22 / 14,
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
                              : work.choosingReference || value.text.trim().isEmpty && work.imageName == null
                              ? null
                              : () {
                                  following = true;
                                  tabs.animateTo(0);
                                  widget.focus.unfocus();
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${rows.length} 轮对话  ·  ${usage.reported ? "已回报 ${usage.total} Token" : "Token 未回报"}${usage.percent == null ? "" : "  ·  ${usage.cacheLabel}"}',
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

const _workErrorColor = Color(0xffffa8a4);
TextStyle? _failureStyle(Map row) => row['failureReason'] != null || row['state'] == 'interrupted'
    ? const TextStyle(color: _workErrorColor) : null;

String _status(Map row) =>
    row['status']?.toString() ??
    (row['failureReason'] != null ? '工作未完成 · ${row['failureReason']}' : null) ??
    switch (row['state']) {
      'completed' when row['researchEnd'] == 'evidence_incomplete' => '已交付 · 部分依据待核实',
      'completed' => '已完成',
      'stopped' => '已停止',
      'interrupted' => '工作已中断',
      _ => '本轮尚未交付',
    };

List<Map> _receipts(Map row) =>
    (row['receipts'] as List? ?? row['evidence'] as List? ?? const [])
        .whereType<Map>()
        .toList();

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
              if (!live) _status(row),
              if (row['image_reference'] case {'name': final String imageName}) '图片 · $imageName',
              if (row['text_reference'] case {'name': final String name}) '引用 · $name',
              if (row['researchEnd'] == 'budget') '已到调研上限',
              if (row['researchEnd'] == 'evidence_incomplete') '部分依据待核实',
              if (rounds is int) '规划 $rounds 轮',
              if (receipts.isNotEmpty || rounds != null)
                '工具 ${receipts.length} 次',
            ].join('  ·  '),
            style: TextStyle(color: _failureStyle(row)?.color ?? workMuted, fontSize: 12),
          ),
          if (live) WorkActivity(_status(row)),
          if (receipts.isEmpty)
            for (final step in steps.where((s) => !live || s != _status(row)))
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
                  '${lane.key == "commission_final_reply" ? "正文" : "规划"} · 输入 ${u["input"]} / 输出 ${u["output"]}${u["reasoning"] != null ? " / 推理 ${u['reasoning']}" : ""}${u["hit"] != null ? " / 缓存命中 ${u['hit']}（${WorkUsage([
                              {
                                'usage': {lane.key: u},
                              },
                            ]).percent ?? "—"}）" : ""} Token',
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
      'work_file_applied' => '用户确认写回',
      'work_app_read' => '读取 App 资料',
      'work_propose_text_edit' => '生成文件修改稿',
      'work_deliver_html' => '交付 HTML 作品',
      'workspace_save' => '保存文档',
      'workspace_read' => '读取文档',
      'github_search_repositories' => '搜索 GitHub',
      'work_history_search' => '查工作会话原文',
      'github_read_readme' => '读取 README',
      _ => item['tool']?.toString() ?? '工具回执',
    };
    final target = item['target'] ?? item['query'] ?? item['repository'];
    final result =
        (item['error'] != null ? workErrorReason(item['error']!, fallback: '工具执行失败') : null) ??
        item['display'] ??
        item['saved'] ??
        item['file'] ??
        (item['excerpts'] != null
            ? '找到 ${item['excerpts']} 段原文'
            : item['matches'] != null || item['repositories'] is List
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
              style: TextStyle(color: item['error'] != null ? _workErrorColor : workInk, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPhoto extends StatefulWidget {
  const _ResultPhoto({super.key, required this.load});
  final Future<Uint8List> Function() load;
  @override
  State<_ResultPhoto> createState()=>_ResultPhotoState();
}
class _ResultPhotoState extends State<_ResultPhoto> {
  late final photo = widget.load();
  @override
  Widget build(BuildContext context)=>FutureBuilder<Uint8List>(future:photo,builder:(ctx,snap){
    if(snap.hasError) return const Text('无法读取这张结果截图');
    if(!snap.hasData) return const LinearProgressIndicator();
    final image = snap.requireData;
    return InkWell(onTap:()=>showDialog<void>(context:ctx,builder:(d)=>Dialog(
      child:InteractiveViewer(child:Image.memory(image)))),child:Image.memory(image,height:220,
      fit:BoxFit.contain,semanticLabel:'网页答题结果截图'));
  });
}
