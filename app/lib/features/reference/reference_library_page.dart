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
        title: const Text('参考资料'),
        actions: [
          IconButton(
            tooltip: '新增资料',
            onPressed: _createDocument,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDocument,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增资料'),
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
                        '这里保存的是她可以按需查阅的背景资料，不是她本人的角色卡。完整原文始终留在本机；聊天时只会检索与当前话题相关的少量片段。',
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
                    '资料 ${documents.length} 份 · 检索片段 ${chunks.length} 个',
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
                        await db.setReferenceDocumentEnabled(doc.id, enabled);
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
                child: Icon(_kindIcon(document.kind), size: 21),
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
                        if (!document.enabled)
                          Text(
                            '已停用',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kindLabel(document.kind)} · $chunkCount 个片段 · 原文 ${document.rawContent.length} 字符',
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
                value: document.enabled,
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
            Text('还没有参考资料', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              '可以把人物完整资料、世界设定或其他背景信息整份粘贴进来。程序会保留原文并自动生成检索片段。',
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
