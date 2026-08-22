import 'package:flutter/material.dart';

class CompanionMorePage extends StatelessWidget {
  const CompanionMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    const domains = [
      (
        route: '/companion',
        icon: Icons.face_retouching_natural_rounded,
        title: '她',
        subtitle: '人格、外观、性格试穿与她自己的状态',
      ),
      (
        route: '/relationship',
        icon: Icons.favorite_outline_rounded,
        title: '你们',
        subtitle: '认识天数、关系连续性、记忆与共同经历',
      ),
      (
        route: '/capabilities',
        icon: Icons.auto_awesome_motion_outlined,
        title: '能力',
        subtitle: '模型、联网、识图、TTS 与后续 Agent 工具',
      ),
      (
        route: '/perception',
        icon: Icons.visibility_outlined,
        title: '手机感知',
        subtitle: '当前 App、轻视觉、通知与悬浮陪伴状态',
      ),
      (
        route: '/data-advanced',
        icon: Icons.storage_outlined,
        title: '数据与高级',
        subtitle: '规则、迁移、诊断和开发者检查',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Text('功能分类', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '先按稳定职责分开入口；这次不换皮肤，也不复制任何配置状态。',
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
              for (final domain in domains)
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
        Center(
          child: Text(
            'AI Companion · v0.36.0+85',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
