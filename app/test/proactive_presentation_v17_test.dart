import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_presentation.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_rhythm_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
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
