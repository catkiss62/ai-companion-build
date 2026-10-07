import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';

void main() {
  final at = DateTime(2026, 10, 7, 10);
  CompanionWish wish({String route = 'game', String state = 'active', bool hold = false}) => CompanionWish(
    id: 'w', goal: '想弄明白折痕', reason: '好奇', route: route,
    criterion: '真实观察到对应关系', gameId: 'white_room',
    createdAt: at, updatedAt: at, state: state, manualHold: hold);
  CompanionWish apply(CompanionWish w, String state, {bool decision = true,
    String speech = 'considered_decision', String kind = 'assistant_text',
    String quote = '我已经不想追究标准答案了', DateTime? sourceAt}) {
    return WishPolicy.apply(wishes: [w], payload: {'updates': [{
      'id': 'w', 'state': state, 'evidence_id': 'e', 'quote': quote,
      'confidence': .95, 'same_target': true, 'observed': true,
      'self_decision': decision, 'speech_act': speech,
      'reason': '我现在觉得不必再追究标准答案',
    }]}, evidence: [WishEvidence(id: 'e', kind: kind,
      text: '我已经不想追究标准答案了', at: sourceAt ?? at.add(const Duration(minutes: 10)))],
      catalogIds: {'white_room'}, now: at.add(const Duration(hours: 1)),
      canGenerate: false).single;
  }
  test('self can let go without fabricating game completion', () {
    final result = apply(wish(), 'abandoned');
    expect(result.state, 'abandoned');
    expect(result.manualHold, false);
    expect(result.evidenceIds, ['e']);
    expect(result.criterion, '真实观察到对应关系');
    expect(result.mayAct(at.add(const Duration(hours: 2))), false);
    expect(apply(wish(), 'completed').state, 'active');
    expect(apply(wish(), 'satisfied').state, 'active');
  });
  test('aspiration may be subjectively satisfied and round-trip', () {
    final result = apply(wish(route: 'aspiration'), 'satisfied');
    final restored = CompanionWish.fromJson(result.toJson());
    expect(restored.state, 'satisfied');
    expect(restored.terminal, true);
    expect(restored.active, false);
    expect(restored.progress, isNotEmpty);
  });
  test('self pause can resume but user pause is respected', () {
    expect(apply(wish(), 'paused').manualHold, false);
    expect(apply(wish(state: 'paused'), 'active').state, 'active');
    expect(apply(wish(state: 'paused', hold: true), 'active').state, 'paused');
    expect(apply(wish(state: 'abandoned'), 'active').state, 'abandoned');
  });
  test('jokes, missing decisions and invalid citations cannot retire goals', () {
    expect(apply(wish(), 'abandoned', decision: false).state, 'active');
    expect(apply(wish(), 'abandoned', speech: 'joke').state, 'active');
    expect(apply(wish(), 'abandoned', quote: '编造的引用').state, 'active');
    expect(apply(wish(), 'abandoned', sourceAt: at).state, 'active');
  });
}
