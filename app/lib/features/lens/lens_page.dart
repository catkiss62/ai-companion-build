import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/app_database.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_service.dart';
import 'lens_session.dart';

class LensPage extends StatefulWidget {
  const LensPage({super.key, required this.travel});
  final bool travel;
  @override
  State<LensPage> createState() => _LensPageState();
}

class _LensPageState extends State<LensPage> with WidgetsBindingObserver {
  static const channel = MethodChannel('ai_companion/lens');
  final session = LensSession();
  final input = TextEditingController();
  final audio = TtsPlaybackQueue(service: TtsService());
  final scroll = ScrollController();
  final clock = Stopwatch()..start();
  int? view;
  int epoch = 0, frames = 0, batches = 0, calls = 0, elapsed = 0;
  bool foreground = true, manual = false, granted = false, started = false;
  bool reading = false, userBusy = false, listening = false;
  bool checkingStats = false;
  Duration nextTravel = Duration.zero;
  Timer? timer;
  LensRequest? pending;
  String? status;
  String? pendingVoice;

  bool get active => mounted && foreground && !manual && granted && started;
  Future<T?> native<T>(String method, [Map<String, Object> args = const {}]) =>
      channel.invokeMethod<T>(method, {'id': view, ...args});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(AndroidBridge.instance.setImmersiveChatPageVisible(true));
  }

  Future<void> permission() async {
    try {
      granted = await native<bool>('permission') == true;
      if (!mounted) return;
      setState(() => status = granted ? null : '打开相机需要相机权限');
      if (granted) await start();
    } on PlatformException catch (e) {
      if (mounted) setState(() => status = e.message);
    }
  }

  Future<void> start() async {
    final token = epoch;
    if (!mounted ||
        !foreground ||
        manual ||
        !granted ||
        view == null ||
        started)
      return;
    try {
      final ok = await native<bool>('start') == true;
      if (!mounted || token != epoch || !ok) return;
      setState(() {
        started = true;
        status = null;
      });
      nextTravel = clock.elapsed + const Duration(seconds: 2);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (pendingVoice != null) {
          final words = pendingVoice!;
          pendingVoice = null;
          unawaited(ask(words));
        } else if (widget.travel &&
            clock.elapsed >= nextTravel &&
            !listening &&
            !userBusy &&
            !reading) {
          unawaited(read(''));
        } else if (!reading && !checkingStats) {
          unawaited(refreshStats());
        }
      });
    } on PlatformException catch (e) {
      if (mounted && token == epoch) setState(() => status = e.message);
    }
  }

  Future<void> refreshStats() async {
    final token = epoch;
    checkingStats = true;
    try {
      final data = await native<Map<Object?, Object?>>('take', {'stats': true});
      if (!active || token != epoch || data == null) return;
      setState(() {
        frames = data['frames'] as int? ?? frames;
        batches = data['batches'] as int? ?? batches;
        final cameraState = data['status'] as String?;
        if (cameraState != null && !cameraState.startsWith('采集中')) {
          status = cameraState;
        } else if (status?.startsWith('打开摄像头') == true ||
            status?.startsWith('摄像头') == true) {
          status = null;
        }
      });
    } on PlatformException {
      /* View was detached during the sample. */
    } finally {
      checkingStats = false;
    }
  }

  void interrupt() {
    epoch++;
    pending?.close();
    pending = null;
    reading = false;
    userBusy = false;
    unawaited(audio.stop());
  }

  void pause() {
    interrupt();
    timer?.cancel();
    started = false;
    if (view != null)
      unawaited(native<void>('pause').catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (foreground == visible) return;
    foreground = visible;
    if (visible) {
      unawaited(start());
    } else {
      pause();
    }
    if (mounted) setState(() {});
  }

  Future<void> ask(String text) async {
    final words = text.trim();
    if (!active || words.isEmpty) return;
    interrupt();
    input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await read(words);
  }

  Future<void> voice() async {
    if (!active || listening) return;
    interrupt();
    setState(() => listening = true);
    try {
      final words = await native<String>('voice');
      if (!mounted || manual || words == null || words.trim().isEmpty) return;
      // The system recognizer may return before this activity resumes.
      pendingVoice = words;
    } on PlatformException catch (e) {
      if (mounted) setState(() => status = e.message);
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> read(String question) async {
    if (!active || reading) return;
    final token = epoch;
    bool current() => mounted && active && token == epoch;
    final user = question.isNotEmpty;
    setState(() {
      reading = true;
      userBusy = user;
    });
    final began = clock.elapsed;
    LensRequest? request;
    try {
      Map<Object?, Object?>? data;
      for (int i = 0; i < (user ? 9 : 1); i++) {
        data = await native<Map<Object?, Object?>>('take', {'user': user});
        if (!current()) return;
        if (data?['frame'] != null || !user) break;
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!current()) return;
      }
      frames = data?['frames'] as int? ?? frames;
      batches = data?['batches'] as int? ?? batches;
      final frame = data?['frame'] as Uint8List?;
      if (frame == null) {
        if (user) {
          input.text = question;
          status = '暂时没有清晰的新画面，等取景恢复后再发一次';
        } else if (frames == 0 ||
            !(data?['status']?.toString().startsWith('采集中') ?? true)) {
          status = data?['status']?.toString();
        }
        return;
      }
      request = LensRequest(() async => current());
      pending = request;
      calls++;
      final turn = await request.run(
        session,
        question,
        frame,
        data?['sheet'] as Uint8List?,
      );
      if (!current()) return;
      elapsed = (clock.elapsed - began).inMilliseconds;
      session.remember(turn);
      status = null;
      nextTravel =
          clock.elapsed + Duration(seconds: turn.reply.isEmpty ? 12 : 30);
      if (turn.reply.isNotEmpty) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
        if (await AppDatabase.instance.getSetting('tts_enabled') == '1' &&
            current()) {
          final intent = audio.createIntent(
            ownerId: 'lens-$view',
            canContinue: () async => current(),
          );
          await audio.playText(
            turn.reply,
            intent: intent,
            ownerId: 'lens-$view',
          );
          await audio.waitUntilIdle();
        }
      }
    } catch (e) {
      if (current()) {
        status = e is StateError ? e.message : '镜头识别暂时失败，请检查第一通道配置或网络';
        if (user && input.text.isEmpty) input.text = question;
        nextTravel = clock.elapsed + const Duration(seconds: 30);
      }
    } finally {
      request?.close();
      if (current())
        setState(() {
          pending = null;
          reading = false;
          userBusy = false;
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pause();
    unawaited(AndroidBridge.instance.setImmersiveChatPageVisible(false));
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turns = session.turns.where((t) => t.reply.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.travel ? '旅行模式' : '观察模式'),
        actions: [
          if (granted)
            IconButton(
              tooltip: manual ? '继续取景' : '暂停取景',
              icon: Icon(manual ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                setState(() => manual = !manual);
                if (manual) {
                  pendingVoice = null;
                  pause();
                } else {
                  unawaited(start());
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AndroidView(
                    viewType: 'ai_companion/lens_preview',
                    onPlatformViewCreated: (id) {
                      view = id;
                      unawaited(permission());
                    },
                  ),
                  if (!active)
                    ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: !granted && status != null
                            ? TextButton(
                                onPressed: permission,
                                child: Text(status!),
                              )
                            : Text(
                                manual ? '取景已暂停' : '等待相机',
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  status ??
                      (userBusy
                          ? '小鲸鱼正在看…'
                          : widget.travel
                          ? '一起看 · 可以随时插话'
                          : '你问时，小鲸鱼会回应'),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final t in turns) ...[
                    if (t.question.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(t.question),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(t.reply),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '本段 $frames 帧 · 拼图 $batches 张 · 本场请求 $calls 次${elapsed > 0 ? " · 上次 ${elapsed}ms" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '语音输入',
                    onPressed: active && !listening ? voice : null,
                    icon: const Icon(Icons.mic_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: active,
                      maxLength: 800,
                      decoration: const InputDecoration(
                        hintText: '和她说句话',
                        counterText: '',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: ask,
                    ),
                  ),
                  IconButton(
                    tooltip: '发送',
                    onPressed: active ? () => ask(input.text) : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
