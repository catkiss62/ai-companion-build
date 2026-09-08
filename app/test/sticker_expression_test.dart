import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/desire/conversation_initiative_policy.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pack aliases and Chinese tag labels do not mutate stable ids', () {
    const personal = StickerPackMeta(
      id: 'personal-001',
      name: '个人表情包 68 张',
      description: '',
      license: '',
      rootPath: '/ignored',
      count: 68,
    );
    const official = StickerPackMeta(
      id: 'official-001',
      name: '官方表情包1号',
      description: '',
      license: '',
      rootPath: '/ignored',
      count: 20,
    );
    expect(StickerDisplayLabels.packName(personal), '表情包A');
    expect(StickerDisplayLabels.packName(official), '表情包B');
    expect(StickerDisplayLabels.comparePacks(personal, official), lessThan(0));
    expect(
      [official, personal]..sort(StickerDisplayLabels.comparePacks),
      [personal, official],
    );
    expect(personal.id, 'personal-001');
    expect(StickerDisplayLabels.tagName('happy'), '开心');
    expect(StickerDisplayLabels.tagName('custom_tag'), 'custom_tag');
  });

  test('sticker agency exposes NSFW and dark humor but hides group-chat waste',
      () {
    const darkHumor = StickerRecord(
      packId: 'personal-001',
      path: 'memes/0068.jpg',
      tag: 'daily',
      caption: '上吊黑色幽默表情',
      keywords: '上吊 黑色幽默',
      toneScope: 'disabled',
      intensity: 1,
      enabled: false,
    );
    const groupChatWaste = StickerRecord(
      packId: 'personal-001',
      path: 'memes/0066.jpg',
      tag: 'daily',
      caption: '投喂群友便便',
      keywords: '群聊 便便',
      toneScope: 'disabled',
      intensity: 1,
      enabled: false,
    );
    const nsfw = StickerRecord(
      packId: 'personal-001',
      path: 'memes/0067.jpg',
      tag: 'bold',
      caption: '成人表情',
      keywords: '成人',
      toneScope: 'nsfw',
      intensity: 2,
      enabled: true,
    );

    expect(StickerAgencyPolicy.isVisible(darkHumor), isTrue);
    expect(StickerAgencyPolicy.isAssistantSelectable(darkHumor), isTrue);
    expect(StickerAgencyPolicy.isVisible(groupChatWaste), isFalse);
    expect(
      StickerAgencyPolicy.isAssistantSelectable(groupChatWaste),
      isFalse,
    );
    expect(StickerAgencyPolicy.isVisible(nsfw), isTrue);
    expect(StickerAgencyPolicy.isAssistantSelectable(nsfw), isTrue);
    expect(StickerAgencyPolicy.categoryKey(nsfw), 'nsfw');
    expect(StickerDisplayLabels.tagName('nsfw'), '涩涩');
  });

  test('real sticker actions may carry the whole reply without dialogue', () {
    expect(
      StickerExpressionService.shouldUseStickerOnly(
        messageId: 'explicit',
        generatedText: '「给你。」',
        speechAct: ConversationSpeechAct.answer,
        explicitStickerTool: true,
      ),
      isTrue,
    );
    expect(
      StickerExpressionService.shouldUseStickerOnly(
        messageId: 'battle',
        generatedText: '「接招。」',
        speechAct: ConversationSpeechAct.react,
        stickerBattle: true,
      ),
      isTrue,
    );
    expect(
      StickerExpressionService.shouldUseStickerOnly(
        messageId: 'question',
        generatedText: '「你具体想找哪一张？」',
        speechAct: ConversationSpeechAct.ask,
      ),
      isFalse,
    );
  });

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
      content: '',
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

    expect(
      message.promptContent,
      '[我发送了一张表情包：蹦蹦跳跳地从角落赶来]',
    );
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

  test('user sticker uses indexed meaning and never becomes vision input', () {
    final message = ChatMessage(
      id: 'user-sticker-1',
      role: 'user',
      content: '晚安',
      createdAt: DateTime.fromMillisecondsSinceEpoch(3000),
      attachments: [
        MessageAttachment(
          id: 'sticker-user-1',
          messageId: 'user-sticker-1',
          kind: MessageAttachment.imageKind,
          originalPath: 'originals/sticker-user-1.gif',
          thumbnailPath: 'thumbnails/sticker-user-1.png',
          mimeType: 'image/gif',
          byteSize: 123,
          width: 120,
          height: 120,
          source: 'user_sticker:personal-001',
          createdAt: DateTime.fromMillisecondsSinceEpoch(3000),
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: '抱着枕头困困地说晚安',
          visionModel: 'sticker_index',
        ),
      ],
    );
    expect(message.promptContent, contains('[用户发送了一张表情包：'));
    expect(message.promptContent, contains('抱着枕头困困地说晚安'));
    expect(message.promptContent, isNot(contains('视觉模型观察')));
    expect(message.promptContent, contains('附言：晚安'));
  });
}
