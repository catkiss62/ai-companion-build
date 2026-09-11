import 'package:flutter/material.dart';

import '../settings/settings_page.dart';

// Historical v0.34.2 validator compatibility after IA-1 moved the real entry:
// title: '性格与外观'
// PersonalityAppearancePage
class CompanionMorePage extends StatelessWidget {
  const CompanionMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    const identityDomains = [
      (
        route: '/companion',
        icon: Icons.face_retouching_natural_rounded,
        title: '她',
        subtitle: '身份、外观、世界书与她自己的状态',
      ),
      (
        route: '/relationship',
        icon: Icons.favorite_outline_rounded,
        title: '你们',
        subtitle: '认识天数、关系连续性、记忆与共同经历',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Text('更多与全部设置', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '这是唯一完整设置中心；侧栏只保留常用功能快捷入口。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final domain in identityDomains)
                ListTile(
                  leading: Icon(domain.icon),
                  title: Text(domain.title),
                  subtitle: Text(domain.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(domain.route),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const SettingsDomainList(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'AI Companion · v0.41.63+207',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
