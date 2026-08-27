enum ProactivePopupMode {
  alwaysPopup,
  smart,
  gentle;

  String get key => switch (this) {
        alwaysPopup => 'always_popup',
        smart => 'smart',
        gentle => 'gentle',
      };

  String get zhLabel => switch (this) {
        alwaysPopup => '始终弹窗',
        smart => '智能弹窗',
        gentle => '轻声通知',
      };

  String get description => switch (this) {
        alwaysPopup => '她主动找你时优先显示系统横幅；桌宠被其他 App 隐藏时也尽量能看到。',
        smart => '按她判断出的忙碌程度选择横幅或轻声通知。',
        gentle => '只进入通知栏，通常不主动弹出横幅。',
      };

  String effectiveDeliveryStyle(String suggested) => switch (this) {
        alwaysPopup => 'normal',
        smart => suggested == 'quiet' ? 'quiet' : 'normal',
        gentle => 'quiet',
      };

  static ProactivePopupMode fromSetting(String? raw) => switch (raw) {
        'smart' => smart,
        'gentle' => gentle,
        _ => alwaysPopup,
      };
}

enum ProactiveNotificationSound {
  chime,
  soft,
  bubble,
  system,
  silent;

  String get key => name;

  String get zhLabel => switch (this) {
        chime => '清脆三音',
        soft => '柔和水滴',
        bubble => '气泡轻弹',
        system => '系统默认',
        silent => '静音',
      };

  static ProactiveNotificationSound fromSetting(String? raw) => switch (raw) {
        'soft' => soft,
        'bubble' => bubble,
        'system' => system,
        'silent' => silent,
        _ => chime,
      };
}
