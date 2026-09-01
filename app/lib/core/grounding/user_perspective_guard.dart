class UserPerspectiveGuardResult {
  const UserPerspectiveGuardResult({
    required this.allowed,
    this.reason = '',
  });

  final bool allowed;
  final String reason;
}

/// High-confidence runtime backstop for the ordinary/proactive second-person
/// contract. It intentionally does not reject every occurrence of “他”,
/// because a genuine third party may be discussed. These patterns are limited
/// to narration that directly treats the current conversation partner as him.
class UserPerspectiveGuard {
  const UserPerspectiveGuard._();

  static final _thirdPartyContext = RegExp(
    r'(?:(?:我|你)(?:老板|朋友|同事|同学|家人|哥哥|弟弟|父亲|男友|老公)|(?:老板|朋友|同事|同学|家人|哥哥|弟弟|父亲|男友|老公)(?:他|说|在|的)|(?:和|跟|被|对|向)他(?:聊|说|问|发|回|看|这)|(?:^|[，。！？\s])他(?:说|在|的|刚|又|还|也|给|把|让|聊|问|发|回|看))',
  );

  static final _forbidden = <RegExp>[
    RegExp(r'被他这(?:句|句话|声|条|个)'),
    RegExp(r'(?:看着|望着|瞥向|转向|盯着|等着|靠近|贴近|抱住|拉住|戳了戳)他(?:那边|这边|的|一下|一眼|，|。|…|$)'),
    RegExp(r'(?:对着|冲着|朝着)他(?:说|笑|眨眼|挑眉|抬下巴|挥手|，|。|…|$)'),
    RegExp(r'他那边(?:的)?(?:屏幕|消息|声音|回复|动静)'),
  ];

  static UserPerspectiveGuardResult evaluate(
    String text, {
    String currentUserText = '',
  }) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // If the current/recent real-user context introduces a third party, do not
    // guess which later “他” refers to. Prefer a rare miss over rewriting a
    // legitimate discussion; the prompt contract remains the first line.
    if (_thirdPartyContext.hasMatch(currentUserText)) {
      return const UserPerspectiveGuardResult(allowed: true);
    }
    for (final pattern in _forbidden) {
      if (pattern.hasMatch(normalized)) {
        return const UserPerspectiveGuardResult(
          allowed: false,
          reason: 'current_user_narrated_as_third_person',
        );
      }
    }
    return const UserPerspectiveGuardResult(allowed: true);
  }
}
