import 'package:flutter/material.dart';
import '../../core/agent/work_model.dart';
import '../../core/ai/first_channel_model.dart';
import '../../core/ai/model_profile.dart';
import '../../core/database/app_database.dart';

class WorkModelSettings extends StatefulWidget {
  const WorkModelSettings(this.db, {super.key});
  final AppDatabase db;
  @override
  State<WorkModelSettings> createState() => _WorkModelSettingsState();
}

class _WorkModelSettingsState extends State<WorkModelSettings> {
  String? name;
  String level = '';
  String inheritedName = '', inheritedLevel = '';
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final db = widget.db;
    final model = await FirstChannelModel.read(db);
    final effort = await FirstChannelModel.readEffort(db);
    final override = await db.getSetting(WorkModel.modelKey) ?? '';
    final value = await db.getSetting(WorkModel.effortKey) ?? '';
    if (mounted) setState(() {
      name = override; level = value;
      inheritedName = model.apiName; inheritedLevel = effort.label;
    });
  }

  Future<void> edit() async {
    var draft = name ?? '';
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('工作模型'), content: TextFormField(initialValue: draft,
        autofocus: true, maxLength: 120, onChanged: (v) => draft = v.trim(),
        decoration: InputDecoration(hintText: inheritedName, labelText: '第一通道模型名称')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('跟随第一通道')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, draft), child: const Text('保存')),
      ],
    ));
    if (value == null) return;
    await widget.db.setSetting(WorkModel.modelKey, value);
    await load();
  }

  @override
  Widget build(BuildContext context) => name == null ? const SizedBox.shrink() : Column(children: [
    ListTile(title: const Text('工作模型'), subtitle: Text(name!.isEmpty ? '跟随第一通道 · $inheritedName' : name!),
      onTap: edit),
    ListTile(title: const Text('思考力度'), trailing: DropdownButton<String>(
      value: WorkModel.levels.any((e) => e.apiName == level) ? level : '',
      items: [DropdownMenuItem(value: '', child: Text('跟随 · $inheritedLevel')),
        for (final ReasoningEffort e in WorkModel.levels) DropdownMenuItem(value: e.apiName, child: Text(e.label))],
      onChanged: (v) async { if(v != null) { await widget.db.setSetting(WorkModel.effortKey,v); await load(); } },
    )),
  ]);
}
