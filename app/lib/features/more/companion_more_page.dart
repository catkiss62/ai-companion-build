import 'package:flutter/material.dart';

import '../memory/memory_page.dart';
import '../reference/reference_library_page.dart';
import '../relationship/relationship_page.dart';

class CompanionMorePage extends StatelessWidget {
  const CompanionMorePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Text('更多', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '长期关系、资料与设备管理都在这里；平时不需要把这些工程状态摆在你们之间。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        _Group(
          title: '你们之间',
          children: [
            _Entry(
              icon: Icons.favorite_outline_rounded,
              title: '你们之间',
              subtitle: '最近几天、她仍在意的事、没说完的话与共同经历',
              onTap: () => _open(context, const RelationshipPage()),
            ),
            _Entry(
              icon: Icons.memory_rounded,
              title: '长期记忆',
              subtitle: '她长期保留下来的资料、经历、偏好与 AI Self',
              onTap: () => _open(context, const MemoryPage()),
            ),
            _Entry(
              icon: Icons.menu_book_outlined,
              title: '参考资料',
              subtitle: '人物、世界与其他按需查阅的背景资料',
              onTap: () => _open(context, const ReferenceLibraryPage()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Group(
          title: '设备',
          children: [
            _Entry(
              icon: Icons.swap_horiz_rounded,
              title: '手机 / 平板接管',
              subtitle: '让同一个她安全地换到另一台设备继续',
              onTap: () => Navigator.of(context).pushNamed('/transfer'),
            ),
            _Entry(
              icon: Icons.security_outlined,
              title: '权限与系统状态',
              subtitle: '悬浮、使用情况、通知、后台恢复与系统诊断',
              onTap: () => Navigator.of(context).pushNamed('/system'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Group(
          title: '设置',
          children: [
            _Entry(
              icon: Icons.tune_rounded,
              title: 'AI 与陪伴设置',
              subtitle: '模型、思考、TTS、记忆、感知与主动联系配置',
              onTap: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: const Text('高级与诊断'),
          subtitle: const Text('开发阶段保留，不作为日常关系界面'),
          children: [
            ListTile(
              leading: const Icon(Icons.psychology_alt_outlined),
              title: const Text('内在状态诊断'),
              subtitle: const Text('Thought / Desire / lifecycle / 主动联系调试'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pushNamed('/inner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'AI Companion · v0.31.2',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 4),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
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
