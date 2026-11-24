import '../../core/agent/commission_thread.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/agent/commission_workspace.dart';
import '../../core/agent/workspace_archive.dart';

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
  bool busy = true;
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
      files = (await store!.list()).reversed.toList();
      labels.clear();
      final threads = await store!.conversations();
      for (final rows in threads.values) {
        final latest = '任务-${rows.last['id']}.json';
        labels[latest] = rows.first['goal'] as String;
        final older = rows
            .take(rows.length - 1)
            .map((r) => '任务-${r['id']}.json')
            .toSet();
        files.removeWhere(older.contains);
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> inspect(String name) async {
    if (widget.selectTask && labels.containsKey(name)) {
      Navigator.pop(context, name);
      return;
    }
    final raw = await store!.read(name);
    final task = name.endsWith('.json');
    final row = task ? jsonDecode(raw) as Map : null;
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
            child: task
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          if (!task)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存'),
            ),
        ],
      ),
    );
    if (choice == 'save') await store!.write(name, edited);
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
      final names = turns.map((r) => '任务-${r['id']}.json').toList();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('工作区'),
      actions: [
        PopupMenuButton<String>(
          enabled: !busy,
          onSelected: (v) => run(() async {
            if (v == 'choose') await CommissionWorkspace.choose();
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
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'choose', child: Text('选择手机文件夹')),
            PopupMenuItem(value: 'default', child: Text('打开默认工作区')),
            PopupMenuItem(value: 'export', child: Text('导出工作区')),
            PopupMenuItem(value: 'import', child: Text('合并导入工作区')),
          ],
        ),
      ],
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              if (error != null)
                ListTile(title: Text(error!), onTap: () => run(() async {})),
              if (files.isEmpty && error == null)
                const ListTile(
                  title: Text('还没有工作文件'),
                  subtitle: Text('在聊天页点鲸尾，即可开始工作。'),
                ),
              for (final name in files)
                ListTile(
                  leading: Icon(
                    name.endsWith('.json')
                        ? Icons.history
                        : name.contains('技能-')
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
                      if (files.contains(target))
                        throw const FormatException('已有同名技能');
                      await store!.write(target, await store!.read(name));
                      await store!.remove(name);
                    }),
                    itemBuilder: (_) => [
                      if (name.contains('技能-'))
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(name.startsWith('停用') ? '启用' : '停用'),
                        ),
                      const PopupMenuItem(value: 'remove', child: Text('删除')),
                    ],
                  ),
                ),
            ],
          ),
  );
}
