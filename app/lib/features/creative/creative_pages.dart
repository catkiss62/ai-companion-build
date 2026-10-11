import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/app_database.dart';
import '../../core/creative/creative_contract.dart';
import '../../core/creative/creative_store.dart';
import '../../core/creative/creative_play.dart';
import '../../core/platform/android_bridge.dart';
import '../chat/chat_controller.dart';

class CreativePortfolioPage extends StatelessWidget {
  const CreativePortfolioPage({super.key, required this.chat});
  final ChatController chat;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('作品集')),
    body: CreativeCards(chat: chat),
  );
}

class CreativeCards extends StatefulWidget {
  const CreativeCards({super.key, required this.chat, this.messageId});
  final ChatController chat;
  final String? messageId;
  @override
  State<CreativeCards> createState() => _CreativeCardsState();
}

class _CreativeCardsState extends State<CreativeCards> {
  final store = CreativeStore(AppDatabase.instance);
  List<Map<String, dynamic>> works = [];
  Timer? timer;
  bool loading = true;
  @override
  void initState() {
    super.initState(); _load();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) _load();
    });
  }
  Future<void> _load() async {
    final items = await store.list();
    if (mounted) setState(() {
      works = items.where((w) => widget.messageId == null || w['message_id'] == widget.messageId).toList();
      loading = false;
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> _action(Future<void> Function() action) async {
    try { await action(); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }
  Widget _card(Map<String, dynamic> work) {
    final id = work['id'] as String;
    final playable = (work['current'] as String? ?? '').isNotEmpty;
    final cover = work['cover'] as String? ?? '';
    return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (cover.isNotEmpty) SizedBox(height: 130, child: Image.memory(base64Decode(cover), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome))),
        ListTile(leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(work['title'] as String? ?? '小作品'),
          subtitle: Text('${work['intro'] ?? ''}\n${work['note'] ?? ''}'.trim()),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (value) => _action(() async {
            if (value == 'stop') await store.stop(id);
            if (value == 'resume') {
              await store.resume(id, deepThinking: widget.chat.deepThinking);
              await AndroidBridge.instance.wakeBackgroundBrain(reason: 'creative_resume');
            }
            if (value == 'edit') {
              if (!widget.chat.deepThinking) throw const FormatException('请先开启聊天的深度思考，再明确委托修改');
              final input = TextEditingController();
              final brief = await showDialog<String>(context: context, builder: (c) => AlertDialog(
                title: const Text('想怎么修改？'), content: TextField(controller: input, autofocus: true, minLines: 2, maxLines: 5),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(c, input.text), child: const Text('在聊天中委托'))]));
              input.dispose();
              if (brief != null && brief.trim().isNotEmpty) await widget.chat.sendText('请修改作品「${work['title']}」（作品 ID：$id）：${brief.trim()}');
            }
            if (value == 'export') {
              final html = await AppDatabase.instance.getSetting('${CreativeContract.sourcePrefix}${work['current']}');
              if (html != null) await AndroidBridge.instance.savePromptPack(content: html, suggestedName: 'work_$id.html');
            }
            if (value == 'delete') {
              final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                title: const Text('删除这件作品？'), content: const Text('将同时删除它的草稿与游玩进度。'),
                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除'))]));
              if (yes == true) await store.delete(id);
            }
          }), itemBuilder: (_) => [
            if (CreativeContract.active.contains(work['status'])) const PopupMenuItem(value: 'stop', child: Text('暂停制作')),
            if ({'paused', 'failed'}.contains(work['status'])) const PopupMenuItem(value: 'resume', child: Text('继续制作')),
            const PopupMenuItem(value: 'edit', child: Text('委托修改')),
            if (playable) const PopupMenuItem(value: 'export', child: Text('导出 HTML 源文件')),
            const PopupMenuItem(value: 'delete', child: Text('删除作品')),
          ])),
        if (playable) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.tonalIcon(icon: const Icon(Icons.play_arrow_rounded), label: const Text('打开作品'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreativePlayerPage(work: work, chat: widget.chat))))),
      ]));
  }
  @override
  Widget build(BuildContext context) {
    if (widget.messageId != null) return Column(children: works.map(_card).toList());
    if (loading) return const Center(child: CircularProgressIndicator());
    if (works.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32),
      child: Text('这里会留住她为你做的小作品。\n\n开启聊天的深度思考，告诉她你想做什么。制作时可以继续聊天或离开 App。', textAlign: TextAlign.center)));
    return ListView(children: works.map(_card).toList());
  }
}

class CreativePlayerPage extends StatefulWidget {
  const CreativePlayerPage({super.key, required this.work, required this.chat});
  final Map<String, dynamic> work;
  final ChatController chat;
  @override
  State<CreativePlayerPage> createState() => _CreativePlayerPageState();
}

class _CreativePlayerPageState extends State<CreativePlayerPage> {
  late final play = CreativePlay(AppDatabase.instance, widget.work['id'] as String);
  final input = TextEditingController();
  String? html;
  String version = '';
  Object? publicState;
  String? error;
  bool showChat = false;
  MethodChannel? channel;
  int generation = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load({bool restart = false}) async {
    try {
      final state = await play.open(restart: restart);
      final source = await AppDatabase.instance.getSetting('${CreativeContract.sourcePrefix}${state['version']}');
      if (source == null) throw const FormatException('找不到作品源码');
      if (mounted) setState(() { html = source; publicState = state['public']; version = state['version'] as String; error = null; generation++; });
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
  }
  Future<void> _created(int id) async {
    final current = MethodChannel('ai_companion/creative_player/$id');
    final viewVersion = version;
    channel?.setMethodCallHandler(null);
    channel = current;
    current.setMethodCallHandler((call) async {
      if (!mounted || channel != current) throw PlatformException(code: 'closed', message: '作品已关闭');
      if (call.method == 'event') {
        try { return await play.event(viewVersion, call.arguments as String); }
        catch (e) { throw PlatformException(code: 'work_event', message: e.toString()); }
      }
      if (call.method == 'error') { setState(() => error = CreativeContract.clip(call.arguments, 160)); }
      return null;
    });
    await current.invokeMethod<void>('load');
  }
  @override
  void dispose() { channel?.setMethodCallHandler(null); input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.work['title'] as String? ?? '小作品'), actions: [
      IconButton(tooltip: '一起聊聊', icon: const Icon(Icons.chat_bubble_outline), onPressed: () => setState(() => showChat = !showChat)),
      PopupMenuButton<String>(onSelected: (_) async {
        final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('开始新一局？'), content: const Text('清空本作品的游玩进度，并使用最新版本。'),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('开始'))]));
        if (yes == true) await _load(restart: true);
      }, itemBuilder: (_) => [const PopupMenuItem(value: 'restart', child: Text('使用新版，开始新一局'))]),
    ]),
    body: SafeArea(child: Column(children: [
      if (error != null) MaterialBanner(content: Text(error!), actions: [TextButton(onPressed: _load, child: const Text('重新打开'))]),
      Expanded(child: html == null ? const Center(child: CircularProgressIndicator()) : AndroidView(
        key: ValueKey(generation), viewType: 'ai_companion/creative_player',
        creationParams: {'html': html, 'state': jsonEncode(publicState)},
        creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _created)),
      if (showChat) SizedBox(height: 260, child: AnimatedBuilder(animation: widget.chat, builder: (context, _) => Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(12), reverse: true,
          children: widget.chat.messages.reversed.take(6).map((m) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text('${m.isUser ? '你' : '她'}：${m.content}'))).toList())),
        if (widget.chat.generationActive) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 4, 4), child: Row(children: [
          Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: '和她聊聊这件作品…'), maxLines: 2, minLines: 1)),
          IconButton(icon: const Icon(Icons.send_rounded), onPressed: widget.chat.generationActive ? null : () async {
            final text = input.text;
            if (await widget.chat.sendText(text) && mounted) input.clear();
          }),
        ])),
      ]))),
    ])),
  );
}
