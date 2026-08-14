import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/rule_layer.dart';
import '../../core/rules/rule_layer_grouping.dart';

class RuleLayersPage extends StatefulWidget {
  const RuleLayersPage({super.key});

  @override
  State<RuleLayersPage> createState() => _RuleLayersPageState();
}

class _RuleLayersPageState extends State<RuleLayersPage> {
  final db = AppDatabase.instance;
  List<RuleLayer> layers = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    layers = await db.listRuleLayers();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit(RuleLayer layer) async {
    final controller = TextEditingController(text: layer.content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(layer.title),
        content: SizedBox(
          width: 720,
          child: TextField(
            controller: controller,
            minLines: 14,
            maxLines: 28,
            decoration: InputDecoration(
              helperText: '加载策略：${layer.loadPolicy}',
              border: const OutlineInputBorder(),
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
    );
    if (saved == true) {
      await db.updateRuleLayer(layer.key, content: controller.text.trim());
      await _load();
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupRuleLayers(layers);
    return Scaffold(
      appBar: AppBar(title: const Text('行为规则层')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '同类规则按维护职责归在一张卡片中，内部小节仍分别保存，不会互相覆盖。01 身份/关系基础锁定常驻；03 行为原则常驻，初始性格种子仍可单独编辑和关闭。04/05 只在亲密 Session；06 只在亲密 Session 且检索到相关资料时加载。',
                ),
                const SizedBox(height: 12),
                ...groups.map(_buildGroupCard),
              ],
            ),
    );
  }

  Widget _buildGroupCard(RuleLayerGroup group) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(group.title),
            subtitle: Text(group.description),
          ),
          const Divider(height: 1),
          for (var i = 0; i < group.layers.length; i++) ...[
            _buildSectionTile(group.layers[i]),
            if (i < group.layers.length - 1)
              const Divider(height: 1, indent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTile(RuleLayer layer) {
    final preview = layer.content.split('\n').take(2).join(' ');
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(ruleLayerSectionTitle(layer))),
          if (layer.locked)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.lock_outline, size: 18),
            ),
        ],
      ),
      subtitle: Text(
        '${layer.loadPolicy} · ${layer.content.length} 字符\n$preview',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Switch(
        value: layer.enabled || layer.locked,
        onChanged: layer.locked
            ? null
            : (value) async {
                await db.updateRuleLayer(layer.key, enabled: value);
                await _load();
              },
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '编辑 ${ruleLayerSectionTitle(layer)}',
            onPressed: () => _edit(layer),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '恢复 ${ruleLayerSectionTitle(layer)} 默认内容',
            onPressed: () async {
              await db.resetRuleLayer(layer.key);
              await _load();
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
    );
  }
}
