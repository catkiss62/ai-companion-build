import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/proactive_intent.dart';
import '../../widgets/reasoning_panel.dart';
import 'chat_controller.dart';
import 'chat_timestamp_formatter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final ChatController controller = ChatController();
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();
  Timer? _externalSyncTimer;
  bool _appResumed = true;

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
    _externalSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_appResumed && !controller.sending) {
        unawaited(controller.syncExternalMessages());
      }
    });
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final wasNearBottom = !scroll.hasClients ||
        (scroll.position.maxScrollExtent - scroll.offset) < 140 ||
        controller.sending;
    if (wasNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        if (scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed && !controller.sending) {
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

  Future<void> _send() async {
    final text = input.text;
    if (text.trim().isEmpty) return;
    input.clear();
    await controller.sendText(text);
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
                            onSpeak: message.isAssistant
                                ? () => controller.speakMessage(message)
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
                  else if (controller.sending)
                    Text(
                      '正在想…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (controller.ttsState.running)
              IconButton(
                onPressed: controller.stopSpeech,
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: controller.ttsState.pending > 0
                    ? '停止语音（队列 ${controller.ttsState.pending}）'
                    : '停止语音',
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
  const _MessageBubble({required this.message, this.onSpeak});
  final ChatMessage message;
  final VoidCallback? onSpeak;

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
            SelectableText(message.content, style: const TextStyle(height: 1.45)),
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
                if (message.isAssistant && onSpeak != null) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: onSpeak,
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: '重新朗读这条回复',
                  ),
                ],
              ],
            ),
          ],
        ),
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
            ReasoningPanel(
              reasoning: controller.streamingReasoning,
              streaming: true,
            ),
            if (controller.streamingContent.isNotEmpty)
              SelectableText(controller.streamingContent),
            if (controller.streamingContent.isEmpty &&
                controller.streamingReasoning.isEmpty)
              Text(controller.recoveringGeneration ? '正在接回刚才没完成的回复…' : '她正在准备回复…'),
          ],
        ),
      ),
    );
  }
}
