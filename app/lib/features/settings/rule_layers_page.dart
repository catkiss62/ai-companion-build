import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/models/rule_layer.dart';

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('六层行为规则')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '01/03 常驻；02 只用于日常聊天；04/05 只在亲密 Session；06 只在亲密 Session 且检索到相关参考资料时加载。01 的 AI 本体身份不能被关闭。',
                ),
                const SizedBox(height: 12),
                ...layers.map((layer) => Card(
                      child: ListTile(
                        title: Text('${layer.key} · ${layer.title}'),
                        subtitle: Text(
                          '${layer.loadPolicy} · ${layer.content.length} 字符\n${layer.content.split('\n').take(2).join(' ')}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: Switch(
                          value: layer.enabled || layer.key == '01_core',
                          onChanged: layer.key == '01_core'
                              ? null
                              : (v) async {
                                  await db.updateRuleLayer(layer.key, enabled: v);
                                  await _load();
                                },
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: '编辑',
                              onPressed: () => _edit(layer),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: '恢复默认',
                              onPressed: () async {
                                await db.resetRuleLayer(layer.key);
                                await _load();
                              },
                              icon: const Icon(Icons.restart_alt),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}
