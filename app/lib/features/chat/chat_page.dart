import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';

import '../../core/ai/reasoning_translation_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/attachment_pipeline_telemetry.dart';
import '../../core/models/message_attachment.dart';
import '../../core/models/reference_document.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/models/proactive_frequency.dart';
import '../../core/models/proactive_notification_settings.dart';
import '../../core/presentation/chat_visuals.dart';
import '../../core/presentation/generation_presentation_policy.dart';
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
    final storedValue = await AppDatabase.instance.getSetting(
      'chat_last_presented_assistant_id',
    );
    final stored = storedValue ?? '';
    ChatMessage? unseenAssistant;
    if (stored.isNotEmpty) {
      final cursor = controller.messages.indexWhere(
        (message) => message.id == stored,
      );
      if (cursor >= 0) {
        for (final message in controller.messages.skip(cursor + 1)) {
          if (message.isAssistant) {
            unseenAssistant = message;
          }
        }
      }
    }
    _knownMessageIds.addAll(controller.messages.map((message) => message.id));
    if (_typewriterEnabled && unseenAssistant != null) {
      // A non-empty cursor proves this answer was committed after the last
      // completed App presentation. Resume it once, including ordinary turns
      // interrupted while post-turn work was still active.
      _animatedMessageId = unseenAssistant.id;
    } else {
      // A fresh install/upgrade with no cursor must not replay arbitrary chat
      // history. Seed the cursor only when no interrupted presentation exists.
      await _markLatestAssistantPresented();
    }
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
    if (discoveredAssistant &&
        GenerationPresentationPolicy.markPresentedOnDiscovery(
          typewriterEnabled: _typewriterEnabled,
        )) {
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
        !c