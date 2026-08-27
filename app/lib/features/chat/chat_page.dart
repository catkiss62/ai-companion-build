import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/personality_trial.dart';
import '../../core/database/app_database.dart';
import '../../core/models/message_attachment.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/models/proactive_notification_settings.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../core/tts/tts_text_processor.dart';
import '../../widgets/reasoning_panel.dart';
import '../../widgets/action_tint_text.dart';
import '../../widgets/chat_portrait_stage.dart';
import 'chat_controller.dart';
import 'chat_timestamp_formatter.dart';
import '../personality/personality_lab_page.dart';
import '../phone/simulated_phone_page.dart';
import '../immersive/immersive_room_page.dart';

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
  Timer? _personalityTimer;
  PersonalityTrial? _personalityTrial;
  SpecialStyleTrial? _specialTrial;
  bool _appResumed = true;
  bool _pickingImage = false;
  bool _visualStageEnabled = true;
  bool _emotionSoundEnabled = false;
  double _emotionSoundVolume = 0.15;
  bool _showEmotionLabel = true;
  bool _typewriterEnabled = true;
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
    await _refreshPersonalityTrials();
    _personalityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshPersonalityTrials());
    });
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
    _ttsEnabled = (await db.getSetting('tts_enabled')) == '1';
    _notificationSound = ProactiveNotificationSound.fromSetting(
      await db.getSetting('proactive_notification_sound'),
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
    if (_appResumed) unawaited(_refreshPersonalityTrials());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _externalSyncTimer?.cancel();
    _personalityTimer?.cancel();
    controller.removeListener(_onChanged);
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshPersonalityTrials() async {
    final profile = await AppDatabase.instance.activePersonalityTrial();
    final special = await AppDatabase.instance.activeSpecialStyleTrial();
    if (!mounted) return;
    setState(() {
      _personalityTrial = profile;
      _specialTrial = special;
    });
  }

  String _shortRemaining(Duration duration) {
    if (duration.isNegative) return '0分';
    if (duration.inDays > 0) return '${duration.inDays}天';
    if (duration.inHours > 0) return '${duration.inHours}时';
    return '${duration.inMinutes.clamp(0, 999)}分';
  }

  Future<void> _openPersonalityLab() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalityLabPage()),
    );
    await _refreshPersonalityTrials();
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

    return Column(
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
          