import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_evidence_window.dart';

void main() {
  final at = DateTime(2026, 10, 1);
  final wish = CompanionWish(id: 'private-wish-id', goal: '想再去白房间看明白纸角折痕',
    reason: '好奇', route: 'game', criterion: '实际探索纸角折痕的对应关系',
    gameId: 'white_room', createdAt: at, updatedAt: at);
  WishEvidence line(String id, String text, int minute, {String kind = 'assistant_text'}) =>
    WishEvidence(id: id, kind: kind, text: text, at: at.add(Duration(minutes: minute)));
  final decision = line('older-decision', '白房间的愿望，我想通了，不再追求证明那个折痕了。', 2);
  final sources = [line('context', '你对那个白房间的愿望怎么想？', 1, kind: 'user_text'), decision,
    for (var i = 3; i < 60; i++) line('chat-$i', '聊别的事情$i', i)];
  Map<String, dynamic> proposal({String state = 'abandoned', String quote = '不再追求证明那个折痕了。',
      bool self = true}) => {'updates': [{
    'id': wish.id, 'state': state, 'quote': quote, 'evidence_id': decision.id,
    'same_target': true, 'confidence': .95, 'self_decision': self,
    'speech_act': 'considered_decision', 'reason': '我已经不想继续证明原来的目标',
  }]};
  List<CompanionWish> apply(Map<String, dynamic> payload, List<Map<String, Object?>> logs) =>
    WishPolicy.apply(wishes: [wish], payload: payload,
      evidence: WishEvidenceWindow.select(sources, [wish]), catalogIds: {'white_room'},
      now: at.add(const Duration(days: 1)), canGenerate: false, decisions: logs);
  test('older considered decision survives latest-sixteen truncation with its context', () {
    final selected = WishEvidenceWindow.select(sources, [wish]);
    expect(selected.map((s) => s.id), containsAll(['older-decision', 'context', 'chat-59']));
    expect(selected.length, lessThanOrEqualTo(44));
    final logs = <Map<String, Object?>>[];
    final result = apply(proposal(), logs).single;
    expect(result.state, 'abandoned');
    expect(result.criterion, wish.criterion);
    expect(result.manualHold, false);
    expect(logs.single['result'], 'applied');
    expect(logs.single['reason'], 'self_decision');
    expect(jsonEncode(logs), isNot(contains(wish.id)));
    expect(jsonEncode(logs), isNot(contains('折痕')));
  });
  test('retrieval words alone never change a state', () {
    final logs = <Map<String, Object?>>[];
    expect(apply({'updates': []}, logs).single.state, 'active');
    expect(logs.single['reason'], 'no_proposal');
  });
  test('diagnostics distinguish invalid quotation from missing decision fields', () {
    final quoteLogs = <Map<String, Object?>>[];
    expect(apply(proposal(quote: '没有说过这句话'), quoteLogs).single.state, 'active');
    expect(quoteLogs.single['reason'], 'quote_mismatch');
    final selfLogs = <Map<String, Object?>>[];
    expect(apply(proposal(self: false), selfLogs).single.state, 'active');
    expect(selfLogs.single['result'], 'unchanged');
    expect(selfLogs.single['reason'], 'self_decision_fields_missing');
  });
  test('letting go cannot masquerade as a completed game outcome', () {
    for (final state in ['completed', 'satisfied']) {
      final logs = <Map<String, Object?>>[];
      expect(apply(proposal(state: state), logs).single.state, 'active');
      expect(logs.single['result'], 'unchanged');
    }
  });
  test('a newer intention or manual hold wins over the older decision', () {
    for (final current in [wish.copyWith(updatedAt: at.add(const Duration(hours: 1))),
      wish.copyWith(state: 'paused', manualHold: true)]) {
      expect(WishPolicy.apply(wishes: [current], payload: proposal(), evidence: [decision],
        catalogIds: {'white_room'}, now: at.add(const Duration(days: 1)),
        canGenerate: false).single.state, current.state);
    }
  });
}
