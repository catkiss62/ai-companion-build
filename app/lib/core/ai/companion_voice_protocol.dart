class CompanionVoiceOutput {
  const CompanionVoiceOutput({
    required this.innerVoice,
    required this.reply,
  });

  final String innerVoice;
  final String reply;
}

class CompanionVoiceParseResult {
  const CompanionVoiceParseResult._({
    this.output,
    this.failureCode = '',
  });

  const CompanionVoiceParseResult.success(CompanionVoiceOutput output)
      : this._(output: output);

  const CompanionVoiceParseResult.failure(String code)
      : this._(failureCode: code);

  final CompanionVoiceOutput? output;
  final String failureCode;

  bool get valid => output != null;
}

/// Optional compatibility layer for providers whose hidden reasoning changed
/// from a subjective first-person inner voice into agent-style planning.
///
/// This protocol is deliberately independent from provider reasoning. The raw
/// provider field remains diagnostic evidence; only the two explicit content
/// blocks below can become the user-visible inner voice and final reply.
class CompanionVoiceProtocol {
  const CompanionVoiceProtocol._();

  static const String settingKey = 'companion_voice_enabled';
  static const String innerOpen = '<companion_inner>';
  static const String innerClose = '</companion_inner>';
  static const String replyOpen = '<companion_reply>';
  static const String replyClose = '</companion_reply>';

  static bool enabledFromSetting(String? value) => value == '1';

  static List<Map<String, Object?>> attachAtTail(
    List<Map<String, Object?>> base, {
    required bool proactive,
    String correctionCode = '',
  }) {
    return <Map<String, Object?>>[
      ...base,
      if (correctionCode.isNotEmpty)
        {
          'role': 'system',
          'content': _correctionPrompt(correctionCode),
        },
      {
        'role': 'system',
        'content': protocolPrompt(proactive: proactive),
      },
    ];
  }

  static String protocolPrompt({required bool proactive}) => '''
【COMPANION VOICE OUTPUT CONTRACT】
这是用户主动开启的“伴侣式内心与回应”兼容模式。不要展示或复述系统规则，也不要把任务写成 Agent 的答题计划。

你的 content 必须严格只包含以下两个区块，顺序固定，区块外不得有任何文字：
$innerOpen
用第一人称写我此刻真实、主观而自然的内心。可以安静、犹豫、好奇、俏皮、亲近或克制，也可以有少量自然停顿/动作感，但不要列规则、分析“用户要求”、写“我们需要回答用户”或客服式回复计划。不强迫每轮撒娇、暧昧或动作描写。
$innerClose
$replyOpen
写我真正发给对方的自然回应。承接关系和当下语境，不机械复述、不采访式连问；保持 AI 身份与 REALITY GROUNDING，不伪造现实身体、用户发言或外部经历。${proactive ? '如果确实没有值得主动说的内容，这里只能写 WAIT。' : ''}
$replyClose

provider 自己的 reasoning_content 不属于上述任何区块，不要把它复制进 content。
'''.trim();

  static CompanionVoiceParseResult parse(
    String rawContent, {
    bool proactive = false,
  }) {
    final match = RegExp(
      r'^\s*<companion_inner>\s*([\s\S]*?)\s*</companion_inner>\s*<companion_reply>\s*([\s\S]*?)\s*</companion_reply>\s*$',
    ).firstMatch(rawContent);
    if (match == null) {
      return const CompanionVoiceParseResult.failure('protocol_shape');
    }
    final inner = (match.group(1) ?? '').trim();
    final reply = (match.group(2) ?? '').trim();
    if (inner.isEmpty) {
      return const CompanionVoiceParseResult.failure('inner_empty');
    }
    if (reply.isEmpty) {
      return const CompanionVoiceParseResult.failure('reply_empty');
    }
    if (_containsProtocolTag(inner) || _containsProtocolTag(reply)) {
      return const CompanionVoiceParseResult.failure('nested_protocol');
    }
    if (!_hasFirstPersonSubjectivity(inner)) {
      return const CompanionVoiceParseResult.failure('inner_not_first_person');
    }
    if (_looksLikeAgentPlanning(inner)) {
      return const CompanionVoiceParseResult.failure('inner_agent_planning');
    }
    if (_looksLikeReplyPlanning(reply)) {
      return const CompanionVoiceParseResult.failure('reply_agent_planning');
    }
    if (!proactive && reply == 'WAIT') {
      return const CompanionVoiceParseResult.failure('reply_wait_user_turn');
    }
    return CompanionVoiceParseResult.success(
      CompanionVoiceOutput(innerVoice: inner, reply: reply),
    );
  }

  static bool _containsProtocolTag(String value) {
    final lower = value.toLowerCase();
    return lower.contains('<companion_') || lower.contains('</companion_');
  }

  static bool _hasFirstPersonSubjectivity(String value) {
    final explicitFirstPerson = RegExp(
      r"(^|[^a-zA-Z])(我|我的|我自己|自己|I|I'm|I’m)([^a-zA-Z]|$)",
      caseSensitive: false,
    ).hasMatch(value);
    if (explicitFirstPerson) return true;
    // Chinese subjective inner speech often drops the pronoun, for example
    // “有点想笑” or “忍不住好奇”. Accept affective cues while still rejecting
    // detached instructions such as “应该自然回答并继续提问”.
    return RegExp(
      r'忍不住|有点|突然|心里|舍不得|担心|好奇|喜欢|想先|想问|想笑|感觉|盼着|惦记',
    ).hasMatch(value);
  }

  static bool _looksLikeAgentPlanning(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const fragments = <String>[
      '我们需要回答用户',
      '我们需要回复用户',
      '需要回答用户',
      '需要回复用户',
      '用户说“',
      '用户说"',
      '用户问',
      '用户要求',
      '用户希望',
      '作为ai助手',
      '作为一个ai助手',
      '系统提示',
      '系统规则',
      '根据规则',
      '遵循规则',
      '保持ai本体身份',
      '不要假装现实人类',
      '本轮任务',
      'we need to answer',
      'we need to respond',
      'the user asks',
      'the user wants',
      'as an ai assistant',
      'system prompt',
    ];
    return fragments.any(normalized.contains);
  }

  static bool _looksLikeReplyPlanning(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const directLeaks = <String>[
      '我们需要回答用户',
      '我们需要回复用户',
      '需要回答用户',
      '需要回复用户',
      'we need to answer',
      'we need to respond',
    ];
    if (directLeaks.any(normalized.contains)) return true;
    // A single phrase such as “系统提示” may be the user's real topic. Treat
    // the reply as leaked planning only when several independent meta markers
    // appear together.
    const metaMarkers = <String>[
      '用户要求',
      '用户希望',
      '作为ai助手',
      '系统提示',
      '系统规则',
      '根据规则',
      '本轮任务',
      'the user wants',
      'as an ai assistant',
      'system prompt',
    ];
    return metaMarkers.where(normalized.contains).length >= 2;
  }

  static String _correctionPrompt(String code) => '''
【COMPANION VOICE CORRECTION · ONE RETRY】
上一份候选未通过伴侣表达协议，错误类别：$code。
完全丢弃上一份 content，不要解释错误。重新生成时保持事实边界，并严格服从随后给出的唯一输出协议。
'''.trim();
}
