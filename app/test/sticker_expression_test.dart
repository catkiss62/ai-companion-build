import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sticker expression mapping', () {
    test('maps existing companion emotion keys to six local moods', () {
      expect(StickerExpressionService.moodForEmotion('playful'), 'happy');
      expect(StickerExpressionService.moodForEmotion('angry'), 'angry');
      expect(StickerExpressionService.moodForEmotion('helpless'), 'sad');
      expect(StickerExpressionService.moodForEmotion('flustered'), 'shy');
      expect(StickerExpressionService.moodForEmotion('surprised'), 'confused');
      expect(StickerExpressionService.moodForEmotion('calm'), 'daily');
    });

    test('accepts upstream tags and fixes speechless locally', () {
      expect(StickerExpressionService.moodForTag('like'), 'happy');
      expect(StickerExpressionService.moodForTag('fool'), 'angry');
      expect(StickerExpressionService.moodForTag('speechless'), 'sad');
      expect(StickerExpressionService.moodForTag('see'), 'confused');
      expect(StickerExpressionService.moodForTag('cpu'), 'daily');
      expect(StickerExpressionService.moodForTag('unknown'), 'daily');
    });

    test('explicit Agent intent narrows mood without inventing one', () {
      expect(StickerExpressionService.moodForExplicitRequest('来张开心的'), 'happy');
      expect(StickerExpressionService.moodForExplicitRequest('发个生气的'), 'angry');
      expect(StickerExpressionService.moodForExplicitRequest('来张害羞的'), 'shy');
      expect(StickerExpressionService.moodForExplicitRequest('随便来一张'), isNull);
    });
  });

  group('sticker pack path safety', () {
    test('allows normalized relative pack paths', () {
      expect(
        StickerPackStorage.requireSafeArchivePath('personal-001/index.db'),
        'personal-001/index.db',
      );
      expect(
        StickerPackStorage.requireSafePackPath('memes/0001.gif'),
        'memes/0001.gif',
      );
    });

    test('rejects traversal, absolute and directory record paths', () {
      for (final value in ['../index.db', '/tmp/index.db', r'..\index.db']) {
        expect(
          () => StickerPackStorage.requireSafeArchivePath(value),
          throwsFormatException,
        );
      }
      for (final value in ['memes/../secret.jpg', '/memes/a.jpg', 'memes/']) {
        expect(
          () => StickerPackStorage.requireSafePackPath(value),
          throwsFormatException,
        );
      }
    });

    test('accepts only root-level ZIP files in a multi-pack bundle', () {
      expect(
        StickerPackStorage.requireRootBundleZipNames([
          'personal-001.zip',
          'official-001.ZIP',
          'dafeiyu-001.zip',
        ]),
        ['dafeiyu-001.zip', 'official-001.ZIP', 'personal-001.zip'],
      );
      expect(
        () => StickerPackStorage.requireRootBundleZipNames([
          'packs/personal-001.zip',
          'official-001.zip',
        ]),
        throwsFormatException,
      );
      expect(
        () => StickerPackStorage.requireRootBundleZipNames([
          'personal-001.zip',
          'readme.txt',
        ]),
        throwsFormatException,
      );
      expect(
        () => StickerPackStorage.requireRootBundleZipNames(
          ['personal-001.zip', 'official-001.zip'],
          hasDirectory: true,
        ),
        throwsFormatException,
      );
    });
  });

  test('assistant sticker history stays first-person and uses index caption', () {
    final message = ChatMessage(
      id: 'assistant-1',
      role: 'assistant',
      content: '来啦。',
      reasoningContent: '',
      model: 'test',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      attachments: [
        MessageAttachment(
          id: 'sticker-1',
          messageId: 'assistant-1',
          kind: MessageAttachment.imageKind,
          originalPath: 'originals/sticker-1.gif',
          thumbnailPath: 'thumbnails/sticker-1.png',
          mimeType: 'image/gif',
          byteSize: 123,
          width: 100,
          height: 100,
          source: 'assistant_sticker:personal-001',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: '蹦蹦跳跳地从角落赶来',
          visionModel: 'sticker_index',
        ),
      ],
    );

    expect(message.promptContent, contains('[我发送了一张表情包：'));
    expect(message.promptContent, contains('蹦蹦跳跳地从角落赶来'));
    expect(message.promptContent, isNot(contains('用户发送了一张图片')));
    expect(message.attachments.single.source, 'assistant_sticker:personal-001');
    expect(
      message.attachments.single.visionStatus,
      MessageAttachment.visionCompletedStatus,
    );
    expect(message.attachments.single.visionModel, 'sticker_index');
  });

  test('assistant image history never loses first-person ownership', () {
    final message = ChatMessage(
      id: 'assistant-image-1',
      role: 'assistant',
      content: '这张给你。',
      createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      attachments: [
        MessageAttachment(
          id: 'image-1',
          messageId: 'assistant-image-1',
          kind: MessageAttachment.imageKind,
          originalPath: 'originals/image-1.jpg',
          thumbnailPath: 'thumbnails/image-1.jpg',
          mimeType: 'image/jpeg',
          byteSize: 456,
          width: 800,
          height: 1200,
          source: 'assistant_web_image:https://example.invalid/image.jpg',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: '一张蓝色调的二次元插画',
          visionModel: 'verified_source_summary',
        ),
      ],
    );

    expect(message.promptContent, contains('[我发送了一张图片；图片内容：'));
    expect(message.promptContent, contains('一张蓝色调的二次元插画'));
    expect(message.promptContent, isNot(contains('用户发送了一张图片')));
  });
}
