import '../models/chat_message.dart';

enum GroundingDaypart {
  lateNight,
  morning,
  midday,
  afternoon,
  evening,
}

extension GroundingDaypartLabel on GroundingDaypart {
  String get key => switch (this) {
        GroundingDaypart.lateNight => 'late_night',
        GroundingDaypart.morning => 'morning',
        GroundingDaypart.midday => 'midday',
        GroundingDaypart.afternoon => 'afternoon',
        GroundingDaypart.evening => 'evening',
      };

  String get zhLabel => switch (this) {
        GroundingDaypart.lateNight => '深夜',
        GroundingDaypart.morning => '上午',
        GroundingDaypart.midday => '中午',
        GroundingDaypart.afternoon => '下午',
        GroundingDaypart.evening => '晚上',
      };
}

class GroundingSnapshot {
  static const transientSceneRecheckMinutes = 45;
  static const longGapMinutes = 120;

  const GroundingSnapshot({
    required this.nowLocal,
    required this.utcOffset,
    required this.weekday,
    required this.daypart,
    required this.lastUserMessageId,
    required this.lastAssistantMessageId,
    required this.lastUserAt,
    required this.lastAssistantAt,
    required this.lastUserAnswered,
    required this.pendingUserTurn,
    required this.userSpokeAfterLastAssistant,
    required this.assistantMessagesSinceLastUser,
    required this.proactiveMessagesSinceLastUser,
    required this.lastAssistantWasProactive,
    required this.minutesSinceLastUser,
    required this.minutesSinceLastAssistant,
    this.previousConversationAt,
    this.currentTurnGapMinutes,
    this.currentTurnCrossedCalendarDays = 0,
  });

  final DateTime nowLocal;
  final Duration utcOffset;
  final int weekday;
  final GroundingDaypart daypart;
  final String? lastUserMessageId;
  final String? lastAssistantMessageId;
  final DateTime? lastUserAt;
  final DateTime? lastAssistantAt;
  final bool lastUserAnswered;
  final bool pendingUserTurn;
  final bool userSpokeAfterLastAssistant;
  final int assistantMessagesSinceLastUser;
  final int proactiveMessagesSinceLastUser;
  final bool lastAssistantWasProactive;
  final int? minutesSinceLastUser;
  final int? minutesSinceLastAssistant;
  final DateTime? previousConversationAt;
  final int? currentTurnGapMinutes;
  final int currentTurnCrossedCalendarDays;

  bool get currentTurnCrossedDay => currentTurnCrossedCalendarDays > 0;
  bool get currentTurnRequiresTransientRecheck =>
      currentTurnCrossedDay ||
      (currentTurnGapMinutes != null &&
          currentTurnGapMinutes! >= transientSceneRecheckMinutes);
  bool get currentTurnHasLongGap =>
      currentTurnGapMinutes != null &&
      currentTurnGapMinutes! >= longGapMinutes;

  String get currentTurnGapBand {
    if (currentTurnGapMinutes == null) return 'none';
    if (currentTurnCrossedDay) return 'cross_day';
    if (currentTurnHasLongGap) return 'long_gap';
    if (currentTurnRequiresTransientRecheck) return 'transient_recheck';
    return 'same_scene';
  }

  bool get hasConversation => lastUserMessageId != null || lastAssistantMessageId != null;

  String get weekdayZh => const {
        DateTime.monday: '星期一',
        DateTime.tuesday: '星期二',
        DateTime.wednesday: '星期三',
        DateTime.thursday: '星期四',
        DateTime.friday: '星期五',
        DateTime.saturday: '星期六',
        DateTime.sunday: '星期日',
      }[weekday] ?? '未知';

  String get conversationState {
    if (!hasConversation) return 'no_history';
    if (pendingUserTurn) return 'user_turn_pending';
    if (lastUserAnswered && !userSpokeAfterLastAssistant) {
      return proactiveMessagesSinceLastUser > 0
          ? 'assistant_proactive_after_answer_user_silent'
          : 'assistant_replied_user_silent';
    }
    if (userSpokeAfterLastAssistant) return 'user_spoke_after_assistant';
    return 'settled';
  }

  Map<String, Object?> toRedactedJson() => {
        'localDate': _dateOnly(nowLocal),
        'localTime': _timeOnly(nowLocal),
        'utcOffsetMinutes': utcOffset.inMinutes,
        'weekday': weekday,
        'daypart': daypart.key,
        'conversationState': conversationState,
        'hasLastUser': lastUserMessageId != null,
        'hasLastAssistant': lastAssistantMessageId != null,
        'lastUserAnswered': lastUserAnswered,
        'pendingUserTurn': pendingUserTurn,
        'userSpokeAfterLastAssistant': userSpokeAfterLastAssistant,
        'assistantMessagesSinceLastUser': assistantMessagesSinceLastUser,
        'proactiveMessagesSinceLastUser': proactiveMessagesSinceLastUser,
        'lastAssistantWasProactive': lastAssistantWasProactive,
        'minutesSinceLastUser': minutesSinceLastUser,
        'minutesSinceLastAssistant': minutesSinceLastAssistant,
        'hasPreviousConversationBeforeCurrentTurn':
            previousConversationAt != null,
        'currentTurnGapMinutes': currentTurnGapMinutes,
        'currentTurnCrossedCalendarDays': currentTurnCrossedCalendarDays,
        'currentTurnCrossedDay': currentTurnCrossedDay,
        'currentTurnGapBand': currentTurnGapBand,
        'currentTurnRequiresTransientRecheck':
            currentTurnRequiresTransientRecheck,
        'currentTurnHasLongGap': currentTurnHasLongGap,
      };

  static GroundingDaypart daypartFor(DateTime value) {
    final hour = value.hour;
    if (hour < 5 || hour >= 23) return GroundingDaypart.lateNight;
    if (hour < 11) return GroundingDaypart.morning;
    if (hour < 14) return GroundingDaypart.midday;
    if (hour < 18) return GroundingDaypart.afternoon;
    return GroundingDaypart.evening;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _timeOnly(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class OrdinaryChatSceneBoundaryPolicy {
  const OrdinaryChatSceneBoundaryPolicy._();

  static String promptContract(GroundingSnapshot grounding) {
    if (grounding.currentTurnGapMinutes == null) return '';
    if (!grounding.currentTurnRequiresTransientRecheck) {
      return '''
普通聊天临时现场边界：当前是短间隔，可以把上一段中的短时活动视为可能继续；当前 REAL_USER_MESSAGE 有更新或纠正时始终以它为准，不要机械复述时间戳。''';
    }
    return '''
普通聊天临时现场边界：
- 上一段聊天中的“正在吃饭/洗澡/通勤/出门/开会/准备睡”等短寿命活动，此刻一律视为 unknown；不得默认它仍在继续，也不得反向虚构“已经做完”。
- 当前 REAL_USER_MESSAGE 若明确说“还在/刚做完/一直在”，以当前原话覆盖 unknown；不能仅凭旧 ASSISTANT_HISTORY 覆盖。
- 话题、关系、长期事实与记忆不因这个间隔失效；可以继续话题，但不能把继续话题写成继续旧的物理活动。
- 除非用户正在讨论时间，不要机械复述时间戳或解释这条规则。''';
  }
}

class ConversationGroundingPolicy {
  const ConversationGroundingPolicy._();

  static GroundingSnapshot build({
    required DateTime now,
    required List<ChatMessage> recent,
    Set<String> answeredUserMessageIds = const <String>{},
  }) {
    final localNow = now.toLocal();
    ChatMessage? lastUser;
    ChatMessage? lastAssistant;
    for (final message in recent) {
      if (message.isUser &&
          (lastUser == null || message.createdAt.isAfter(lastUser.createdAt))) {
        lastUser = message;
      }
      if (message.isAssistant &&
          (lastAssistant == null ||
              message.createdAt.isAfter(lastAssistant.createdAt))) {
        lastAssistant = message;
      }
    }

    var answered = lastUser != null &&
        (!lastUser.expectsReply || answeredUserMessageIds.contains(lastUser.id));
    if (!answered && lastUser != null) {
      // Backward-compatible fallback for historical messages predating durable
      // generation jobs. Only a normal assistant reply can satisfy the user
      // turn; a proactive message never counts as answering it.
      answered = recent.any((message) =>
          message.isAssistant &&
          !message.isProactive &&
          message.createdAt.isAfter(lastUser!.createdAt));
    }

    final userAfterAssistant = lastUser != null &&
        (lastAssistant == null || lastUser.createdAt.isAfter(lastAssistant.createdAt));
    final pendingUserTurn = lastUser != null && !answered;

    var assistantSinceUser = 0;
    var proactiveSinceUser = 0;
    if (lastUser != null) {
      for (final message in recent) {
        if (!message.isAssistant || !message.createdAt.isAfter(lastUser.createdAt)) {
          continue;
        }
        assistantSinceUser += 1;
        if (message.isProactive) proactiveSinceUser += 1;
      }
    }

    int? ageMinutes(DateTime? at) {
      if (at == null) return null;
      if (localNow.isBefore(at)) return 0;
      return localNow.difference(at).inMinutes;
    }

    ChatMessage? previousConversation;
    int? currentTurnGapMinutes;
    var currentTurnCrossedCalendarDays = 0;
    if (lastUser != null && userAfterAssistant) {
      for (final message in recent) {
        if (!message.createdAt.isBefore(lastUser.createdAt)) continue;
        if (previousConversation == null ||
            message.createdAt.isAfter(previousConversation.createdAt)) {
          previousConversation = message;
        }
      }
      if (previousConversation != null) {
        final gap = lastUser.createdAt.difference(
          previousConversation.createdAt,
        );
        currentTurnGapMinutes = gap.isNegative ? 0 : gap.inMinutes;
        final previousLocal = previousConversation.createdAt.toLocal();
        final currentLocal = lastUser.createdAt.toLocal();
        final previousDay = DateTime(
          previousLocal.year,
          previousLocal.month,
          previousLocal.day,
        );
        final currentDay = DateTime(
          currentLocal.year,
          currentLocal.month,
          currentLocal.day,
        );
        currentTurnCrossedCalendarDays =
            currentDay.difference(previousDay).inDays.clamp(0, 36500).toInt();
      }
    }

    return GroundingSnapshot(
      nowLocal: localNow,
      utcOffset: localNow.timeZoneOffset,
      weekday: localNow.weekday,
      daypart: GroundingSnapshot.daypartFor(localNow),
      lastUserMessageId: lastUser?.id,
      lastAssistantMessageId: lastAssistant?.id,
      lastUserAt: lastUser?.createdAt,
      lastAssistantAt: lastAssistant?.createdAt,
      lastUserAnswered: answered,
      pendingUserTurn: pendingUserTurn,
      userSpokeAfterLastAssistant: userAfterAssistant,
      assistantMessagesSinceLastUser: assistantSinceUser,
      proactiveMessagesSinceLastUser: proactiveSinceUser,
      lastAssistantWasProactive: lastAssistant?.isProactive ?? false,
      minutesSinceLastUser: ageMinutes(lastUser?.createdAt),
      minutesSinceLastAssistant: ageMinutes(lastAssistant?.createdAt),
      previousConversationAt: previousConversation?.createdAt,
      currentTurnGapMinutes: currentTurnGapMinutes,
      currentTurnCrossedCalendarDays: currentTurnCrossedCalendarDays,
    );
  }
}
