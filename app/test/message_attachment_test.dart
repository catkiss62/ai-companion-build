import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/media_blob_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final attachment = MessageAttachment(
    id: 'attachment-1',
    messageId: 'message-1',
    kind: MessageAttachment.imageKind,
    originalPath: 'originals/attachment-1.jpg',
    thumbnailPath: 'thumbnails/attachment-1.png',
    mimeType: 'image/jpeg',
    byteSize: 1234,
    width: 1200,
    height: 800,
    source: 'gallery',
    createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
  );

  test('attachment database round trip preserves durable relative paths', () {
    final restored = MessageAttachment.fromDb(attachment.toDb());
    expect(restored.id, attachment.id);
    expect(restored.messageId, attachment.messageId);
    expect(restored.originalPath, attachment.originalPath);
    expect(restored.thumbnailPath, attachment.thumbnailPath);
    expect(restored.width, 1200);
    expect(restored.height, 800);
  });

  test('shared blob id and reference paths survive a database round trip', () {
    final originalSha = List<String>.filled(64, 'a').join();
    final thumbnailSha = List<String>.filled(64, 'b').join();
    final shared = MessageAttachment(
      id: 'attachment-shared',
      messageId: 'message-shared',
      kind: MessageAttachment.imageKind,
      originalPath: 'media/originals/$originalSha.jpg',
      thumbnailPath: 'media/thumbnails/$thumbnailSha.png',
      mimeType: 'image/jpeg',
      byteSize: 321,
      width: 32,
      height: 24,
      source: 'user_sticker:pack:item',
      createdAt: DateTime.fromMillisecondsSinceEpoch(654321),
      blobId: originalSha,
    );

    final restored = MessageAttachment.fromDb(shared.toDb());
    expect(restored.blobId, originalSha);
    expect(restored.originalPath, shared.originalPath);
    expect(MediaBlobStorage.isMediaReference(restored.thumbnailPath), isTrue);
    expect(
      MessageAttachmentStorage.requireSafeRelativePath(restored.originalPath),
      restored.originalPath,
    );
  });

  test('pending image history never pretends recognition finished', () {
    final message = ChatMessage(
      id: 'message-1',
      role: 'user',
      content: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
      attachments: [attachment],
    );
    expect(message.promptContent, contains('视觉识别尚未完成'));
    expect(message.promptContent, isNotEmpty);
    expect(message.toDb().containsKey('attachments'), isFalse);
    expect(message.toJson()['attachments'], hasLength(1));
  });

  test('caption is retained as an explicit image annotation', () {
    final message = ChatMessage(
      id: 'message-1',
      role: 'user',
      content: '今天看到的云',
      createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
      attachments: [attachment],
    );
    expect(message.promptContent, contains('附言：今天看到的云'));
  });

  test('snapshot paths reject traversal and absolute paths', () {
    expect(
      MessageAttachmentStorage.requireSafeRelativePath(
        'originals/attachment-1.jpg',
      ),
      'originals/attachment-1.jpg',
    );
    expect(
      () => MessageAttachmentStorage.requireSafeRelativePath('../secret'),
      throwsFormatException,
    );
    expect(
      () => MessageAttachmentStorage.requireSafeRelativePath('/tmp/file.jpg'),
      throwsFormatException,
    );
  });
}
