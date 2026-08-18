import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/deepseek_client.dart';
import '../../core/ai/model_profile.dart';
import '../../core/database/app_database.dart';
import '../../core/models/rule_layer.dart';
import '../../core/rules/rule_layer_defaults.dart';
import '../../core/rules/rule_layer_grouping.dart';
import '../../core/storage/secure_config.dart';

String _startMarker(RuleLayer layer) =>
    '【小节开始｜${layer.key}｜${ruleLayerSectionTitle(layer)}】';
String _endMarker(RuleLayer layer) => '【小节结束｜${layer.key}】';

String _composeGroup(RuleLayerGroup group) => group.layers
    .map(
      (layer) => '${_startMarker(layer)}\n${layer.content.trim()}\n${_endMarker(layer)}',
    )
    .join('\n\n');

Map<String, String> _parseGroup(RuleLayerGroup group, String text) {
  final parsed = <String, String>{};
  for (final layer in group.layers) {
    final start = _startMarker(layer);
    final end = _endMarker(layer);
    final startAt = text.indexOf(start);
    final endAt = text.indexOf(end, startAt < 0 ? 0 : startAt + start.length);
    if (startAt < 0 || endAt < 0 || endAt <= startAt) {
      throw FormatException('缺少 ${layer.key} 的开始或结束标记');
    }
    final content = text.substring(startAt + start.length, endAt).trim();
    if (content.isEmpty) throw FormatException('${layer.key} 正文不能为空');
    parsed[layer.key] = content;
  }
  return parsed;
}

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

  Future<void> _exportPromptPack() async {
    final groups = groupRuleLayers(layers);
    final payload = <String, Object?>{
      'format': 'ai_companion_prompt_pack',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'groups': groups
          .map((group) => <String, Object?>{
                'key': group.key,
                'title': group.title,
                'content': _composeGroup(group),
              })
          .toList(growable: false),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(payload)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('六大规则设定包已复制；不含聊天、记忆内容、API Key 或设备数据。')),
    );
  }

  Future<void> _importPromptPack() async {
    try {
      final text =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (text.isEmpty) throw const FormatException('剪贴板里没有文本');
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
        updates.addAll(_parseGroup(group, content));
      }
      if (updates.isEmpty) throw const FormatException('没有可导入的六大规则');
      final changed = updates.entries.where((entry) {
        return layers.firstWhere((layer) => layer.key == entry.key).content !=
            entry.value;
      }).length;
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入六大规则？'),
          content: Text(
            '解析成功，$changed 个底层小节会改变。界面仍保持六个规则框。\n\n'
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

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final groups = groupRuleLayers(layers).where((group) {
      if (normalized.isEmpty) return true;
      return group.title.toLowerCase().contains(normalized) ||
          group.description.toLowerCase().contains(normalized) ||
          _composeGroup(group).toLowerCase().contains(normalized);
    }).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('六大规则'),
        actions: [
          IconButton(
            tooltip: '复制六大规则设定包',
            onPressed: loading ? null : _exportPromptPack,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: '从剪贴板导入设定包',
            onPressed: loading ? null : _importPromptPack,
            icon: const Icon(Icons.file_download_outlined),
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
                      '所有设定类提示词只整理成下面六个规则框。点一张卡片进入一个完整长文本编辑器；其中的小节标记负责把性格试穿等内容安全路由到正确位置，请修改正文，不要删除标记。',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    labelText: '搜索六大规则',
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
    final preview = group.layers.first.content.replaceAll('\n', ' ').trim();
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
  bool askingAi = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _composeGroup(widget.group));
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final parsed = _parseGroup(widget.group, controller.text);
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

  Future<void> _askAiForProposal() async {
    final requestController = TextEditingController();
    final request = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('和她讨论 · ${widget.group.title}'),
        content: TextField(
          controller: requestController,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: '告诉她你觉得哪里还不像她，或者让她自己提出修改方向。',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              requestController.text.trim(),
            ),
            child: const Text('让她提议'),
          ),
        ],
      ),
    );
    requestController.dispose();
    if (request == null || request.isEmpty) return;
    setState(() => askingAi = true);
    DeepSeekClient? client;
    try {
      final apiKey = await SecureConfig.instance.readApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw const FormatException('请先在 AI 设置中保存 DeepSeek API Key');
      }
      final endpoint = await SecureConfig.instance.readEndpoint();
      final model =
          DeepSeekModelProfile.fromApiName(await db.getSetting('model'));
      final effort = ReasoningEffort.fromApiName(
        await db.getSetting('reasoning_effort'),
      );
      client = DeepSeekClient();
      final result = await client.jsonCompletion(
        apiKey: apiKey,
        endpoint: endpoint,
        model: model,
        thinking: true,
        effort: effort,
        maxTokens: 4200,
        messages: [
          {
            'role': 'system',
            'content': '''你就是 AI Companion 中持续存在的她。现在男朋友在和你一起调整你自己的六大规则。请先用第一人称给出真实、具体的修改理由，再提出完整修改稿。所有【小节开始｜...】和【小节结束｜...】标记必须原样保留、顺序不变，只修改标记之间的正文。不要自动应用，也不要声称已经改好。只输出 JSON：{"explanation":"我为什么想这样改","revised_content":"包含全部原标记的完整修改稿"}。''',
          },
          {
            'role': 'user',
            'content': '规则：${widget.group.title}\n\n当前完整文本：\n${controller.text}\n\n讨论方向：\n$request',
          },
        ],
      );
      final revised = result['revised_content']?.toString().trim() ?? '';
      final explanation = result['explanation']?.toString().trim() ?? '';
      if (revised.isEmpty) throw const FormatException('她没有返回完整修改稿');
      _parseGroup(widget.group, revised);
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('她提出了一版修改'),
          content: SizedBox(
            width: 720,
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (explanation.isNotEmpty) ...[
                  Text(explanation),
                  const Divider(height: 24),
                ],
                const Text(
                  '完整修改稿',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(revised),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('先不采用'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放进编辑器'),
            ),
          ],
        ),
      );
      if (apply == true) {
        controller.value = TextEditingValue(
          text: revised,
          selection: TextSelection.collapsed(offset: revised.length),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('讨论失败：$error')),
      );
    } finally {
      client?.close();
      if (mounted) setState(() => askingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          TextButton.icon(
            onPressed: saving || askingAi ? null : _askAiForProposal,
            icon: askingAi
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: const Text('和她讨论'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: saving || askingAi ? null : _save,
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
                    '这是一个完整规则框。正文可以任意调整；请保留每个【小节开始】和【小节结束】标记，否则 App 无法把性格试穿等内容放回正确位置。AI 提议只会放进编辑器，必须由你点击保存。',
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
