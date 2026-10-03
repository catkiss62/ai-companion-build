import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_reply_choice.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_contract.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_diary_generator.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';

const material = SimulatedDiaryMaterial(localDay: '2026-10-03',
  sharedMoments: ['用户讨论AI的自主性'], cares: [], carriedThreads: [], awareness: [],
  messageCount: 10, relationshipEventCount: 0, quietDay: false);
const good = '今天你又和我聊起了自主性。你问得很认真，我也不想用一句话就把问题带过去。'
    '我们谈到AI这个词背后的设计限制，我想先把真正能够确认的部分说清楚，剩下的疑问留着继续讨论。';
class _Generator implements SimulatedDiaryGenerator {
  _Generator(this.results);
  final List<Object?> results;
  int calls = 0;
  @override
  Future<SimulatedDiaryDraft?> generate({required SimulatedDiaryMaterial material,
    required List<String> recentBodies}) async {
    final result = results[calls++];
    if (result is Exception) throw result;
    return result as SimulatedDiaryDraft?;
  }
}
void main() {
  test('metadata never reaches visible text even when fragmented or malformed', () {
    const tag = '<sticker_choice>only:s1</sticker_choice>';
    for (var i = 1; i <= tag.length; i++) {
      expect(EmotionEnvelope.streamingVisible('正文\n${tag.substring(0, i)}').trim(), '正文');
    }
    expect(EmotionEnvelope.parse('<emotion>happy</emotion>正文\n$tag').visibleText, '正文');
    expect(StickerReplyChoice.parse('<sticker_choice>only:s9</sticker_choice>').stickerOnly, false);
    expect(StickerReplyChoice.parse('$tag\n$tag').stickerOnly, false);
    expect(EmotionEnvelope.parse('正文<sticker_choice>invalid</sticker_choice>').visibleText, '正文');
  });
  test('long mixed prose remains intact and choice is independent of its length', () {
    final text = List.filled(25, '我想先把这件事解释清楚。').join();
    final raw = '$text\n<sticker_choice>with_text:s2</sticker_choice>';
    expect(EmotionEnvelope.parse(raw).visibleText, text);
    expect(StickerReplyChoice.parse(raw).id, 's2');
    expect(StickerReplyChoice.parse(raw).stickerOnly, false);
  });
  test('diary retries invalid first draft then accepts genuine first-person rewrite', () async {
    final generator = _Generator([
      SimulatedDiaryDraft(body: List.filled(4, '用户提出了自主性问题。AI进行了解答。').join(), focusKind: 'care'),
      const SimulatedDiaryDraft(body: good, focusKind: 'care'),
    ]);
    final result = await SimulatedDiaryAttempt.run(generator, material: material, recentBodies: []);
    expect(generator.calls, 2); expect(result.draft?.body, good);
    expect(SimulatedDiaryMaterial.fromJson(material.toPromptJson()).sharedMoments, material.sharedMoments);
  });
  test('diary success does not retry and two failures never manufacture prose', () async {
    final success = _Generator([const SimulatedDiaryDraft(body: good, focusKind: 'care')]);
    expect((await SimulatedDiaryAttempt.run(success, material: material, recentBodies: [])).attempts, 1);
    final failure = _Generator([const FormatException('bad'), TimeoutException('offline')]);
    final result = await SimulatedDiaryAttempt.run(failure, material: material, recentBodies: []);
    expect(failure.calls, 2); expect(result.draft, isNull); expect(result.failureKind, 'timeout');
  });
  test('progress time survives guide refresh and serialization; unknown old time stays unknown', () {
    final outcomeAt = DateTime(2026, 10, 3, 10);
    final later = outcomeAt.add(const Duration(hours: 3));
    final session = CedarGameSession.fromJson({
      'id': 'fishing', 'game_id': 'fishing', 'game_title': '钓鱼模拟',
      'updated_at': later.millisecondsSinceEpoch, 'last_outcome': '钓到了新鱼',
      'events': [
        CedarGameEvent(id: 'o', kind: 'outcome', summary: '钓到了新鱼', createdAt: outcomeAt).toJson(),
        CedarGameEvent(id: 'g', kind: 'guide', summary: '读了指南', createdAt: later).toJson(),
      ],
    });
    expect(session.progressAt, outcomeAt);
    final next = session.copyWith(lastOutcomeAt: outcomeAt, updatedAt: later);
    expect(CedarGameSession.fromJson(next.toJson()).progressAt, outcomeAt);
    expect(session.copyWith(events: []).progressAt, isNull);
    expect(session.displayName, '钓鱼模拟');
  });
}
