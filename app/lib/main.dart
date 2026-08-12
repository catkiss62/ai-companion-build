import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'background_main.dart' as background_runtime;
import 'core/database/app_database.dart';


@pragma('vm:entry-point')
Future<void> companionBackgroundMain() =>
    background_runtime.companionBackgroundMain();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => _FatalFlutterError(details: details);
  runApp(const _StartupRecoveryRoot());
}

class _StartupRecoveryRoot extends StatefulWidget {
  const _StartupRecoveryRoot();

  @override
  State<_StartupRecoveryRoot> createState() => _StartupRecoveryRootState();
}

class _StartupRecoveryRootState extends State<_StartupRecoveryRoot> {
  final List<_StartupStep> _steps = <_StartupStep>[
    const _StartupStep('Flutter 首帧', _StartupStepState.pending),
    const _StartupStep('打开本地数据库', _StartupStepState.pending),
    const _StartupStep('检查本机身份', _StartupStepState.pending),
    const _StartupStep('进入主界面', _StartupStepState.pending),
  ];

  bool _running = false;
  bool _ready = false;
  String? _error;
  int? _failedStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markDone(0);
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    if (_running || _ready) return;
    setState(() {
      _running = true;
      _error = null;
      _failedStep = null;
      for (var i = 1; i < _steps.length; i++) {
        _steps[i] = _StartupStep(_steps[i].label, _StartupStepState.pending);
      }
    });

    try {
      await _runStep(
        1,
        () => AppDatabase.instance.database.timeout(const Duration(seconds: 30)),
      );
      await _runStep(
        2,
        () => AppDatabase.instance.ensureDeviceId().timeout(const Duration(seconds: 10)),
      );
      _markRunning(3);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _markDone(3);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _running = false;
      });
    } on TimeoutException catch (error) {
      _failCurrent('初始化超时：${error.message ?? '某个启动步骤没有在限定时间内完成'}');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AI Companion startup recovery',
          context: ErrorDescription('while bootstrapping the local companion runtime'),
        ),
      );
      _failCurrent('${error.runtimeType}: $error');
    }
  }

  Future<void> _runStep(int index, Future<Object?> Function() action) async {
    _markRunning(index);
    await action();
    _markDone(index);
  }

  void _markRunning(int index) {
    if (!mounted) return;
    setState(() {
      _steps[index] = _StartupStep(_steps[index].label, _StartupStepState.running);
      _failedStep = index;
    });
  }

  void _markDone(int index) {
    if (!mounted) return;
    setState(() {
      _steps[index] = _StartupStep(_steps[index].label, _StartupStepState.done);
      if (_failedStep == index) _failedStep = null;
    });
  }

  void _failCurrent(String message) {
    if (!mounted) return;
    setState(() {
      _running = false;
      _error = message;
      final index = _failedStep;
      if (index != null) {
        _steps[index] = _StartupStep(_steps[index].label, _StartupStepState.failed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AiCompanionApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Companion Startup',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFB082FF),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                shrinkWrap: true,
                children: [
                  const Icon(Icons.favorite_rounded, size: 54),
                  const SizedBox(height: 18),
                  Text(
                    'AI Companion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'v0.30.1 · Overlay Touch Recovery',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final step in _steps) _StartupStepRow(step: step),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('启动没有完成', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            SelectableText(_error!),
                            const SizedBox(height: 12),
                            const Text(
                              '这条信息只显示当前启动阶段，不会读取或显示聊天正文、API Key、通知正文或 Reference 内容。',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _running ? null : _bootstrap,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重新尝试'),
                    ),
                  ] else if (_running) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Text('第一次启动可能需要几秒。数据库或本机身份如果异常，会直接显示在哪一步。', textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StartupStepState { pending, running, done, failed }

class _StartupStep {
  const _StartupStep(this.label, this.state);
  final String label;
  final _StartupStepState state;
}

class _StartupStepRow extends StatelessWidget {
  const _StartupStepRow({required this.step});
  final _StartupStep step;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (step.state) {
      _StartupStepState.pending => (Icons.radio_button_unchecked_rounded, Theme.of(context).colorScheme.outline),
      _StartupStepState.running => (Icons.timelapse_rounded, Theme.of(context).colorScheme.primary),
      _StartupStepState.done => (Icons.check_circle_rounded, Colors.greenAccent),
      _StartupStepState.failed => (Icons.error_rounded, Theme.of(context).colorScheme.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(step.label)),
        ],
      ),
    );
  }
}

class _FatalFlutterError extends StatelessWidget {
  const _FatalFlutterError({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF101014),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Companion · Flutter UI error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SelectableText('${details.exceptionAsString()}'),
                  const SizedBox(height: 12),
                  const Text('请把这一页截图发回即可。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
