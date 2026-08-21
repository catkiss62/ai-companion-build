import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/personality_trial.dart';
import '../../core/database/app_database.dart';
import '../../core/models/message_attachment.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/storage/message_attachment_storage.dart';
import '../../core/models/proactive_intent.dart';
import '../../core/tts/tts_playback_queue.dart';
import '../../widgets/reasoning_panel.dart';
import 'chat_controller.dart';
import 'chat_timestamp_formatter.dart';
import '../personality/personality_lab_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onChanged);
    _initializeController();
  }


  Future<void> _initializeController() async {
    await controller.initialize();
    if (!mounted) return;
    _scrollToLatest();
    await _refreshPersonalityTrials();
    _personalityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshPersonalityTrials());
    });
    await _recoverLostImage();
    if (!mounted) return;
    _externalSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appResumed &&
          widget.active &&
          !controller.sending &&
          !controller.analyzingImage) {
        unawaited(controller.acknowledgeOverlayUnread());
        unawaited(controller.syncExternalMessages());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _scrollToLatest();
      unawaited(controller.acknowledgeOverlayUnread());
      if (!controller.sending && !controller.analyzingImage) {
        unawaited(controller.syncExternalMessages());
      }
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final wasNearBottom = !scroll.hasClients ||
        (scroll.position.maxScrollExtent - scroll.offset) < 140 ||
        controller.sending;
    if (wasNearBottom) {
      _scrollToLatest(animate: true);
    }
  }

  void _scrollToLatest({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final target = scroll.position.maxScrollExtent;
      if (animate) {
        scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        scroll.jumpTo(target);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed &&
        widget.active &&
        !controller.sending &&
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
    if (_pickingImage || controller.sending || controller.savingImage || controller.analyzingImage) return;
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
    final body = Column(
      children: [
        _topBar(context),
        Expanded(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  itemCount: controller.messages.length + (controller.sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < controller.messages.length) {
                      final message = controller.messages[index];
                      final previous = index == 0
                          ? null
                          : controller.messages[index - 1];
                      final showDate = ChatTimestampFormatter.shouldShowDateSeparator(
                        message.createdAt,
                        previous?.createdAt,
                      );
                      return Column(
                        children: [
                          if (showDate)
                            _DateSeparator(createdAt: message.createdAt),
                          _MessageBubble(
                            message: message,
                            ttsPhase: controller.ttsPhaseForMessage(message.id),
                            attachmentStorage: controller.attachmentStorage,
                            onOpenAttachment: _openAttachment,
                            onDelete: message.isUser && message.hasAttachments
                                ? () => _confirmDeleteAttachmentMessage(message)
                                : null,
                            onRetryVision: message.isUser &&
                                    message.attachments.any(
                                      (item) => item.visionFailed,
                                    )
                                ? () => _retryImageVision(message)
                                : null,
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
                    return _StreamingBubble(controller: controller);
                  },
                ),
        ),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _composer(context),
      ],
    );

    return body;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '她',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (controller.cancellingGeneration)
                    Text(
                      '正在停止…',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (controller.recoveringGeneration)
                    Text(
                      '正在接回刚才没完成的回复…',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (controller.analyzingImage)
                    Text(
                      '正在看图片…',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (controller.sending)
                    Text(
                      '正在想…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (_personalityTrial != null || _specialTrial != null)
              TextButton(
                onPressed: _openPersonalityLab,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                ),
                child: Text([
                  if (_personalityTrial != null)
                    '试穿 ${_shortRemaining(_personalityTrial!.remaining())}',
                  if (_specialTrial != null)
                    '特殊 ${_shortRemaining(_specialTrial!.remaining())}',
                ].join(' · ')),
              ),
            if (_personalityTrial != null || _specialTrial != null)
              const SizedBox(width: 4),
            Tooltip(
              message: controller.nsfwActive
                  ? '本轮成人规则已开启；点击后下一轮强制关闭'
                  : '本轮成人规则未开启；点击后下一轮强制开启',
              child: SizedBox(
                height: 24,
                child: OutlinedButton(
                  onPressed: controller.sending || controller.analyzingImage
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
              onPressed: controller.sending ||
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
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
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
              onPressed: controller.sending
                  ? (controller.cancellingGeneration
                      ? null
                      : controller.cancelCurrentGeneration)
                  : controller.analyzingImage
                      ? null
                      : _send,
              tooltip: controller.sending ? '停止这轮回复' : '发送',
              icon: controller.sending
                  ? const Icon(Icons.stop_rounded)
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}


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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.ttsPhase,
    required this.attachmentStorage,
    required this.onOpenAttachment,
    this.onSpeechAction,
    this.onDelete,
    this.onRetryVision,
  });
  final ChatMessage message;
  final TtsPlaybackPhase ttsPhase;
  final MessageAttachmentStorage attachmentStorage;
  final ValueChanged<MessageAttachment> onOpenAttachment;
  final VoidCallback? onSpeechAction;
  final VoidCallback? onDelete;
  final VoidCallback? onRetryVision;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    final color = user
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isProactive)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '她 · ${ProactiveIntentKind.fromKey(message.proactiveIntent).zhLabel}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            if (message.isAssistant)
              ReasoningPanel(
                reasoning: message.reasoningContent,
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
              SelectableText(
                message.content,
                style: const TextStyle(height: 1.45),
              ),
            ],
            const SizedBox(height: 4),
            Row(
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
            ),
          ],
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
  const _StreamingBubble({required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.agentActivity != null)
              _AgentActivityLine(
                text: controller.agentActivity!.text,
                active: controller.agentActivity!.active,
              ),
            ReasoningPanel(
              reasoning: controller.streamingReasoning,
              streaming: true,
            ),
            if (controller.streamingContent.isNotEmpty)
              SelectableText(controller.streamingContent),
            if (controller.streamingContent.isEmpty &&
                controller.streamingReasoning.isEmpty &&
                controller.agentActivity == null)
              Text(controller.recoveringGeneration ? '正在接回刚才没完成的回复…' : '她正在准备回复…'),
            if (controller.activeGenerationTtsPhase != TtsPlaybackPhase.idle)
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
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
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
