import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/personality_learning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() => db.closeForTesting());
  Future<PersonalityLearningCandidate> current() async => (await db.personalityLearningCandidatesForExtraction(contextKey: 'ordinary')).single;
  Future<bool> add(String source, int time, {bool conflict = false,
    PersonalityLearningCandidate? target, bool resolve = false, String? token}) async {
    final old = target;
    return db.applyPersonalityLearningProposal(
      proposal: PersonalityLearningProposal(scope: PersonalityLearningScope.userPreference,
        subjectKey: 'user.preference.communication.less_formal',
        proposition: '用户偏好少一些客套', polarity: conflict ? PersonalityLearningPolarity.contradict : PersonalityLearningPolarity.support,
        evidenceKind: PersonalityLearningEvidenceKind.explicitPreference,
        evidenceText: conflict ? '不想这样了' : '以后少些客套', confidence: .99,
        targetCandidateId: old?.id),
      context: const PersonalityLearningContext.ordinary(), sourceMessageId: source,
      assistantMessageId: '', observedAt: DateTime.fromMillisecondsSinceEpoch(time),
      expectedTargetToken: token, resolvesBarrierIds: resolve ? old!.barrierIds : const []);
  }
  test('old majority cannot erase a boundary; new permission starts a fresh epoch', () async {
    expect(await add('one', 1000), isTrue);
    expect(await add('two', 2000, target: await current()), isTrue);
    expect(await db.establishedPersonalityLearningCandidates(), hasLength(1));
    expect(await add('no', 3000, conflict: true, target: await current()), isTrue);
    for (var i = 0; i < 5; i++) { await add('late-$i', 1500, target: await current()); }
    expect(await db.establishedPersonalityLearningCandidates(), isEmpty);
    final blocked = await current();
    expect(blocked.lastObservedAt.millisecondsSinceEpoch, 3000);
    expect(await add('permission', 4000, target: blocked, resolve: true, token: blocked.reviewToken), isTrue);
    expect((await current()).supportCount, 1);
    expect(await db.establishedPersonalityLearningCandidates(), isEmpty);
    await add('confirmation', 5000, target: await current());
    expect(await db.establishedPersonalityLearningCandidates(), hasLength(1));
    expect((await (await db.database).query('personality_learning_evidence', where: "polarity = 'contradict'")).length, 1);
  });
  test('changed candidate rejects stale semantic permission', () async {
    await add('one', 1000);
    await add('no', 2000, conflict: true, target: await current());
    final captured = await current();
    await add('new-no', 3000, conflict: true, target: captured);
    expect(await add('old-permission', 4000, target: captured, resolve: true, token: captured.reviewToken), isFalse);
    expect((await current()).blockedByConflict, isTrue);
  });
  test('same-time permission cannot resolve a boundary', () async {
    await add('one', 1000);
    await add('no', 2000, conflict: true, target: await current());
    final captured = await current();
    await add('permission', 2000, target: captured, resolve: true, token: captured.reviewToken);
    expect((await current()).blockedByConflict, isTrue);
  });
}
