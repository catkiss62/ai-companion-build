import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/reference_document.dart';
import '../../core/models/reference_item.dart';
import 'reference_document_editor_page.dart';
import 'reference_document_page.dart';

class ReferenceLibraryPage extends StatefulWidget {
  const ReferenceLibraryPage({super.key});

  @override
  State<ReferenceLibraryPage> createState() => _ReferenceLibraryPageState();
}

class _ReferenceLibraryPageState extends State<ReferenceLibraryPage> {
  final db = AppDatabase.instance;
  final searchController = TextEditingController();

  List<ReferenceDocument> documents = const [];
  List<ReferenceItem> chunks = const [];
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final nextDocuments = await db.listReferenceDocuments();
    final nextChunks = await db.listReferenceItems();
    if (!mounted) return;
    setState(() {
      documents = nextDocuments;
      chunks = nextChunks;
      loading = false;
    });
  }

  Future<void> _createDocument() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReferenceDocumentEditorPage()),
    );
    if (changed == true) await _load();
  }

  Future<void> _openDocument(ReferenceDocument document) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReferenceDocumentPage(documentId: document.id),
      ),
    );
    await _load();
  }

  Iterable<ReferenceDocument> get _visibleDocuments {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return documents;
    return documents.where((doc) {
      final haystack = [
        doc.name,
        doc.kind,
        ...doc.aliases,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleDocuments.toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('世界书'),
        actions: [
          IconButton(
            tooltip: '新增条目',
            onPressed: _createDocument,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDocument,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增条目'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '知识资料按话题检索；行为模块引导表达，但只有真实的跨场景行为才可能经过证据门缓慢成长；角色扮演是显式启停、独立记忆边界的临时娱乐 Session。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: '按名称或别名查找',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '条目 ${documents.length} 个 · 知识片段 ${chunks.length} 个',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!loading && documents.isEmpty)
              const _EmptyLibrary()
            else if (!loading && visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('没有找到匹配的资料。')),
              )
            else
              ...visible.map((doc) {
                final count = chunks.where((item) => item.documentId == doc.id).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReferenceDocumentCard(
                    document: doc,
                    chunkCount: count,
                    onOpen: () => _openDocument(doc),
                    onEnabledChanged: (enabled) async {
                      try {
                        if ((doc.isBehavior || doc.isRoleplay) &&
                            doc.activationMode == 'manual') {
                          await db.setWorldBookManualActive(doc.id, enabled);
                        } else {
                          await db.setReferenceDocumentEnabled(doc.id, enabled);
                        }
                        await _load();
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('状态更新失败，请稍后再试。')),
                        );
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ReferenceDocumentCard extends StatelessWidget {
  const _ReferenceDocumentCard({
    required this.document,
    required this.chunkCount,
    required this.onOpen,
    required this.onEnabledChanged,
  });

  final ReferenceDocument document;
  final int chunkCount;
  final VoidCallback onOpen;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final aliases = document.aliases.isEmpty
        ? '无别名'
        : document.aliases.take(4).join(' / ');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  document.isBehavior
                      ? Icons.tune_rounded
                      : document.isRoleplay
                          ? Icons.theater_comedy_outlined
                      : _kindIcon(document.kind),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!document.enabled ||
                            ((document.isBehavior || document.isRoleplay) &&
                                document.activationMode == 'manual' &&
                                !document.manualActive))
                          Text(
                            document.enabled ? '未激活' : '已停用',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.isBehavior || document.isRoleplay
                          ? '${document.isRoleplay ? "角色扮演" : "行为模块"} · ${_activationLabel(document.activationMode)} · 优先级 ${document.priority} · ${document.activationProbability}% · ${_scopeLabel(document.scope)}'
                          : '${_kindLabel(document.kind)} · $chunkCount 个片段 · 原文 ${document.rawContent.length} 字符',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      aliases,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: (document.isBehavior || document.isRoleplay) &&
                        document.activationMode == 'manual'
                    ? document.manualActive
                    : document.enabled,
                onChanged: onEnabledChanged,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.library_add_outlined, size: 34),
            const SizedBox(height: 10),
            Text('还没有世界书条目', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              '可以加入按需检索的背景资料，也可以创建随时开关的动作、幽默或表达模块。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
      'character' => '人物参考',
      'intimacy' => '亲密参考',
      'world' => '背景 / 世界',
      _ => '其他参考',
    };

IconData _kindIcon(String kind) => switch (kind) {
      'character' => Icons.person_outline_rounded,
      'intimacy' => Icons.favorite_border_rounded,
      'world' => Icons.public_rounded,
      _ => Icons.notes_rounded,
    };

String _activationLabel(String mode) => switch (mode) {
      'always' => '常驻',
      'manual' => '手动',
      _ => '关键词',
    };

String _scopeLabel(String scope) => switch (scope) {
      'chat' => '普通聊天',
      'chat|proactive' => '普通与主动',
      'proactive' => '主动联系',
      'immersive' => '沉浸房间',
      _ => '全部场景',
    };
