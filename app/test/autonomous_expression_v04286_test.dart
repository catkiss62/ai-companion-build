import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/autonomous_expression_choice.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  ChatMessage reply(int i, {String intent = '', String roleplay = ''}) => ChatMessage(
    id: '$i', role: 'assistant', content: '私有正文$i，你呢？', createdAt: DateTime(2026, 10, 8, 8, i),
    proactiveIntent: intent, worldBookContextJson: roleplay,
    segments: const [ChatSegment(kind: ChatSegmentKind.action, text: '笑了一下'),
      ChatSegment(kind: ChatSegmentKind.dialogue, text: '你呢？')]);
  final recent = [for (var i = 0; i < 10; i++) reply(i)];
  test('structure is bounded and stores no dialogue or identifiers', () {
    final stats = AutonomousExpressionChoice.structure(recent);
    expect(stats, {'sample': 6, 'with_action': 6, 'question_end': 6, 'brief': 6});
    expect(jsonEncode(stats), isNot(contains('私有正文')));
  });
  test('reminder and roleplay histories do not become ordinary style evidence', () {
    final stats = AutonomousExpressionChoice.structure([
      reply(1, intent: 'calendar_reminder'),
      reply(2, roleplay: const WorldBookTurnContext(roleplaySessionId: 'story').encode()),
      ChatMessage(id: 'u', role: 'user', content: '嗯', createdAt: DateTime(2026)),
      reply(3),
    ]);
    expect(stats['sample'], 1);
  });
  test('explicit switch and roleplay exemption remove the extra guidance', () {
    for (final flags in [(false, false), (true, true)]) {
      expect(AutonomousExpressionChoice.render(enabled: flags.$1, roleplay: flags.$2,
        freshSourceOnly: false, recent: recent), isEmpty);
    }
  });
  test('fresh proactive source does not import recent conversation statistics', () {
    final text = AutonomousExpressionChoice.render(enabled: true, roleplay: false,
      freshSourceOnly: true, recent: recent);
    expect(text, isNot(contains('近期6条')));
    expect(text, isNot(contains('私有正文')));
    expect(text, contains('允许不调整'));
  });
  test('ordinary guidance permits continuity and natural endings without rotation', () {
    final text = AutonomousExpressionChoice.render(enabled: true, roleplay: false,
      freshSourceOnly: false, recent: recent);
    expect(text, contains('近期6条'));
    expect(text, contains('不强制轮换'));
    expect(text, contains('允许纯对白'));
    expect(text, contains('用户短回复不等于拒绝话题'));
    expect(text, contains('不改长期人格'));
  });
  test('real prompt builder honors switch without changing the latest user turn', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    final currentUser = ChatMessage(id: 'current-user', role: 'user',
      content: '请直接告诉我你的看法，不要问问题', createdAt: DateTime(2026, 10, 8, 9));
    await db.insertMessage(currentUser);
    Future<String> build() async {
      final result = await PromptBuilder(db).buildChatPrompt(latestUserText: '请直接告诉我你的看法，不要问问题',
        retrievalQuery: '', recent: [...recent, currentUser], desire: await db.loadDesire(), thoughts: const [],
        now: DateTime(2026, 10, 8, 10));
      expect(result.messages.last['role'], 'user');
      expect(result.messages.last['content'].toString(), contains(currentUser.content));
      return result.messages.map((m) => m['content']).join('\n');
    }
    expect(await build(), contains('【自主表达选择】'));
    await db.setSetting(AutonomousExpressionChoice.settingKey, '0');
    final disabled = await build();
    expect(disabled, isNot(contains('【自主表达选择】')));
    expect(disabled, contains('【本轮回应重心】'));
    final diagnostics = jsonDecode((await db.getSetting(AutonomousExpressionChoice.diagnosticKey))!);
    expect(diagnostics['applied'], false);
    expect(jsonEncode(diagnostics), isNot(contains('私有正文')));
  });

}
