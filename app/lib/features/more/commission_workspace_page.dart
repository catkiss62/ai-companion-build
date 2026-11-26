import '../chat/work_markdown.dart' show WorkCopyButton;
import '../../core/agent/commission_thread.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/agent/commission_workspace.dart';
import '../../core/agent/workspace_archive.dart';
import '../../core/agent/work_error.dart';

class CommissionWorkspacePage extends StatefulWidget {
  const CommissionWorkspacePage({super.key, this.selectTask = false});
  final bool selectTask;
  @override
  State<CommissionWorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<CommissionWorkspacePage> {
  CommissionWorkspace? store;
  List<String> files = [];
  final labels = <String, String>{};
  final latestAt = <String, int>{};
  bool busy = true;
  bool hasPrivateFiles = false;
  String? error;
  @override
  void initState() {
    super.initState();
    run(() async {});
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      store = await CommissionWorkspace.open();
      hasPrivateFiles = store!.tree != null && await CommissionWorkspace.hasPrivateFiles();
      files = (await store!.list()).reversed.toList();
      labels.clear();
      latestAt.clear();
      final threads = await store!.conversations();
      for (final rows in threads.values) {
        final bundle='会话-${CommissionThread.key(rows.first)}.json';
        final latest=files.contains(bundle) ? bundle : "任务-${rows.last['id']}.json";
        labels[latest] = rows.first['goal'] as String;
        latestAt[latest] = rows.last['at'] as int? ?? 0;
        final older = rows
            .where((r)=>"任务-${r['id']}.json"!=latest)
            .map((r) => '任务-${r['id']}.json')
            .toSet();
        files.removeWhere(older.contains);
      }
    } catch (e) {
      error = workErrorReason(e, fallback: '工作区操作失败');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> inspect(String name) async {
    if (widget.selectTask && labels.containsKey(name)) {
      Navigator.pop(context, name);
      return;
    }
    final image = name.endsWith('.png');
    final html = name.endsWith('.html');
    final raw = html ? await store!.readHtml(name) : await store!.read(name);
    final task = name.endsWith('.json');
    final row = task && labels.containsKey(name)
        ? jsonDecode(raw) as Map
        : null;
    final initial = row == null
        ? raw
        : (await store!.conversation(
            name,
          )).map(CommissionThread.display).join('\n\n');
    if (!mounted) return;
    var edited = initial;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(task ? '工作记录' : name),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: image ? Image.memory(base64Decode(raw)) : task || html
                ? SelectableText(initial)
                : TextFormField(
                    initialValue: raw,
                    onChanged: (s) => edited = s,
                    minLines: 6,
                    maxLines: null,
                  ),
          ),
        ),
        actions: [
          if (html || task || image) ...[
            if (html) WorkCopyButton('源码', raw),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'open'), child: const Text('用其他应用打开')),
          ] else Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'open'), child: const Text('用其他应用打开')),
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
              FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('保存')),
            ]),
          ]),
        ],
      ),
    );
    if (choice == 'open') await store!.openExternally(name);
    if (choice == 'save') await store!.saveMarkdown(name, edited, expected: raw);
  }

  Future<void> remove(String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除${name.endsWith(".json") ? "整段工作对话" : "文件"}？'),
        content: Text(labels[name] ?? name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (name.endsWith('.json') && labels.containsKey(name)) {
      final turns = await store!.conversation(name);
      final existing=(await store!.list()).toSet();
      final names = {...turns.map((r) => '任务-${r['id']}.json'),name}.where(existing.contains).toList();
      if (names.any(CommissionWorkspace.writingTasks.contains))
        throw StateError('请先停止正在执行的任务');
      for (final entry in names) {
        await store!.remove(entry);
      }
    } else {
      await store!.remove(name);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('工作区'),
          if (store != null) Text(store!.locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ]),
        bottom: const TabBar(
          tabs: [
            Tab(text: '对话'),
            Tab(text: '文件'),
            Tab(text: '技能'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !busy,
            onSelected: (v) => run(() async {
              if (v == 'choose') await CommissionWorkspace.choose();
              if (v == 'private') await CommissionWorkspace.useDefault(private: true);
              if (v == 'default') await CommissionWorkspace.useDefault();
              if (v == 'export') await WorkspaceArchive.export(store!);
              if (v == 'import') {
                final msg = await WorkspaceArchive.import(store!);
                if (mounted && msg.isNotEmpty)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
              }
            }),
            itemBuilder: (_) => [
              if (hasPrivateFiles) const PopupMenuItem(value: 'private', child: Text('打开旧版内部工作区')),
              const PopupMenuItem(value: 'choose', child: Text('选择手机文件夹')),
              const PopupMenuItem(value: 'default', child: Text('打开默认工作区')),
              const PopupMenuItem(value: 'export', child: Text('导出工作区')),
              const PopupMenuItem(value: 'import', child: Text('合并导入工作区')),
            ],
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                group(
                  files.where((n) => n.endsWith('.json')).toList()..sort(
                    (a, b) => (latestAt[b] ?? 0).compareTo(latestAt[a] ?? 0),
                  ),
                  '暂无工作对话',
                ),
                group(
                  files.where((n) => !n.endsWith('.json') && !isSkill(n)),
                  '暂无工作文件',
                ),
                group(files.where(isSkill), '暂无私人技能'),
              ],
            ),
    ),
  );
  bool isSkill(String name) =>
      name.startsWith('技能-') || name.startsWith('停用技能-');

  Widget group(Iterable<String> entries, String empty) => ListView(
    children: [
      if (error != null)
        ListTile(title: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), onTap: () => run(() async {})),
      if (entries.isEmpty && error == null) ListTile(title: Text(empty)),
      for (final name in entries)
        ListTile(
          leading: Icon(
            name.endsWith('.json')
                ? Icons.history
                : isSkill(name)
                ? Icons.build_outlined
                : Icons.description_outlined,
          ),
          title: Text(
            labels[name] ?? name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => run(() => inspect(name)),
          trailing: PopupMenuButton<String>(
            onSelected: (v) => run(() async {
              if (v == 'remove') {
                await remove(name);
                return;
              }
              final target = name.startsWith('停用')
                  ? name.substring(2)
                  : '停用$name';
              if (files.contains(target)) throw const FormatException('已有同名技能');
              await store!.write(target, await store!.read(name));
              await store!.remove(name);
            }),
            itemBuilder: (_) => [
              if (isSkill(name))
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(name.startsWith('停用') ? '启用' : '停用'),
                ),
              const PopupMenuItem(value: 'remove', child: Text('删除')),
            ],
          ),
        ),
    ],
  );
}
