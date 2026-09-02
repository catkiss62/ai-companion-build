import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_presentation.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_rhythm_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/proactive_intent.dart';

void main() {
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
