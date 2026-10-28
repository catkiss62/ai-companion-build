/// Per visible generation, including any semantic correction. A grounding
/// rejection is not a transport failure and never switches the provider.
class FinalReplyRoute {
  FinalReplyRoute({required this.secondChannelEnabled});
  final bool secondChannelEnabled;
  Object? _failure;
  Object? _thirdFailure;
  bool usedThirdChannel = false;
  bool get thirdChannelAvailable => _thirdFailure == null;
  Object? get thirdChannelFailure => _thirdFailure;
  void recordThirdFailure(Object error) { _thirdFailure = error; usedThirdChannel = false; }
  bool get useSecondChannel => secondChannelEnabled && _failure == null;
  void recordFailure(Object error) { _failure = error; }

  /// Relay APIs may turn system-only messages into an empty contents array.
  /// This is an internal task envelope, never persisted as a real user turn.
  static List<Map<String, Object?>> prepareMessages(
      List<Map<String, Object?>> messages) {
    if (messages.any((m) => m['role'] == 'user')) return messages;
    return [
      ...messages,
      const {
        'role': 'user',
        'content': '【内部表达任务；不是真实用户发言】依据前述事实、事件和表达要求生成本次正文。'
            '这条任务封装不代表用户刚刚说话、提问或在线。',
      },
    ];
  }
}
