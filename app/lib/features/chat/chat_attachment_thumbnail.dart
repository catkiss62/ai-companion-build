import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/message_attachment.dart';
import '../../core/storage/message_attachment_storage.dart';

class ChatAttachmentThumbnail extends StatefulWidget {
  const ChatAttachmentThumbnail({
    super.key,
    required this.attachment,
    required this.storage,
    required this.onTap,
  });

  final MessageAttachment attachment;
  final MessageAttachmentStorage storage;
  final VoidCallback onTap;

  @override
  State<ChatAttachmentThumbnail> createState() =>
      _ChatAttachmentThumbnailState();
}

class _ChatAttachmentThumbnailState extends State<ChatAttachmentThumbnail> {
  late Future<File> _file;

  String _path(MessageAttachment attachment) {
    final sticker =
        attachment.source.startsWith('assistant_sticker:') ||
        attachment.source.startsWith('user_sticker:');
    final animatedSticker = sticker && attachment.mimeType == 'image/gif';
    return animatedSticker ? attachment.originalPath : attachment.thumbnailPath;
  }

  @override
  void initState() {
    super.initState();
    _file = widget.storage.fileFor(_path(widget.attachment));
  }

  @override
  void didUpdateWidget(covariant ChatAttachmentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage ||
        _path(oldWidget.attachment) != _path(widget.attachment)) {
      _file = widget.storage.fileFor(_path(widget.attachment));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final sticker =
        attachment.source.startsWith('assistant_sticker:') ||
        attachment.source.startsWith('user_sticker:');
    final ratio = attachment.width > 0 && attachment.height > 0
        ? attachment.width / attachment.height
        : 220 / 150;
    // This is nested in an intrinsic-width bubble. Use the saved dimensions
    // for the same bounded footprint before, during and after image decoding.
    final maximumWidth = sticker ? 180.0 : 300.0;
    final width = (320 * ratio).clamp(0.0, maximumWidth).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: width / ratio),
      child: AspectRatio(
        aspectRatio: ratio,
        // The child supplies the preferred intrinsic width to the bubble.
        // AspectRatio then sizes the image with the actual available width.
        child: SizedBox(
          width: width,
          child: FutureBuilder<File>(
            key: ValueKey(_file),
            future: _file,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const MissingChatAttachment();
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const MissingChatAttachment(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class MissingChatAttachment extends StatelessWidget {
  const MissingChatAttachment();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 150,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined),
            SizedBox(height: 6),
            Text('图片文件暂时不可用'),
          ],
        ),
      ),
    );
  }
}
