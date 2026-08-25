import 'package:ai_companion_localfirst/core/models/proactive_notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing popup setting defaults to always popup', () {
    expect(
      ProactivePopupMode.fromSetting(null),
      ProactivePopupMode.alwaysPopup,
    );
    expect(
      ProactivePopupMode.alwaysPopup.effectiveDeliveryStyle('quiet'),
      'normal',
    );
  });

  test('smart and gentle preserve their explicit notification behavior', () {
    expect(
      ProactivePopupMode.smart.effectiveDeliveryStyle('quiet'),
      'quiet',
    );
    expect(
      ProactivePopupMode.smart.effectiveDeliveryStyle('normal'),
      'normal',
    );
    expect(
      ProactivePopupMode.gentle.effectiveDeliveryStyle('normal'),
      'quiet',
    );
  });

  test('missing sound setting defaults to bundled chime', () {
    expect(
      ProactiveNotificationSound.fromSetting(null),
      ProactiveNotificationSound.chime,
    );
    expect(
      ProactiveNotificationSound.fromSetting('silent'),
      ProactiveNotificationSound.silent,
    );
  });
}
