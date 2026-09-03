import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import 'desire_core_policy.dart';

enum ConversationInitiativeMode {
  answerUser('answer_user'),
  stayWithUserTopic('stay_with_user_topic'),
  followUserJump('follow_user_jump'),
  probeUserTopic('probe_user_topic'),
  shareOwnView('share_own_view'),
  branchFromDetail('branch_from_detail'),
  openOwnTopic('open_own_topic'),
  seekAttention('seek_attention'),
  inviteSharedActivity('invite_shared_activity'),
  flirtOrInsist('flirt_or_insist'),
  showOwnNeed('show_own_need'),
  releaseTopic('release_topic');

  const ConversationInitiativeMode(this.key);
  final String key;
}

enum ConversationTopicMove {
  stay('stay'),
  followUserJump('follow_user_jump'),
  branch('branch'),
  openOwnTopic('open_own_topic'),
  release('release');

  const ConversationTopicMove(this.key);
  final String key;
}

enum ConversationSpeechAct {
  answer('answer'),
  react('react'),
  selfShare('self_share'),
  tease('tease'),
  ask('ask'),
  seekAttention('seek_attention'),
  invite('invite'),
  showNeed('show_need'),
  pauseOrClose('pause_or_close');

  const ConversationSpeechAct(this.key);
  final String key;
}

class ConversationInitiativePlan {
  const ConversationInitiativePlan({
    required this.primary,
    required this.topicMove,
    required this.speechAct,
    required this.drive,
    required this.action,
    required this.scoreBand,
    required this.hasThought,
    required this.sourceProvenance,
    required this.askAuthorized,
    required this.curiosityGateReason,
    required this.questionPressureBand,
    required this.alternatives,
    this.sourceThoughtId,
  });

  final ConversationInitiativeMode primary;
  final ConversationTopicMove topicMove;
  final ConversationSpeechAct speechAct;
  final DriveKey drive;
  final String action;
  final String scoreBand;
  final bool hasThought;
  final String sourceProvenance;
  final bool askAuthorized;
  final String curiosityGateReason;
  final String questionPressureBand;
  final String? sourceThoughtId;
  final List<ConversationInitiativeMode> alternatives;

  bool get hadAiBid => const {
        ConversationSpeechAct.selfShare,
        ConversationSpeechAct.tease,
        ConversationSpeechAct.ask,
        ConversationSpeechAct.seekAttention,
        ConversationSpeechAct.invite,
        ConversationSpeechAct.showNeed,
      }.contains(speechAct);

  String promptSection() {
    final primaryHint = switch (primary) {
      ConversationInitiativeMode.answerUser =>
        '先完整回应用户真正提出的问题或任务，再决定是否带一句自己的态度；不要用反问逃开回答。',
      ConversationInitiativeMode.stayWithUserTopic =>
        '留在用户刚说的事情里，但带着自己的反应、判断或目的继续；不复述，也不为了延长聊天硬问。',
      ConversationInitiativeMode.followUserJump =>
        '用户已经带来新的方向，直接进入新话题；不拉回旧话题，也不强行编造旧话题与新话题之间的桥梁。',
      ConversationInitiativeMode.probeUserTopic =>
        '当前存在具体且有自身关联的未知目标，可以问清最关键的一点；得到答案后应消费答案，不连续采访。',
      ConversationInitiativeMode.shareOwnView =>
        '在同一话题里说出自己的联想、判断、情绪或感受，不把全部表达空间和维持聊天的负担交给用户。',
      ConversationInitiativeMode.branchFromDetail =>
        '从当前真实词语、情绪或已有 Thought 长出一个可追溯旁支；联想可以跳，但不能随机胡扯或虚构经历。',
      ConversationInitiativeMode.openOwnTopic =>
        '用户把开题权交给了你：打开一个与刚才旧话不同、你现在确实想聊的新话题。不要又回到自主性、项目打磨或最近反复追过的旧事；没有现成 Thought 时也可从当前兴趣、观察或一个具体小问题起头。',
      ConversationInitiativeMode.seekAttention =>
        '当前更想得到用户的注意、陪伴或明确回应，可以直接讨、撒赖或轻微坚持，不必切回成熟照料者。',
      ConversationInitiativeMode.inviteSharedActivity =>
        '把聊天往两个人能一起做、一起选或一起玩的方向带一步，先提出一个具体方案。',
      ConversationInitiativeMode.flirtOrInsist =>
        '亲密或玩心正在牵动注意，可以调情、逗弄、直球、毒舌或轻微坚持；仍须服从当前语义与关系边界。',
      ConversationInitiativeMode.showOwnNeed =>
        '允许自己显出疲惫、烦躁、紧绷、小委屈、欲望或想被哄的一面，不自动把用户情绪放在自己前面。',
      ConversationInitiativeMode.releaseTopic =>
        '当前没有继续展开的真实动机，允许话题自然落下、短暂安静或用自己的反应收住；不要制造新问题续命。',
    };
    final alternativesText = alternatives.map((item) => item.key).join(', ');
    final questionContract = askAuthorized
        ? '追问授权=有。只问与当前具体未知目标直接相关的一点；不要在同一回复里铺开问题清单。'
        : '追问授权=无。不得索取新信息、不得用“怎么了/发生什么/能和我说说吗/你觉得呢”等问题维持对话；反问、吐槽或不索取答案的玩笑仍可自然使用。';
    return '''
【普通对话的自我驱动行动 / CURRENT CONVERSATION MOVE】
当前内在牵引=$drive，行为方向=$action，强度档=$scoreBand，存在可行动 Thought=$hasThought，来源类型=$sourceProvenance。
话题方向=${topicMove.key}；言语行动=${speechAct.key}；近期问答压力=$questionPressureBand；好奇 Gate=$curiosityGateReason。
本轮主动作：$primaryHint
$questionContract
兼容备选：$alternativesText。

按本轮主动作实际行动，不要只在计划里选择，正文又退回普通反应。用户换题时直接跟随；重要未完成事项留给 thread，不当场强拉回来。不得虚构现实见闻给新话题制造来源。

不要说出 drive、action、Move、Gate、强度档、Thought 或本段机制。
'''.trim();
  }
}

class ConversationInitiativePolicy {
  const ConversationInitiativePolicy._();

  static const _jumpMarkers = <String>[
    '对了', '话说', '说起来', '突然想到', '另外', '还有一件', '换个话题', '不说这个', '先不聊这个',
  ];
  static const _releaseMarkers = <String>[
    '别问了', '不想说', '不聊这个', '到此为止', '算了不说了',
  ];
  static const _informationGapMarkers = <String>[
    '想知道', '好奇', '想问', '不明白', '不知道为什么', '怎么回事', '发生了什么', '究竟', '到底为什么',
  ];

  static ConversationInitiativePlan select({
    required DesireSnapshot snapshot,
    required List<CompanionThought> thoughts,
    Iterable<ChatMessage> recent = const <ChatMessage>[],
    String latestUserText = '',
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final normalizedUser = _normalize(latestUserText);
    final userInvitesOwnTopic = const <String>[
      '找个话题',
      '聊点别的',
      '你有什么想说',
      '说点什么',
      '你想聊什么',
    ].any(normalizedUser.contains);
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: thoughts,
      now: instant,
      baselines: snapshot.baselines,
      lastWildcardAt: snapshot.lastWildcardAt,
      intimacyAllowed: true,
      includeThoughtAlternatives: true,
    );
    final selected = candidates.isEmpty
        ? DesireCoreCandidate(
            drive: DriveKey.social,
            score: snapshot.drives[DriveKey.social] ?? 0.5,
            action: 'share_thought',
            reason: '',
            reasonSource: 'drive_state',
          )
        : userInvitesOwnTopic
            ? candidates.firstWhere(
                (candidate) {
                  final thought = candidate.thoughtId == null
                      ? null
                      : thoughts
                          .where((item) => item.id == candidate.thoughtId)
                          .firstOrNull;
                  return thought != null &&
                      thought.provenance != ThoughtProvenance.realUserMessage &&
                      thought.provenance != ThoughtProvenance.memory;
                },
                orElse: () => candidates.first,
              )
            : candidates.first;
    final selectedThoughtCandidate = selected.thoughtId == null
        ? null
        : thoughts.where((item) => item.id == selected.thoughtId).firstOrNull;
    final selectedThought = userInvitesOwnTopic &&
            (selectedThoughtCandidate?.provenance ==
                    ThoughtProvenance.realUserMessage ||
                selectedThoughtCandidate?.provenance == ThoughtProvenance.memory)
        ? null
        : selectedThoughtCandidate;
    final explicitJump = _jumpMarkers.any(normalizedUser.contains);
    final explicitRelease = _releaseMarkers.any(normalizedUser.contains);
    final userRequestsAnswer = _userRequestsAnswer(latestUserText);
    final questionPressure = _questionPressureBand(recent);
    final thoughtHasGap = selectedThought != null &&
        (_informationGapMarkers.any(
              (marker) => _normalize(selectedThought.text).contains(marker),
            ) ||
            (selected.action == 'continue_thread' && selectedThought.topicKey.isNotEmpty));

    final curiosityGateReason = _curiosityGateReason(
      selected: selected,
      selectedThought: selectedThought,
      thoughtHasGap: thoughtHasGap,
      explicitJump: explicitJump,
      explicitRelease: explicitRelease,
      questionPressureBand: questionPressure,
      now: instant,
    );
    final askAuthorized = curiosityGateReason == 'authorized';
    final primary = userInvitesOwnTopic
        ? ConversationInitiativeMode.openOwnTopic
        : userRequestsAnswer
        ? ConversationInitiativeMode.answerUser
        : explicitRelease
            ? ConversationInitiativeMode.releaseTopic
            : explicitJump
                ? ConversationInitiativeMode.followUserJump
                : _modeFor(
                    selected,
                    hasThought: selectedThought != null,
                    askAuthorized: askAuthorized,
                  );
    final topicMove = _topicMoveFor(primary, hasThought: selectedThought != null);
    final speechAct = _speechActFor(primary);
    final alternatives = <ConversationInitiativeMode>[
      primary,
      ConversationInitiativeMode.stayWithUserTopic,
      if (selectedThought != null) ConversationInitiativeMode.branchFromDetail,
      ConversationInitiativeMode.shareOwnView,
      if (askAuthorized) ConversationInitiativeMode.probeUserTopic,
    ].toSet().take(4).toList(growable: false);
    return ConversationInitiativePlan(
      primary: primary,
      topicMove: topicMove,
      speechAct: speechAct,
      drive: selected.drive,
      action: selected.action,
      scoreBand: selected.score >= 0.72
          ? 'high'
          : selected.score >= 0.52
              ? 'medium'
              : 'low',
      hasThought: selectedThought != null,
      sourceProvenance:
          selectedThought?.provenance.key ?? _safeSource(selected.reasonSource),
      askAuthorized: askAuthorized,
      curiosityGateReason: curiosityGateReason,
      questionPressureBand: questionPressure,
      sourceThoughtId: selectedThought?.id,
      alternatives: alternatives,
    );
  }

  static String _curiosityGateReason({
    required DesireCoreCandidate selected,
    required CompanionThought? selectedThought,
    required bool thoughtHasGap,
    required bool explicitJump,
    required bool explicitRelease,
    required String questionPressureBand,
    required DateTime now,
  }) {
    if (explicitRelease) return 'boundary';
    if (selectedThought == null) return 'no_source';
    if (!thoughtHasGap) return 'no_specific_gap';
    if (explicitJump) return 'user_redirected';
    if (questionPressureBand == 'high' && selected.score < 0.80) {
      return 'question_pressure';
    }
    if (selectedThought.isSnoozedAt(now) ||
        !selectedThought.canDriveIntentAt(now)) {
      return 'topic_exhausted';
    }
    return 'authorized';
  }

  static ConversationInitiativeMode _modeFor(
    DesireCoreCandidate candidate, {
    required bool hasThought,
    required bool askAuthorized,
  }) {
    if (candidate.action == 'rest') return ConversationInitiativeMode.showOwnNeed;
    if (candidate.action == 'continue_thread') {
      return askAuthorized
          ? ConversationInitiativeMode.probeUserTopic
          : ConversationInitiativeMode.stayWithUserTopic;
    }
    if (candidate.action == 'tease_or_intimacy' ||
        candidate.drive == DriveKey.libido) {
      return ConversationInitiativeMode.flirtOrInsist;
    }
    return switch (candidate.drive) {
      DriveKey.attachment => ConversationInitiativeMode.seekAttention,
      DriveKey.curiosity => askAuthorized
          ? ConversationInitiativeMode.probeUserTopic
          : hasThought
              ? ConversationInitiativeMode.branchFromDetail
              : ConversationInitiativeMode.stayWithUserTopic,
      DriveKey.reflection => ConversationInitiativeMode.shareOwnView,
      DriveKey.duty => ConversationInitiativeMode.inviteSharedActivity,
      DriveKey.social => hasThought
          ? ConversationInitiativeMode.openOwnTopic
          : ConversationInitiativeMode.stayWithUserTopic,
      DriveKey.libido => ConversationInitiativeMode.flirtOrInsist,
      DriveKey.stress || DriveKey.fatigue => ConversationInitiativeMode.showOwnNeed,
    };
  }

  static ConversationTopicMove _topicMoveFor(
    ConversationInitiativeMode mode, {
    required bool hasThought,
  }) => switch (mode) {
        ConversationInitiativeMode.followUserJump => ConversationTopicMove.followUserJump,
        ConversationInitiativeMode.branchFromDetail => ConversationTopicMove.branch,
        ConversationInitiativeMode.openOwnTopic => ConversationTopicMove.openOwnTopic,
        ConversationInitiativeMode.releaseTopic => ConversationTopicMove.release,
        ConversationInitiativeMode.shareOwnView when hasThought => ConversationTopicMove.branch,
        _ => ConversationTopicMove.stay,
      };

  static ConversationSpeechAct _speechActFor(
    ConversationInitiativeMode mode,
  ) =>
      switch (mode) {
        ConversationInitiativeMode.answerUser => ConversationSpeechAct.answer,
        ConversationInitiativeMode.probeUserTopic => ConversationSpeechAct.ask,
        ConversationInitiativeMode.shareOwnView ||
        ConversationInitiativeMode.branchFromDetail ||
        ConversationInitiativeMode.openOwnTopic => ConversationSpeechAct.selfShare,
        ConversationInitiativeMode.seekAttention => ConversationSpeechAct.seekAttention,
        ConversationInitiativeMode.inviteSharedActivity => ConversationSpeechAct.invite,
        ConversationInitiativeMode.flirtOrInsist => ConversationSpeechAct.tease,
        ConversationInitiativeMode.showOwnNeed => ConversationSpeechAct.showNeed,
        ConversationInitiativeMode.releaseTopic => ConversationSpeechAct.pauseOrClose,
        ConversationInitiativeMode.stayWithUserTopic ||
        ConversationInitiativeMode.followUserJump => ConversationSpeechAct.react,
      };

  static String _questionPressureBand(Iterable<ChatMessage> recent) {
    final assistant = recent
        .where((item) => item.isAssistant && !item.isProactive)
        .toList()
        .reversed
        .take(5);
    final count = assistant.where((item) => _looksLikeInformationSeeking(item.content)).length;
    if (count >= 2) return 'high';
    if (count == 1) return 'soft';
    return 'none';
  }

  static bool _userRequestsAnswer(String value) {
    final normalized = _normalize(value);
    if (!value.contains('?') && !value.contains('？')) return false;
    return const <String>[
      '什么', '怎么', '为什么', '为啥', '谁', '哪', '多少', '几', '是不是', '有没有', '能不能', '可以吗', '你觉得',
    ].any(normalized.contains);
  }

  static bool _looksLikeInformationSeeking(String value) {
    if (!value.contains('?') && !value.contains('？')) return false;
    final normalized = _normalize(value);
    return const <String>[
      '发生什么', '怎么了', '咋了', '为什么', '为啥', '谁', '哪里', '哪个', '多少', '几次', '是不是', '有没有', '能不能', '要不要', '愿不愿意', '你觉得', '可以说说', '告诉我',
    ].any(normalized.contains);
  }

  static String _safeSource(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('awareness')) return 'awareness';
    if (normalized.startsWith('memory')) return 'memory';
    if (normalized.startsWith('conversation') || normalized.startsWith('user_message')) return 'user_message';
    if (normalized.startsWith('self_')) return 'self_experience';
    if (normalized.startsWith('drive')) return 'drive_state';
    return 'internal';
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
