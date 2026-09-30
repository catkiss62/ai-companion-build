import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/memory/remembered_user_facts.dart';

class RememberedUserFactsPage extends StatefulWidget {
  const RememberedUserFactsPage({super.key});
  @override
  State<RememberedUserFactsPage> createState() =>
      _RememberedUserFactsPageState();
}

class _RememberedUserFactsPageState extends State<RememberedUserFactsPage> {
  final _store = RememberedUserFactsStore(AppDatabase.instance);
  RememberedUserFacts? _facts;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final facts = await _store.load();
    if (mounted) setState(() => _facts = facts);
  }

  Future<void> _save(List<RememberedUserFact> items) async {
    setState(() => _saving = true);
    try {
      await _store.save(RememberedUserFacts(items));
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([int? index]) async {
    final items = _facts!.items;
    final original = index == null ? null : items[index];
    final subject = TextEditingController(text: original?.subject);
    final content = TextEditingController(text: original?.content);
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? '添加记住事项' : '编辑记住事项'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: subject,
                  maxLength: 24,
                  decoration: const InputDecoration(
                    labelText: '事项',
                    hintText: '例如：通常午饭时间',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return '请填写事项';
                    if (items.asMap().entries.any(
                      (e) => e.key != index && e.value.subject == text,
                    ))
                      return '已有同名事项，请编辑原事项';
                    return null;
                  },
                ),
                TextFormField(
                  controller: content,
                  maxLength: 120,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '事实',
                    hintText: '例如：我通常下午 1 点吃午饭',
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? '请填写事实' : null,
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
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final next = RememberedUserFact(
      subject: subject.text.trim(),
      content: content.text.trim(),
    );
    subject.dispose();
    content.dispose();
    if (saved != true || !mounted) return;
    final updated = items.toList();
    if (index == null) {
      updated.add(next);
    } else {
      updated[index] = next;
    }
    await _save(updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('记住事项')),
    floatingActionButton:
        _facts != null &&
            !_saving &&
            _facts!.items.length < RememberedUserFacts.maxItems
        ? FloatingActionButton(
            onPressed: () => _edit(),
            child: const Icon(Icons.add),
          )
        : null,
    body: _facts == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              const Text(
                '保存容易记错的日常小事。相关聊天会参考这些事实，不会把它们当成重要事情或提醒。当天临时变化以你当前说的话为准。',
              ),
              const SizedBox(height: 12),
              Text(
                '${_facts!.items.length}/${RememberedUserFacts.maxItems} 项 · 由你添加和维护',
              ),
              if (_facts!.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('还没有记住事项，点击 + 添加。'),
                ),
              for (final entry in _facts!.items.asMap().entries)
                Card(
                  child: ListTile(
                    title: Text(entry.value.subject),
                    subtitle: Text(entry.value.content),
                    onTap: _saving ? null : () => _edit(entry.key),
                    trailing: IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _saving
                          ? null
                          : () => _save(
                              _facts!.items.toList()..removeAt(entry.key),
                            ),
                    ),
                  ),
                ),
            ],
          ),
  );
}
