import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/reference_document.dart';
import '../../core/models/reference_item.dart';
import '../../core/reference/reference_document_chunker.dart';
import 'reference_document_editor_page.dart';

class ReferenceDocumentPage extends StatefulWidget {
  const ReferenceDocumentPage({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  State<ReferenceDocumentPage> createState() => _ReferenceDocumentPageState();
}

class _ReferenceDocumentPageState extends State<ReferenceDocumentPage> {
  final db = AppDatabase.instance;
  final chunker = const ReferenceDocumentChunker();
  ReferenceDocument? document;
  List<ReferenceItem> chunks = const [];
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nextDocument = await db.referenceDocumentById(widget.documentId);
    final nextChunks = await db.referenceItemsForDocument(widget.documentId);
    if (!mounted) return;
    setState(() {
      document = nextDocument;
      chunks = nextChunks;
      loading = false;
    });
  }

  Future<void> _edit() async {
    final current = document;
    if (current == null) return;
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReferenceDocumentEditorPage(document: current),
      ),
    );
    if (didChange == true) {
      await _load();
    }
  }

  Future<void> _rechunk() async {
    final current = document;
    if (current == null || busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成检索片段？'),
        content: const Text(
          '只会根据当前完整原文重新生成检索片段，不会修改或删除完整原文。资料当前的启用 / 停用状态也会保持不变。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新分块'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => busy = true);
    try {
      final drafts = chunker.chunk(
        name: current.name,
        raw: current.rawContent,
        aliases: current.aliases,
        section: current.kind,
      );
      await db.replaceDocumentChunks(
        current.id,
        sourceName: current.name,
        chunks: drafts.map((draft) => draft.toMap()).toList(growable: false),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重新生成 ${drafts.length} 个检索片段，完整原文没有改变。')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新分块失败，请稍后再试。')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final current = document;
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      await db.setReferenceDocumentEnabled(current.id, enabled);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('状态更新失败，请稍后再试。')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setManualActive(bool active) async {
    final current = document;
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      await db.setWorldBookManualActive(current.id, active);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模块状态更新失败，请稍后再试。')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final current = document;
    if (current == null || busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个条目？'),
        content: Text(
          '“${current.name}”会从本机删除。这个操作不能在应用内撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => busy = true);
    try {
      await db.deleteReferenceDocument(current.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败，请稍后再试。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = document;
    return Scaffold(
        appBar: AppBar(
          title: Text(current?.name ?? '世界书条目'),
          actions: [
            if (current != null)
              IconButton(
                tooltip: '编辑',
                onPressed: busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : current == null
                ? const Center(child: Text('这个条目已经不存在。'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      current.isBehavior
                                          ? '行为模块'
                                          : current.isRoleplay
                                              ? '角色扮演'
                                          : _kindLabel(current.kind),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  Switch(
                                    value: current.enabled,
                                    onChanged: busy ? null : _setEnabled,
                                  ),
                                ],
                              ),
                              Text(
                                current.isBehavior || current.isRoleplay
                                    ? (current.enabled
                                        ? '${current.isRoleplay ? "临时 Session" : "可用"} · ${_activationLabel(current.activationMode)} · 优先级 ${current.priority} · 概率 ${current.activationProbability}% · ${_scopeLabel(current.scope)}'
                                        : '已停用：配置仍保留，但不会注入聊天。')
                                    : (current.enabled
                                        ? '已启用：相关话题出现时，这份资料可以被检索。'
                                        : '已停用：完整原文仍保留，但不会进入聊天检索。'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                              ),
                              if (current.aliases.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('别名：${current.aliases.join(' / ')}'),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                current.isBehavior || current.isRoleplay
                                    ? '提示词 ${current.rawContent.length} 字符 · ${current.isRoleplay ? "独立角色扮演边界" : "模块启停本身不计成长证据"}'
                                    : '原文 ${current.rawContent.length} 字符 · 检索片段 ${chunks.length} 个',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if ((current.isBehavior || current.isRoleplay) &&
                          current.activationMode == 'manual') ...[
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          title: Text(current.isRoleplay ? '开始这场扮演' : '当前激活'),
                          subtitle: Text(current.isRoleplay
                              ? '开启后建立临时 Session；关闭不会改变或删除真实人格。'
                              : current.exclusiveGroup.isEmpty
                                  ? '聊天框快捷面板使用同一开关。'
                                  : '与同组性格/姿态模块互斥。'),
                          value: current.manualActive,
                          onChanged: busy ? null : _setManualActive,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: current.isBehavior
                            ? '行为提示词'
                            : current.isRoleplay
                                ? '角色卡 / 扮演提示词'
                                : '完整原文',
                        subtitle: current.isBehavior || current.isRoleplay
                            ? (current.isRoleplay
                                ? '只在当前角色扮演 Session 内生效。'
                                : '可直接修改；模块本身不会成为她能意识到的成长事件。')
                            : '这是本机保存的原始资料，不会因为重新分块而改变。',
                        child: SelectableText(
                          current.rawContent,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                      if (current.isKnowledge) ...[
                        const SizedBox(height: 12),
                        Card(
                        margin: EdgeInsets.zero,
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          title: Text('检索片段 · ${chunks.length}'),
                          subtitle: const Text('聊天时只会按当前话题取少量相关片段'),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            if (chunks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('目前没有检索片段，可以点击“重新分块”生成。'),
                              )
                            else
                              ...chunks.asMap().entries.map((entry) {
                                final chunk = entry.value;
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chunk.title.isEmpty ? '片段 ${entry.key + 1}' : chunk.title,
                                        style: Theme.of(context).textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 5),
                                      SelectableText(
                                        chunk.content,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _rechunk,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: const Text('重新分块'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(current.isBehavior
                            ? '编辑行为模块'
                            : current.isRoleplay
                                ? '编辑角色卡'
                                : '编辑完整资料'),
                      ),
                      const SizedBox(height: 18),
                      if (!current.builtin)
                        TextButton.icon(
                        onPressed: busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除这个条目'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
      'character' => '人物参考',
      'intimacy' => '亲密参考',
      'world' => '背景 / 世界资料',
      _ => '其他参考',
    };

String _activationLabel(String mode) => switch (mode) {
      'always' => '常驻注入',
      'manual' => '手动开关',
      _ => '关键词触发',
    };

String _scopeLabel(String scope) => switch (scope) {
      'chat' => '普通聊天',
      'chat|proactive' => '普通与主动',
      'proactive' => '主动联系',
      'immersive' => '沉浸房间',
      _ => '所有聊天',
    };
