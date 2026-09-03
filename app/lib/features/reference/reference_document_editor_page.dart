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
  late String entryType;
  late String activationMode;
  late String scope;
  late double priority;
  late double probability;
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
    entryType = document?.entryType ?? 'knowledge';
    activationMode = document?.activationMode ?? 'keyword';
    scope = document?.scope ?? 'all';
    priority = (document?.priority ?? 500).toDouble();
    probability = (document?.activationProbability ?? 100).toDouble();
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
        entryType: entryType,
        activationMode: entryType == 'behavior' ? activationMode : 'keyword',
        priority: priority.round(),
        activationProbability: probability.round(),
        scope: entryType == 'behavior' ? scope : 'all',
        manualActive: entryType == 'behavior' && activationMode == 'manual'
            ? widget.document?.manualActive ?? false
            : false,
        exclusiveGroup: widget.document?.exclusiveGroup ?? '',
        builtin: widget.document?.builtin ?? false,
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
      appBar: AppBar(title: Text(editing ? '编辑世界书条目' : '新增世界书条目')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            entryType == 'behavior'
                ? '行为模块会按激活方式直接影响表达，但不会写入长期记忆、AI Self、学习候选或成长状态。'
                : '知识资料保留完整原文，并自动生成用于按需检索的片段。它不会自动变成她的人格。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: entryType,
            decoration: InputDecoration(
              labelText: '条目用途',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'knowledge', child: Text('知识资料 · 按话题检索')),
              DropdownMenuItem(value: 'behavior', child: Text('行为模块 · 控制表达')),
            ],
            onChanged: saving
                ? null
                : (value) => setState(() {
                      entryType = value ?? entryType;
                      if (entryType == 'behavior' && activationMode == 'keyword') {
                        activationMode = 'manual';
                      }
                    }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: '条目名称',
              hintText: entryType == 'behavior' ? '例如：动作与神态' : '例如：Yuki',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: aliasesController,
            decoration: InputDecoration(
              labelText: entryType == 'behavior' ? '关键词 / 别名（可选）' : '别名 / 检索词（可选）',
              hintText: entryType == 'behavior' ? '例如：幽默，玩笑，造梗' : '例如：有希，Yuki',
              helperText: '多个词可用逗号或换行分开。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (entryType == 'knowledge') ...[
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
          ] else ...[
            DropdownButtonFormField<String>(
              value: activationMode,
              decoration: const InputDecoration(
                labelText: '激活方式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('手动开关')),
                DropdownMenuItem(value: 'always', child: Text('常驻注入')),
                DropdownMenuItem(value: 'keyword', child: Text('关键词触发')),
              ],
              onChanged: saving ? null : (value) => setState(() => activationMode = value ?? activationMode),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: scope,
              decoration: const InputDecoration(
                labelText: '生效场景',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('所有聊天')),
                DropdownMenuItem(value: 'chat|proactive', child: Text('普通聊天与主动联系')),
                DropdownMenuItem(value: 'chat', child: Text('普通聊天')),
                DropdownMenuItem(value: 'proactive', child: Text('主动联系')),
                DropdownMenuItem(value: 'immersive', child: Text('沉浸房间')),
              ],
              onChanged: saving ? null : (value) => setState(() => scope = value ?? scope),
            ),
            const SizedBox(height: 10),
            Text('优先级 ${priority.round()} · 只处理模块冲突'),
            Slider(
              value: priority,
              min: 0,
              max: 1000,
              divisions: 100,
              label: priority.round().toString(),
              onChanged: saving ? null : (value) => setState(() => priority = value),
            ),
            Text('本轮触发概率 ${probability.round()}%'),
            Slider(
              value: probability,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${probability.round()}%',
              onChanged: saving ? null : (value) => setState(() => probability = value),
            ),
          ],
          TextField(
            controller: rawController,
            minLines: 12,
            maxLines: 28,
            decoration: InputDecoration(
              labelText: entryType == 'behavior' ? '行为提示词' : '完整资料原文',
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
              child: Text(entryType == 'behavior'
                  ? (editing ? '保存行为模块' : '创建行为模块')
                  : (editing ? '保存修改并重新分块' : '保存资料并生成检索片段')),
            ),
          ),
        ],
      ),
    );
  }
}
