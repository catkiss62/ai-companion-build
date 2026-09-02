import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/ai/reasoning_translation_service.dart';
import '../../core/database/app_database.dart';
import '../../core/immersive/immersive_room_controller.dart';
import '../../core/immersive/immersive_room_repository.dart';
import '../../core/models/immersive_room.dart';
import '../../core/models/personality_trial.dart';
import '../../core/personality/personality_catalog.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../widgets/action_tint_text.dart';
import '../../widgets/active_trial_capsule.dart';
import '../../widgets/chat_portrait_stage.dart';
import '../../widgets/reasoning_panel.dart';
import '../chat/chat_timestamp_formatter.dart';

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

  Future<void> _renameRoom(ImmersiveRoom room) async {
    final title = TextEditingController(text: room.title);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('修改房间名称'),
          content: TextField(
            controller: title,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '房间名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await repository.renameRoom(room.id, title.text);
      await _load();
    } finally {
      title.dispose();
    }
  }

  Future<void> _deleteRoom(ImmersiveRoom room) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个房间？'),
        content: Text(_deleteRoomWarning(room)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await repository.deleteRoom(room.id);
    await _load();
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                tooltip: '房间操作',
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    await _renameRoom(room);
                                  } else if (value == 'delete') {
                                    await _deleteRoom(room);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('修改名称'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除房间'),
                                  ),
                                ],
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
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

  static String _deleteRoomWarning(ImmersiveRoom room) => room.isEnded
      ? '“${room.title}”的完整原文、现场和归档都会永久删除。这个房间已经整理结束，当时已经筛选进长期记忆的条目不会随房间删除。此操作无法撤销。'
      : '“${room.title}”的完整原文和现场都会永久删除。直接删除不会执行“整理并结束”，也不会新增长期记忆。此操作无法撤销。';
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
  bool _visualStageEnabled = true;
  bool _visualSettingsLoaded = false;
  double _panelOpacity = 0.75;
  double _panelFraction = 0.62;
  ChatPortraitSet _portraitSet = ChatPortraitSet.largeWhale;
  double _portraitScale = ChatPortraitTransform.defaults.scale;
  Offset _portraitOffset = ChatPortraitTransform.defaults.offset;
  String _backgroundMode = 'auto';
  bool _followLatest = true;
  bool _programmaticScroll = false;
  bool _scrollFrameScheduled = false;
  Timer? _trialTimer;
  PersonalityTrial? _personalityTrial;
  SpecialStyleTrial? _activeSpecialTrial;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    unawaited(controller.initialize());
    unawaited(_loadVisualSettings());
    unawaited(_refreshTrials());
    _trialTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshTrials()),
    );
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    _trialTimer?.cancel();
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshTrials() async {
    final profile = await AppDatabase.instance.activePersonalityTrial();
    final special = await AppDatabase.instance.activeSpecialStyleTrial();
    if (!mounted) return;
    setState(() {
      _personalityTrial = profile;
      _activeSpecialTrial = special;
    });
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleFollowLatest();
  }

  void _scheduleFollowLatest() {
    if (!_followLatest || _scrollFrameScheduled) return;
    _scrollFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFrameScheduled = false;
      if (!mounted || !_followLatest || !scroll.hasClients) return;
      _programmaticScroll = true;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      _programmaticScroll = false;
    });
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (_programmaticScroll || !scroll.hasClients) return false;
    final distance = scroll.position.maxScrollExtent - scroll.offset;
    if (notification.direction == ScrollDirection.forward) {
      _followLatest = false;
    } else if (distance < 8) {
      _followLatest = true;
    }
    return false;
  }

  Future<void> _loadVisualSettings() async {
    final db = AppDatabase.instance;
    final visualStageEnabled =
        (await db.getSetting('chat_visual_stage_enabled')) != '0';
    final panelOpacity = (double.tryParse(
              await db.getSetting('chat_panel_opacity') ?? '',
            ) ??
            0.75)
        .clamp(0.45, 0.95)
        .toDouble();
    final panelFraction = (double.tryParse(
              await db.getSetting('immersive_panel_fraction') ?? '',
            ) ??
            0.62)
        .clamp(0.42, 0.94)
        .toDouble();
    final backgroundMode =
        await db.getSetting('chat_background_mode') ?? 'auto';
    final portraitSet = chatPortraitSetFromKey(
      await db.getSetting('chat_portrait_set'),
    );
    final defaults = ChatPortraitTransform.defaultsFor(portraitSet);
    final legacyScale = portraitSet == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_scale')
        : null;
    final legacyX = portraitSet == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_x')
        : null;
    final legacyY = portraitSet == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_y')
        : null;
    final scale = (double.tryParse(
              await db.getSetting(
                    'chat_portrait_scale_${portraitSet.key}',
                  ) ??
                  legacyScale ??
                  '',
            ) ??
            defaults.scale)
        .clamp(0.85, 1.80)
        .toDouble();
    final offset = Offset(
      (double.tryParse(
                await db.getSetting(
                      'chat_portrait_offset_x_${portraitSet.key}',
                    ) ??
                    legacyX ??
                    '',
              ) ??
              defaults.offset.dx)
          .clamp(-0.45, 0.45)
          .toDouble(),
      (double.tryParse(
                await db.getSetting(
                      'chat_portrait_offset_y_${portraitSet.key}',
                    ) ??
                    legacyY ??
                    '',
              ) ??
              defaults.offset.dy)
          .clamp(-0.35, 0.35)
          .toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _visualStageEnabled = visualStageEnabled;
      _panelOpacity = panelOpacity;
      _panelFraction = panelFraction;
      _backgroundMode = backgroundMode;
      _portraitSet = portraitSet;
      _portraitScale = scale;
      _portraitOffset = offset;
      _visualSettingsLoaded = true;
    });
    _scheduleFollowLatest();
  }

  bool get _useNightBackground {
    if (_backgroundMode == 'night') return true;
    if (_backgroundMode == 'day') return false;
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 18;
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
    _followLatest = true;
    input.clear();
    await controller.send(text);
  }

  Future<void> _renameRoom() async {
    final room = controller.room;
    if (room == null || controller.sending || controller.ending) return;
    final title = TextEditingController(text: room.title);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('修改房间名称'),
          content: TextField(
            controller: title,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '房间名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (approved == true) await controller.rename(title.text);
    } finally {
      title.dispose();
    }
  }

  Future<void> _deleteRoom() async {
    final room = controller.room;
    if (room == null || controller.sending || controller.ending) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个房间？'),
        content: Text(room.isEnded
            ? '“${room.title}”的完整原文、现场和归档都会永久删除。这个房间已经整理结束，当时已筛选进长期记忆的条目不会随房间删除。此操作无法撤销。'
            : '“${room.title}”的完整原文和现场都会永久删除。直接删除不会执行“整理并结束”，也不会新增长期记忆。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    if (await controller.deleteRoom() && mounted) Navigator.pop(context);
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

  Widget _conversationPanel(ImmersiveRoom? room) => Column(
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
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                itemCount: controller.messages.length +
                    (controller.showStreamingDraft ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < controller.messages.length) {
                    final message = controller.messages[index];
                    final previous = index == 0
                        ? null
                        : controller.messages[index - 1];
                    return Column(
                      children: [
                        if (ChatTimestampFormatter.shouldShowDateSeparator(
                          message.createdAt,
                          previous?.createdAt,
                        ))
                          _ImmersiveDateSeparator(
                            createdAt: message.createdAt,
                          ),
                        _ImmersiveMessageView(
                          key: ValueKey(message.id),
                          message: message,
                          bubbleOpacity:
                              _visualStageEnabled ? _panelOpacity : 1.0,
                          ttsPhase:
                              controller.ttsPhaseForMessage(message.id),
                          onSpeechAction: message.isAssistant
                              ? () {
                                  if (controller.ttsPhaseForMessage(message.id) ==
                                      TtsPlaybackPhase.playing) {
                                    controller.stopSpeech();
                                  } else {
                                    controller.speakMessage(message);
                                  }
                                }
                              : null,
                        ),
                      ],
                    );
                  }
                  return _ImmersiveStreamingView(
                    reasoning: controller.streamingReasoning,
                    content: controller.streamingContent,
                  );
                },
              ),
            ),
          ),
          if (controller.ending) const LinearProgressIndicator(),
          if (room?.isEnded != true) _inputBar(),
        ],
      );

  Widget _nsfwButton(ImmersiveRoom room) {
    final active = room.nsfwActive;
    final manualPending = room.nsfwManualOverride.isNotEmpty;
    final color = immersiveRailPink;
    final tooltip = controller.nsfwRouting
        ? '正在根据当前房间剧情判定本轮是否需要成人小说规则'
        : manualPending
            ? '已手动${active ? '开启' : '关闭'}；下一轮使用后恢复自动判定'
            : '自动判定当前${active ? '已开启' : '未开启'}；点击后下一轮强制${active ? '关闭' : '开启'}';
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 24,
        child: OutlinedButton(
          onPressed: controller.sending ||
                  controller.ending ||
                  controller.nsfwRouting ||
                  room.isEnded
              ? null
              : () => controller.setNsfwActive(!active),
          style: OutlinedButton.styleFrom(
            foregroundColor: active ? color : Colors.white,
            disabledForegroundColor:
                active ? color.withValues(alpha: 0.6) : Colors.white70,
            side: BorderSide(color: active ? color : Colors.white70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            textStyle: Theme.of(context).textTheme.labelSmall,
          ),
          child: const Text('NSFW'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    return WillPopScope(
      onWillPop: _leave,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            room?.title ?? '沉浸房间',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (room != null) _nsfwButton(room),
            if (room != null) const SizedBox(width: 4),
            if (room != null)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') await _renameRoom();
                  if (value == 'edit') await _editRoom();
                  if (value == 'leave' && await _leave() && mounted) {
                    Navigator.pop(context);
                  }
                  if (value == 'end') await _endRoom();
                  if (value == 'delete') await _deleteRoom();
                  if (value == 'special_pin') {
                    await controller.pinCurrentSpecialStyle();
                    await _refreshTrials();
                  }
                  if (value == 'special_disable') {
                    await controller.disableSpecialStyle();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('修改名称'),
                  ),
                  if (!room.isEnded)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('房间设定与小说规则'),
                    ),
                  if (!room.isEnded)
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('暂时离开'),
                    ),
                  if (!room.isEnded)
                    const PopupMenuItem(
                      value: 'end',
                      child: Text('结束房间'),
                    ),
                  if (!room.isEnded &&
                      _activeSpecialTrial != null &&
                      PersonalityCatalog.isKnownSpecial(
                        _activeSpecialTrial!.styleKey,
                      ) &&
                      room.specialStyleKey != _activeSpecialTrial!.styleKey)
                    PopupMenuItem(
                      value: 'special_pin',
                      child: Text(
                        '改用 ${PersonalityCatalog.special(_activeSpecialTrial!.styleKey).label}',
                      ),
                    ),
                  if (!room.isEnded && room.specialStyleKey.isNotEmpty)
                    PopupMenuItem(
                      value: 'special_disable',
                      child: Text(
                        '解除 ${PersonalityCatalog.special(room.specialStyleKey).label}',
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除房间'),
                  ),
                ],
              ),
          ],
        ),
        body: controller.loading || !_visualSettingsLoaded
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final fraction =
                      _visualStageEnabled ? _panelFraction : 1.0;
                  final panelHeight = constraints.maxHeight * fraction;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_visualStageEnabled) ...[
                        Image.asset(
                          _useNightBackground
                              ? 'assets/lingchat/background/night.webp'
                              : 'assets/lingchat/background/day.webp',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ChatPortraitStage(
                              emotion: ChatVisualResolver.resolveEmotionKey(
                                'affection',
                              ),
                              portraitSet: _portraitSet,
                              transform: ChatPortraitTransform(
                                scale: _portraitScale,
                                offset: _portraitOffset,
                              ),
                              showEffect: false,
                              animate: false,
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: panelHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(
                                  alpha: _visualStageEnabled
                                      ? _panelOpacity
                                      : 1.0,
                                ),
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                          child: _conversationPanel(room),
                        ),
                      ),
                      if (_visualStageEnabled)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: panelHeight - 13,
                          child: Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                final next = (_panelFraction -
                                        details.delta.dy /
                                            constraints.maxHeight)
                                    .clamp(0.42, 0.94)
                                    .toDouble();
                                setState(() => _panelFraction = next);
                              },
                              onVerticalDragEnd: (_) =>
                                  AppDatabase.instance.setSetting(
                                'immersive_panel_fraction',
                                _panelFraction.toStringAsFixed(3),
                              ),
                              child: Container(
                                width: 84,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.drag_handle_rounded,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (activeTrialCapsuleLabels(
                        personalityBaseKey: _personalityTrial?.baseKey ?? '',
                        specialStyleKey: room?.specialStyleKey ?? '',
                      ).isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 12,
                          child: ActiveTrialCapsule(
                            labels: activeTrialCapsuleLabels(
                              personalityBaseKey:
                                  _personalityTrial?.baseKey ?? '',
                              specialStyleKey:
                                  room?.specialStyleKey ?? '',
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
  const _ImmersiveMessageView({
    super.key,
    required this.message,
    required this.bubbleOpacity,
    required this.ttsPhase,
    this.onSpeechAction,
  });

  final ImmersiveMessage message;
  final double bubbleOpacity;
  final TtsPlaybackPhase ttsPhase;
  final VoidCallback? onSpeechAction;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _ImmersiveUserBubbleSurface(
        color: Theme.of(context).colorScheme.primaryContainer,
        opacity: bubbleOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                ChatTimestampFormatter.time(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
              ),
            ),
          ],
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
              child: ReasoningPanel(
                reasoning: message.reasoningContent,
                messageId: message.id,
                translationScope: ReasoningTranslationScope.immersive,
              ),
            ),
          _ImmersiveAssistantRail(
            content: message.content,
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  ChatTimestampFormatter.time(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                ),
                if (onSpeechAction != null) ...[
                  const SizedBox(width: 2),
                  _ImmersiveSpeechActionButton(
                    phase: ttsPhase,
                    onPressed: onSpeechAction!,
                  ),
                ],
              ],
            ),
          ),
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
  const _ImmersiveAssistantRail({required this.content, this.footer});

  final String content;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        padding: const EdgeInsets.fromLTRB(13, 7, 5, 7),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: immersiveRailPink.withValues(alpha: 0.82),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovelTintText(
              text: content,
              style: const TextStyle(height: 1.62),
            ),
            if (footer != null) ...[
              const SizedBox(height: 4),
              footer!,
            ],
          ],
        ),
      );
}

class _ImmersiveUserBubbleSurface extends StatelessWidget {
  const _ImmersiveUserBubbleSurface({
    required this.color,
    required this.child,
    required this.opacity,
  });

  final Color color;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.sizeOf(context).width.clamp(260, 560).toDouble() * 0.84;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: opacity.clamp(0.18, 1).toDouble(),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
                bottomLeft: Radius.circular(17),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ImmersiveDateSeparator extends StatelessWidget {
  const _ImmersiveDateSeparator({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                ChatTimestampFormatter.dateSeparator(createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      );
}

class _ImmersiveSpeechActionButton extends StatelessWidget {
  const _ImmersiveSpeechActionButton({
    required this.phase,
    required this.onPressed,
  });

  final TtsPlaybackPhase phase;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final synthesizing = phase == TtsPlaybackPhase.synthesizing;
    final playing = phase == TtsPlaybackPhase.playing;
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: synthesizing ? null : onPressed,
      icon: synthesizing
          ? const Text('…', style: TextStyle(fontSize: 20, height: 0.8))
          : playing
              ? const Text('■', style: TextStyle(fontSize: 15, height: 1))
              : const Icon(Icons.volume_up_outlined),
      tooltip: synthesizing
          ? '正在合成语音'
          : playing
              ? '停止播放'
              : '朗读这条回复',
    );
  }
}
