import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/memory/memory_browse_repository.dart';
import '../../core/models/memory_item.dart';
import '../../core/platform/memory_galaxy.dart';
import '../../core/relationship/relationship_age.dart';
import 'remembered_user_facts_page.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final db = AppDatabase.instance;
  List<MemoryItem> items = const [];
  bool loading = true;
  RelationshipAge? relationshipAge;
  String kind = 'all';
  String status = 'active';
  final searchController = TextEditingController();
  Timer? searchDelay;
  int loadGeneration = 0;
  bool openingGalaxy = false;

  static const kinds = <String, String>{
    'all': '全部',
    'user_profile': '用户资料',
    'shared_experience': '共同经历',
    'ai_self': 'AI Self',
    'preference': '偏好/边界',
  };

  static String semanticLabel(MemoryItem item) {
    if (item.status == 'superseded') return '历史版本';
    return switch (item.semanticType) {
      'inference' => '不确定推断',
      'shared_experience' => '共同经历',
      _ => '当前事实',
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchDelay?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++loadGeneration;
    if (mounted) setState(() => loading = true);
    final loadedItems = await db.listMemories(
      kind: kind,
      status: status,
      query: searchController.text,
    );
    final loadedAge = await db.relationshipAge();
    if (!mounted || generation != loadGeneration) return;
    setState(() {
      items = loadedItems;
      relationshipAge = loadedAge;
      loading = false;
    });
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _edit(MemoryItem item) async {
    final evidence = await db.memoryEvidenceFor(item.id, limit: 8);
    final related = await MemoryBrowseRepository(db).sameTopic(item);
    if (!mounted) return;
    final content = TextEditingController(text: item.content);
    final tags = TextEditingController(text: item.tags.join('、'));
    var importance = item.importance;
    var confidence = item.confidence;
    var pinned = item.pinned;
    final subject = TextEditingController(text: item.subjectKey);
    final saved = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
              title: Text(kinds[item.kind] ?? item.kind),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: content,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '记忆内容',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tags,
                        decoration: const InputDecoration(
                          labelText: '标签（顿号/逗号分隔）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subject,
                        decoration: const InputDecoration(
                          labelText: '事实键（可空）',
                          helperText: '同一事实改变时用于替换旧版本，例如 user.sleep_schedule',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '语义：${semanticLabel(item)} · 版本 v${item.factVersion} · 证据 ${item.evidenceCount} 次',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (evidence.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('最近证据'),
                          subtitle: const Text('重复说法会强化同一条记忆，不再堆成副本。'),
                          children: evidence.map((row) {
                            final text = row['evidence_text'] as String? ?? '';
                            final relation = row['relation'] as String? ?? 'created';
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 8, right: 4),
                              title: Text(text),
                              subtitle: Text('来源：${row['source']} · $relation'),
                            );
                          }).toList(),
                        ),
                      ],
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('锁定这条记忆'),
                        subtitle: const Text('锁定后自动记忆整理不能用同一事实键覆盖它。'),
                        value: pinned,
                        onChanged: (v) => setLocal(() => pinned = v ?? false),
                      ),
                      const SizedBox(height: 6),
                      Text('重要度 ${importance.toStringAsFixed(2)}'),
                      Slider(
                        value: importance,
                        onChanged: (v) => setLocal(() => importance = v),
                      ),
                      Text('可信度 ${confidence.toStringAsFixed(2)}'),
                      Slider(
                        value: confidence,
                        onChanged: (v) => setLocal(() => confidence = v),
                      ),
                      if (related.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('同话题记忆'),
                          children: related
                              .map(
                                (relatedItem) => ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(
                                    left: 8,
                                    right: 4,
                                  ),
                                  title: Text(
                                    relatedItem.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(_date(relatedItem.createdAt)),
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => _RelatedMemoryDialog(
                                      item: relatedItem,
                                      repository: MemoryBrowseRepository(db),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!saved) {
      content.dispose();
      tags.dispose();
      subject.dispose();
      return;
    }
    final parsedTags = tags.text
        .split(RegExp(r'[、,，|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      await db.updateMemoryItem(
        id: item.id,
        content: content.text,
        importance: importance,
        confidence: confidence,
        tags: parsedTags,
        subjectKey: subject.text,
        pinned: pinned,
      );
      await _load();
    } on StateError catch (error) {
      if (mounted && error.message == 'current_fact_subject_conflict') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已有同一事实键的当前版本，请先归档当前版本再修改。')),
        );
      } else {
        rethrow;
      }
    } finally {
      content.dispose();
      tags.dispose();
      subject.dispose();
    }
  }

  Future<void> _toggleArchive(MemoryItem item) async {
    final next = item.status == 'active' ? 'archived' : 'active';
    try {
      await db.setMemoryStatus(item.id, next);
      await _load();
    } on StateError catch (error) {
      if (mounted && error.message == 'current_fact_subject_conflict') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已有同一事实键的当前版本，不能同时恢复两个当前事实。')),
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _openGalaxy() async {
    if (openingGalaxy) return;
    setState(() => openingGalaxy = true);
    try {
      await MemoryGalaxyLauncher.open();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('记忆星谷暂时无法打开，请稍后再试。')));
      }
    } finally {
      if (mounted) setState(() => openingGalaxy = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地记忆库'),
        actions: [
          TextButton(
            onPressed: openingGalaxy ? null : _openGalaxy,
            child: const Text('记忆星谷'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RememberedUserFactsPage(),
              ),
            ),
            child: const Text('记住事项'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (relationshipAge != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text('认识第 ${relationshipAge!.dayNumber} 天'),
                  subtitle: Text(
                    '从 ${_date(relationshipAge!.startedAt)} 开始记录'
                    ' · 已跨过 ${relationshipAge!.elapsedCalendarDays} 个自然日',
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final typePicker = DropdownButtonFormField<String>(
                  value: kind,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: kinds.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    kind = v ?? 'all';
                    _load();
                  },
                );
                final statusPicker = SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('有效')),
                    ButtonSegment(value: 'archived', label: Text('归档')),
                    ButtonSegment(value: 'superseded', label: Text('旧版本')),
                  ],
                  selected: {status},
                  onSelectionChanged: (v) {
                    status = v.first;
                    _load();
                  },
                );
                if (constraints.maxWidth < 470) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      typePicker,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: statusPicker),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: typePicker),
                    const SizedBox(width: 10),
                    statusPicker,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '搜索记忆内容、标签或事实键',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          searchController.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                searchDelay?.cancel();
                setState(() {});
                searchDelay = Timer(const Duration(milliseconds: 220), _load);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SQLite 是记忆真源。当前事实、历史版本、不确定推断和共同经历会分开保存；重复证据会强化同一条记忆。低价值记忆只会归档，不会删除原始聊天。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(child: Text('当前没有对应记忆。'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              title: Text(item.content),
                              subtitle: Text(
                                '${kinds[item.kind] ?? item.kind} · ${semanticLabel(item)} · 证据 ${item.evidenceCount} 次'
                                '${item.factVersion > 1 ? ' · v${item.factVersion}' : ''}'
                                '${item.pinned ? ' · 已锁定' : ''}'
                                '\n重要 ${item.importance.toStringAsFixed(2)} · 可信 ${item.confidence.toStringAsFixed(2)} · 保留 ${item.retentionScore.toStringAsFixed(2)}'
                                '${item.subjectKey.isEmpty ? '' : '\n事实键：${item.subjectKey}'}'
                                '${item.tags.isEmpty ? '' : '\n${item.tags.join(' · ')}'}',
                              ),
                              onTap: () => _edit(item),
                              trailing: item.status == 'superseded'
                                  ? const Icon(Icons.history)
                                  : IconButton(
                                      tooltip: item.status == 'active' ? '归档' : '恢复',
                                      onPressed: () => _toggleArchive(item),
                                      icon: Icon(item.status == 'active'
                                          ? Icons.archive_outlined
                                          : Icons.unarchive_outlined),
                                    ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Related memories share one read-only dialog. Choosing another item updates
/// this view instead of recursively opening more dialogs or an edit form.
class _RelatedMemoryDialog extends StatefulWidget {
  const _RelatedMemoryDialog({required this.item, required this.repository});

  final MemoryItem item;
  final MemoryBrowseRepository repository;

  @override
  State<_RelatedMemoryDialog> createState() => _RelatedMemoryDialogState();
}

class _RelatedMemoryDialogState extends State<_RelatedMemoryDialog> {
  late MemoryItem item;
  List<MemoryItem> related = const [];
  bool loading = true;
  bool loadFailed = false;
  int loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    item = widget.item;
    _loadRelated(item);
  }

  Future<void> _loadRelated(MemoryItem next) async {
    final generation = ++loadGeneration;
    setState(() {
      item = next;
      related = const [];
      loading = true;
      loadFailed = false;
    });
    try {
      final loaded = await widget.repository.sameTopic(next);
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        related = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('查看记忆'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(item.content),
              const SizedBox(height: 12),
              Text(
                '${_MemoryPageState.kinds[item.kind] ?? item.kind} · '
                '${_MemoryPageState.semanticLabel(item)} · 版本 v${item.factVersion}'
                '\n记录于 ${_date(item.createdAt)} · 证据 ${item.evidenceCount} 次',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.tags.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ] else if (loadFailed) ...[
                const SizedBox(height: 12),
                const Text('同话题记忆暂时无法读取。'),
                TextButton(
                  onPressed: () => _loadRelated(item),
                  child: const Text('重试'),
                ),
              ] else if (related.isNotEmpty)
                ExpansionTile(
                  key: ValueKey(item.id),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('同话题记忆'),
                  children: related
                      .map(
                        (next) => ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 8,
                            right: 4,
                          ),
                          title: Text(
                            next.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_date(next.createdAt)),
                          onTap: () => _loadRelated(next),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
