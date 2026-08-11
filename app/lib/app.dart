import 'package:flutter/material.dart';

import 'features/chat/chat_page.dart';
import 'features/home/companion_home_page.dart';
import 'features/inner/inner_page.dart';
import 'features/more/companion_more_page.dart';
import 'features/settings/settings_page.dart';
import 'features/system/system_page.dart';
import 'features/system/preflight_diagnostics_page.dart';
import 'features/system/real_device_checkpoint_page.dart';
import 'features/transfer/transfer_page.dart';

class AiCompanionApp extends StatelessWidget {
  const AiCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Companion',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFB082FF),
        useMaterial3: true,
      ),
      routes: {
        '/transfer': (_) => const _SecondaryScaffold(
              title: '手机 / 平板接管',
              child: TransferPage(),
            ),
        '/system': (_) => const _SecondaryScaffold(
              title: '权限与系统状态',
              child: SystemPage(),
            ),
        '/preflight': (_) => const _SecondaryScaffold(
              title: '真机测试前自检',
              child: PreflightDiagnosticsPage(),
            ),
        '/checkpoint': (_) => const _SecondaryScaffold(
              title: '第一次综合真机验收',
              child: RealDeviceCheckpointPage(),
            ),
        '/settings': (_) => const _SecondaryScaffold(
              title: 'AI 与陪伴设置',
              child: SettingsPage(),
            ),
        '/inner': (_) => const _SecondaryScaffold(
              title: '内在状态诊断',
              child: InnerPage(),
            ),
      },
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      CompanionHomePage(onOpenChat: _openChat),
      const ChatPage(),
      const CompanionMorePage(),
    ];
  }

  void _openChat() {
    if (!mounted) return;
    setState(() => index = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '她',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: '更多',
          ),
        ],
      ),
    );
  }
}

class _SecondaryScaffold extends StatelessWidget {
  const _SecondaryScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
