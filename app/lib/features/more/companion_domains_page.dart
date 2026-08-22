import 'package:flutter/material.dart';

import '../memory/memory_page.dart';
import '../personality/personality_lab_page.dart';
import '../reference/reference_library_page.dart';
import '../relationship/relationship_page.dart';
import '../self/personality_appearance_page.dart';
import '../settings/rule_layers_page.dart';

class CompanionDomainPage extends StatelessWidget {
  const CompanionDomainPage({super.key});

  @override
  Widget build(BuildContext context) => _DomainList(
        description: '她是谁、她正在形成怎样的自己。',
        entries: [
          _DomainEntry(
            icon: Icons.face_retouching_natural_rounded,
            title: '人格与外观',
            subtitle: '初始性格、可编辑底色和固定外观认知',
            onTap: () => _push(context, const PersonalityAppearancePage()),
          ),
          _DomainEntry(
            icon: Icons.checkroom_outlined,
            title: '性格试穿',
            subtitle: '体验临时风格，符合条件后再决定是否长期保留',
            onTap: () => _push(context, const PersonalityLabPage()),
          ),
        ],
      );
}

class RelationshipDomainPage extends StatelessWidget {
  const RelationshipDomainPage({super.key});

  @override
  Widget build(BuildContext context) => _DomainList(
        description: '关系时间、共同经历、记忆与没说完的话。',
        entries: [
          _DomainEntry(
            icon: Icons.favorite_outline_rounded,
            title: '你们之间',
            subtitle: '近期连续性、关系事件和未完成话题',
            onTap: () => _push(context, const RelationshipPage()),
          ),
          _DomainEntry(
            icon: Icons.memory_rounded,
            title: '长期记忆',
            subtitle: '认识天数、用户画像、共同经历与 AI Self',
            onTap: () => _push(context, const MemoryPage()),
          ),
          _DomainEntry(
            icon: Icons.menu_book_outlined,
            title: '参考资料',
            subtitle: '人物、世界与按需查阅的背景资料',
            onTap: () => _push(context, const ReferenceLibraryPage()),
          ),
        ],
      );
}

class CapabilitiesDomainPage extends StatelessWidget {
  const CapabilitiesDomainPage({super.key});

  @override
  Widget build(BuildContext context) => _DomainList(
        description: '她能调用的模型、联网、识图与语音能力。',
        entries: [
          _DomainEntry(
            icon: Icons.tune_rounded,
            title: '模型、联网、识图与 TTS',
            subtitle: '现有能力配置真源；后续再按能力继续细拆',
            onTap: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      );
}

class PerceptionDomainPage extends StatelessWidget {
  const PerceptionDomainPage({super.key});

  @override
  Widget build(BuildContext context) => _DomainList(
        description: '她能从这台手机感知到什么，以及当前连接是否健康。',
        entries: [
          _DomainEntry(
            icon: Icons.visibility_outlined,
            title: '权限与系统状态',
            subtitle: '轻视觉、通知、当前 App、悬浮陪伴与生命周期',
            onTap: () => Navigator.of(context).pushNamed('/system'),
          ),
        ],
      );
}

class DataAdvancedDomainPage extends StatelessWidget {
  const DataAdvancedDomainPage({super.key});

  @override
  Widget build(BuildContext context) => _DomainList(
        description: '规则、迁移、诊断和内部状态；日常聊天不必进入这里。',
        entries: [
          _DomainEntry(
            icon: Icons.rule_folder_outlined,
            title: '六大规则',
            subtitle: '运行规则的唯一编辑入口',
            onTap: () => _push(context, const RuleLayersPage()),
          ),
          _DomainEntry(
            icon: Icons.swap_horiz_rounded,
            title: '手机 / 平板接管',
            subtitle: '让同一个她换到另一台设备继续',
            onTap: () => Navigator.of(context).pushNamed('/transfer'),
          ),
          _DomainEntry(
            icon: Icons.psychology_alt_outlined,
            title: '内在状态诊断',
            subtitle: 'Thought、Desire、生命周期与主动联系调试',
            onTap: () => Navigator.of(context).pushNamed('/inner'),
          ),
          _DomainEntry(
            icon: Icons.health_and_safety_outlined,
            title: '真机自检',
            subtitle: '权限、API、存储和设备能力检查',
            onTap: () => Navigator.of(context).pushNamed('/preflight'),
          ),
          _DomainEntry(
            icon: Icons.fact_check_outlined,
            title: '综合验收',
            subtitle: '开发阶段的真实设备检查点',
            onTap: () => Navigator.of(context).pushNamed('/checkpoint'),
          ),
        ],
      );
}

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _DomainList extends StatelessWidget {
  const _DomainList({required this.description, required this.entries});

  final String description;
  final List<Widget> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: entries),
        ),
      ],
    );
  }
}

class _DomainEntry extends StatelessWidget {
  const _DomainEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
