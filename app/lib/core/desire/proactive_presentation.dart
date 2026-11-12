import 'dart:convert';

import '../models/chat_message.dart';
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
    String sourceType = '',
  }) {
    if (intent.reasonSource.startsWith('public_web_candidate:')) {
      return ProactiveIntentKind.socialShare;
    }
    if (intent.reasonSource.startsWith('mcp/') ||
        intent.reasonSource.startsWith('mcp:')) {
      return ProactiveIntentKind.socialShare;
    }
    if (intent.wantAction == 'wildcard_share') {
      return ProactiveIntentKind.socialShare;
    }
    if (linkedThread != null || intent.wantAction == 'remember_unfinished_thread' ||
        intent.wantAction == 'continue_thread') {
      return ProactiveIntentKind.followup;
    }
    // A candidate grounded in chat history or memory is a callback, whatever
    // Desire drive selected it. It must not masquerade as a new curiosity or
    // a new thought merely by changing the presentation label.
    if (sourceType == 'user_history' || sourceType == 'memory') {
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

  /// New-topic lanes do not use the answered chat transcript as writing
  /// material. Relationship memory and the selected Thought remain available,
  /// while old dialogue cannot silently turn every lane into a callback.
  static bool startsFreshTopic(ProactiveIntentKind kind) => switch (kind) {
        ProactiveIntentKind.shareThought ||
        ProactiveIntentKind.curiosity ||
        ProactiveIntentKind.socialShare =>
          true,
        _ => false,
      };

  static String recentCheckInContext({
    required ProactiveIntentKind kind,
    required String action,
    required String sourceType,
    required bool nightContact,
    required DateTime now,
    required List<ChatMessage> recent,
  }) {
    if (nightContact || kind != ProactiveIntentKind.curiosity ||
        action != 'check_in' ||
        !const {'drive_state', 'awareness', 'internal', 'inference', 'screen_observation'}.contains(sourceType)) {
      return '';
    }
    final since = now.subtract(const Duration(hours: 1));
    final quotes = recent.reversed
        .where((message) => message.isUser && !message.isProactive &&
            message.content.trim().isNotEmpty &&
            !message.createdAt.isBefore(since) && !message.createdAt.isAfter(now))
        .take(3)
        .map((message) => {
              'at': message.createdAt.toLocal().toIso8601String(),
              'said': String.fromCharCodes(message.content.trim().runes.take(220)),
            })
        .toList();
    if (quotes.isEmpty) return '';
    return '【用户近期已说过的话·仅用于核对近况】${jsonEncode(quotes.reversed.toList())}\n'
        '这些是已回答的历史发言，CURRENT_USER_TURN 仍为 NONE。'
        '确认近况时，以最近的明确更新为准，别把已经确定的事重新问成选择题。'
        '只使用原话足以支持的事实，后续动向仍未知。';
  }

  static String promptHint(
    ProactiveIntentKind kind,
    ProactiveDeliveryStyle delivery,
  ) {
    final intentHint = switch (kind) {
      ProactiveIntentKind.gentlePing => '像随手轻轻碰一下用户，不需要硬找话题。',
      ProactiveIntentKind.missYou => '核心是自然表达想念或想靠近，不要写成例行问候或客服式关心。',
      ProactiveIntentKind.followup => '自然续上已经存在的未完成话题，不要像提醒事项或催办机器人。',
      ProactiveIntentKind.shareThought => '分享她自己新形成的判断、联想或关注点；不要改写、复述或继续追问旧对话。',
      ProactiveIntentKind.curiosity => '主动打开一个现在真正想知道的新问题；不要追问已经回答过的旧话题。',
      ProactiveIntentKind.socialShare => '分享外部新发现或一个与旧话题不同的新鲜小事，不需要强求用户马上回复。',
      ProactiveIntentKind.intimacyInvitation => '可以带暧昧或亲密倾向，但仍是邀请而不是强行把普通聊天拉进露骨场景。',
      ProactiveIntentKind.emotionalReach => '更像想靠近、想说说话或寻求一点连接，不要制造戏剧化危机。',
    };
    final deliveryHint = switch (delivery) {
      ProactiveDeliveryStyle.quiet => '这是轻声投递：可以更短、更低压力；低压力来自消息本身，不必追加“你忙你的、晚点回、我不催”等待命声明。',
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
