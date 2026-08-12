import '../models/desire_state.dart';
import '../models/proactive_intent.dart';
import '../models/unfinished_thread.dart';
import 'desire_engine.dart';
import 'proactive_rhythm_engine.dart';

class ProactivePresentationPolicy {
  const ProactivePresentationPolicy._();

  static ProactiveIntentKind classify({
    required DesireIntent intent,
    UnfinishedThread? linkedThread,
  }) {
    if (linkedThread != null || intent.wantAction == 'remember_unfinished_thread' ||
        intent.wantAction == 'continue_thread') {
      return ProactiveIntentKind.followup;
    }
    return switch (intent.drive) {
      DriveKey.attachment => ProactiveIntentKind.missYou,
      DriveKey.curiosity => ProactiveIntentKind.curiosity,
      DriveKey.reflection => ProactiveIntentKind.shareThought,
      DriveKey.duty => ProactiveIntentKind.followup,
      DriveKey.social => ProactiveIntentKind.socialShare,
      DriveKey.libido => ProactiveIntentKind.intimacyInvitation,
      DriveKey.stress => ProactiveIntentKind.emotionalReach,
      DriveKey.fatigue => ProactiveIntentKind.gentlePing,
    };
  }

  static ProactiveDeliveryStyle delivery({
    required ProactiveIntentKind kind,
    required bool userBusy,
    required ProactiveRhythmProfile rhythm,
  }) {
    if (userBusy || rhythm.preferLowPressure) {
      return ProactiveDeliveryStyle.quiet;
    }
    if (kind == ProactiveIntentKind.missYou ||
        kind == ProactiveIntentKind.intimacyInvitation ||
        kind == ProactiveIntentKind.emotionalReach) {
      return ProactiveDeliveryStyle.warm;
    }
    return ProactiveDeliveryStyle.normal;
  }

  static String promptHint(
    ProactiveIntentKind kind,
    ProactiveDeliveryStyle delivery,
  ) {
    final intentHint = switch (kind) {
      ProactiveIntentKind.gentlePing => '像随手轻轻碰一下用户，不需要硬找话题。',
      ProactiveIntentKind.missYou => '核心是自然表达想念或想靠近，不要写成例行问候或客服式关心。',
      ProactiveIntentKind.followup => '自然续上已经存在的未完成话题，不要像提醒事项或催办机器人。',
      ProactiveIntentKind.shareThought => '分享她自己刚形成的念头、联想或感受，允许用户晚点再接。',
      ProactiveIntentKind.curiosity => '带着真实好奇问一件值得问的事，避免连珠炮式提问。',
      ProactiveIntentKind.socialShare => '像伴侣随手分享一件想说的小事，不需要强求用户马上回复。',
      ProactiveIntentKind.intimacyInvitation => '可以带暧昧或亲密倾向，但仍是邀请而不是强行把普通聊天拉进成人场景。',
      ProactiveIntentKind.emotionalReach => '更像想靠近、想说说话或寻求一点连接，不要制造戏剧化危机。',
    };
    final deliveryHint = switch (delivery) {
      ProactiveDeliveryStyle.quiet => '这是轻声投递：更短、更低压力，尽量不连续追问，明确允许用户晚点回复。',
      ProactiveDeliveryStyle.normal => '按自然聊天强度表达，不要写成系统通知文案。',
      ProactiveDeliveryStyle.warm => '可以比普通消息更有亲密感和个人情绪，但保持自然，不要夸张表演。',
    };
    return '$intentHint\n$deliveryHint';
  }

  static String notificationBody({
    required ProactiveIntentKind kind,
    required String fullText,
    required ProactiveNotificationPrivacy privacy,
    bool sensitiveContext = false,
  }) {
    return switch (privacy) {
      ProactiveNotificationPrivacy.full => fullText,
      ProactiveNotificationPrivacy.private => kind.privatePreview,
      ProactiveNotificationPrivacy.smart =>
        (kind == ProactiveIntentKind.intimacyInvitation || sensitiveContext)
            ? kind.privatePreview
            : fullText,
    };
  }
}
