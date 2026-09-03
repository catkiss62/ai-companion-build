import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/moe/domain/moe_models.dart';
import '../../core/moe/infrastructure/sqlite_moe_repository.dart';
import '../reference/reference_library_page.dart';

class PersonalityAppearancePage extends StatefulWidget {
  const PersonalityAppearancePage({super.key});

  @override
  State<PersonalityAppearancePage> createState() =>
      _PersonalityAppearancePageState();
}

class _PersonalityAppearancePageState
    extends State<PersonalityAppearancePage> {
  static const _appearanceAsset =
      'assets/appearance/large_whale_mirror.jpg';

  final db = AppDatabase.instance;
  late final SqliteMoeRepository _moeRepository =
      SqliteMoeRepository(() => db.database);
  bool loading = true;
  bool _moeExpressionEnabled = true;
  MoeExpressionMode _moeExpressionMode = MoeExpressionMode.obvious;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final moeExpressionEnabled =
        (await db.getSetting('moe_expression_enabled')) != '0';
    final moeExpressionMode = await _moeRepository.loadExpressionMode();
    if (mounted) {
      setState(() {
        loading = false;
        _moeExpressionEnabled = moeExpressionEnabled;
        _moeExpressionMode = moeExpressionMode;
        status = null;
      });
    }
  }

  Future<void> _setMoeExpressionEnabled(bool value) async {
    await db.setSetting('moe_expression_enabled', value ? '1' : '0');
    if (mounted) {
      setState(() {
        _moeExpressionEnabled = value;
        status = value
            ? '动态萌属性已开始影响表达；内部数值和属性名称不会写进对话。'
            : '动态萌属性数值仍会旁路更新，但不再影响对话表达。';
      });
    }
  }

  Future<void> _setMoeExpressionMode(MoeExpressionMode mode) async {
    await _moeRepository.setExpressionMode(mode);
    if (mounted) {
      setState(() {
        _moeExpressionMode = mode;
        status = '萌属性表现强度已切换为“${mode.label}”。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外观与动态状态')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: const Text('表达与性格模块'),
                    subtitle: const Text(
                      '默认不注入性格种子。动作、幽默、相处姿态和特殊风格都在世界书中独立开关和编辑。',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReferenceLibraryPage(),
                      ),
                    ),
                  ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(status!),
                  ),
                const Divider(height: 36),
                Text(
                  '动态萌属性',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '这是与世界书分开的实验动态层，新版本默认开启并使用“明显”。九轴状态只给出当轮表达倾向；关闭后仍可旁路观察，不改变记忆、事实、学习候选、工具或主动联系资格。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('让萌属性影响对话表达'),
                        subtitle: const Text('只传递具体表达建议，不会让她报出属性或数值'),
                        value: _moeExpressionEnabled,
                        onChanged: _setMoeExpressionEnabled,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<MoeExpressionMode>(
                            segments: [
                              for (final mode in MoeExpressionMode.values)
                                ButtonSegment<MoeExpressionMode>(
                                  value: mode,
                                  label: Text(mode.label),
                                ),
                            ],
                            selected: {_moeExpressionMode},
                            onSelectionChanged: !_moeExpressionEnabled
                                ? null
                                : (selection) {
                                    if (selection.isNotEmpty) {
                                      _setMoeExpressionMode(selection.first);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
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
