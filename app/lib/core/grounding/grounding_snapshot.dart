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
  static const transientSceneRecheckMinutes = 30;
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
    this.previousRealUserAt,
    this.currentTriggerAt,
    this.currentTurnGapMinutes,
    this.currentTurnInteractionGapMinutes,
    this.currentTurnCrossedCalendarDays = 0,
    this.userSceneAnchorAt,
    this.userSceneAnchorMessageId = '',
    this.userSceneGapMinutes,
    this.userSceneCrossedCalendarDays = 0,
    this.hasProactiveBoundaryAfterSceneAnchor = false,
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
  final DateTime? previousRealUserAt;
  final DateTime? currentTriggerAt;
  final int? currentTurnGapMinutes;
  final int? currentTurnInteractionGapMinutes;
  final int currentTurnCrossedCalendarDays;
  final DateTime? userSceneAnchorAt;
  final String userSceneAnchorMessageId;
  final int? userSceneGapMinutes;
  final int userSceneCrossedCalendarDays;
  final bool hasProactiveBoundaryAfterSceneAnchor;

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

  bool get userSceneCrossedDay => userSceneCrossedCalendarDays > 0;
  bool get userSceneRequiresTransientRecheck =>
      userSceneCrossedDay ||
      (userSceneGapMinutes != null &&
          userSceneGapMinutes! >= transientSceneRecheckMinutes);
  bool get userSceneHasLongGap =>
      userSceneGapMinutes != null && userSceneGapMinutes! >= longGapMinutes;

  String get userSceneGapBand {
    if (userSceneGapMinutes == null) return 'none';
    if (userSceneCrossedDay) return 'cross_day';
    if (userSceneHasLongGap) return 'long_gap';
    if (userSceneRequiresTransientRecheck) return 'transient_recheck';
    return 'same_scene';
  }

  String get timeBoundaryPromptMode {
    if (!userSceneRequiresTransientRecheck) return 'none';
    return hasProactiveBoundaryAfterSceneAnchor
        ? 'carry_forward'
        : 'detailed';
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
        'hasPreviousRealUserBeforeCurrentTurn': previousRealUserAt != null,
        'currentTurnGapMinutes': currentTurnGapMinutes,
        'currentTurnInteractionGapMinutes': currentTurnInteractionGapMinutes,
        'currentTurnCrossedCalendarDays': currentTurnCrossedCalendarDays,
        'currentTurnCrossedDay': currentTurnCrossedDay,
        'currentTurnGapBand': currentTurnGapBand,
        'currentTurnRequiresTransientRecheck':
            currentTurnRequiresTransientRecheck,
        'currentTurnHasLongGap': currentTurnHasLongGap,
        'hasUserSceneAnchor': userSceneAnchorAt != null,
        'userSceneGapMinutes': userSceneGapMinutes,
        'userSceneCrossedCalendarDays': userSceneCrossedCalendarDays,
        'userSceneGapBand': userSceneGapBand,
        'userSceneRequiresTransientRecheck':
            userSceneRequiresTransientRecheck,
        'userSceneHasLongGap': userSceneHasLongGap,
        'hasProactiveBoundaryAfterSceneAnchor':
            hasProactiveBoundaryAfterSceneAnchor,
        'timeBoundaryPromptMode': timeBoundaryPromptMode,
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
    if (!grounding.userSceneRequiresTransientRecheck) return '';
    return '''
普通聊天临时现场边界：
- 上一条真实用户消息中的短期现场已经经过至少半小时，不能机械延续。结合活动类型、上一条 REAL_USER_HISTORY 明确给出的持续时间/结束点、当前时段与当前真实用户原话自行判断。
- “吃饭/洗澡/短途通勤”等通常已不再是当前现场；“长途出行到晚上/会议到五点”等有明确持续时间的活动可以合理继续。偶发不确定时宁可不提或自然询问，不把推断写成确定事实。
- 当前 REAL_USER_MESSAGE 若明确说“还在/刚做完/一直在”，始终以当前原话为准；不能仅凭旧 ASSISTANT_HISTORY 或 AI 自己的主动消息刷新用户现实现场。
- 话题、关系、长期事实与记忆不因这个间隔失效；可以继续话题，但不能把继续话题写成继续旧的物理活动。
- 除非用户正在讨论时间，不要机械复述时间戳、间隔数字或解释这条规则；对活动是否结束的推断只用于本轮自然表达，不写成长期事实。''';
  }
}

class ConversationGroundingPolicy {
  const ConversationGroundingPolicy._();

  static GroundingSnapshot build({
    required DateTime now,
    required List<ChatMessage> recent,
    Set<String> answeredUserMessageIds = const <String>{},
    String proactiveBoundaryInjectedUserMessageId = '',
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

    int crossedCalendarDays(DateTime? start, DateTime? end) {
      if (start == null || end == null) return 0;
      final startLocal = start.toLocal();
      final endLocal = end.toLocal();
      final startDay = DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
      );
      final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
      return endDay.difference(startDay).inDays.clamp(0, 36500).toInt();
    }

    int? elapsedMinutes(DateTime? start, DateTime? end) {
      if (start == null || end == null) return null;
      final gap = end.difference(start);
      return gap.isNegative ? 0 : gap.inMinutes;
    }

    ChatMessage? previousConversation;
    ChatMessage? previousRealUser;
    int? currentTurnInteractionGapMinutes;
    if (lastUser != null && userAfterAssistant) {
      for (final message in recent) {
        if (!message.createdAt.isBefore(lastUser.createdAt)) continue;
        if (previousConversation == null ||
            message.createdAt.isAfter(previousConversation.createdAt)) {
          previousConversation = message;
        }
        if (message.isUser &&
            (previousRealUser == null ||
                message.createdAt.isAfter(previousRealUser.createdAt))) {
          previousRealUser = message;
        }
      }
      currentTurnInteractionGapMinutes = elapsedMinutes(
        previousConversation?.createdAt,
        lastUser.createdAt,
      );
    }

    final currentTriggerAt = userAfterAssistant ? lastUser?.createdAt : localNow;
    final userSceneAnchor = userAfterAssistant
        ? (previousRealUser ?? previousConversation)
        : lastUser;
    final userSceneAnchorAt = userSceneAnchor?.createdAt;
    final userSceneGapMinutes = elapsedMinutes(
      userSceneAnchorAt,
      currentTriggerAt,
    );
    final userSceneCrossedCalendarDays = crossedCalendarDays(
      userSceneAnchorAt,
      currentTriggerAt,
    );
    var hasProactiveBoundaryAfterSceneAnchor = !userAfterAssistant &&
        userSceneAnchor != null &&
        proactiveBoundaryInjectedUserMessageId == userSceneAnchor.id;
    if (userSceneAnchorAt != null && currentTriggerAt != null) {
      for (final message in recent) {
        if (!message.isAssistant || !message.isProactive) continue;
        if (!message.createdAt.isAfter(userSceneAnchorAt) ||
            message.createdAt.isAfter(currentTriggerAt)) {
          continue;
        }
        final boundaryAge = elapsedMinutes(
          userSceneAnchorAt,
          message.createdAt,
        );
        if (boundaryAge != null &&
            boundaryAge >= GroundingSnapshot.transientSceneRecheckMinutes) {
          hasProactiveBoundaryAfterSceneAnchor = true;
          break;
        }
      }
    }
    final currentTurnGapMinutes =
        userAfterAssistant ? userSceneGapMinutes : null;
    final currentTurnCrossedCalendarDays =
        userAfterAssistant ? userSceneCrossedCalendarDays : 0;

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
      previousRealUserAt: previousRealUser?.createdAt,
      currentTriggerAt: currentTriggerAt,
      currentTurnGapMinutes: currentTurnGapMinutes,
      currentTurnInteractionGapMinutes: currentTurnInteractionGapMinutes,
      currentTurnCrossedCalendarDays: currentTurnCrossedCalendarDays,
      userSceneAnchorAt: userSceneAnchorAt,
      userSceneAnchorMessageId: userSceneAnchor?.id ?? '',
      userSceneGapMinutes: userSceneGapMinutes,
      userSceneCrossedCalendarDays: userSceneCrossedCalendarDays,
      hasProactiveBoundaryAfterSceneAnchor:
          hasProactiveBoundaryAfterSceneAnchor,
    );
  }
}
