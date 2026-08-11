import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/reference_document.dart';
import '../../core/reference/reference_document_chunker.dart';

class ReferenceDocumentEditorPage extends StatefulWidget {
  const ReferenceDocumentEditorPage({
    super.key,
    this.document,
  });

  final ReferenceDocument? document;

  @override
  State<ReferenceDocumentEditorPage> createState() => _ReferenceDocumentEditorPageState();
}

class _ReferenceDocumentEditorPageState extends State<ReferenceDocumentEditorPage> {
  final db = AppDatabase.instance;
  final chunker = const ReferenceDocumentChunker();
  late final TextEditingController nameController;
  late final TextEditingController aliasesController;
  late final TextEditingController rawController;
  late String kind;
  bool saving = false;
  String? error;

  bool get editing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    nameController = TextEditingController(text: document?.name ?? '');
    aliasesController = TextEditingController(text: document?.aliases.join('，') ?? '');
    rawController = TextEditingController(text: document?.rawContent ?? '');
    kind = document?.kind ?? 'character';
  }

  @override
  void dispose() {
    nameController.dispose();
    aliasesController.dispose();
    rawController.dispose();
    super.dispose();
  }

  List<String> _aliases() => aliasesController.text
      .split(RegExp(r'[,，|\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .take(16)
      .toList(growable: false);

  Future<void> _save() async {
    if (saving) return;
    final name = nameController.text.trim();
    final raw = rawController.text.trim();
    if (name.isEmpty || raw.isEmpty) {
      setState(() => error = '请填写资料名称，并粘贴完整资料原文。');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });
    try {
      final aliases = _aliases();
      final drafts = chunker.chunk(
        name: name,
        raw: raw,
        aliases: aliases,
        section: kind,
      );
      await db.saveReferenceDocumentWithChunks(
        id: widget.document?.id,
        name: name,
        kind: kind,
        rawContent: raw,
        aliases: aliases,
        enabled: widget.document?.enabled ?? true,
        chunks: drafts.map((draft) => draft.toMap()).toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑参考资料' : '新增参考资料')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            '保存后，完整原文仍会单独保留在本机，同时重新生成用于按需检索的片段。无需手工拆成性格、外貌或说话方式。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '资料名称',
              hintText: '例如：Yuki',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: aliasesController,
            decoration: const InputDecoration(
              labelText: '别名 / 检索词（可选）',
              hintText: '例如：有希，Yuki',
              helperText: '多个别名可用逗号或换行分开。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: kind,
            decoration: const InputDecoration(
              labelText: '资料类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'character', child: Text('人物参考')),
              DropdownMenuItem(value: 'intimacy', child: Text('亲密参考')),
              DropdownMenuItem(value: 'world', child: Text('背景 / 世界资料')),
              DropdownMenuItem(value: 'other', child: Text('其他参考')),
            ],
            onChanged: saving ? null : (value) => setState(() => kind = value ?? kind),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: rawController,
            minLines: 12,
            maxLines: 28,
            decoration: const InputDecoration(
              labelText: '完整资料原文',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(editing ? '保存修改并重新分块' : '保存资料并生成检索片段'),
            ),
          ),
        ],
      ),
    );
  }
}
