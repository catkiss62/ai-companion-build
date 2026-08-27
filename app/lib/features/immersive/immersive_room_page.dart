import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/immersive/immersive_room_controller.dart';
import '../../core/immersive/immersive_room_repository.dart';
import '../../core/models/immersive_room.dart';
import '../../widgets/action_tint_text.dart';
import '../../widgets/reasoning_panel.dart';

const immersiveRailPink = Color(0xFFF472B6);

class ImmersiveRoomLobbyPage extends StatefulWidget {
  const ImmersiveRoomLobbyPage({super.key});

  @override
  State<ImmersiveRoomLobbyPage> createState() =>
      _ImmersiveRoomLobbyPageState();
}

class _ImmersiveRoomLobbyPageState extends State<ImmersiveRoomLobbyPage> {
  late final ImmersiveRoomRepository repository =
      ImmersiveRoomRepository(AppDatabase.instance);
  List<ImmersiveRoom> rooms = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final next = await repository.listRooms();
    if (!mounted) return;
    setState(() {
      rooms = next;
      loading = false;
    });
  }

  Future<void> _createRoom() async {
    final title = TextEditingController(text: '新的沉浸房间');
    final scene = TextEditingController();
    var inherit = false;
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('新建沉浸房间'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '房间标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scene,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '开场、世界观或当前场景（可选）',
                      hintText: '例如地点、时间、人物身份、最初姿势或玩法背景。',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: inherit,
                    onChanged: (value) =>
                        setDialogState(() => inherit = value ?? false),
                    title: const Text('承接当前普通聊天入场'),
                    subtitle: const Text(
                      '只复制最近少量聊天作为开场背景；创建后两边继续独立。',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('创建'),
              ),
            ],
          ),
        ),
      );
      if (approved != true || !mounted) return;
      final room = await repository.createRoom(
        title: title.text,
        openingScene: scene.text,
        inheritCurrentChat: inherit,
      );
      if (!mounted) return;
      await _openRoom(room);
    } finally {
      title.dispose();
      scene.dispose();
    }
  }

  Future<void> _openRoom(ImmersiveRoom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImmersiveRoomPage(roomId: room.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('沉浸房间')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _createRoom,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建房间'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        '同一个她会带着正式性格、关系与重要记忆进入房间；每个房间的现场、长篇原文和详细玩法独立保存。暂离后可继续，正式结束后默认新开故事。',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (rooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('还没有房间。')),
                    )
                  else
                    ...rooms.map(
                      (room) => Card(
                        child: ListTile(
                          leading: Icon(
                            room.isEnded
                                ? Icons.inventory_2_outlined
                                : room.isPaused
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.auto_stories_rounded,
                            color: room.isEnded ? null : immersiveRailPink,
                          ),
                          title: Text(room.title),
                          subtitle: Text(
                            '${_statusLabel(room)} · ${_roomTime(room.updatedAt)}'
                            '${room.rollingSummary.trim().isEmpty ? '' : '\n${room.rollingSummary.trim()}'}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: room.rollingSummary.trim().isNotEmpty,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openRoom(room),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _statusLabel(ImmersiveRoom room) {
    if (room.isEnded) return '已结束';
    if (room.isPaused) return '暂离中';
    return '进行中';
  }

  static String _roomTime(DateTime time) =>
      '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class ImmersiveRoomPage extends StatefulWidget {
  const ImmersiveRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<ImmersiveRoomPage> createState() => _ImmersiveRoomPageState();
}

class _ImmersiveRoomPageState extends State<ImmersiveRoomPage> {
  late final ImmersiveRoomController controller =
      ImmersiveRoomController(roomId: widget.roomId);
  final input = TextEditingController();
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<bool> _leave() async {
    if (controller.sending || controller.ending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先停止或等待当前操作结束。')),
      );
      return false;
    }
    if (controller.room?.isEnded != true) await controller.pause();
    return true;
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    input.clear();
    await controller.send(text);
  }

  Future<void> _editRoom() async {
    final room = controller.room;
    if (room == null || room.isEnded) return;
    final title = TextEditingController(text: room.title);
    final entry = TextEditingController(text: room.entryContext);
    final rules = TextEditingController(text: room.novelRules);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('房间设定与小说规则'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('保存'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: title,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '房间标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: entry,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '入场背景',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rules,
                  minLines: 16,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: '只对本房间生效的小说规则',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (saved == true) {
        await controller.updateDetails(
          title: title.text,
          entryContext: entry.text,
          novelRules: rules.text,
        );
      }
    } finally {
      title.dispose();
      entry.dispose();
      rules.dispose();
    }
  }

  Future<void> _endRoom() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('结束这个房间？'),
        content: const Text(
          '系统会保留完整原文，生成房间归档摘要，并只把真正重要的共同经历筛选进长期记忆。结束后这个房间只能回看。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('整理并结束'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final ended = await controller.endRoom();
    if (ended && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    return WillPopScope(
      onWillPop: _leave,
      child: Scaffold(
        appBar: AppBar(
          title: Text(room?.title ?? '沉浸房间'),
          actions: [
            if (room != null && !room.isEnded)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') await _editRoom();
                  if (value == 'leave' && await _leave() && mounted) {
                    Navigator.pop(context);
                  }
                  if (value == 'end') await _endRoom();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('房间设定与小说规则')),
                  PopupMenuItem(value: 'leave', child: Text('暂时离开')),
                  PopupMenuItem(value: 'end', child: Text('结束房间')),
                ],
              ),
          ],
        ),
        body: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (controller.error != null)
                    MaterialBanner(
                      content: Text(controller.error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => controller.error = null),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  if (room?.isEnded == true)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      padding: const EdgeInsets.all(12),
                      child: const Text('这个房间已经结束，下面保留完整原文供回看。'),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                      itemCount: controller.messages.length +
                          (controller.showStreamingDraft ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < controller.messages.length) {
                          return _ImmersiveMessageView(
                            message: controller.messages[index],
                          );
                        }
                        return _ImmersiveStreamingView(
                          reasoning: controller.streamingReasoning,
                          content: controller.streamingContent,
                        );
                      },
                    ),
                  ),
                  if (controller.ending) const LinearProgressIndicator(),
                  if (room?.isEnded != true) _inputBar(),
                ],
              ),
      ),
    );
  }

  Widget _inputBar() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  enabled: !controller.ending,
                  minLines: 1,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '继续这个房间…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              IconButton.filled(
                tooltip: controller.sending ? '停止' : '发送',
                onPressed: controller.ending
                    ? null
                    : controller.sending
                        ? controller.stop
                        : _send,
                icon: Icon(
                  controller.sending ? Icons.stop_rounded : Icons.send_rounded,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ImmersiveMessageView extends StatelessWidget {
  const _ImmersiveMessageView({required this.message});

  final ImmersiveMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 330),
          margin: const EdgeInsets.only(left: 44, bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            message.content,
            style: const TextStyle(height: 1.5),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.reasoningContent.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 7, right: 4, bottom: 7),
              child: ReasoningPanel(reasoning: message.reasoningContent),
            ),
          _ImmersiveAssistantRail(content: message.content),
        ],
      ),
    );
  }
}

class _ImmersiveStreamingView extends StatelessWidget {
  const _ImmersiveStreamingView({
    required this.reasoning,
    required this.content,
  });

  final String reasoning;
  final String content;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reasoning.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 7, right: 4, bottom: 7),
                child: ReasoningPanel(reasoning: reasoning, streaming: true),
              ),
            if (content.isNotEmpty)
              _ImmersiveAssistantRail(content: content)
            else if (reasoning.isEmpty)
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text('她正在进入这个场景…'),
              ),
          ],
        ),
      );
}

class _ImmersiveAssistantRail extends StatelessWidget {
  const _ImmersiveAssistantRail({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: immersiveRailPink,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: NovelTintText(
                text: content,
                style: const TextStyle(height: 1.62),
              ),
            ),
          ),
          ],
        ),
      );
}
