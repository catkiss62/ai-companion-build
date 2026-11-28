import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/lens/lens_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('旁听保留实际观察，用户追问需要回答；新场不继承历史', () {
    final session = LensSession();
    final turn = LensSession.parse('{"summary":"花盆旁边一只猫","reply":""}', '');
    expect(turn.history.containsKey('用户原话'), isFalse);
    session.remember(turn);
    expect(session.prompt('刚才猫在哪里'), contains('花盆旁边'));
    expect(
      () => LensSession.parse('{"summary":"花","reply":""}', '是什么'),
      throwsFormatException,
    );
    for (int i = 0; i < 15; i++) {
      session.remember(LensTurn('', '路牌 $i', ''));
    }
    expect(session.turns.length, 12);
    expect(LensSession().turns, isEmpty);
  });

  for (final status in [200, 503]) {
    test('相机图文只发第一通道，状态 $status', () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'lens-test',
        'vision_api_key': 'other',
      });
      await db.setSetting('deepseek_model', 'lens-first-test');
      await db.setSetting('app_qwen_vision_enabled_v1', '1');
      final requests = <http.Request>[];
      final request = LensRequest(
        () async => true,
        database: db,
        clientFactory: () => MockClient((r) async {
          requests.add(r);
          final content = jsonEncode({'summary': '花', 'reply': '是朵花。'});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': content},
                    'finish_reason': 'stop',
                  },
                ],
              }),
            ),
            status,
          );
        }),
      );
      addTearDown(request.close);
      final before = await db.recentMessages(limit: 10);
      final result = request.run(
        LensSession(),
        '这是什么',
        Uint8List.fromList([2]),
        Uint8List.fromList([1]),
      );
      if (status == 200) {
        expect((await result).observation, '花');
      } else {
        await expectLater(result, throwsStateError);
      }
      expect(requests, hasLength(1));
      final outgoing = jsonDecode(requests.single.body);
      expect(outgoing['model'], 'lens-first-test');
      expect(requests.single.headers['Authorization'], 'Bearer lens-test');
      final images = (outgoing['messages'][1]['content'] as List).where(
        (e) => e['type'] == 'image_url',
      );
      expect(images.last['image_url']['url'], endsWith('Ag=='));
      expect((await db.recentMessages(limit: 10)).length, before.length);
    });
  }
}
