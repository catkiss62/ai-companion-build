import 'package:flutter/material.dart';

import 'settings_category_pages.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final domains = <_SettingsDomain>[
      _SettingsDomain(
        icon: Icons.hub_outlined,
        title: '模型与联网',
        subtitle: 'DeepSeek、千问视觉、Tavily、Agnes 与公开网页发现',
        page: const ModelNetworkSettingsPage(),
      ),
      _SettingsDomain(
        icon: Icons.psychology_alt_outlined,
        title: '记忆与成长',
        subtitle: '长期记忆、Thought、Self-Drive、AI Self 与关系连续性',
        page: const MemoryGrowthSettingsPage(),
      ),
      _SettingsDomain(
        icon: Icons.notifications_active_outlined,
        title: '主动联系与感知',
        subtitle: '主动频率、通知方式、隐私、提示音与环境感知',
        page: const ProactivePerceptionSettingsPage(),
      ),
      _SettingsDomain(
        icon: Icons.auto_awesome_outlined,
        title: '语音与聊天呈现',
        subtitle: '本地 TTS、情绪、立绘、背景、透明度与文字演出',
        page: const PresentationSettingsPage(),
      ),
      _SettingsDomain(
        icon: Icons.devices_other_outlined,
        title: '设备与数据',
        subtitle: 'Active Brain、新上下文、设备接管、权限与备份',
        page: const DeviceDataSettingsPage(),
      ),
      _SettingsDomain(
        icon: Icons.build_circle_outlined,
        title: '诊断与开发',
        subtitle: '快速自检、深度验收、运行维护与开发者入口',
        page: const DiagnosticsDevelopmentSettingsPage(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        Text(
          '按用途找到设置',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          '常用聊天选项也保留在头像侧栏；两处使用同一份设置，不会互相覆盖。',
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
              for (var index = 0; index < domains.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  leading: Icon(domains[index].icon),
                  title: Text(domains[index].title),
                  subtitle: Text(domains[index].subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => domains[index].page),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsDomain {
  const _SettingsDomain({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}
