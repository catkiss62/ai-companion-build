import 'package:flutter/material.dart';

import '../../core/models/message_attachment.dart';
import '../../core/storage/message_attachment_storage.dart';

class ChatImageSendDialog extends StatelessWidget {
  const ChatImageSendDialog({
    super.key,
    required this.selected,
    required this.caption,
    required this.qwenConfigured,
    required this.onCaptionChanged,
  });

  final List<PreparedImageAttachment> selected;
  final String caption;
  final bool qwenConfigured;
  final ValueChanged<String> onCaptionChanged;

  @override
  Widget build(BuildContext context) {
    const buttonPadding = EdgeInsets.symmetric(horizontal: 6);
    return StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text('一起发送 ${selected.length} 张图片'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final draft in selected)
                        Stack(
                          children: [
                            Image.file(
                              draft.thumbnailFile,
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                tooltip: '移除这张图片',
                                onPressed: () =>
                                    update(() => selected.remove(draft)),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: caption,
                  onChanged: onCaptionChanged,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '附言（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('这些图片作为一条消息发送，识别完成后一起回复。'),
                Text(
                  qwenConfigured
                      ? '千问未识别成功时使用 DS 识图。'
                      : '填写千问视觉 API Key 后可使用千问识图。',
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actions: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(padding: buttonPadding),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('取消'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, ImageVisionRoute.first),
                  style: OutlinedButton.styleFrom(padding: buttonPadding),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('DS识图'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: selected.isEmpty || !qwenConfigured
                      ? null
                      : () => Navigator.pop(context, ImageVisionRoute.qwen),
                  style: FilledButton.styleFrom(padding: buttonPadding),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('千问识图'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
