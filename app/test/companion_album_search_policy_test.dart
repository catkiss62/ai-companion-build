import 'package:ai_companion_localfirst/core/models/companion_album.dart';
import 'package:ai_companion_localfirst/core/phone/companion_album_search_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('self-image intent ranks saved self image above unrelated pictures', () {
    final matches = CompanionAlbumSearchPolicy.rank(
      query: '你记不记得之前存的一张你自己的图片',
      items: [
        albumItem(
          id: 'landscape',
          title: '海边晚霞',
          summary: '海面和橙色夕阳',
          category: 'other',
          savedAt: DateTime(2026, 8, 29, 20),
        ),
        albumItem(
          id: 'self',
          title: '蓝发鲸鱼娘',
          summary: '蓝色长发、鲸鱼尾和女仆装的动漫人物',
          category: 'self_image',
          savedAt: DateTime(2026, 8, 28, 20),
        ),
      ],
    );

    expect(matches, isNotEmpty);
    expect(matches.first.item.id, 'self');
  });

  test('visual clue fuzzy-matches stored vision summary', () {
    final matches = CompanionAlbumSearchPolicy.rank(
      query: '相册里那张蓝头发还有鲸鱼尾巴的图',
      items: [
        albumItem(
          id: 'self',
          title: '她的形象',
          summary: '蓝色长发，身后有明显鲸鱼尾，白色背景',
          category: 'self_image',
        ),
        albumItem(
          id: 'cat',
          title: '猫咪',
          summary: '窗边睡觉的橘猫',
        ),
      ],
    );

    expect(matches.first.item.id, 'self');
    expect(matches.first.score, greaterThan(0));
  });

  test('soft-deleted and nsfw entries are never searchable', () {
    final matches = CompanionAlbumSearchPolicy.rank(
      query: '帮我找那张蓝发图片',
      items: [
        albumItem(
          id: 'deleting',
          title: '蓝发图片',
          lifecycle: CompanionAlbumItem.softDeleted,
        ),
        albumItem(id: 'unsafe', title: '蓝发图片', nsfw: true),
      ],
    );

    expect(matches, isEmpty);
  });

  test('generic unmatched request returns bounded ambiguous recent choices', () {
    final matches = CompanionAlbumSearchPolicy.rank(
      query: '你记得之前存的那张图片吗',
      items: [
        albumItem(id: 'older', title: '第一张', savedAt: DateTime(2026, 8, 1)),
        albumItem(id: 'newer', title: '第二张', savedAt: DateTime(2026, 8, 2)),
      ],
    );

    expect(matches.first.item.id, 'newer');
    expect(matches.every((item) => item.confidence == 'ambiguous_recent'), isTrue);
  });
}

CompanionAlbumItem albumItem({
  required String id,
  String title = '',
  String summary = '',
  String category = 'other',
  String lifecycle = CompanionAlbumItem.saved,
  bool nsfw = false,
  DateTime? savedAt,
}) =>
    CompanionAlbumItem(
      id: id,
      sourceKind: 'public_web',
      sourceId: 'source-$id',
      sourceUrl: 'https://example.com/$id.jpg',
      sourceDomain: 'example.com',
      title: title,
      summary: summary,
      reason: '喜欢这张图',
      category: category,
      nsfw: nsfw,
      thumbnailPath: '$id.jpg',
      contentSha256: 'hash-$id',
      visualFingerprint: '',
      perceptualHash: '',
      visionModel: 'test',
      width: 100,
      height: 100,
      lifecycle: lifecycle,
      feedback: 'neutral',
      comment: '',
      categorySource: 'ai',
      createdAt: DateTime(2026, 8, 1),
      savedAt: savedAt ?? DateTime(2026, 8, 1),
      deleteAfter: null,
      unread: false,
    );
