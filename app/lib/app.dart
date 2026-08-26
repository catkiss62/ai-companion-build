import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/platform/android_bridge.dart';
import 'features/chat/chat_page.dart';
import 'features/home/companion_home_page.dart';
import 'features/inner/inner_page.dart';
import 'features/more/companion_more_page.dart';
import 'features/more/companion_domains_page.dart';
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
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
        '/companion': (_) => const _SecondaryScaffold(
              title: '她',
              child: CompanionDomainPage(),
            ),
        '/relationship': (_) => const _SecondaryScaffold(
              title: '你们',
              child: RelationshipDomainPage(),
            ),
        '/capabilities': (_) => const _SecondaryScaffold(
              title: '能力',
              child: CapabilitiesDomainPage(),
            ),
        '/perception': (_) => const _SecondaryScaffold(
              title: '手机感知',
              child: PerceptionDomainPage(),
            ),
        '/data-advanced': (_) => const _SecondaryScaffold(
              title: '数据与高级',
              child: DataAdvancedDomainPage(),
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int index = 0;
  StreamSubscription<void>? _openChatSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openChatSubscription = AndroidBridge.instance.openChatLaunches.listen((_) {
      _openChat();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeOpenChatLaunch();
    });
  }

  Future<void> _consumeOpenChatLaunch() async {
    final requested = await AndroidBridge.instance.consumeOpenChatLaunch();
    if (!mounted || !requested) return;
    setState(() => index = 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeOpenChatLaunch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openChatSubscription?.cancel();
    super.dispose();
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
        child: IndexedStack(
          index: index,
          children: [
            CompanionHomePage(onOpenChat: _openChat),
            ChatPage(active: index == 1),
            const CompanionMorePage(),
          ],
        ),
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
