import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_archive_worker.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_prompt_builder.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_controller.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/models/immersive_room.dart';
import 'package:ai_companion_localfirst/core/personality/form_context_snapshot.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late ImmersiveRoomRepository repository;
  late ImmersiveRoom room;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-key'});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('tts_enabled', '0');
    repository = ImmersiveRoomRepository(db);
    room = await repository.createRoom(
      title: '快照测试', openingScene: '', inheritCurrentChat: false);
    await repository.setNsfwManualOverride(room.id, false);
    room = (await repository.roomById(room.id))!;
  });

  tearDown(() async {
    await db.closeForTesting();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> setForm(bool qForm) => db.setSetting(
    PlayfulFormState.settingKey,
    PlayfulFormState(qForm: qForm, heat: qForm ? 100 : 0,
      manualRevision: qForm ? 7 : 8).encode(),
  );

  test('room messages keep entry form when ordinary chat changes form', () async {
    await setForm(true);
    final client = _ReplyClient();
    final controller = ImmersiveRoomController(
      roomId: room.id, db: db, client: client);
    await controller.initialize();
    await setForm(false);
    await controller.send('我们继续聊。');

    expect(controller.error, isNull);
    final messages = await repository.messagesForRoom(room.id);
    expect(messages, hasLength(2));
    for (final message in messages) {
      expect(message.formContext.form,
        FormContextSnapshot.fromForm(qForm: true, now: DateTime.now(),
          kind: 'test').form);
      expect(message.formContext.manualRevision, 7);
      expect(message.formContext.captureKind, 'room_entry');
      expect(message.copyWith().formContextJson, message.formContextJson);
    }
    expect(client.request!.any((item) =>
      item['content'].toString().contains('进入时的小豆丁形态')), isTrue);
    controller.dispose();
  });

  test('interrupted draft keeps original entry after reopening and confirmation', () async {
    await setForm(true);
    final controller = ImmersiveRoomController(
      roomId: room.id, db: db, client: _ReplyClient(truncate: true));
    await controller.initialize();
    await controller.send('继续。');
    final draft = controller.incompleteReplyDraft!;
    final originalFormJson = draft.formContextJson;
    expect(draft.formContext.captureKind, 'room_entry');
    final settingKey = 'immersive_pending_reply_${Uri.encodeComponent(room.id)}';
    final persisted = jsonDecode((await db.getSetting(settingKey))!) as Map;
    expect(persisted['form_context_json'], originalFormJson);
    controller.dispose();

    await setForm(false);
    final reopened = ImmersiveRoomController(roomId: room.id, db: db);
    await reopened.initialize();
    expect(reopened.formSnapshot.qForm, isFalse);
    expect(reopened.incompleteReplyDraft!.formContextJson, originalFormJson);
    await reopened.confirmIncompleteReply();
    expect(reopened.error, isNull);
    final stored = (await repository.messagesForRoom(room.id)).last;
    expect(stored.formContextJson, originalFormJson);
    expect(stored.content, draft.content);
    reopened.dispose();
  });

  test('old draft and old rows retain unknown form after confirmation and backup', () async {
    final user = await repository.addMessage(
      roomId: room.id, role: 'user', content: '旧对话');
    await db.setSetting(
      'immersive_pending_reply_${Uri.encodeComponent(room.id)}',
      jsonEncode({
        'room_id': room.id, 'user_message_id': user.id,
        'content': '旧草稿。', 'reasoning': '', 'created_at': 1,
      }),
    );
    await setForm(true);
    final controller = ImmersiveRoomController(roomId: room.id, db: db);
    await controller.initialize();
    expect(controller.incompleteReplyDraft!.formContext.form, 'unknown');
    await controller.confirmIncompleteReply();
    expect(controller.error, isNull);
    controller.dispose();
    final exported = await db.exportAll();
    await db.importAll(exported);
    for (final message in await repository.messagesForRoom(room.id)) {
      expect(message.formContextJson, isEmpty);
      expect(message.formContext.form, 'unknown');
    }
  });

  test('known form survives backup and is visible only in prompt history', () async {
    final snapshot = FormContextSnapshot.fromForm(
      qForm: true, now: DateTime.fromMillisecondsSinceEpoch(123), kind: 'room_entry');
    await repository.addMessage(roomId: room.id, role: 'assistant',
      content: '她轻轻点头。', formContextJson: snapshot.encode());
    final exported = await db.exportAll();
    await db.importAll(exported);
    final history = await repository.messagesForRoom(room.id);
    expect(history.single.formContextJson, snapshot.encode());
    expect(history.single.content, '她轻轻点头。');
    final prompt = await ImmersivePromptBuilder(db).build(
      room: room, history: history, latestUserText: '继续', nsfwActive: false);
    final assistant = prompt.singleWhere((item) => item['role'] == 'assistant');
    expect(assistant['content'], '【历史记录·${snapshot.historicalLabel}】\n她轻轻点头。');
    expect(ImmersiveArchiveWorker.transcript(history),
      'AI正文〔${snapshot.historicalLabel}〕：她轻轻点头。');
    expect(ImmersiveArchiveWorker.transcript(List.filled(1000, history.single))
      .length, lessThanOrEqualTo(26000));
  });
}

class _ReplyClient extends DeepSeekClient {
  _ReplyClient({this.truncate = false});
  final bool truncate;
  List<Map<String, Object?>>? request;

  @override
  Stream<DeepSeekDelta> streamChat({
    required String apiKey,
    required DeepSeekModelProfile model,
    required ReasoningEffort effort,
    required List<Map<String, Object?>> messages,
    String endpoint = DeepSeekClient.defaultEndpoint,
    ChatApiProvider? requestProvider,
    String? modelName,
    bool thinking = true,
    int? maxTokens,
    List<Map<String, Object?>> tools = const [],
    String? toolChoice,
    GenerationCancellationToken? cancellationToken,
    Duration requestTimeout = const Duration(seconds: 120),
    String usageLane = 'unclassified',
    String usageExecutionId = '',
    FinalReplyRoute? finalReplyRoute,
    SecureConfig? thirdChannelSecure,
    Future<bool> Function()? thirdChannelCurrent,
  }) async* {
    request = messages;
    yield const DeepSeekDelta(content: '她轻轻点头。');
    if (!truncate) {
      yield const DeepSeekDelta(done: true, finishReason: 'stop');
    }
  }
}
