import '../models/memory_item.dart';

class MemoryLifecycleProfile {
  const MemoryLifecycleProfile({
    required this.factState,
    required this.attentionState,
    required this.recallPolicy,
    required this.spontaneousSalience,
    required this.source,
  });

  final String factState;
  final String attentionState;
  final String recallPolicy;
  final double spontaneousSalience;
  final String source;
}

/// Keeps durable truth, current attention and permission to speak separate.
///
/// The model may propose a profile for new evidence, but these local enums and
/// conservative fallbacks remain authoritative. In particular, a stale
/// `ongoing` memory is never enough to manufacture a follow-up; only a live
/// unfinished thread grants that lane.
class MemoryLifecyclePolicy {
  const MemoryLifecyclePolicy._();

  static const factStates = <String>{
    'stable',
    'ongoing',
    'completed',
    'cancelled',
    'unknown',
  };
  static const attentionStates = <String>{
    'active',
    'snoozed',
    'closed',
  };
  static const recallPolicies = <String>{
    'contextual',
    'reminiscence',
    'identity',
    'followup',
  };

  static final RegExp _negativeCompletion = RegExp(
    r'(还没|尚未|未完成|没(?:有)?(?:做完|做好|完成|改好|弄完|搞定)|'
    r'还(?:在|要|得|差)|正在|才开始|只做了|差一点|快了)',
  );
  static final RegExp _completionQuestion = RegExp(
    r'((?:做完|做好|完成|改好|弄完|搞定)(?:了)?(?:吗|没|没有|么)[？?]?$|'
    r'(?:是不是|是否).{0,12}(?:做完|做好|完成|改好|弄完|搞定))',
  );
  static final RegExp _completion = RegExp(
    r'((?:已经|早就|终于|刚刚|刚|都|算是)?(?:做完|做好|完成|改好|弄完|搞定|收尾)(?:了|啦|咯)?|'
    r'(?:已经|现已|现在已经).{0,12}(?:实现|上线|可用|结束))',
  );
  static final RegExp _cancelled = RegExp(
    r'(不做了|不弄了|取消了?|放弃了?|算了不(?:做|弄)|不用再(?:做|弄|继续))',
  );
  static final RegExp _deferred = RegExp(
    r'(以后再|之后再|晚点再|明天再|改天再|有空再|先放放|暂时不|还要继续|接着做)',
  );
  static final RegExp _meaningCue = RegExp(
    r'(第一次|终于|特别|重要|感动|生气|愤怒|难忘|纪念|一起|共同|惊喜|喜欢|爱好|形象|Live2D|呆毛|表情包|鲸鱼)',
    caseSensitive: false,
  );
  static final RegExp _interestCue = RegExp(
    r'(爱好|兴趣|最喜欢|喜欢.{0,8}(?:音乐|歌曲|歌手|电影|动画|漫画|游戏|书|小说|角色|动物|食物|运动|活动))',
  );

  static String compact(String value) => value
      .replaceAll(RegExp(r'''[\s，。！？、,.!?：:；;“”"'（）()【】\[\]]+'''), '')
      .trim();

  static bool isExplicitCompletion(String text) {
    final value = compact(text);
    if (value.isEmpty ||
        _negativeCompletion.hasMatch(value) ||
        _completionQuestion.hasMatch(value)) {
      return false;
    }
    return _completion.hasMatch(value);
  }

  static bool isExplicitCancellation(String text) {
    final value = compact(text);
    return value.isNotEmpty && _cancelled.hasMatch(value);
  }

  static bool isExplicitDeferral(String text) {
    final value = compact(text);
    if (value.isEmpty || isExplicitCompletion(value)) return false;
    return _deferred.hasMatch(value) || _negativeCompletion.hasMatch(value);
  }

  static MemoryLifecycleProfile derive({
    required String kind,
    required String semanticType,
    required String temporalScope,
    required String content,
    required double importance,
    String? proposedFactState,
    String? proposedAttentionState,
    String? proposedRecallPolicy,
    double? proposedSpontaneousSalience,
    bool hasActiveThread = false,
    String source = 'local_default',
  }) {
    final normalizedFact = _factState(
      proposedFactState,
      semanticType: semanticType,
      temporalScope: temporalScope,
      content: content,
      kind: kind,
    );
    var attention = attentionStates.contains(proposedAttentionState)
        ? proposedAttentionState!
        : normalizedFact == 'ongoing'
            ? 'snoozed'
            : 'closed';
    var recall = recallPolicies.contains(proposedRecallPolicy)
        ? proposedRecallPolicy!
        : _defaultRecallPolicy(
            kind: kind,
            semanticType: semanticType,
            factState: normalizedFact,
            importance: importance,
            content: content,
          );

    // Suggested autonomous lanes are bounded by local meaning checks. A model
    // cannot turn a high-importance work item into a reminiscence merely by
    // assigning a generous score.
    if (recall == 'reminiscence' &&
        !_eligibleReminiscence(
          semanticType: semanticType,
          factState: normalizedFact,
          importance: importance,
          content: content,
        )) {
      recall = 'contextual';
    }
    if (recall == 'identity' &&
        !_eligibleIdentity(
          kind: kind,
          factState: normalizedFact,
          importance: importance,
          content: content,
        )) {
      recall = 'contextual';
    }

    // A model-written follow-up label is not authority. Only a currently live
    // thread may keep an item in the task lane.
    if (hasActiveThread && normalizedFact == 'ongoing') {
      attention = 'active';
      recall = 'followup';
    } else if (recall == 'followup') {
      attention = 'snoozed';
      recall = 'contextual';
    }
    if (normalizedFact == 'completed' || normalizedFact == 'cancelled') {
      attention = 'closed';
      if (recall == 'followup') recall = 'contextual';
    }

    final suggested = proposedSpontaneousSalience == null
        ? _defaultSalience(
            kind: kind,
            semanticType: semanticType,
            content: content,
            importance: importance,
            recallPolicy: recall,
          )
        : proposedSpontaneousSalience.clamp(0.0, 1.0).toDouble();
    final salience = recall == 'reminiscence' || recall == 'identity'
        ? suggested
        : 0.0;
    return MemoryLifecycleProfile(
      factState: normalizedFact,
      attentionState: attention,
      recallPolicy: recall,
      spontaneousSalience: salience,
      source: source,
    );
  }

  static MemoryLifecycleProfile forLegacy(
    MemoryItem item, {
    bool hasActiveThread = false,
    DateTime? now,
  }) {
    final derived = derive(
        kind: item.kind,
        semanticType: item.semanticType,
        temporalScope: item.temporalScope,
        content: item.content,
        importance: item.importance,
        hasActiveThread: hasActiveThread,
        source: 'legacy_v49_backfill',
      );
    final instant = now ?? DateTime.now();
    final staleOngoing = derived.factState == 'ongoing' &&
        !hasActiveThread &&
        instant.difference(item.lastEvidenceAt).inDays >= 14;
    if (!staleOngoing) return derived;
    return const MemoryLifecycleProfile(
      factState: 'unknown',
      attentionState: 'snoozed',
      recallPolicy: 'contextual',
      spontaneousSalience: 0.0,
      source: 'legacy_v49_stale_ongoing',
    );
  }

  static bool eligibleForSpontaneousRecall(MemoryItem item) =>
      item.isActive &&
      item.attentionState == 'closed' &&
      (item.recallPolicy == 'reminiscence' ||
          item.recallPolicy == 'identity') &&
      item.spontaneousSalience >= 0.68;

  static String _factState(
    String? proposed, {
    required String semanticType,
    required String temporalScope,
    required String content,
    required String kind,
  }) {
    if (isExplicitCancellation(content)) return 'cancelled';
    if (isExplicitCompletion(content)) return 'completed';
    if (factStates.contains(proposed)) return proposed!;
    if (semanticType == 'shared_experience' || temporalScope == 'event') {
      return 'completed';
    }
    if (temporalScope == 'ongoing' || temporalScope == 'scheduled') {
      return 'ongoing';
    }
    if (temporalScope == 'stable' || kind == 'preference' || kind == 'ai_self') {
      return 'stable';
    }
    return 'unknown';
  }

  static String _defaultRecallPolicy({
    required String kind,
    required String semanticType,
    required String factState,
    required double importance,
    required String content,
  }) {
    if (_eligibleIdentity(
      kind: kind,
      factState: factState,
      importance: importance,
      content: content,
    )) {
      return 'identity';
    }
    if (_eligibleReminiscence(
      semanticType: semanticType,
      factState: factState,
      importance: importance,
      content: content,
    )) {
      return 'reminiscence';
    }
    return 'contextual';
  }

  static bool _eligibleReminiscence({
    required String semanticType,
    required String factState,
    required double importance,
    required String content,
  }) =>
      (semanticType == 'shared_experience' || factState == 'completed') &&
      importance >= 0.72 &&
      _meaningCue.hasMatch(content);

  static bool _eligibleIdentity({
    required String kind,
    required String factState,
    required double importance,
    required String content,
  }) =>
      importance >= 0.72 &&
      ((kind == 'ai_self' && factState != 'ongoing') ||
          (kind == 'preference' && _interestCue.hasMatch(content)));

  static double _defaultSalience({
    required String kind,
    required String semanticType,
    required String content,
    required double importance,
    required String recallPolicy,
  }) {
    if (recallPolicy != 'reminiscence' && recallPolicy != 'identity') return 0;
    var score = importance * 0.78;
    if (semanticType == 'shared_experience') score += 0.08;
    if (_meaningCue.hasMatch(content)) score += 0.08;
    if (kind == 'ai_self') score += 0.04;
    return score.clamp(0.0, 1.0).toDouble();
  }
}
