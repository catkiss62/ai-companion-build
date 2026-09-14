class AgentParticipationConsentPolicy {
  const AgentParticipationConsentPolicy._();

  static final RegExp _denial = RegExp(
    r'(不想玩|不玩了|别来|不要来|不用来|拒绝|没(?:有)?邀请|不是邀请|暂时不玩)',
    caseSensitive: false,
  );
  static final RegExp _userInitiated = RegExp(
    r'((?:我|这边).{0,24}(?:开|建|创建|准备)(?:好|了)?.{0,24}(?:房|房间|房号|对局).{0,30}(?:要来|来吧|来玩|加入|进来|一起玩|玩吗))|'
    r'((?:邀请你|叫你|喊你).{0,20}(?:来|加入|进|玩|下棋))|'
    r'((?:要不要|要来|来不来|来吧|进来吧|一起).{0,16}(?:玩|下棋|游戏|对局))',
    caseSensitive: false,
  );
  static final RegExp _accepted = RegExp(
    r'^(?=.{1,24}$)(?:好|好的|好啊|可以|可以啊|行|行啊|同意|答应|没问题|走起|来|来吧|开始|开始吧|一起玩|进来|进来吧)(?:[，,、\s]*(?:来|来吧|开始|开始吧|一起玩|进来|进来吧))?[！!。.，,\s]*$',
    caseSensitive: false,
  );
  static final RegExp _roomShared = RegExp(
    r'(?:房间码|房号|room\s*id).{0,24}[A-Za-z0-9]{5,16}',
    caseSensitive: false,
  );
  static final RegExp _standaloneRoomCode = RegExp(
    r'^[A-Z0-9]{5,16}$',
    caseSensitive: false,
  );

  static bool explicitlyGranted(String text) {
    final clean = text.trim();
    if (clean.isEmpty || _denial.hasMatch(clean)) return false;
    return _userInitiated.hasMatch(clean) ||
        _accepted.hasMatch(clean) ||
        _roomShared.hasMatch(clean) ||
        _standaloneRoomCode.hasMatch(clean);
  }

  static bool describesExistingRoom(String text) {
    final clean = text.trim();
    if (clean.isEmpty || _denial.hasMatch(clean)) return false;
    return RegExp(
      r'((?:我|这边).{0,20}(?:已经|刚刚|刚才)?(?:开|建|创建)(?:好|了).{0,20}(?:房|房间|对局))|'
      r'((?:房间码|房号|room\s*id).{0,24}[A-Za-z0-9]{5,16})|'
      r'(^[A-Z0-9]{5,16}$)',
      caseSensitive: false,
    ).hasMatch(clean);
  }
}
