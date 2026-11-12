import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_presentation.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_rhythm_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/proactive_intent.dart';

void main() {
  test('new-topic lanes do not write from answered chat history', () {
    expect(
      ProactivePresentationPolicy.startsFreshTopic(
        ProactiveIntentKind.shareThought,
      ),
      isTrue,
    );
    expect(
      ProactivePresentationPolicy.startsFreshTopic(
        ProactiveIntentKind.curiosity,
      ),
      isTrue,
    );
    expect(
      ProactivePresentationPolicy.startsFreshTopic(
        ProactiveIntentKind.socialShare,
      ),
      isTrue,
    );
    expect(
      ProactivePresentationPolicy.startsFreshTopic(ProactiveIntentKind.followup),
      isFalse,
    );
  });

  test('daytime check-in sees the recently confirmed end of work', () {
    final at = DateTime(2026, 11, 12, 18, 54);
    ChatMessage message(String id, String role, String content, int minutesAgo) =>
        ChatMessage(id: id, role: role, content: content,
          createdAt: at.subtract(Duration(minutes: minutesAgo)));
    final recent = [
      message('old', 'user', '昨晚在家', 70),
      message('u', 'user', '下班咯', 21),
      message('a', 'assistant', '应该到家了', 20),
    ];
    String context({String action = 'check_in', String source = 'awareness',
      ProactiveIntentKind kind = ProactiveIntentKind.curiosity, bool night = false}) =>
        ProactivePresentationPolicy.recentCheckInContext(kind: kind, action: action,
          sourceType: source, nightContact: night, now: at, recent: recent);
    expect(context(), contains('下班咯'));
    expect(context(), contains('18:33'));
    expect(context(), contains('CURRENT_USER_TURN 仍为 NONE'));
    expect(context(), isNot(contains('应该到家了')));
    expect(context(), isNot(contains('昨晚在家')));
    expect(context(action: 'discover_interest'), isEmpty);
    expect(context(source: 'public_web'), isEmpty);
    expect(context(kind: ProactiveIntentKind.socialShare), isEmpty);
    expect(context(night: true), isEmpty);
  });

  test('follow-up presentation allows older recalled topics', () {
    expect(ProactiveIntentKind.followup.zhLabel, '想起之前的话');
  });

  test('attachment intent becomes miss-you presentation', () {
    const intent = DesireIntent(
      drive: DriveKey.attachment,
      score: 0.74,
      reason: '有点想他了',
      wantAction: 'contact_user',
    );
    final kind = ProactivePresentationPolicy.classify(intent: intent);
    expect(kind, ProactiveIntentKind.missYou);
  });

  test('history-backed curiosity is honestly classified as follow-up', () {
    const intent = DesireIntent(
      drive: DriveKey.curiosity,
      score: 0.8,
      reason: '旧对话里的问题',
      wantAction: 'ask_user',
      reasonSource: 'real_user_message:old',
    );
    final kind = ProactivePresentationPolicy.classify(
      intent: intent,
      sourceType: 'user_history',
    );
    expect(kind, ProactiveIntentKind.followup);
  });

  test('busy context becomes quiet delivery without muting contact', () {
    final delivery = ProactivePresentationPolicy.delivery(
      kind: ProactiveIntentKind.missYou,
      userBusy: true,
      rhythm: ProactiveRhythmProfile.neutral(),
    );
    expect(delivery, ProactiveDeliveryStyle.quiet);
  });

  test('smart privacy hides intimacy preview but keeps ordinary content', () {
    final hidden = ProactivePresentationPolicy.notificationBody(
      kind: ProactiveIntentKind.intimacyInvitation,
      fullText: 'private body',
      privacy: ProactiveNotificationPrivacy.smart,
    );
    final visible = ProactivePresentationPolicy.notificationBody(
      kind: ProactiveIntentKind.shareThought,
      fullText: 'ordinary body',
      privacy: ProactiveNotificationPrivacy.smart,
    );
    expect(hidden, isNot('private body'));
    expect(visible, 'ordinary body');
  });

  test('smart privacy also hides any active sensitive session preview', () {
    final body = ProactivePresentationPolicy.notificationBody(
      kind: ProactiveIntentKind.missYou,
      fullText: 'session-sensitive body',
      privacy: ProactiveNotificationPrivacy.smart,
      sensitiveContext: true,
    );
    expect(body, isNot('session-sensitive body'));
  });
}
