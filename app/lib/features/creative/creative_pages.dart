import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/app_database.dart';
import '../../core/creative/creative_contract.dart';
import '../../core/creative/creative_store.dart';
import '../../core/creative/creative_control.dart';
import '../../core/creative/creative_autonomy_policy.dart';
import '../../core/creative/creative_play.dart';
import '../../core/creative/creative_delivery.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/models/chat_message.dart';
import '../../widgets/action_tint_text.dart';
import '../chat/chat_controller.dart';
import 'creative_input_trace.dart';
import 'creative_player_layout.dart';

class CreativePortfolioPage extends StatelessWidget {
  const CreativePortfolioPage({super.key, required this.chat});
  final ChatController chat;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('作品集')), body: CreativeCards(chat: chat));
}

class CreativeCards extends StatefulWidget {
  const CreativeCards({super.key, required this.chat, this.messageId});
  final ChatController chat;
  final String? messageId;
  @override
  State<CreativeCards> createState() => _CreativeCardsState();
}

class _CreativeCardsState extends State<CreativeCards> {
  late final store = CreativeStore(widget.chat.db);
  List<Map<String, dynamic>> works = [];
  Map<String, CreativeControlTarget> controlTargets = {};
  final Map<String, CreativeControlTarget?> openedTargets = {};
  final Set<String> pausedNotices = {};
  Timer? timer;
  bool loading = true, fetching = false;
  String fingerprint = '';
  @override
  void initState() {
    super.initState(); _load();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) _load();
    });
  }
  Future<void> _load() async {
    if (fetching) return;
    fetching = true;
    try {
      final fence = await widget.chat.db.captureBrainWorkFence();
      final items = widget.messageId == null ? await store.list() : await store.forMessage(widget.messageId!);
      if (fence != null && !await widget.chat.db.brainWorkFenceCurrent(fence)) return;
      final targets = <String, CreativeControlTarget>{};
      for (final item in items) {
        if (fence != null && item['id'] is String && item['request_id'] is String) {
          targets[item['id'] as String] = CreativeControlTarget(workId: item['id'] as String,
            requestId: item['request_id'] as String, brainFence: fence);
        }
      }
      final paused = <String>{};
      for (final item in items) {
        if ((await CreativeDelivery(widget.chat.db).read(item['id'] as String))['status'] == 'paused') paused.add(item['id'] as String);
      }
      // Worker checkpoints do not invalidate card layout or decode its cover.
      final next = jsonEncode([items.map((w) => {for (final k in ['id','request_id','title','intro','note','status','current','cover','card_kind','record_completed']) k:w[k]}).toList(), paused.toList(), fence?.identity]);
      if (mounted && (loading || next != fingerprint)) setState(() {
        works = items; controlTargets = targets; fingerprint = next;
        pausedNotices..clear()..addAll(paused); loading = false;
      });
    } catch (_) { if (mounted && loading) setState(() => loading = false); }
    finally { fetching = false; }
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> _action(Future<void> Function() action) async {
    try { await action(); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }
  Future<void> _edit(Map<String, dynamic> work) async {
    if (!widget.chat.deepThinking) throw const FormatException('请先开启聊天的深度思考，再明确委托修改');
    FocusManager.instance.primaryFocus?.unfocus();
    final brief = await Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true, builder: (_) => CreativeEditPage(title: work['title'] as String? ?? '小作品')));
    if (!mounted) return;
    if (brief != null && brief.trim().isNotEmpty) {
      await widget.chat.sendText('请修改作品「${work['title']}」（作品 ID：${work['id']}）：${brief.trim()}');
    }
  }
  Widget _card(Map<String, dynamic> work) {
    final id = work['id'] as String;
    // Capture on menu open: PopupMenuButton can read a newer onSelected
    // callback after an in-flight card refresh rebuilds this widget.
    final target = controlTargets[id];
    final playable = (work['current'] as String? ?? '').isNotEmpty;
    return CreativeWorkCard(key: ValueKey(id), work: work,
      onOpen: playable ? () { FocusManager.instance.primaryFocus?.unfocus(); Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreativePlayerPage(work: work, chat: widget.chat))); } : null,
      menu: PopupMenuButton<String>(
        onOpened: () { openedTargets[id] = target; },
        onCanceled: () { openedTargets.remove(id); },
        onSelected: (value) {
        final target = openedTargets.remove(id);
        _action(() async {
        if ({'stop', 'resume', 'delete'}.contains(value) && target == null) {
          throw const FormatException('当前作品状态暂不可修改，请刷新后重试');
        }
        CreativeControlResult? control;
        if (value == 'stop') control = await store.stopTarget(target!);
        if (value == 'resume') {
          control = await store.resumeTarget(target!);
          if (control.applied) await AndroidBridge.instance.wakeBackgroundBrain(reason: 'creative_resume');
        }
        if (value == 'retry_notice') { await CreativeDelivery(widget.chat.db).retry(id); await AndroidBridge.instance.wakeBackgroundBrain(reason: 'creative_delivery'); }
        if (value == 'edit') await _edit(work);
        if (value == 'export') {
          if (!CreativeAutonomyPolicy.visible(await store.get(id))) return;
          final html = await widget.chat.db.getSetting('${CreativeContract.sourcePrefix}${work['current']}');
          if (html != null) await AndroidBridge.instance.savePromptPack(content: html, suggestedName: 'work_$id.html');
        }
        if (value == 'delete') {
          final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('删除这件作品？'), content: const Text('将同时删除它的草稿与游玩进度。'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除'))]));
          if (yes == true) control = await store.deleteTarget(target!);
        }
        if (control != null && !control.applied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(control.explanation)));
        }
        });
      }, itemBuilder: (_) => [
        if (CreativeContract.active.contains(work['status'])) const PopupMenuItem(value: 'stop', child: Text('暂停制作')),
        if ({'paused', 'failed'}.contains(work['status'])) const PopupMenuItem(value: 'resume', child: Text('继续制作')),
        if (pausedNotices.contains(id)) const PopupMenuItem(value: 'retry_notice', child: Text('重试完成提示')),
        const PopupMenuItem(value: 'edit', child: Text('委托修改')),
        if (playable) const PopupMenuItem(value: 'export', child: Text('导出 HTML 源文件')),
        const PopupMenuItem(value: 'delete', child: Text('删除作品')),
      ]));
  }
  @override
  Widget build(BuildContext context) {
    if (widget.messageId != null) return Column(children: works.map(_card).toList());
    if (loading) return const Center(child: CircularProgressIndicator());
    if (works.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32),
      child: Text('这里会留住她为你做的小作品。\n\n开启聊天的深度思考，告诉她你想做什么。制作时可以继续聊天或离开 App。', textAlign: TextAlign.center)));
    return ListView.builder(itemCount: works.length, itemBuilder: (_, i) => _card(works[i]));
  }
}

class CreativeWorkCard extends StatefulWidget {
  const CreativeWorkCard({super.key, required this.work, this.onOpen, this.menu});
  final Map<String, dynamic> work;
  final VoidCallback? onOpen;
  final Widget? menu;
  @override
  State<CreativeWorkCard> createState() => _CreativeWorkCardState();
}
class _CreativeWorkCardState extends State<CreativeWorkCard> {
  bool expanded = false;
  String? decodedSource;
  Uint8List? cover;
  void _toggle() {
    if (!expanded && widget.work['card_kind'] != 'progress') {
      final source = widget.work['cover'] as String? ?? '';
      if (source != decodedSource) {
        decodedSource = source;
        try { cover = source.isEmpty ? null : base64Decode(source); } catch (_) { cover = null; }
      }
    }
    setState(() => expanded = !expanded);
  }
  @override
  void didUpdateWidget(CreativeWorkCard old) {
    super.didUpdateWidget(old);
    if (old.work['cover'] != widget.work['cover']) { decodedSource = null; cover = null; }
  }
  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final progress = work['card_kind'] == 'progress';
    final completed = work['record_completed'] is bool
        ? work['record_completed'] as bool : work['status'] == 'ready';
    return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(title: Text(work['title'] as String? ?? '小作品'), onTap: _toggle,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (progress && completed) ...[
              Text('已完成', style: Theme.of(context).textTheme.labelMedium), const SizedBox(width: 6)],
            Icon(expanded ? Icons.expand_less : Icons.expand_more)])),
        if (expanded) ...[
          if (!progress && cover != null) Image.memory(cover!, height: 130, fit: BoxFit.cover),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(progress
            ? '制作记录 · ${completed ? '已完成' : work['note'] ?? '等待制作'}'
            : '${work['intro'] ?? ''}\n${work['note'] ?? ''}'.trim())),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 8, 8), child: Row(children: [
            if (!progress && widget.onOpen != null) Expanded(child: FilledButton.tonalIcon(
              onPressed: widget.onOpen, icon: const Icon(Icons.open_in_new), label: const Text('打开作品')))
            else const Spacer(),
            if (widget.menu != null) widget.menu!,
          ])),
        ],
      ]));
  }
}

/// Opaque route: the chat stage does not participate in the IME transition.
class CreativeEditPage extends StatefulWidget {
  const CreativeEditPage({super.key, required this.title});
  final String title;
  @override
  State<CreativeEditPage> createState() => _CreativeEditPageState();
}
class _CreativeEditPageState extends State<CreativeEditPage> {
  final input = TextEditingController();
  final focus = FocusNode();
  final trace = CreativeInputTrace('revision_editor');
  Animation<double>? animation;
  bool focusRequested = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (animation != routeAnimation) { animation?.removeStatusListener(_status); animation = routeAnimation; animation?.addStatusListener(_status); }
    if (animation == null || animation!.status == AnimationStatus.completed) _requestFocus();
  }
  void _status(AnimationStatus status) { if (status == AnimationStatus.completed) _requestFocus(); }
  void _requestFocus() {
    if (focusRequested) return;
    focusRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) focus.requestFocus(); });
  }
  @override
  void dispose() { animation?.removeStatusListener(_status); trace.dispose(); input.dispose(); focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    trace.observe(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.sizeOf(context).height);
    return Scaffold(appBar: AppBar(title: const Text('委托修改'), actions: [TextButton(onPressed: () {
      if (input.text.trim().isNotEmpty) { focus.unfocus(); Navigator.pop(context, input.text.trim()); }
    }, child: const Text('发送'))]), body: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title), const SizedBox(height: 16),
        Expanded(child: TextField(controller: input, focusNode: focus, expands: true, minLines: null, maxLines: null,
          textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(hintText: '想怎么修改？', border: InputBorder.none))),
      ])));
  }
}

class CreativeChatBubble extends StatelessWidget {
  const CreativeChatBubble({super.key, required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) => Align(alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
      margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: message.isUser ? const Color(0xff40394e) : const Color(0xff262831), borderRadius: BorderRadius.circular(12)),
      child: message.isUser ? Text(message.content, style: const TextStyle(color: Colors.white, height: 1.4))
        : ActionTintText(text: message.content, style: const TextStyle(height: 1.4))));
}

class CreativePlayerPage extends StatefulWidget {
  const CreativePlayerPage({super.key, required this.work, required this.chat});
  final Map<String, dynamic> work;
  final ChatController chat;
  @override
  State<CreativePlayerPage> createState() => _CreativePlayerPageState();
}

/// A static work may have a newer version without ever having saved progress.
class CreativePlayerMenu extends StatelessWidget {
  const CreativePlayerMenu({super.key, this.onReset, this.onSwitchVersion});
  final VoidCallback? onReset, onSwitchVersion;
  @override
  Widget build(BuildContext context) {
    if (onReset == null && onSwitchVersion == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(tooltip: '作品选项', onSelected: (value) {
      if (value == 'update') onSwitchVersion?.call();
      if (value == 'restart') onReset?.call();
    }, itemBuilder: (_) => [
      if (onSwitchVersion != null) const PopupMenuItem(value: 'update', child: Text('切换到最新版本')),
      if (onReset != null) const PopupMenuItem(value: 'restart', child: Text('重新开始／重置进度')),
    ]);
  }
}

class _CreativePlayerPageState extends State<CreativePlayerPage> {
  late final play = CreativePlay(AppDatabase.instance, widget.work['id'] as String);
  final input = TextEditingController();
  final trace = CreativeInputTrace('work_chat');
  Widget? webSurface;
  String version = '', sessionId = '', latestVersion = '';
  String? error;
  bool showChat = false, capturing = false, canReset = false;
  ChatDialogueColorOption color = ChatDialogueColorOption.purple;
  MethodChannel? channel;
  Timer? updateTimer;
  bool opening = false, checkingUpdate = false;
  int generation = 0, readyGeneration = -1;
  @override
  void initState() {
    super.initState(); _load();
    updateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) _checkUpdate();
    });
  }
  Future<void> _checkUpdate() async {
    if (opening || checkingUpdate) return;
    checkingUpdate = true;
    try {
      final work = await CreativeStore(AppDatabase.instance).get(play.workId);
      final latest = CreativeAutonomyPolicy.visible(work) ? work['current'] as String? ?? '' : '';
      if (mounted && latestVersion != latest) setState(() => latestVersion = latest);
    } catch (_) { /* Keep the currently open version when a refresh fails. */ }
    finally { checkingUpdate = false; }
  }
  Future<void> _load({bool restart = false}) async {
    if (opening) return;
    setState(() { opening = true; readyGeneration = -1; });
    try {
      final state = await play.open(restart: restart);
      final source = await AppDatabase.instance.getSetting('${CreativeContract.sourcePrefix}${state['version']}');
      if (source == null) throw const FormatException('找不到作品源码');
      final selected = ChatDialogueColorOption.fromSetting(await AppDatabase.instance.getSetting(ChatDialogueColorOption.settingKey));
      if (mounted) setState(() {
        version = state['version'] as String; sessionId = state['session_id'] as String;
        color = selected; error = null; generation++;
        final viewGeneration = generation, viewVersion = version, viewSession = sessionId;
        canReset = (state['description'] as Map?)?['resettable'] == true ||
          (state['saved_at'] as num? ?? 0) > 0 ||
          (state['turns'] as Map? ?? {}).isNotEmpty ||
          (state['public'] is Map && (state['public'] as Map).isNotEmpty) ||
          (state['public'] is List && (state['public'] as List).isNotEmpty);
        webSurface = RepaintBoundary(child: AndroidView(key: ValueKey(generation), viewType: 'ai_companion/creative_player',
          creationParams: {'html': source, 'state': jsonEncode(state['public'])},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _created(id, viewGeneration, viewVersion, viewSession)));
      });
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => opening = false); else opening = false; }
    if (mounted) await _checkUpdate();
  }
  Future<void> _created(int id, int viewGeneration, String viewVersion, String viewSession) async {
    if (!mounted || viewGeneration != generation) return;
    final current = MethodChannel('ai_companion/creative_player/$id');
    channel?.setMethodCallHandler(null); channel = current;
    current.setMethodCallHandler((call) async {
      if (!mounted || channel != current || viewGeneration != generation) throw PlatformException(code: 'closed', message: '作品已关闭');
      if (call.method == 'event') {
        try {
          final result = await play.event(viewVersion, call.arguments as String, sessionId: viewSession);
          final event = CreativeContract.decode(call.arguments as String);
          final kind = event['kind'];
          final resettable = {'save', 'choose', 'reveal'}.contains(kind) ||
            (kind == 'describe' && (event['data'] as Map?)?['resettable'] == true);
          if (mounted && channel == current && !canReset && resettable) setState(() => canReset = true);
          return result;
        } catch (e) { throw PlatformException(code: 'work_event', message: e.toString()); }
      }
      if (call.method == 'error') { setState(() => error = CreativeContract.clip(call.arguments, 160)); }
      return null;
    });
    try {
      await current.invokeMethod<void>('load');
      if (mounted && channel == current && viewGeneration == generation) setState(() => readyGeneration = viewGeneration);
    }
    catch (e) { if (mounted && channel == current && viewGeneration == generation) setState(() => error = e.toString()); }
  }
  Future<void> _send() async {
    if (capturing || opening || readyGeneration != generation || channel == null || widget.chat.generationActive || input.text.trim().isEmpty) return;
    final text = input.text, owner = channel, session = sessionId, viewGeneration = generation;
    setState(() => capturing = true);
    try {
      Map<String, dynamic> observation;
      try { observation = CreativeContract.decode(await owner?.invokeMethod<String>('observe').timeout(const Duration(seconds: 4))); }
      catch (_) { observation = {'available': false}; }
      if (observation['pending_writes'] == true) throw const FormatException('作品正在保存这一回合，请稍后再发送');
      if (!mounted || opening || readyGeneration != viewGeneration || generation != viewGeneration || owner != channel || session != sessionId) return;
      final snapshot = await play.captureSnapshot(observation: observation);
      if (!mounted || opening || readyGeneration != viewGeneration || generation != viewGeneration || owner != channel || session != sessionId) return;
      final sending = widget.chat.sendText(text, workContext: snapshot);
      if (await sending && mounted && input.text == text) input.clear();
      if (mounted && widget.chat.error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.chat.error!)));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => capturing = false); }
  }
  Future<void> _restart({bool switchVersion = false}) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(switchVersion ? '切换到最新版本？' : '重新开始？'),
      content: Text(switchVersion
        ? '打开最新完成的版本，并清空当前作品进度。聊天历史会保留。取消则继续使用当前版本和进度。'
        : '清空当前作品进度，使用最新版本。聊天历史会保留，重置后的进度会单独记录。'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('开始'))]));
    if (yes == true && mounted) await _load(restart: true);
  }
  @override
  void dispose() { updateTimer?.cancel(); generation++; channel?.setMethodCallHandler(null); trace.dispose(); input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(resizeToAvoidBottomInset: false,
    appBar: AppBar(title: Text(widget.work['title'] as String? ?? '小作品'), actions: [
      IconButton(tooltip: '一起聊聊', icon: const Icon(Icons.chat_bubble_outline), onPressed: () {
        FocusManager.instance.primaryFocus?.unfocus(); setState(() => showChat = !showChat);
      }),
      CreativePlayerMenu(onReset: canReset ? () => _restart() : null,
        onSwitchVersion: latestVersion.isNotEmpty && version.isNotEmpty && latestVersion != version
          ? () => _restart(switchVersion: true) : null),
    ]),
    body: SafeArea(maintainBottomViewPadding: true, child: CreativePlayerLayout(onMetrics: trace.observe,
      page: webSurface ?? const Center(child: CircularProgressIndicator()),
      banner: error == null ? null : MaterialBanner(content: Text(error!),
        actions: [TextButton(onPressed: _load, child: const Text('重新打开'))]),
      chat: !showChat ? null : Material(color: Theme.of(context).colorScheme.surface,
        child: ChatDialogueColorScope(option: color,
            child: AnimatedBuilder(animation: widget.chat, builder: (context, _) {
              final messages = widget.chat.messages.reversed.take(40).toList();
              return Column(children: [
                Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), reverse: true,
                  itemCount: messages.length, itemBuilder: (_, i) => CreativeChatBubble(message: messages[i]))),
                if (widget.chat.generationActive || capturing) const LinearProgressIndicator(minHeight: 2),
                Padding(padding: const EdgeInsets.fromLTRB(12, 0, 4, 4), child: Row(children: [
                  Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: '和她聊聊这件作品…'), maxLines: 2, minLines: 1)),
                  IconButton(icon: const Icon(Icons.send_rounded), onPressed: widget.chat.generationActive || capturing || opening || readyGeneration != generation || channel == null ? null : _send),
                ])),
              ]);
            }))),
    )),
  );
}
