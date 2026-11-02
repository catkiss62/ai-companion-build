import 'dart:async';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/unfinished_thread.dart';
import 'package:ai_companion_localfirst/core/relationship/relationship_presentation.dart';
import 'package:ai_companion_localfirst/features/relationship/relationship_companion_state.dart';
import 'package:ai_companion_localfirst/features/relationship/relationship_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RelationshipCompanionSnapshot sample(String text, {bool thread = true}) {
  final now = DateTime(2026, 11, 2);
  return RelationshipCompanionSnapshot(activeBrain: true, transferLocked: false,
    currentCares: [CompanionCareView(id: 'care', label: '在意', text: text,
      updatedAt: now, source: 'dialogue')], dailyContinuity: [], sharedMoments: [],
    unfinishedThreads: [if (thread) UnfinishedThread(id: 'thread', title: '待续的话题',
      detail: '下次继续', importance: .8, status: 'active', createdAt: now, updatedAt: now)],
    refreshedAt: now);
}

class FakeRepository extends RelationshipCompanionRepository {
  FakeRepository() : super(AppDatabase.instance);
  int calls = 0;
  RelationshipCompanionSnapshot value = sample('旧念头');
  Completer<RelationshipCompanionSnapshot>? pending;
  bool fail = false;
  @override
  Future<RelationshipCompanionSnapshot> load() async {
    calls++;
    if (fail) throw StateError('read failed');
    return pending == null ? value : pending!.future;
  }
}

void main() {
  testWidgets('detail refreshes changed cares and removes resolved thread without reopening', (t) async {
    final repo = FakeRepository();
    await t.pumpWidget(MaterialApp(home: RelationshipPage(repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('旧念头'), findsOneWidget);
    repo.value = sample('新念头', thread: false);
    await t.pump(const Duration(seconds: 12)); await t.pump();
    expect(repo.calls, 2); expect(find.text('新念头'), findsOneWidget);
    expect(find.text('还没说完的事'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 24)); expect(repo.calls, 2);
  });
  testWidgets('background pauses reads and resume refreshes immediately', (t) async {
    final repo = FakeRepository();
    await t.pumpWidget(MaterialApp(home: RelationshipPage(repository: repo)));
    await t.pumpAndSettle();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 36)); expect(repo.calls, 1);
    repo.value = sample('恢复后的念头');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(); await t.pump();
    expect(repo.calls, 2); expect(find.text('恢复后的念头'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('inflight read is not duplicated and transient error keeps old snapshot', (t) async {
    final repo = FakeRepository();
    await t.pumpWidget(MaterialApp(home: RelationshipPage(repository: repo)));
    await t.pumpAndSettle();
    repo.pending = Completer<RelationshipCompanionSnapshot>();
    await t.pump(const Duration(seconds: 12));
    await t.pump(const Duration(seconds: 24)); expect(repo.calls, 2);
    repo.pending!.complete(sample('读取完成')); await t.pump(); await t.pump();
    repo.pending = null; repo.fail = true;
    await t.pump(const Duration(seconds: 12)); await t.pump();
    expect(find.text('读取完成'), findsOneWidget);
    expect(find.text('暂时没能读到你们的关系记录，请稍后再试。'), findsOneWidget);
    repo.fail = false; repo.value = sample('再次更新');
    await t.pump(const Duration(seconds: 12)); await t.pump();
    expect(find.text('再次更新'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
