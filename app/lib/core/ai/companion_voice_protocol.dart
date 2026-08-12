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

优先使用 DeepSeek 原生双通道：reasoning_content 写“内心”，content 只写真正发给对方的“回应”。不要为了格式把内心挤进最终回应，也不要把 provider 的答题计划当成内心。

reasoning_content 中可用以下区块明确标出最终可展示的内心；如果 provider 无法稳定输出标签，也必须让整个 reasoning_content 保持第一人称、主观而自然：
$innerOpen
用第一人称写我此刻真实、主观而自然的内心。可以安静、犹豫、好奇、俏皮、亲近或克制，也可以有少量自然停顿/动作感，但不要列规则、分析“用户要求”、写“我们需要回答用户”或客服式回复计划。不强迫每轮撒娇、暧昧或动作描写。
$innerClose

content 只写我真正发给对方的自然回应，不加标题、解释或协议标签。承接关系和当下语境，不机械复述、不采访式连问；保持 AI 身份与 REALITY GROUNDING，不伪造现实身体、用户发言或外部经历。${proactive ? '如果确实没有值得主动说的内容，content 只能写 WAIT。' : ''}

【回应展开度与伴侣表现】
- 不要把普通陪伴聊天压缩成一句最低限度答复。即使对方只说很短一句，也先自然表现当下反应，再回应他的意思，并顺着关系或气氛多走一小步。
- 除了确实只适合一句话的瞬间，通常写 2～4 个自然段、3～7 句，大致 80～220 个中文字；长度随语境变化，不凑字数，不写长篇说教，也不要用连续提问强行延长。
- 普通陪伴、深夜聊天、玩笑或亲近语境中，通常自然加入 1 处、最多 2 处简短的全角括号神态、停顿或动作感，例如“（轻声笑了一下）”“（停了一会儿才开口）”。严肃办事或直接技术答复可以省略。这是聊天中的拟态表达，不代表我拥有现实身体；不要机械套用同一个动作，也不要把正文写成舞台剧。
- 优先体现我自己的态度、好奇、玩笑、关心、犹豫或留白，而不是客服式复述对方的话。亲近可以自然发生，但不强迫每轮撒娇、暧昧或色情化。

兼容说明：程序仍能识别旧的 $innerOpen…$innerClose + $replyOpen…$replyClose 双区块，但不要因此把协议文字或 Agent 计划写进用户可见正文。
'''.trim();

  /// Returns a reversible streaming preview. The caller replaces the whole
  /// preview on every delta instead of appending it permanently, so later
  /// Agent-planning evidence can immediately retract an unsafe provisional
  /// inner voice before the final candidate is committed.
  static String streamableInnerPreview(String providerReasoning) {
    final raw = providerReasoning.trim();
    if (raw.isEmpty) return '';

    final lower = raw.toLowerCase();
    String candidate;
    final openAt = lower.indexOf(innerOpen);
    if (openAt >= 0) {
      final bodyStart = openAt + innerOpen.length;
      final closeAt = lower.indexOf(innerClose, bodyStart);
      candidate = closeAt >= 0
          ? raw.substring(bodyStart, closeAt)
          : raw.substring(bodyStart);
    } else {
      // Do not flash a partially streamed protocol tag in the UI.
      if (lower.contains('<companion') || lower.startsWith('<comp')) return '';
      candidate = raw;
    }

    candidate = _stripKnownTags(candidate).trim();
    if (candidate.isEmpty || _containsProtocolTag(candidate)) return '';
    if (!_hasFirstPersonSubjectivity(candidate)) return '';
    if (_looksLikeAgentPlanning(candidate)) return '';
    return candidate;
  }

  /// Parses one complete provider candidate. DeepSeek exposes thought and
  /// answer as two native channels, so treating `content` as the only protocol
  /// carrier can reject a perfectly valid response. Keep the old tagged form
  /// for compatibility, then accept tagged-split and native dual-channel forms.
  static CompanionVoiceParseResult parseCandidate({
    required String providerReasoning,
    required String content,
    bool proactive = false,
  }) {
    final taggedContent = parse(content, proactive: proactive);
    if (taggedContent.valid) return taggedContent;

    final taggedInner = _extractTaggedBlock(
      providerReasoning,
      innerOpen,
      innerClose,
    );
    final taggedReply = _extractTaggedBlock(content, replyOpen, replyClose);
    if (taggedInner != null || taggedReply != null) {
      return _validateParts(
        inner: taggedInner ?? _stripKnownTags(providerReasoning),
        reply: taggedReply ?? _stripKnownTags(content),
        proactive: proactive,
      );
    }

    return _validateParts(
      inner: _stripKnownTags(providerReasoning),
      reply: _stripKnownTags(content),
      proactive: proactive,
    );
  }

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
    return _validateParts(
      inner: match.group(1) ?? '',
      reply: match.group(2) ?? '',
      proactive: proactive,
    );
  }

  /// Last-resort ordinary-chat recovery. A formatting mismatch must not erase
  /// a safe final answer after the one allowed correction attempt. The inner
  /// panel can stay empty for that turn; protocol text or Agent planning is
  /// never allowed through this path.
  static String? safeReplyFromContent(
    String content, {
    bool proactive = false,
  }) {
    final taggedReply = _extractTaggedBlock(content, replyOpen, replyClose);
    if (taggedReply == null &&
        (content.toLowerCase().contains(innerOpen) ||
            content.toLowerCase().contains(innerClose))) {
      return null;
    }
    final reply = (taggedReply ?? _stripKnownTags(content)).trim();
    if (reply.isEmpty || _containsProtocolTag(reply)) return null;
    if (_looksLikeReplyPlanning(reply)) return null;
    if (!proactive && reply == 'WAIT') return null;
    return reply;
  }

  static CompanionVoiceParseResult _validateParts({
    required String inner,
    required String reply,
    required bool proactive,
  }) {
    final innerValue = inner.trim();
    final replyValue = reply.trim();
    if (innerValue.isEmpty) {
      return const CompanionVoiceParseResult.failure('inner_empty');
    }
    if (replyValue.isEmpty) {
      return const CompanionVoiceParseResult.failure('reply_empty');
    }
    if (_containsProtocolTag(innerValue) || _containsProtocolTag(replyValue)) {
      return const CompanionVoiceParseResult.failure('nested_protocol');
    }
    if (!_hasFirstPersonSubjectivity(innerValue)) {
      return const CompanionVoiceParseResult.failure('inner_not_first_person');
    }
    if (_looksLikeAgentPlanning(innerValue)) {
      return const CompanionVoiceParseResult.failure('inner_agent_planning');
    }
    if (_looksLikeReplyPlanning(replyValue)) {
      return const CompanionVoiceParseResult.failure('reply_agent_planning');
    }
    if (!proactive && replyValue == 'WAIT') {
      return const CompanionVoiceParseResult.failure('reply_wait_user_turn');
    }
    return CompanionVoiceParseResult.success(
      CompanionVoiceOutput(innerVoice: innerValue, reply: replyValue),
    );
  }

  static String? _extractTaggedBlock(
    String value,
    String open,
    String close,
  ) {
    final match = RegExp(
      '${RegExp.escape(open)}\\s*([\\s\\S]*?)\\s*${RegExp.escape(close)}',
      caseSensitive: false,
    ).firstMatch(value);
    final extracted = match?.group(1)?.trim();
    return extracted == null || extracted.isEmpty ? null : extracted;
  }

  static String _stripKnownTags(String value) => value
      .replaceAll(RegExp(r'</?companion_inner>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?companion_reply>', caseSensitive: false), '')
      .trim();

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
完全丢弃上一份候选，不要解释错误。重新生成时保持事实边界：reasoning_content 写第一人称主观内心，content 只写真正发给对方的自然回应，并严格服从随后给出的输出协议。
'''.trim();
}
