import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';

import '../../core/ai/reasoning_translation_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/database/app_database.dart';
import '../../core/models/message_attachment.dart';
import '../../core/models/reference_document.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/models/proactive_frequency.dart';
import '../../core/models/proactive_notification_settings.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/relationship/relationship_age.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_text_processor.dart';
import '../../widgets/reasoning_panel.dart';
import '../../widgets/action_tint_text.dart';
import '../../widgets/chat_portrait_stage.dart';
import 'chat_controller.dart';
import 'chat_timestamp_formatter.dart';
import '../reference/reference_library_page.dart';
import '../phone/simulated_phone_page.dart';
import '../immersive/immersive_room_page.dart';
import 'chat_quick_settings_pages.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.active = false});

  final bool active;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final ChatController controller = ChatController();
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AndroidBridge _android = AndroidBridge.instance;
  Timer? _externalSyncTimer;
  bool _appResumed = true;
  bool _pickingImage = false;
  bool _visualStageEnabled = true;
  bool _emotionSoundEnabled = false;
  double _emotionSoundVolume = 0.15;
  bool _showEmotionLabel = true;
  bool _typewriterEnabled = true;
  ChatDialogueColorOption _dialogueColor = ChatDialogueColorOption.purple;
  RelationshipAge? _relationshipAge;
  bool _ttsEnabled = false;
  double _panelOpacity = 0.75;
  double _panelFraction = 0.62;
  ChatPortraitSet _portraitSet = ChatPortraitSet.largeWhale;
  double _portraitScale = ChatPortraitTransform.defaults.scale;
  Offset _portraitOffset = ChatPortraitTransform.defaults.offset;
  int _typewriterMs = 48;
  String _backgroundMode = 'auto';
  ChatEmotionVisual _currentEmotion = ChatVisualResolver.normal;
  String _currentEmotionLabel = '正常';
  bool _followLatest = true;
  bool _programmaticScroll = false;
  bool _lastGenerationActive = false;
  final GlobalKey _timelineTailKey = GlobalKey();
  final GlobalKey _streamingBodyTailKey = GlobalKey();
  ProactiveNotificationSound _notificationSound =
      ProactiveNotificationSound.chime;
  ProactiveFrequencyMode _proactiveFrequency =
      ProactiveFrequencyPolicy.defaultMode;
  TtsReadingScope _ttsReadingScope = TtsReadingScope.dialogueOnly;
  final Set<String> _knownMessageIds = <String>{};
  String? _animatedMessageId;
  bool _initializingMessages = true;
  String _lastPresentedAssistantId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onChanged);
    _initializeController();
  }


  Future<void> _initializeController() async {
    await controller.initialize();
    await _loadVisualSettings();
    await _restorePresentationCursor();
    if (!mounted) return;
    _initializingMessages = false;
    _onChanged();
    _scrollToLatest();
    await _recoverLostImage();
    if (!mounted) return;
    _externalSyncTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_appResumed &&
          widget.active &&
          !controller.analyzingImage) {
        unawaited(controller.syncExternalMessages());
        if (!controller.generationActive) {
          unawaited(controller.acknowledgeOverlayUnread());
        }
      }
    });
  }

  Future<void> _restorePresentationCursor() async {
    final stored = await AppDatabase.instance.getSetting(
          'chat_last_presented_assistant_id',
        ) ??
        '';
    ChatMessage? unseenProactive;
    if (stored.isNotEmpty) {
      final cursor = controller.messages.indexWhere(
        (message) => message.id == stored,
      );
      if (cursor >= 0) {
        for (final message in controller.messages.skip(cursor + 1)) {
          if (message.isAssistant && message.isProactive) {
            unseenProactive = message;
          }
        }
      }
    }
    _knownMessageIds.addAll(controller.messages.map((message) => message.id));
    if (_typewriterEnabled && unseenProactive != null) {
      _animatedMessageId = unseenProactive.id;
    }
    await _markLatestAssistantPresented();
  }

  Future<void> _markLatestAssistantPresented() async {
    String latest = '';
    for (final message in controller.messages.reversed) {
      if (message.isAssistant) {
        latest = message.id;
        break;
      }
    }
    if (latest.isEmpty || latest == _lastPresentedAssistantId) return;
    _lastPresentedAssistantId = latest;
    await AppDatabase.instance.setSetting(
      'chat_last_presented_assistant_id',
      latest,
    );
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _scrollToLatest();
      unawaited(controller.acknowledgeOverlayUnread());
      if (!controller.analyzingImage) {
        unawaited(controller.syncExternalMessages());
      }
    }
  }

  void _onChanged() {
    if (!mounted || _initializingMessages) return;
    final generationEnded =
        _lastGenerationActive && !controller.generationActive;
    _lastGenerationActive = controller.generationActive;
    var discoveredAssistant = false;
    for (final message in controller.messages) {
      if (_knownMessageIds.add(message.id) && message.isAssistant) {
        _animatedMessageId = message.id;
        discoveredAssistant = true;
      }
    }
    if (discoveredAssistant) {
      unawaited(_markLatestAssistantPresented());
    }
    if (controller.streamingContent.trim().isNotEmpty) {
      // Streaming may preview a portrait, but the header label only changes
      // after the final DeepSeek 19-label envelope has been persisted.
      _currentEmotion =
          ChatVisualResolver.resolve(controller.streamingContent);
    } else {
      for (final message in controller.messages.reversed) {
        if (!message.isAssistant) continue;
        if (message.emotionKey.isNotEmpty) {
          _currentEmotion =
              ChatVisualResolver.resolveEmotionKey(message.emotionKey);
          _currentEmotionLabel = message.emotionLabel.isEmpty
              ? _currentEmotion.zhLabel
              : message.emotionLabel;
        } else {
          _currentEmotion = ChatVisualResolver.resolve(message.content);
          _currentEmotionLabel = _currentEmotion.zhLabel;
        }
        break;
      }
    }
    setState(() {});
    if (_followLatest) {
      if (controller.generationActive &&
          controller.streamingContent.trim().isNotEmpty) {
        // Follow the actual visible answer tail. A long reasoning panel above
        // it may change height dramatically while streaming/collapsing, so the
        // ListView's old max extent is not a stable anchor.
        _anchorStreamingBody();
      } else if (generationEnded) {
        _anchorTimelineTail();
      } else {
        // Reasoning deltas arrive faster than a 180 ms animation can finish.
        // Jumping here prevents queued animations from lagging behind the
        // provider stream and later winning against the final collapse anchor.
        _scrollToLatest();
      }
    }
    if (_appResumed && widget.active && !controller.generationActive) {
      unawaited(controller.acknowledgeOverlayUnread());
    }
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (_programmaticScroll || !scroll.hasClients) return false;
    final distance = scroll.position.maxScrollExtent - scroll.offset;
    if (notification.direction == ScrollDirection.forward &&
        (controller.generationActive || _animatedMessageId != null)) {
      // Only an actual upward user gesture disables follow mode. Content-size
      // changes from a growing/collapsing reasoning panel are not user scrolls.
      _followLatest = false;
    } else if (distance < 8) {
      _followLatest = true;
    }
    return false;
  }

  Future<void> _loadVisualSettings() async {
    final db = AppDatabase.instance;
    _visualStageEnabled =
        (await db.getSetting('chat_visual_stage_enabled')) != '0';
    _emotionSoundEnabled =
        (await db.getSetting('emotion_sound_enabled')) == '1';
    _emotionSoundVolume = (double.tryParse(
              await db.getSetting('emotion_sound_volume') ?? '',
            ) ??
            0.15)
        .clamp(0.0, 1.0)
        .toDouble();
    _showEmotionLabel =
        (await db.getSetting('show_emotion_label')) != '0';
    _typewriterEnabled =
        (await db.getSetting('chat_typewriter_enabled')) != '0';
    _dialogueColor = ChatDialogueColorOption.fromSetting(
      await db.getSetting(ChatDialogueColorOption.settingKey),
    );
    _relationshipAge = await db.relationshipAge();
    await _android.setOverlayDialogueColor(_dialogueColor.key);
    _ttsEnabled = (await db.getSetting('tts_enabled')) == '1';
    _notificationSound = ProactiveNotificationSound.fromSetting(
      await db.getSetting('proactive_notification_sound'),
    );
    _proactiveFrequency = ProactiveFrequencyMode.fromSetting(
      await db.getSetting(ProactiveFrequencyPolicy.settingKey),
    );
    _ttsReadingScope = TtsReadingScope.fromSetting(
      await db.getSetting('tts_reading_scope'),
    );
    _panelOpacity = (double.tryParse(
              await db.getSetting('chat_panel_opacity') ?? '',
            ) ??
            0.75)
        .clamp(0.45, 0.95)
        .toDouble();
    _panelFraction = (double.tryParse(
              await db.getSetting('chat_panel_fraction') ?? '',
            ) ??
            0.62)
        .clamp(0.42, 0.94)
        .toDouble();
    _portraitSet = chatPortraitSetFromKey(
      await db.getSetting('chat_portrait_set'),
    );
    await _loadPortraitTransform(_portraitSet);
    _typewriterMs = (int.tryParse(
              await db.getSetting('chat_typewriter_ms') ?? '',
            ) ??
            48)
        .clamp(20, 120)
        .toInt();
    _backgroundMode =
        await db.getSetting('chat_background_mode') ?? 'auto';
    if (mounted && !_initializingMessages) setState(() {});
  }

  String _portraitSettingKey(String field, ChatPortraitSet set) =>
      'chat_portrait_${field}_${set.key}';

  Future<void> _loadPortraitTransform(ChatPortraitSet set) async {
    final db = AppDatabase.instance;
    final defaults = ChatPortraitTransform.defaultsFor(set);
    final legacyScale = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_scale')
        : null;
    final legacyX = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_x')
        : null;
    final legacyY = set == ChatPortraitSet.smallWhale
        ? await db.getSetting('chat_portrait_offset_y')
        : null;
    _portraitScale = (double.tryParse(
              await db.getSetting(_portraitSettingKey('scale', set)) ??
                  legacyScale ??
                  '',
            ) ??
            defaults.scale)
        .clamp(0.85, 1.80)
        .toDouble();
    _portraitOffset = Offset(
      (double.tryParse(
                await db.getSetting(_portraitSettingKey('offset_x', set)) ??
                    legacyX ??
                    '',
              ) ??
              defaults.offset.dx)
          .clamp(-0.45, 0.45)
          .toDouble(),
      (double.tryParse(
                await db.getSetting(_portraitSettingKey('offset_y', set)) ??
                    legacyY ??
                    '',
              ) ??
              defaults.offset.dy)
          .clamp(-0.35, 0.35)
          .toDouble(),
    );
  }

  Future<void> _selectPortraitSet(ChatPortraitSet set) async {
    if (set == _portraitSet) return;
    await _loadPortraitTransform(set);
    if (!mounted) return;
    setState(() => _portraitSet = set);
    await AppDatabase.instance.setSetting('chat_portrait_set', set.key);
  }

  Future<void> _setVisualSetting(String key, String value) async {
    await AppDatabase.instance.setSetting(key, value);
    if (mounted) setState(() {});
  }

  Future<void> _openPortraitTransformEditor() async {
    final result = await Navigator.of(context).push<ChatPortraitTransform>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatPortraitTransformEditor(
          emotion: _currentEmotion,
          portraitSet: _portraitSet,
          initial: ChatPortraitTransform(
            scale: _portraitScale,
            offset: _portraitOffset,
          ),
          backgroundAsset: _useNightBackground
              ? 'assets/lingchat/background/night.webp'
              : 'assets/lingchat/background/day.webp',
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _portraitScale = result.scale;
      _portraitOffset = result.offset;
    });
    await Future.wait([
      _setVisualSetting(
        _portraitSettingKey('scale', _portraitSet),
        result.scale.toStringAsFixed(4),
      ),
      _setVisualSetting(
        _portraitSettingKey('offset_x', _portraitSet),
        result.offset.dx.toStringAsFixed(4),
      ),
      _setVisualSetting(
        _portraitSettingKey('offset_y', _portraitSet),
        result.offset.dy.toStringAsFixed(4),
      ),
    ]);
  }

  bool get _useNightBackground {
    if (_backgroundMode == 'night') return true;
    if (_backgroundMode == 'day') return false;
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 18;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final target = scroll.position.maxScrollExtent;
      _programmaticScroll = true;
      scroll.jumpTo(target);
      _programmaticScroll = false;
    });
  }

  void _anchorTimelineTail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followLatest) return;
      final tailContext = _timelineTailKey.currentContext;
      if (tailContext == null) {
        _scrollToLatest();
        return;
      }
      _programmaticScroll = true;
      unawaited(
        Scrollable.ensureVisible(
          tailContext,
          alignment: 1,
          duration: Duration.zero,
        ).whenComplete(() => _programmaticScroll = false),
      );
    });
  }

  void _anchorStreamingBody() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_followLatest) return;
      final bodyTailContext = _streamingBodyTailKey.currentContext;
      if (bodyTailContext == null) {
        _scrollToLatest();
        return;
      }
      _programmaticScroll = true;
      unawaited(
        Scrollable.ensureVisible(
          bodyTailContext,
          alignment: 1,
          duration: Duration.zero,
        ).whenComplete(() => _programmaticScroll = false),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed &&
        widget.active &&
        !controller.analyzingImage) {
      unawaited(controller.acknowledgeOverlayUnread());
      unawaited(controller.syncExternalMessages());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _externalSyncTimer?.cancel();
    controller.removeListener(_onChanged);
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _openWorldBookLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReferenceLibraryPage()),
    );
  }

  Future<void> _openWorldBookQuickPanel() async {
    List<ReferenceDocument> modules =
        await AppDatabase.instance.worldBookBehaviorDocuments(
      manualOnly: true,
      limit: 100,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('世界书模块'),
                  subtitle: const Text('这里只显示“手动开关”模块；设置立即作用于下一轮。'),
                  trailing: IconButton(
                    tooltip: '管理全部世界书',
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _openWorldBookLibrary();
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: modules.isEmpty
                      ? const Center(child: Text('还没有手动开关模块。'))
                      : ListView.builder(
                          itemCount: modules.length,
                          itemBuilder: (context, index) {
                            final module = modules[index];
                            return SwitchListTile(
                              value: module.enabled && module.manualActive,
                              title: Text(module.name),
                              subtitle: Text(
                                '优先级 ${module.priority} · ${module.activationProbability}% · ${_worldBookScopeLabel(module.scope)}',
                              ),
                              onChanged: (active) async {
                                await AppDatabase.instance
                                    .setWorldBookManualActive(module.id, active);
                                modules = await AppDatabase.instance
                                    .worldBookBehaviorDocuments(
                                  manualOnly: true,
                                  limit: 100,
                                );
                                if (sheetContext.mounted) setSheetState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = input.text;
    if (text.trim().isEmpty || controller.analyzingImage) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _followLatest = true;
    input.clear();
    await controller.sendText(text);
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        await _prepareAndConfirmImage(files.first, source: 'recovered');
      } else if (response.exception != null) {
        _showMessage('没有恢复刚才选择的图片：${response.exception}');
      }
    } catch (exception) {
      if (mounted) _showMessage('恢复图片选择失败：$exception');
    }
  }

  Future<void> _chooseImageSource() async {
    if (_pickingImage || controller.generationActive || controller.savingImage || controller.analyzingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              subtitle: const Text('使用系统图片选择器'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              subtitle: const Text('打开系统相机'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _pickingImage = true);
    try {
      await _android.beginSystemPickerOverlayGuard(
        reason: source == ImageSource.camera
            ? 'flutter_image_picker_camera'
            : 'flutter_image_picker_gallery',
      );
      XFile? image;
      try {
        image = await _imagePicker.pickImage(
          source: source,
          requestFullMetadata: false,
        );
      } finally {
        await _android.endSystemPickerOverlayGuard(
          reason: source == ImageSource.camera
              ? 'flutter_image_picker_camera_returned'
              : 'flutter_image_picker_gallery_returned',
        );
      }
      if (image != null && mounted) {
        await _prepareAndConfirmImage(
          image,
          source: source == ImageSource.camera ? 'camera' : 'gallery',
        );
      }
    } catch (exception) {
      if (mounted) _showMessage('无法取得图片：$exception');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _prepareAndConfirmImage(
    XFile image, {
    required String source,
  }) async {
    PreparedImageAttachment? draft;
    try {
      draft = await controller.prepareImage(
        sourcePath: image.path,
        source: source,
        mimeType: image.mimeType,
      );
      if (!mounted) {
        await controller.discardPreparedImage(draft);
        return;
      }
      final caption = await _showImageConfirmation(draft);
      if (caption == null) {
        await controller.discardPreparedImage(draft);
        return;
      }
      final saved = await controller.sendPreparedImage(draft, caption: caption);
      if (mounted && saved) {
        _showMessage('图片已保存在本机，正在识别并准备回复…');
      }
    } catch (exception) {
      if (draft != null) {
        try {
          await controller.discardPreparedImage(draft);
        } catch (_) {}
      }
      if (mounted) _showMessage('图片准备失败：$exception');
    }
  }

  Future<String?> _showImageConfirmation(PreparedImageAttachment draft) async {
    final caption = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('发送这张图片？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    draft.thumbnailFile,
                    height: 230,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 150,
                      child: Center(child: Text('缩略图生成失败')),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: caption,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '附言（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '发送后会用千问视觉读取缩略图；观察结果作为本轮经历，是否形成长期记忆仍由记忆系统判断。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, caption.text),
              child: const Text('发送'),
            ),
          ],
        ),
      );
    } finally {
      caption.dispose();
    }
  }

  Future<void> _openAttachment(MessageAttachment attachment) async {
    final file = await controller.attachmentStorage.fileFor(attachment.originalPath);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('图片')),
          body: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _MissingAttachment(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAttachmentMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除图片消息？'),
            content: const Text('这会同时删除本机保存的原图和缩略图。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final deleted = await controller.deleteAttachmentMessage(message);
    if (mounted && !deleted) _showMessage('没有删除这条图片消息。');
  }

  Future<void> _retryImageVision(ChatMessage message) async {
    await controller.retryImageVision(message);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final timeline = controller.timelineItems;
    String? latestAssistantId;
    for (final message in controller.messages.reversed) {
      if (message.isAssistant) {
        latestAssistantId = message.id;
        break;
      }
    }
    final timelineList = controller.loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
            itemCount:
                timeline.length + (controller.showGenerationDraft ? 1 : 0) + 1,
            itemBuilder: (context, index) {
              if (index < timeline.length) {
                final item = timeline[index];
                final previous = index == 0 ? null : timeline[index - 1];
                final showDate = ChatTimestampFormatter.shouldShowDateSeparator(
                  item.createdAt,
                  previous?.createdAt,
                );
                return Column(
                  children: [
                    if (showDate) _DateSeparator(createdAt: item.createdAt),
                    if (item.isInterruption)
                      const _InterruptionMarker()
                    else
                      _MessageBubble(
                        key: ValueKey(item.message!.id),
                        message: item.message!,
                        bubbleOpacity:
                            _visualStageEnabled ? _panelOpacity : 1.0,
                        ttsPhase:
                            controller.ttsPhaseForMessage(item.message!.id),
                        attachmentStorage: controller.attachmentStorage,
                        animateSegments: _typewriterEnabled &&
                            item.message!.id == latestAssistantId &&
                            item.message!.id == _animatedMessageId,
                        typewriterMs: _typewriterMs,
                        onAnimationProgress: () {
                          if (_followLatest) {
                            _scrollToLatest();
                          }
                        },
                        onAnimationFinished: () {
                          if (_animatedMessageId == item.message!.id) {
                            _animatedMessageId = null;
                          }
                        },
                        onEmotionChanged: (emotion) {
                          if (!mounted ||
                              emotion.key == _currentEmotion.key) {
                            return;
                          }
                          setState(() {
                            // Typewriter chunks may animate the portrait only.
                            // Do not replace the persisted 19-label header text
                            // with a legacy visual presentation label.
                            _currentEmotion = emotion;
                          });
                        },
                        onOpenAttachment: _openAttachment,
                        onDelete: item.message!.isUser &&
                                item.message!.hasAttachments
                            ? () => _confirmDeleteAttachmentMessage(item.message!)
                            : null,
                        onRetryVision: item.message!.isUser &&
                                item.message!.attachments.any(
                                  (item) => item.visionFailed,
                                )
                            ? () => _retryImageVision(item.message!)
                            : null,
                        onSpeechAction: item.message!.isAssistant
                            ? () {
                                if (controller.ttsPhaseForMessage(
                                      item.message!.id,
                                    ) ==
                                    TtsPlaybackPhase.playing) {
                                  controller.stopSpeech();
                                } else {
                                  controller.speakMessage(item.message!);
                                }
                              }
                            : null,
                      ),
                  ],
                );
              }
              if (controller.showGenerationDraft && index == timeline.length) {
                return _StreamingBubble(
                  controller: controller,
                  bodyTailKey: _streamingBodyTailKey,
                );
              }
              return SizedBox(key: _timelineTailKey, height: 1);
            },
          );

    return ChatDialogueColorScope(
      option: _dialogueColor,
      child: Column(
        children: [
        _topBar(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fraction = _visualStageEnabled ? _panelFraction : 1.0;
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
                          emotion: _currentEmotion,
                          portraitSet: _portraitSet,
                          transform: ChatPortraitTransform(
                            scale: _portraitScale,
                            offset: _portraitOffset,
                          ),
                          animationToken: latestAssistantId,
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
                      child: Column(
                        children: [
                          Expanded(
                            child:
                                NotificationListener<UserScrollNotification>(
                              onNotification: _onUserScroll,
                              child: timelineList,
                            ),
                          ),
                          if (controller.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Text(
                                controller.error!,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          _composer(context),
                        ],
                      ),
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
                                    details.delta.dy / constraints.maxHeight)
                                .clamp(0.42, 0.94)
                                .toDouble();
                            setState(() => _panelFraction = next);
                          },
                          onVerticalDragEnd: (_) => _setVisualSetting(
                            'chat_panel_fraction',
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
                ],
              );
            },
          ),
        ),
        ],
      ),
    );
  }

  Future<void> _openQuickPanel() async {
    if (Theme.of(context).useMaterial3) {
      await _openQuickPanelV2();
      return;
    }
    await _loadVisualSettings();
    if (!mounted) return;
    final pageContext = context;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭 DeepSeek 面板',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => StatefulBuilder(
        builder: (context, setPanelState) {
          Future<void> update(String key, String value) async {
            await _setVisualSetting(key, value);
            setPanelState(() {});
          }

          return SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                elevation: 18,
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width * 0.78)
                      .clamp(260.0, 320.0)
                      .toDouble(),
                  height: double.infinity,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundImage: AssetImage(
                              'assets/appearance/chat_avatar.webp',
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DeepSeek',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text('聊天外观与常用开关'),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_relationshipAge != null) ...[
                        _RelationshipDaysCard(age: _relationshipAge!),
                        const SizedBox(height: 8),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_iphone_rounded),
                        title: const Text('查手机'),
                        subtitle: const Text(
                          '关闭更新后仍可查看历史；塔罗牌照常每日更新。',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await Navigator.of(pageContext).push(
                            MaterialPageRoute(
                              builder: (_) => const SimulatedPhonePage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.auto_stories_rounded),
                        title: const Text('沉浸房间'),
                        subtitle: const Text('独立长篇场景、真流式输出与房间记忆。'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await Navigator.of(pageContext).push(
                            MaterialPageRoute(
                              builder: (_) => const ImmersiveRoomLobbyPage(),
                            ),
                          );
                        },
                      ),
                      DropdownButtonFormField<ProactiveFrequencyMode>(
                        value: _proactiveFrequency,
                        decoration: const InputDecoration(
                          labelText: '主动频率',
                          border: OutlineInputBorder(),
                          helperText: '这是成功送达上限；她仍会按自己的欲望和时机决定。',
                          helperMaxLines: 2,
                        ),
                        items: ProactiveFrequencyMode.values
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(
                                  '${mode.zhLabel} · ${mode.dayLimit}次/24小时',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => _proactiveFrequency = value);
                          await update(
                            ProactiveFrequencyPolicy.settingKey,
                            value.key,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _proactiveFrequency.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('角色聊天舞台'),
                        subtitle: const Text('只影响 App 内聊天；不改悬浮窗结构。'),
                        value: _visualStageEnabled,
                        onChanged: (value) async {
                          setState(() => _visualStageEnabled = value);
                          await update(
                            'chat_visual_stage_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      if (_visualStageEnabled)
                        DropdownButtonFormField<ChatPortraitSet>(
                          value: _portraitSet,
                          decoration: const InputDecoration(
                            labelText: '立绘套装',
                            border: OutlineInputBorder(),
                          ),
                          items: ChatPortraitSet.values
                              .map(
                                (set) => DropdownMenuItem(
                                  value: set,
                                  child: Text(set.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) async {
                            if (value == null) return;
                            await _selectPortraitSet(value);
                            setPanelState(() {});
                          },
                        ),
                      if (_visualStageEnabled)
                        const SizedBox(height: 10),
                      if (_visualStageEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.zoom_out_map_rounded),
                          title: const Text('自定义立绘'),
                          subtitle: Text(
                            '${_portraitSet.label} · 当前 ${(100 * _portraitScale).round()}% · 独立保存位置',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            await _openPortraitTransformEditor();
                          },
                        ),
                      DropdownButtonFormField<ProactiveNotificationSound>(
                        value: _notificationSound,
                        decoration: const InputDecoration(
                          labelText: '主动消息提示音',
                          border: OutlineInputBorder(),
                        ),
                        items: ProactiveNotificationSound.values
                            .map(
                              (sound) => DropdownMenuItem(
                                value: sound,
                                child: Text(sound.zhLabel),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => _notificationSound = value);
                          await update(
                            'proactive_notification_sound',
                            value.key,
                          );
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6, bottom: 10),
                        child: Text(
                          '选择后还需要在系统通知管理中允许对应频道的声音和横幅。',
                        ),
                      ),
                      if (_ttsEnabled)
                        DropdownButtonFormField<TtsReadingScope>(
                          value: _ttsReadingScope,
                          decoration: const InputDecoration(
                            labelText: 'TTS 朗读内容',
                            border: OutlineInputBorder(),
                          ),
                          items: TtsReadingScope.values
                              .map(
                                (scope) => DropdownMenuItem(
                                  value: scope,
                                  child: Text(scope.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _ttsReadingScope = value);
                            await update('tts_reading_scope', value.key);
                          },
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('显示当前情绪'),
                        subtitle: const Text('在头像旁显示本轮返回的情绪标签。'),
                        value: _showEmotionLabel,
                        onChanged: (value) async {
                          setState(() => _showEmotionLabel = value);
                          await update(
                            'show_emotion_label',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('情绪短音效'),
                        subtitle: const Text('默认关闭；自动 TTS 开启时不会叠音。'),
                        value: _emotionSoundEnabled,
                        onChanged: (value) async {
                          setState(() => _emotionSoundEnabled = value);
                          await update(
                            'emotion_sound_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      if (_emotionSoundEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '情绪音效音量 ${(_emotionSoundVolume * 100).round()}%',
                          ),
                          subtitle: Slider(
                            value: _emotionSoundVolume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            label:
                                '${(_emotionSoundVolume * 100).round()}%',
                            onChanged: (value) {
                              setState(() => _emotionSoundVolume = value);
                              setPanelState(() {});
                            },
                            onChangeEnd: (value) async {
                              await update(
                                'emotion_sound_volume',
                                value.toStringAsFixed(2),
                              );
                            },
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('本地 TTS'),
                        subtitle: const Text('与设置页使用同一开关。'),
                        value: _ttsEnabled,
                        onChanged: (value) async {
                          setState(() => _ttsEnabled = value);
                          await update('tts_enabled', value ? '1' : '0');
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('逐段打字演出'),
                        subtitle: const Text('主动消息仍保持一个完整气泡。'),
                        value: _typewriterEnabled,
                        onChanged: (value) async {
                          setState(() => _typewriterEnabled = value);
                          await update(
                            'chat_typewriter_enabled',
                            value ? '1' : '0',
                          );
                        },
                      ),
                      if (_visualStageEnabled) ...[
                        const Divider(height: 28),
                        DropdownButtonFormField<String>(
                          value: _backgroundMode,
                          decoration: const InputDecoration(
                            labelText: '聊天背景',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'auto', child: Text('跟随昼夜')),
                            DropdownMenuItem(value: 'day', child: Text('固定白天')),
                            DropdownMenuItem(value: 'night', child: Text('固定夜晚')),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _backgroundMode = value);
                            await update('chat_background_mode', value);
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('聊天面板透明度 ${(_panelOpacity * 100).round()}%'),
                        Slider(
                          value: _panelOpacity,
                          min: 0.45,
                          max: 0.95,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => _panelOpacity = value);
                            setPanelState(() {});
                          },
                          onChangeEnd: (value) => update(
                            'chat_panel_opacity',
                            value.toStringAsFixed(2),
                          ),
                        ),
                      ],
                      if (_typewriterEnabled) ...[
                        Text('每字 ${_typewriterMs}ms'),
                        Slider(
                          value: _typewriterMs.toDouble(),
                          min: 24,
                          max: 104,
                          divisions: 10,
                          onChanged: (value) {
                            setState(() => _typewriterMs = value.round());
                            setPanelState(() {});
                          },
                          onChangeEnd: (value) => update(
                            'chat_typewriter_ms',
                            value.round().toString(),
                          ),
                        ),
                      ],
                      const Divider(height: 28),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: const Text('世界书'),
                        subtitle: const Text('开关或编辑动作、幽默与表达模块。'),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await _openWorldBookLibrary();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('通知管理'),
                        subtitle: const Text('提示音与横幅需在系统通知管理中允许。'),
                        onTap: () async {
                          await _android.openCompanionNotificationSettings(
                            soundKey: _notificationSound.key,
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune_rounded),
                        title: const Text('全部设置'),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          await Navigator.of(pageContext).pushNamed('/settings');
                          await _loadVisualSettings();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.copyright_outlined),
                        title: const Text('上游与素材说明'),
                        subtitle: const Text('LingChat · AGPL-3.0 与素材来源'),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('LingChat 上游说明'),
                            content: const SingleChildScrollView(
                              child: Text(
                                '聊天舞台的首批角色立绘、昼夜背景与情绪短音效来自 '
                                'SlimeBoyOwO/LingChat 固定版本。软件源码采用 AGPL-3.0；'
                                '部分素材另有上游注明的来源与非商业限制。本项目仅按个人、'
                                '非商业学习用途接入，并把素材隔离存放，便于后续替换。'
                                '\n\n完整文件：assets/lingchat/NOTICE.md',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  Future<void> _openQuickPanelV2() async {
    await _loadVisualSettings();
    if (!mounted) return;
    final pageContext = context;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭 DeepSeek 面板',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 18,
            color: Theme.of(dialogContext).colorScheme.surface,
            child: SizedBox(
              width: (MediaQuery.sizeOf(dialogContext).width * 0.82)
                  .clamp(280.0, 340.0)
                  .toDouble(),
              height: double.infinity,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundImage: AssetImage(
                          'assets/appearance/chat_avatar.webp',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DeepSeek',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('常用入口与分类设置'),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_relationshipAge != null) ...[
                    _RelationshipDaysCard(age: _relationshipAge!),
                    const SizedBox(height: 8),
                  ],
                  _QuickPanelTile(
                    icon: Icons.phone_iphone_rounded,
                    title: '查手机',
                    subtitle: '相册、浏览器、心情、购物车、塔罗与日记。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => const SimulatedPhonePage(),
                        ),
                      );
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.auto_stories_rounded,
                    title: '沉浸房间',
                    subtitle: '独立长篇场景、真流式输出与房间记忆。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => const ImmersiveRoomLobbyPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 26),
                  _QuickPanelTile(
                    icon: Icons.monitor_heart_outlined,
                    title: '她现在的状态',
                    subtitle: '只读查看欲望数值与萌属性数字。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => const CompanionStateOverviewPage(),
                        ),
                      );
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.auto_stories_outlined,
                    title: '世界书',
                    subtitle: '随时开关动作、幽默、性格与表达模块。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await _openWorldBookLibrary();
                    },
                  ),
                  const _QuickPanelHeading('分类设置'),
                  _QuickPanelTile(
                    icon: Icons.notifications_active_outlined,
                    title: '主动联系',
                    subtitle: '频率、弹窗、隐私、提示音与主动语音。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const ProactiveContactSettingsPage(),
                        ),
                      );
                      await _loadVisualSettings();
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.wallpaper_rounded,
                    title: '聊天画面',
                    subtitle: '立绘、舞台、背景与聊天框透明度。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => ChatVisualSettingsPage(
                            onEditPortrait: () async {
                              await _loadVisualSettings();
                              await _openPortraitTransformEditor();
                            },
                          ),
                        ),
                      );
                      await _loadVisualSettings();
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.graphic_eq_rounded,
                    title: '语音与情绪',
                    subtitle: '本地 TTS、情绪标签与情绪短音效。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => const VoiceEmotionSettingsPage(),
                        ),
                      );
                      await _loadVisualSettings();
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.text_fields_rounded,
                    title: '文字演出',
                    subtitle: '逐段打字、速度与对白颜色。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).push(
                        MaterialPageRoute(
                          builder: (_) => const TextPerformanceSettingsPage(),
                        ),
                      );
                      await _loadVisualSettings();
                    },
                  ),
                  const Divider(height: 26),
                  _QuickPanelTile(
                    icon: Icons.tune_rounded,
                    title: '全部设置',
                    subtitle: '完整设置将在下一步重新分类。',
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await Navigator.of(pageContext).pushNamed('/settings');
                      await _loadVisualSettings();
                    },
                  ),
                  _QuickPanelTile(
                    icon: Icons.copyright_outlined,
                    title: '上游与素材说明',
                    subtitle: 'LingChat · AGPL-3.0 与素材来源',
                    onTap: () => showDialog<void>(
                      context: dialogContext,
                      builder: (context) => AlertDialog(
                        title: const Text('LingChat 上游说明'),
                        content: const SingleChildScrollView(
                          child: Text(
                            '聊天舞台的首批角色立绘、昼夜背景与情绪短音效来自 '
                            'SlimeBoyOwO/LingChat 固定版本。软件源码采用 AGPL-3.0；'
                            '部分素材另有上游注明的来源与非商业限制。本项目仅按个人、'
                            '非商业学习用途接入，并把素材隔离存放，便于后续替换。'
                            '\n\n完整文件：assets/lingchat/NOTICE.md',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final nsfwColor = Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _openQuickPanel,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 19,
                          backgroundImage: AssetImage(
                            'assets/appearance/chat_avatar.webp',
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'DeepSeek',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_showEmotionLabel &&
                            _currentEmotionLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            _currentEmotionLabel,
                            maxLines: 1,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: controller.nsfwActive
                  ? '本轮成人规则已开启；点击后下一轮强制关闭'
                  : '本轮成人规则未开启；点击后下一轮强制开启',
              child: SizedBox(
                height: 24,
                child: OutlinedButton(
                  onPressed: controller.generationActive || controller.analyzingImage
                      ? null
                      : () => controller.setNsfwActive(!controller.nsfwActive),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: controller.nsfwActive
                        ? nsfwColor
                        : Colors.white,
                    disabledForegroundColor: controller.nsfwActive
                        ? nsfwColor.withValues(alpha: 0.6)
                        : Colors.white70,
                    side: BorderSide(
                      color: controller.nsfwActive
                          ? nsfwColor
                          : Colors.white70,
                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: controller.generationActive ||
                      controller.savingImage ||
                      controller.analyzingImage ||
                      _pickingImage
                  ? null
                  : _chooseImageSource,
              tooltip: '发送图片',
              icon: _pickingImage || controller.savingImage
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
            ),
            IconButton(
              onPressed: controller.generationActive || controller.analyzingImage
                  ? null
                  : _openWorldBookQuickPanel,
              tooltip: '世界书模块',
              icon: const Icon(Icons.auto_stories_outlined),
            ),
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '和她说点什么…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: controller.generationActive
                  ? (controller.cancellingGeneration
                      ? null
                      : controller.cancelCurrentGeneration)
                  : controller.analyzingImage
                      ? null
                      : _send,
              tooltip: controller.generationActive ? '停止这轮回复' : '发送',
              icon: controller.generationActive
                  ? const Icon(Icons.stop_rounded)
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String _worldBookScopeLabel(String scope) => switch (scope) {
      'chat' => '普通聊天',
      'chat|proactive' => '普通与主动',
      'proactive' => '主动联系',
      'immersive' => '沉浸房间',
      _ => '全部场景',
    };


class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _InterruptionMarker extends StatelessWidget {
  const _InterruptionMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Center(
        child: Text(
          '这一轮对话已中断',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.bubbleOpacity,
    required this.ttsPhase,
    required this.attachmentStorage,
    required this.onOpenAttachment,
    required this.animateSegments,
    required this.typewriterMs,
    required this.onEmotionChanged,
    required this.onAnimationProgress,
    required this.onAnimationFinished,
    this.onSpeechAction,
    this.onDelete,
    this.onRetryVision,
  });
  final ChatMessage message;
  final double bubbleOpacity;
  final TtsPlaybackPhase ttsPhase;
  final MessageAttachmentStorage attachmentStorage;
  final ValueChanged<MessageAttachment> onOpenAttachment;
  final bool animateSegments;
  final int typewriterMs;
  final ValueChanged<ChatEmotionVisual> onEmotionChanged;
  final VoidCallback onAnimationProgress;
  final VoidCallback onAnimationFinished;
  final VoidCallback? onSpeechAction;
  final VoidCallback? onDelete;
  final VoidCallback? onRetryVision;

  Widget _footer(BuildContext context) => Row(
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
          if (message.isAssistant && onSpeechAction != null) ...[
            const SizedBox(width: 2),
            _SpeechActionButton(
              phase: ttsPhase,
              onPressed: onSpeechAction!,
            ),
          ],
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              iconSize: 17,
              tooltip: '删除图片消息',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    final color = user
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final segments = message.displaySegments;
    if (message.isAssistant &&
        !message.isProactive &&
        !message.hasAttachments &&
        segments.isNotEmpty) {
      final chunks = ChatVisualResolver.chunks(
        segments,
        emotionKey: message.emotionKey,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.reasoningContent.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ReasoningPanel(
                reasoning: message.reasoningContent,
                messageId: message.id,
                translationScope: ReasoningTranslationScope.chat,
              ),
            ),
          _AssistantSegmentSequence(
            chunks: chunks,
            animate: animateSegments,
            millisecondsPerCharacter: typewriterMs,
            onEmotionChanged: onEmotionChanged,
            onProgress: onAnimationProgress,
            onFinished: onAnimationFinished,
            footer: _footer(context),
          ),
        ],
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.isProactive)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '她 · ${ProactiveIntentKind.fromKey(message.proactiveIntent).zhLabel}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        for (final attachment in message.attachments)
          if (attachment.isImage) ...[
            _AttachmentThumbnail(
              attachment: attachment,
              storage: attachmentStorage,
              onTap: () => onOpenAttachment(attachment),
            ),
            const SizedBox(height: 5),
            _VisionStatus(
              attachment: attachment,
              onRetry: onRetryVision,
            ),
          ],
        if (message.content.trim().isNotEmpty) ...[
          if (message.hasAttachments) const SizedBox(height: 8),
          if (message.isAssistant)
            if (message.isProactive && animateSegments)
              _SingleBubbleTypewriterText(
                text: message.content,
                millisecondsPerCharacter: typewriterMs,
                onProgress: onAnimationProgress,
                onFinished: onAnimationFinished,
              )
            else
              ActionTintText(
                text: message.content,
                style: const TextStyle(height: 1.45),
              )
          else
            SelectableText(
              message.content,
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
        ],
        const SizedBox(height: 4),
        _footer(context),
      ],
    );
    if (user) {
      return _UserBubbleSurface(
        color: color,
        opacity: bubbleOpacity,
        child: body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.reasoningContent.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ReasoningPanel(
              reasoning: message.reasoningContent,
              messageId: message.id,
              translationScope: ReasoningTranslationScope.chat,
            ),
          ),
        _AssistantTranscriptSurface(child: body),
      ],
    );
  }
}

class _SingleBubbleTypewriterText extends StatefulWidget {
  const _SingleBubbleTypewriterText({
    required this.text,
    required this.millisecondsPerCharacter,
    required this.onProgress,
    required this.onFinished,
  });

  final String text;
  final int millisecondsPerCharacter;
  final VoidCallback onProgress;
  final VoidCallback onFinished;

  @override
  State<_SingleBubbleTypewriterText> createState() =>
      _SingleBubbleTypewriterTextState();
}

class _SingleBubbleTypewriterTextState
    extends State<_SingleBubbleTypewriterText> {
  Timer? _timer;
  int _visibleCharacters = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final length = widget.text.runes.length;
    if (length == 0) {
      widget.onFinished();
      return;
    }
    _timer = Timer.periodic(
      Duration(milliseconds: widget.millisecondsPerCharacter),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _visibleCharacters++);
        widget.onProgress();
        if (_visibleCharacters >= length) {
          timer.cancel();
          widget.onFinished();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = String.fromCharCodes(
      widget.text.runes.take(_visibleCharacters),
    );
    return ActionTintText(
      text: visible,
      style: const TextStyle(height: 1.45),
    );
  }
}

class _AssistantSegmentSequence extends StatefulWidget {
  const _AssistantSegmentSequence({
    required this.chunks,
    required this.animate,
    required this.millisecondsPerCharacter,
    required this.onEmotionChanged,
    required this.onProgress,
    required this.onFinished,
    required this.footer,
  });

  final List<ChatVisualChunk> chunks;
  final bool animate;
  final int millisecondsPerCharacter;
  final ValueChanged<ChatEmotionVisual> onEmotionChanged;
  final VoidCallback onProgress;
  final VoidCallback onFinished;
  final Widget footer;

  @override
  State<_AssistantSegmentSequence> createState() =>
      _AssistantSegmentSequenceState();
}

class _AssistantSegmentSequenceState
    extends State<_AssistantSegmentSequence> {
  Timer? _timer;
  int _completedChunks = 0;
  int _currentCharacters = 0;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.chunks.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startChunk(0));
    } else {
      _completedChunks = widget.chunks.length;
    }
  }

  @override
  void didUpdateWidget(covariant _AssistantSegmentSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate && !widget.animate) {
      _timer?.cancel();
      _completedChunks = widget.chunks.length;
      _currentCharacters = 0;
    }
  }

  void _startChunk(int index) {
    if (!mounted || index >= widget.chunks.length) {
      widget.onFinished();
      return;
    }
    final chunk = widget.chunks[index];
    widget.onEmotionChanged(chunk.emotion);
    final length = chunk.displayText.runes.length;
    if (length == 0) {
      _finishChunk(index);
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.millisecondsPerCharacter),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _currentCharacters++);
        widget.onProgress();
        if (_currentCharacters >= length) {
          timer.cancel();
          _finishChunk(index);
        }
      },
    );
  }

  void _finishChunk(int index) {
    if (!mounted) return;
    setState(() {
      _completedChunks = index + 1;
      _currentCharacters = 0;
    });
    widget.onProgress();
    if (_completedChunks >= widget.chunks.length) {
      widget.onFinished();
      return;
    }
    _timer = Timer(
      const Duration(milliseconds: 180),
      () => _startChunk(_completedChunks),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = widget.animate
        ? (_completedChunks + (_completedChunks < widget.chunks.length ? 1 : 0))
        : widget.chunks.length;
    return _AssistantTranscriptSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < visibleCount; index++) ...[
            if (index > 0) const _AssistantSegmentDivider(),
            ActionTintText(
              text: _visibleText(index),
              style: const TextStyle(height: 1.45),
            ),
            if (_completedChunks >= widget.chunks.length &&
                index == widget.chunks.length - 1) ...[
              const SizedBox(height: 4),
              widget.footer,
            ],
          ],
        ],
      ),
    );
  }

  String _visibleText(int index) {
    final full = widget.chunks[index].displayText;
    if (!widget.animate || index < _completedChunks) return full;
    return String.fromCharCodes(
      full.runes.take(
        _currentCharacters.clamp(0, full.runes.length).toInt(),
      ),
    );
  }
}

class _AssistantTranscriptSurface extends StatelessWidget {
  const _AssistantTranscriptSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        padding: const EdgeInsets.fromLTRB(13, 7, 5, 7),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: purple.withValues(alpha: 0.82),
              width: 2,
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: child,
        ),
      );
}

class _AssistantSegmentDivider extends StatelessWidget {
  const _AssistantSegmentDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: double.infinity,
          height: 1,
          color: purple.withValues(alpha: 0.24),
        ),
      );
}

class _UserBubbleSurface extends StatelessWidget {
  const _UserBubbleSurface({
    required this.color,
    required this.child,
    this.opacity = 1,
  });

  final Color color;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = color.withValues(
      alpha: opacity.clamp(0.18, 1).toDouble(),
    );
    const radius = BorderRadius.only(
      topLeft: Radius.circular(17),
      topRight: Radius.circular(17),
      bottomLeft: Radius.circular(17),
      bottomRight: Radius.circular(4),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context)
                  .width
                  .clamp(260, 560)
                  .toDouble() *
              0.84,
        ),
        child: IntrinsicWidth(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context)
                      .width
                      .clamp(260, 560)
                      .toDouble() *
                  0.84,
            ),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _VisionStatus extends StatelessWidget {
  const _VisionStatus({
    required this.attachment,
    this.onRetry,
  });

  final MessageAttachment attachment;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (attachment.visionCompleted) {
      return Text(
        '已识别 · ${attachment.visionModel.isEmpty ? '千问视觉' : attachment.visionModel}',
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    if (attachment.visionFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '识别失败',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        const SizedBox(width: 6),
        Text(
          attachment.visionStatus ==
                  MessageAttachment.visionAnalyzingStatus
              ? '正在识别图片…'
              : '等待识别…',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({
    required this.attachment,
    required this.storage,
    required this.onTap,
  });

  final MessageAttachment attachment;
  final MessageAttachmentStorage storage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: storage.fileFor(attachment.thumbnailPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 220,
            height: 150,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
                maxWidth: 300,
                maxHeight: 320,
              ),
              child: Image.file(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _MissingAttachment(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissingAttachment extends StatelessWidget {
  const _MissingAttachment();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 150,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined),
          SizedBox(height: 6),
          Text('图片文件暂时不可用'),
        ],
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({
    required this.controller,
    required this.bodyTailKey,
  });
  final ChatController controller;
  final GlobalKey bodyTailKey;

  @override
  Widget build(BuildContext context) {
    final content = controller.streamingContent;
    final blocks = assistantStreamingTranscriptBlocks(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.streamingReasoning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ReasoningPanel(
              reasoning: controller.streamingReasoning,
              streaming: true,
            ),
          ),
        if (controller.agentActivity != null ||
            content.isNotEmpty ||
            (controller.streamingReasoning.isEmpty &&
                controller.agentActivity == null))
          _AssistantTranscriptSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.agentActivity != null)
                  _AgentActivityLine(
                    text: controller.agentActivity!.text,
                    active: controller.agentActivity!.active,
                  ),
                if (content.isNotEmpty) ...[
                  for (var index = 0; index < blocks.length; index++) ...[
                    if (index > 0) const _AssistantSegmentDivider(),
                    ActionTintText(
                      text: blocks[index],
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                  SizedBox(key: bodyTailKey, height: 1),
                ],
                if (content.isEmpty &&
                    controller.streamingReasoning.isEmpty &&
                    controller.agentActivity == null)
                  Text(
                    controller.recoveringGeneration
                        ? '正在结束上次中断的回复…'
                        : '她正在准备回复…',
                  ),
                if (controller.activeGenerationTtsPhase !=
                    TtsPlaybackPhase.idle)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SpeechActionButton(
                      phase: controller.activeGenerationTtsPhase,
                      onPressed: controller.stopSpeech,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AgentActivityLine extends StatefulWidget {
  const _AgentActivityLine({
    required this.text,
    required this.active,
  });

  final String text;
  final bool active;

  @override
  State<_AgentActivityLine> createState() => _AgentActivityLineState();
}

class _AgentActivityLineState extends State<_AgentActivityLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.48,
      upperBound: 0.84,
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _AgentActivityLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0.72;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Colors.white;
    return FadeTransition(
      opacity: _pulse,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.active ? Icons.auto_awesome_outlined : Icons.check,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                widget.text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechActionButton extends StatelessWidget {
  const _SpeechActionButton({
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
          ? const Text(
              '…',
              style: TextStyle(fontSize: 20, height: 0.8),
            )
          : playing
              ? const Text(
                  '■',
                  style: TextStyle(fontSize: 15, height: 1),
                )
              : const Icon(Icons.volume_up_outlined),
      tooltip: synthesizing
          ? '正在合成语音'
          : playing
              ? '停止播放'
              : '朗读这条回复',
    );
  }
}

class _RelationshipDaysCard extends StatelessWidget {
  const _RelationshipDaysCard({required this.age});

  final RelationshipAge age;

  @override
  Widget build(BuildContext context) {
    final start = age.startedAt.toLocal();
    final date = '${start.year.toString().padLeft(4, '0')}.'
        '${start.month.toString().padLeft(2, '0')}.'
        '${start.day.toString().padLeft(2, '0')}';
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.20),
            primary.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '认识第 ${age.dayNumber} 天',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '从 $date 开始记录',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPanelHeading extends StatelessWidget {
  const _QuickPanelHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _QuickPanelTile extends StatelessWidget {
  const _QuickPanelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
