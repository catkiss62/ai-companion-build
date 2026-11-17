import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_prompt_builder.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });

  tearDown(() async {
    await db.closeForTesting();
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final mode in PromptGenerationMode.values) {
    test('${mode.name}: old jokes remain history while the default address is stable', () async {
      final now = DateTime(2026, 11, 17, 12);
      final recent = [
        ChatMessage(id: 'u1', role: 'user', content: '我刚刚打翻了茶杯',
          createdAt: now.subtract(const Duration(minutes: 4))),
        ChatMessage(id: 'a1', role: 'assistant', content: '「翻杯冠军来啦」',
          createdAt: now.subtract(const Duration(minutes: 3))),
        ChatMessage(id: 'u2', role: 'user', content: '我等下去买菜',
          createdAt: now.subtract(const Duration(minutes: 2))),
      ];
      for (final message in recent) {
        await db.insertMessage(message);
      }
      final proactive = mode == PromptGenerationMode.proactive;
      final built = await PromptBuilder(db).buildChatPrompt(
        latestUserText: proactive ? '' : recent.last.content,
        retrievalQuery: '买菜',
        recent: recent,
        desire: await db.loadDesire(),
        thoughts: const [],
        mode: mode,
        now: now,
      );
      final address = built.messages.singleWhere((message) =>
          message['role'] == 'system' &&
          message['content'].toString().startsWith('【对用户的称呼】'));
      expect(address['content'], contains('以「主人」为基础'));
      expect(address['content'], contains('或省略称呼'));
      expect(address['content'], contains('用户明确说以后也这样叫'));
      expect(address['content'], isNot(contains('翻杯冠军')));
      expect(built.messages.map((m) => m['content']).join('\n'),
          contains('翻杯冠军'));
      if (proactive) {
        expect(built.messages.where((m) => m['role'] == 'user'), isEmpty);
      } else {
        expect(built.messages.last['role'], 'user');
        expect(built.messages.last['content'], contains(recent.last.content));
      }
    });
  }

  test('immersive dialogue gets address guidance within its own viewpoint lock', () async {
    final room = await ImmersiveRoomRepository(db).createRoom(
      title: '称呼测试', openingScene: '', inheritCurrentChat: false);
    final messages = await ImmersivePromptBuilder(db).build(
      room: room, history: const [], latestUserText: '我们先进去吧',
      nsfwActive: false);
    final lock = messages.singleWhere((m) =>
        m['content'].toString().startsWith('【本轮最终锁】'));
    expect(lock['content'], contains('叙述中仍用「你」'));
    expect(lock['content'], contains('仅用于小鲸鱼的对白'));
    expect(lock['content'], contains('以「主人」为基础'));
    expect(lock['content'], contains('用户明确指定的场景称呼只在该场景内用'));
    expect(messages.last['content'], '我们先进去吧');
  });
}
