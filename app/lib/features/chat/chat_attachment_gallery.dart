import 'package:flutter/material.dart';

import '../../core/models/message_attachment.dart';
import '../../core/storage/message_attachment_storage.dart';
import 'chat_attachment_thumbnail.dart';

/// Presentation only: page changes never resend or mutate attachments.
class ChatAttachmentGallery extends StatefulWidget {
  const ChatAttachmentGallery({
    super.key,
    required this.attachments,
    required this.storage,
    required this.onOpen,
    this.statusBuilder,
  });

  final List<MessageAttachment> attachments;
  final MessageAttachmentStorage storage;
  final ValueChanged<MessageAttachment> onOpen;
  final Widget Function(MessageAttachment)? statusBuilder;

  @override
  State<ChatAttachmentGallery> createState() => _ChatAttachmentGalleryState();
}

class _ChatAttachmentGalleryState extends State<ChatAttachmentGallery> {
  int _page = 0;
  PageController _controller = PageController(keepPage: false);

  String _identity(ChatAttachmentGallery widget) => widget.attachments
      .map((a) => '${a.messageId}:${a.id}')
      .join('\u0000');

  @override
  void didUpdateWidget(covariant ChatAttachmentGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recognition/status updates keep the page. A different batch starts at 0.
    if (_identity(oldWidget) != _identity(widget)) {
      _page = 0;
      _controller.dispose();
      _controller = PageController(keepPage: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _thumbnail(MessageAttachment attachment) => ChatAttachmentThumbnail(
        key: ValueKey(attachment.id),
        attachment: attachment,
        storage: widget.storage,
        onTap: () => widget.onOpen(attachment),
      );

  @override
  Widget build(BuildContext context) {
    final images = widget.attachments;
    if (images.isEmpty) return const SizedBox.shrink();
    final selected = images[_page.clamp(0, images.length - 1)];
    if (images.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(selected),
          const SizedBox(height: 5),
          if (widget.statusBuilder != null) widget.statusBuilder!(selected),
        ],
      );
    }
    // Explicit bounds also work inside the chat bubble's IntrinsicWidth.
    // A stable image viewport avoids moving the conversation during swipes.
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: PageView.builder(
              key: ValueKey(_identity(widget)),
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) => Center(
                child: _thumbnail(images[index]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '第 ${_page + 1} 张，共 ${images.length} 张图片，左右滑动切换',
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var index = 0; index < images.length; index++)
                    Container(
                      key: ValueKey('image-dot-$index'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          if (widget.statusBuilder != null) widget.statusBuilder!(selected),
        ],
      ),
    );
  }
}
