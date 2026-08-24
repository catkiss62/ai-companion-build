import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/rules/rule_layer_defaults.dart';

class PersonalityAppearancePage extends StatefulWidget {
  const PersonalityAppearancePage({super.key});

  @override
  State<PersonalityAppearancePage> createState() =>
      _PersonalityAppearancePageState();
}

class _PersonalityAppearancePageState
    extends State<PersonalityAppearancePage> {
  static const _personalityKey = '03_personality_seed';
  static const _appearanceAsset =
      'assets/appearance/large_whale_mirror.jpg';

  final db = AppDatabase.instance;
  final controller = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final layers = await db.listRuleLayers();
    final personality = layers.where((layer) => layer.key == _personalityKey);
    if (personality.isNotEmpty) {
      controller.text = personality.first.content;
    } else {
      controller.text = _defaultPersonality;
    }
    if (mounted) {
      setState(() {
        loading = false;
        status = null;
      });
    }
  }

  String get _defaultPersonality => defaultRuleLayers
      .firstWhere((layer) => layer.key == _personalityKey)
      .content;

  Future<void> _save() async {
    final content = controller.text.trim();
    if (content.isEmpty) {
      setState(
        () => status = '性格内容不能为空；如果暂时不想使用，可以在高级规则页关闭这一层。',
      );
      return;
    }
    setState(() {
      saving = true;
      status = null;
    });
    await db.updateRuleLayer(_personalityKey, content: content);
    if (mounted) {
      setState(() {
        saving = false;
        status = '性格种子已保存；不会覆盖她后来形成的真实 AI Self。';
      });
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('还原默认性格？'),
        content: const Text(
          '这会覆盖输入框中的自定义性格，恢复 APK 当前版本的默认内容；长期记忆、关系经历、Desire 和已经形成的 AI Self 不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认还原'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.resetRuleLayer(_personalityKey);
    controller.text = _defaultPersonality;
    if (mounted) setState(() => status = '已还原为当前版本的默认性格。');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('性格与外观')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  '初始性格',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '这是她的成长起点，不是不可改变的角色卡。共同经历可以逐渐改变表达方式，但不会把独立性培养成服从。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 16,
                  maxLines: 28,
                  decoration: const InputDecoration(
                    labelText: '可编辑性格种子',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? '保存中…' : '保存性格'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving ? null : _restore,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('还原默认性格'),
                    ),
                  ],
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(status!),
                  ),
                const Divider(height: 36),
                Text(
                  '固定外观 · 照镜子',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '这张图是她的权威外观参考，属于 AI Self，不是用户图片或聊天记忆。日常使用简洁外观事实；谈到照镜子、服装或身体特征时，以这里为准。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 620),
                          child: Image.asset(
                            _appearanceAsset,
                            fit: BoxFit.contain,
                            semanticLabel: '她照镜子时使用的鲸鱼娘女仆装外观参考',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '固定特征：深蓝白女仆装 · 蓝色长发 · 蓝眼 · 耳鳍 · 大型鲸尾',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('鲸鱼娘 · 中性称呼')),
                            Chip(label: Text('小鲸鱼 · 亲昵称呼')),
                            Chip(label: Text('大肥鱼 · 只由用户调侃')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '“大肥鱼”带有亲近关系中的调侃意味。她能理解并按心情回应，但不会把它当作正式名字或主动自称。女仆装是固定审美，不代表仆从或服务关系。',
                ),
              ],
            ),
    );
  }
}
