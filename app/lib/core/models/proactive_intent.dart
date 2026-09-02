enum ProactiveIntentKind {
  gentlePing('gentle_ping', '轻轻找你', '她来找你', '她给你留了条消息'),
  missYou('miss_you', '想你', '她有点想你', '她有点想你，点开看看'),
  followup('followup', '想起之前的话', '她想起你们没聊完的事', '她想继续之前的话题'),
  shareThought('share_thought', '分享念头', '她忽然想到一件事', '她有个念头想告诉你'),
  curiosity('curiosity', '好奇', '她想问你一件事', '她有点好奇'),
  socialShare('social_share', '随手分享', '她想和你说点什么', '她给你留了条消息'),
  intimacyInvitation('intimacy_invitation', '亲密邀约', '她想和你靠近一点', '她有点想你，点开看看'),
  emotionalReach('emotional_reach', '想靠近你', '她想和你说说话', '她想和你说说话');

  const ProactiveIntentKind(
    this.key,
    this.zhLabel,
    this.notificationTitle,
    this.privatePreview,
  );

  final String key;
  final String zhLabel;
  final String notificationTitle;
  final String privatePreview;

  static ProactiveIntentKind fromKey(String? value) {
    final normalized = (value ?? '').trim();
    return ProactiveIntentKind.values.firstWhere(
      (e) => e.key == normalized,
      orElse: () => ProactiveIntentKind.gentlePing,
    );
  }
}

enum ProactiveDeliveryStyle {
  quiet('quiet', '轻声'),
  normal('normal', '普通'),
  warm('warm', '更亲密');

  const ProactiveDeliveryStyle(this.key, this.zhLabel);
  final String key;
  final String zhLabel;

  static ProactiveDeliveryStyle fromKey(String? value) {
    final normalized = (value ?? '').trim();
    return ProactiveDeliveryStyle.values.firstWhere(
      (e) => e.key == normalized,
      orElse: () => ProactiveDeliveryStyle.normal,
    );
  }
}

enum ProactiveNotificationPrivacy {
  smart('smart', '智能保护', '亲密主动消息隐藏正文，普通消息显示正文'),
  full('full', '显示正文', '系统通知直接显示主动消息正文'),
  private('private', '始终隐藏正文', '所有主动通知只显示中性提示，正文进入悬浮聊天后查看');

  const ProactiveNotificationPrivacy(this.key, this.zhLabel, this.description);
  final String key;
  final String zhLabel;
  final String description;

  static ProactiveNotificationPrivacy fromKey(String? value) {
    final normalized = (value ?? '').trim();
    return ProactiveNotificationPrivacy.values.firstWhere(
      (e) => e.key == normalized,
      orElse: () => ProactiveNotificationPrivacy.smart,
    );
  }
}
