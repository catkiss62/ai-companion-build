import 'dart:convert';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async => db = await AppDatabase.createForTesting(databaseFactoryFfi));
  tearDown(() async => db.closeForTesting());
  Future<void> add(String id, {List<String> tags = const ['sticker'],
      String state = 'saved', String original = 'stored', int nsfw = 0,
      int? saved = 100}) async {
    await (await db.database).insert('companion_album_candidates', {
      'id': id, 'source_kind': 'test', 'source_id': id,
      'created_at': 1, 'updated_at': 1, 'saved_at': saved,
      'user_tags_json': jsonEncode(tags), 'lifecycle_state': state,
      'original_status': original, 'original_path': 'media/originals/$id.png',
      'nsfw': nsfw,
    });
  }
  test('filters before paging; older sticker behind 240 ordinary photos remains visible', () async {
    for (var i = 0; i < 240; i++) {
      await add('photo$i', tags: ['landscape'], saved: 200);
    }
    await add('old', saved: 10);
    expect((await db.companionAlbumStickerPage()).map((e) => e.id), ['old']);
  });
  test('manual tags are authoritative, removed tags and unavailable items are excluded', () async {
    await add('manual', tags: ['other']);
    await db.setCompanionAlbumTags('manual', tags: ['anime', 'sticker']);
    await add('removed');
    await db.setCompanionAlbumTags('removed', tags: ['anime']);
    await add('deleted', state: 'soft_deleted');
    await add('missing', original: 'missing');
    await add('private', nsfw: 1);
    expect((await db.companionAlbumStickerPage()).map((e) => e.id), ['manual']);
  });
  test('keyset covers tied dates and null dates without duplicates after newer insert', () async {
    for (final id in ['a', 'b', 'c', 'd', 'e']) { await add(id); }
    await add('undated', saved: null);
    final first = await db.companionAlbumStickerPage(limit: 2);
    await add('new', saved: 1000);
    final second = await db.companionAlbumStickerPage(limit: 2, before: first.last);
    final third = await db.companionAlbumStickerPage(limit: 2, before: second.last);
    expect([...first, ...second, ...third].map((e) => e.id), ['e','d','c','b','a','undated']);
    expect(await db.companionAlbumStickerPage(before: third.last), isEmpty);
  });
}
