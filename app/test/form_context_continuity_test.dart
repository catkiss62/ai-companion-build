import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/grounding/prompt_history_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/personality/form_context_snapshot.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late PlayfulFormStore forms;
  final at = DateTime.utc(2026, 10, 12, 10);

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    forms = PlayfulFormStore(db);
  });
  tearDown(() async => db.closeForTesting());

  Future<GenerationJob> start(PlayfulFormState state) async {
    await db.setSetting(PlayfulFormState.settingKey, state.encode());
    final job = await db.createGenerationTurn(user: ChatMessage(
      id: 'user', role: 'user', content: '继续聊', createdAt: at),
      assistantMessageId: 'reply', model: 'deepseek-v4-flash', reasoningEffort: 'high');
    return (await db.claimGenerationJob(job.id))!;
  }

  Future<FormContextSnapshot> capture(GenerationJob job, PlayfulInteraction activity) async {
    final pending = await forms.onTurn(interaction: activity, turn: 'user', now: at);
    final snapshot = FormContextSnapshot.capture(pending,
      now: at.add(const Duration(seconds: 1)), kind: 'generation', generation: true);
    expect(await db.captureGenerationFormContext(job.id,
      runToken: job.runToken, snapshot: snapshot), isTrue);
    return snapshot;
  }

  Future<bool> commit(GenerationJob job, FormContextSnapshot snapshot) =>
    db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      assistant: ChatMessage(id: 'reply', role: 'assistant', content: '好，接着说。',
        createdAt: DateTime.fromMillisecondsSinceEpoch(snapshot.capturedAt).add(const Duration(seconds: 10)),
        formContextJson: snapshot.encode()),
      playfulActivity: PlayfulSelfActivity.none);

  test('receiving normal user and generating Q reply have separate snapshots', () async {
    final job = await start(const PlayfulFormState(heat: 100));
    final snapshot = await capture(job, PlayfulInteraction.strong);
    expect((await db.messageById('user'))!.formContext.form, 'normal');
    expect(snapshot.form, 'q');
    expect((await forms.load()).qForm, false);
    expect((await forms.load()).lastTransitionJson, isEmpty);
    expect(await commit(job, snapshot), true);
    final assistant = (await db.messageById('reply'))!;
    expect(assistant.formContext.form, 'q');
    expect(assistant.formContext.afterForm, 'q');
    expect((await db.generationJobById(job.id))!.formContextJson,
      assistant.formContextJson);
    final transition = jsonDecode((await forms.load()).lastTransitionJson) as Map;
    expect(transition['from'], 'normal');
    expect(transition['to'], 'q');
    expect(transition['at'], snapshot.capturedAt);
  });

  test('zero cooling happens after the Q reply and never rewrites its form', () async {
    final job = await start(const PlayfulFormState(heat: 6, qForm: true));
    final snapshot = await capture(job, PlayfulInteraction.ordinary);
    expect(await commit(job, snapshot), true);
    final assistant = (await db.messageById('reply'))!;
    expect(assistant.formContext.form, 'q');
    expect(assistant.formContext.afterForm, 'normal');
    expect(assistant.formContext.settledAt, greaterThan(0));
    // The final job CAS must not overwrite the already settled snapshot with
    // the pre-commit generation form; recovery reads the job as well as history.
    final completed = (await db.generationJobById(job.id))!;
    expect(completed.status, 'completed');
    expect(completed.formContextJson, assistant.formContextJson);
    expect(FormContextSnapshot.decode(completed.formContextJson).afterForm,
      'normal');
    expect(assistant.historicalFormLabel, contains('回复提交结算后'));
    expect((await forms.load()).qForm, false);
    final next = FormContextSnapshot.capture(await forms.load(),
      now: DateTime.now(), kind: 'user_received');
    expect(next.form, 'normal');
    expect(next.transitionLabel, contains('回复完成结算'));
  });

  test('Stop wins before a slow prompt captures its late provisional transition', () async {
    final job = await start(const PlayfulFormState(heat: 100));
    expect(await db.cancelGenerationJobByUser(job.id), true);
    final pending = await forms.onTurn(interaction: PlayfulInteraction.strong,
      turn: 'user', now: at);
    expect(pending.promptQForm, true);
    final snapshot = FormContextSnapshot.capture(pending,
      now: at, kind: 'generation', generation: true);
    expect(await db.captureGenerationFormContext(job.id,
      runToken: job.runToken, snapshot: snapshot), false);
    expect((await forms.load()).pendingTurn, false);
    expect((await forms.load()).lastTransitionJson, isEmpty);
    expect(await db.messageById('reply'), isNull);
    expect((await db.generationJobById(job.id))!.formContextJson, isEmpty);
    expect(await commit(job, snapshot), false);
  });

  test('failed-attempt breakthrough time is replaced by the successful request time', () async {
    final job = await start(const PlayfulFormState(heat: 100));
    final failedSnapshot = await capture(job, PlayfulInteraction.strong);
    await db.failGenerationJob(job.id, runToken: job.runToken,
      error: 'network', recoverable: true);
    final handle = await db.database;
    await handle.update('generation_jobs', {'next_retry_at': 0},
      where: 'id = ?', whereArgs: [job.id]);
    final retry = (await db.claimGenerationJob(job.id))!;
    final successful = FormContextSnapshot.capture(await forms.load(),
      now: at.add(const Duration(minutes: 3)), kind: 'generation', generation: true);
    expect(successful.capturedAt, greaterThan(failedSnapshot.capturedAt));
    expect(await db.captureGenerationFormContext(retry.id,
      runToken: retry.runToken, snapshot: successful), true);
    expect(await commit(retry, successful), true);
    final transition = jsonDecode((await forms.load()).lastTransitionJson) as Map;
    expect(transition['at'], successful.capturedAt);
    expect((await db.messageById('reply'))!.formContext.capturedAt, successful.capturedAt);
  });

  test('terminal provider failure rolls back pending breakthrough', () async {
    final job = await start(const PlayfulFormState(heat: 100));
    await capture(job, PlayfulInteraction.strong);
    await db.failGenerationJob(job.id, runToken: job.runToken,
      error: 'invalid_response', recoverable: false);
    expect((await forms.load()).pendingTurn, false);
    expect((await forms.load()).promptQForm, false);
    expect((await forms.load()).lastTransitionJson, isEmpty);
    expect(await db.messageById('reply'), isNull);
  });

  test('manual transition during generation is retained without a fake settlement', () async {
    final job = await start(const PlayfulFormState(qForm: true, heat: 50));
    final snapshot = await capture(job, PlayfulInteraction.ordinary);
    final manual = await forms.interact(false);
    final transition = manual.lastTransitionJson;
    expect(await commit(job, snapshot), true);
    final assistant = (await db.messageById('reply'))!;
    expect(assistant.formContext.form, 'q');
    expect(assistant.formContext.afterForm, isEmpty);
    expect((await forms.load()).lastTransitionJson, transition);
    expect(jsonDecode(transition)['source'], 'manual_comfort');
  });

  test('durable partial draft carries request form across confirmation and backup', () async {
    final job = await start(const PlayfulFormState(qForm: true, heat: 6));
    final snapshot = await capture(job, PlayfulInteraction.ordinary);
    await db.holdGenerationJobForUserDecision(job.id, runToken: job.runToken,
      partialReasoning: '', partialContent: '已经生成的半句。');
    final backup = await db.exportAll();
    await forms.interact(false);
    await db.importAll(backup);
    final restored = (await db.generationJobById(job.id))!;
    expect(restored.formContextJson, snapshot.encode());
    final claimed = (await db.claimGenerationDraftForConfirmation(job.id))!;
    expect(claimed.formContextJson, snapshot.encode());
    expect(await commit(claimed, FormContextSnapshot.decode(claimed.formContextJson)), true);
    expect((await db.messageById('reply'))!.formContext.form, 'q');
  });

  test('old record stays unknown through backup and source prompts without editing text', () async {
    await db.insertMessage(ChatMessage(id: 'old', role: 'assistant',
      content: '小手只是历史台词', createdAt: at));
    final backup = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    final tables = backup['tables'] as Map;
    for (final row in tables['messages'] as List) {
      (row as Map).remove('form_context_json');
    }
    await db.importAll(backup);
    await forms.interact(true);
    final old = (await db.messageById('old'))!;
    expect(old.formContext.isKnown, false);
    expect(old.copyWith(content: '引用').formContext.isKnown, false);
    expect(PromptHistoryPolicy.formContextTranscript([old]), contains('未知'));
    expect(PromptHistoryPolicy.userTurnHistory([old]).single['content'], old.content);
    expect(DreamStore.chatSource(old.toDb())!.formContextJson, isEmpty);
  });

  test('regeneration removes the reply transition while keeping received-user provenance', () async {
    final job = await start(const PlayfulFormState(heat: 100));
    final snapshot = await capture(job, PlayfulInteraction.strong);
    final userForm = (await db.messageById('user'))!.formContextJson;
    expect(await commit(job, snapshot), true);
    expect((await forms.load()).lastTransitionJson, isNotEmpty);
    final reopened = await db.restartLatestCompletedReply('reply');
    expect(reopened, isNotNull);
    expect(reopened!.formContextJson, isEmpty);
    expect(await db.messageById('reply'), isNull);
    expect((await db.messageById('user'))!.formContextJson, userForm);
    expect((await forms.load()).qForm, false);
    expect((await forms.load()).lastTransitionJson, isEmpty);
  });

  test('regeneration preserves a newer independent manual transition', () async {
    final job = await start(const PlayfulFormState(qForm: true, heat: 6));
    final snapshot = await capture(job, PlayfulInteraction.ordinary);
    expect(await commit(job, snapshot), true);
    final manual = await forms.interact(true);
    expect(await db.restartLatestCompletedReply('reply'), isNotNull);
    expect((await forms.load()).qForm, true);
    expect((await forms.load()).lastTransitionJson, manual.lastTransitionJson);
  });

  test('compact form ranges use raw-message positions and preserve settlement boundaries', () {
    final normal = FormContextSnapshot.fromForm(qForm: false, now: at, kind: 'user_received');
    final q = FormContextSnapshot.fromForm(qForm: true, now: at, kind: 'generation');
    final settled = q.settled(const PlayfulFormState(), at);
    final messages = List.generate(7, (i) => ChatMessage(id: 'secret-id-$i',
      role: i.isEven ? 'user' : 'assistant', content: '原话$i', createdAt: at,
      formContextJson: i < 3 ? normal.encode() : i == 5 ? settled.encode() : q.encode()));
    final compact = PromptHistoryPolicy.formContextTranscript(messages);
    expect(compact, contains('第1–3条：正常本体'));
    expect(compact, contains('第4–5条：小豆丁'));
    expect(compact, contains('第6条（AI回复）：小豆丁；回复提交结算于'));
    expect(compact, contains('第7条：小豆丁'));
    expect(compact, isNot(contains('secret-id')));
    final raw = PromptHistoryPolicy.userTurnHistory(messages);
    expect(raw.map((m) => m['content']), List.generate(7, (i) => '原话$i'));
    expect(raw.map((m) => m['role']), messages.map((m) => m.role));
    final many = List.generate(64, (i) => messages.first.copyWith(content: '$i'));
    expect(PromptHistoryPolicy.formContextTranscript(many), contains('第1–64条：正常本体'));
    expect(PromptHistoryPolicy.formContextTranscript(many).length, lessThan(200));
  });

  test('message source metadata survives model copy and dream gathering', () async {
    final state = const PlayfulFormState().interact(kindle: true, now: at);
    final snapshot = FormContextSnapshot.capture(state, now: at,
      kind: 'generation', generation: true);
    final message = ChatMessage(id: 'source', role: 'assistant', content: '想继续种花',
      createdAt: at, formContextJson: snapshot.encode());
    expect(ChatMessage.fromDb(message.toDb()).formContextJson, snapshot.encode());
    expect(message.copyWith(content: '修订文本').formContextJson, snapshot.encode());
    final source = DreamStore.chatSource(message.toDb())!;
    expect(source.formContextJson, snapshot.encode());
    expect(source.text, message.content);
  });
}
