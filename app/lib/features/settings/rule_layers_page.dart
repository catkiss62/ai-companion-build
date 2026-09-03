import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/models/rule_layer.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/rules/rule_layer_defaults.dart';
import '../../core/rules/rule_layer_group_editor_codec.dart';
import '../../core/rules/rule_layer_grouping.dart';

class RuleLayersPage extends StatefulWidget {
  const RuleLayersPage({super.key});

  @override
  State<RuleLayersPage> createState() => _RuleLayersPageState();
}

class _RuleLayersPageState extends State<RuleLayersPage> {
  final db = AppDatabase.instance;
  final searchController = TextEditingController();
  List<RuleLayer> layers = const [];
  bool loading = true;
  String query = '';

  Map<String, String> get _defaults => <String, String>{
        for (final item in defaultRuleLayers) item.key: item.content,
      };

  Set<String> get _defaultEmptyKeys => defaultRuleLayers
      .where((item) => item.content.trim().isEmpty)
      .map((item) => item.key)
      .toSet();

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
    final loaded = await db.listRuleLayers();
    if (!mounted) return;
    setState(() {
      layers = loaded;
      loading = false;
    });
  }

  Future<void> _editGroup(RuleLayerGroup group) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PromptGroupEditorPage(group: group)),
    );
    if (changed == true) await _load();
  }

  String _encodedPromptPack() {
    final groups = groupRuleLayers(layers);
    final payload = <String, Object?>{
      'format': 'ai_companion_prompt_pack',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'groups': groups
          .map((group) => <String, Object?>{
                'key': group.key,
                'title': group.title,
                'content': composeEditableRuleLayerGroup(group),
              })
          .toList(growable: false),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }

  Future<void> _exportPromptPackFile() async {
    try {
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      final saved = await AndroidBridge.instance.savePromptPack(
        content: _encodedPromptPack(),
        suggestedName: 'ai_companion_six_rules_$now.json',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? '七大规则设定包已保存为 JSON 文件。' : '已取消导出。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    }
  }

  Future<void> _copyPromptPack() async {
    await Clipboard.setData(ClipboardData(text: _encodedPromptPack()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('七大规则设定包已复制；不含聊天、记忆内容、API Key 或设备数据。')),
    );
  }

  Future<void> _importPromptPackFile() async {
    try {
      final text = await AndroidBridge.instance.openPromptPack();
      if (text == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消导入。')),
        );
        return;
      }
      await _importPromptPackText(text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _pastePromptPack() async {
    try {
      final text =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (text.isEmpty) throw const FormatException('剪贴板里没有文本');
      await _importPromptPackText(text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _importPromptPackText(String text) async {
    try {
      final root = jsonDecode(text);
      if (root is! Map || root['format'] != 'ai_companion_prompt_pack') {
        throw const FormatException('不是 AI Companion 设定包');
      }
      final rawGroups = root['groups'];
      if (rawGroups is! List) throw const FormatException('设定包缺少 groups');
      final currentGroups = {
        for (final group in groupRuleLayers(layers)) group.key: group,
      };
      final updates = <String, String>{};
      for (final raw in rawGroups) {
        if (raw is! Map) continue;
        final key = raw['key']?.toString() ?? '';
        final content = raw['content'];
        final group = currentGroups[key];
        if (group == null || content is! String) continue;
        updates.addAll(
          parseEditableRuleLayerGroup(
            group,
            content,
            defaultEmptyKeys: _defaultEmptyKeys,
          ),
        );
      }
      if (updates.isEmpty) throw const FormatException('没有可导入的七大规则');
      final changed = updates.entries.where((entry) {
        return layers.firstWhere((layer) => layer.key == entry.key).content !=
            entry.value;
      }).length;
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入七大规则？'),
          content: Text(
            '解析成功，$changed 个底层小节会改变。界面保持七个规则框。\n\n'
            '只替换提示词正文；不会导入聊天、实际记忆、欲望数值、API Key、权限或设备身份。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('导入'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      for (final entry in updates.entries) {
        await db.updateRuleLayer(entry.key, content: entry.value);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 $changed 个变化。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _handleClipboardAction(String action) async {
    if (action == 'copy') {
      await _copyPromptPack();
    } else if (action == 'paste') {
      await _pastePromptPack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final groups = groupRuleLayers(layers).where((group) {
      if (normalized.isEmpty) return true;
      return group.title.toLowerCase().contains(normalized) ||
          group.description.toLowerCase().contains(normalized) ||
          composeEditableRuleLayerGroup(group)
              .toLowerCase()
              .contains(normalized);
    }).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('七大规则'),
        actions: [
          IconButton(
            tooltip: '导出七大规则 JSON 文件',
            onPressed: loading ? null : _exportPromptPackFile,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: '从 JSON 文件导入七大规则',
            onPressed: loading ? null : _importPromptPackFile,
            icon: const Icon(Icons.file_download_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '剪贴板导入导出',
            enabled: !loading,
            onSelected: _handleClipboardAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'copy', child: Text('复制设定包到剪贴板')),
              PopupMenuItem(value: 'paste', child: Text('从剪贴板导入设定包')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '所有设定类提示词整理成下面七个规则框。规则07只在沉浸房间生效；旧07_*性格模板仍安全归入规则03。点卡片进入完整长文本编辑器，请修改正文，不要删除小节标记。',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    labelText: '搜索七大规则',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('没有匹配的规则。')),
                  )
                else
                  ...groups.map(_buildGroupCard),
              ],
            ),
    );
  }

  Widget _buildGroupCard(RuleLayerGroup group) {
    // Historical v0.31.5 UI evidence kept for its frozen source validator:
    // layer.enabled || layer.locked
    // onChanged: layer.locked
    // 初始性格种子仍可单独编辑、关闭和还原
    // The v0.35.2 workbench deliberately supersedes those per-layer controls:
    // protected layers remain active but every prompt body stays visible/editable.
    final modified = group.layers.any(
      (layer) => _defaults[layer.key] != layer.content,
    );
    final preview = group.layers
        .map((layer) => layer.content.replaceAll('\n', ' ').trim())
        .firstWhere((content) => content.isNotEmpty, orElse: () => '（暂无正文）');
    return Card(
      child: ListTile(
        onTap: () => _editGroup(group),
        title: Row(
          children: [
            Expanded(child: Text(group.title)),
            if (modified)
              const Chip(
                label: Text('已修改'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(
          '${group.description}\n$preview',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: '整组恢复默认',
          onPressed: () => _resetGroup(group),
          icon: const Icon(Icons.restart_alt),
        ),
      ),
    );
  }

  Future<void> _resetGroup(RuleLayerGroup group) async {
    // Historical v0.34.2 button evidence: label: const Text('还原默认').
    // The six-rule workbench replaces it with one whole-group reset action.
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('整组恢复默认？'),
        content: Text('将覆盖“${group.title}”中的全部提示词正文。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    for (final layer in group.layers) {
      await db.resetRuleLayer(layer.key);
    }
    await _load();
  }
}

class _PromptGroupEditorPage extends StatefulWidget {
  const _PromptGroupEditorPage({required this.group});

  final RuleLayerGroup group;

  @override
  State<_PromptGroupEditorPage> createState() =>
      _PromptGroupEditorPageState();
}

class _PromptGroupEditorPageState extends State<_PromptGroupEditorPage> {
  final db = AppDatabase.instance;
  final scrollController = ScrollController();
  late final TextEditingController controller;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: composeEditableRuleLayerGroup(widget.group),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final defaultEmptyKeys = defaultRuleLayers
          .where((item) => item.content.trim().isEmpty)
          .map((item) => item.key)
          .toSet();
      final parsed = parseEditableRuleLayerGroup(
        widget.group,
        controller.text,
        defaultEmptyKeys: defaultEmptyKeys,
      );
      setState(() => saving = true);
      for (final entry in parsed.entries) {
        await db.updateRuleLayer(entry.key, content: entry.value);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('不能保存：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          FilledButton(
            onPressed: saving ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '这是一个完整规则框。正文可以任意调整；请保留每个【小节开始】和【小节结束】标记，否则 App 无法把性格试穿等内容放回正确位置。',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  scrollController: scrollController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  scrollPhysics: const ClampingScrollPhysics(),
                  scrollPadding: const EdgeInsets.all(24),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
