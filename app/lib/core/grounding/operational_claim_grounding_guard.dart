import '../agent/agent_tool.dart';
import '../agent/agent_tool_text_envelope.dart';

class OperationalClaimGroundingResult {
  const OperationalClaimGroundingResult({
    required this.allowed,
    this.reason = '',
    this.requiredToolId = '',
  });

  final bool allowed;
  final String reason;
  final String requiredToolId;
}

/// Final outbound backstop for falsifiable reports about tool/system work.
///
/// Subjective inner life remains free-form. This guard only handles narrow,
/// high-confidence claims such as having read the growth system, inspected the
/// current screen, invoked MCP, saved something, or scheduled a real reminder.
/// A matching terminal success in the current turn is required. Long-duration
/// claims are never licensed by these bounded one-shot tools.
class OperationalClaimGroundingGuard {
  const OperationalClaimGroundingGuard._();

  static final RegExp _machineProtocol = RegExp(
    r'<\s*/?\s*(?:(?:｜｜|\|\|)DSML(?:｜｜|\|\|)\s+(?:calls|invoke|parameter)|(?:function_calls?|tool_calls?))\b',
    caseSensitive: false,
  );
  static final RegExp _machineProtocolJson = RegExp(
    r'^\s*[\[{][\s\S]{0,240}"tool_calls"\s*:',
    caseSensitive: false,
  );

  static final RegExp _duration = RegExp(
    r'(一整天|整整一天|一天都|一下午|一上午|大半天|半天|好几个小时|几小时|几个钟头|看了很久|查了很久|研究了很久)',
  );
  static final RegExp _completedRead = RegExp(
    r'(刚刚|刚才|之前|最近|今天|已经|确实|真的|我)?\s*'
    r'(看了|看过|查了|查过|读取了|读了|读过|检查了|检查过|研究了|研究过|钻研了|钻研过|折腾了|捣鼓了|翻了|翻过|翻看了|翻看过|浏览了|浏览过|整理了|梳理了|回顾了|复盘了|观察了|观察过|截了|截取了|识别了)',
  );
  static final RegExp _growthObject = RegExp(
    r'(人格学习|人格成长|学习成长|成长学习|学习系统|成长系统|成长状态|学习候选|成长候选|成熟度|证据计数)',
  );
  static final RegExp _systemObject = RegExp(
    r'(自身系统|自己的系统|系统事实|系统状态|能力状态|功能状态|近期工具结果|近期行动结果)',
  );
  static final RegExp _screenObject = RegExp(
    r'(当前屏幕|现在的屏幕|手机屏幕|屏幕画面|屏幕内容|当前画面|截图)',
  );
  static final RegExp _screenContentClaim = RegExp(
    r'((当前|现在的|手机)?屏幕(上|里|中|画面|内容)?[^，,。！？!?\n]{0,16}'
    r'(显示|写着|停在|停留在|打开着|开着|出现|看得到|有[^，,。！？!?\n]{0,8}'
    r'(按钮|文字|图片|页面|界面|调试页))|'
    r'当前画面[^，,。！？!?\n]{0,12}(是|显示|停在|出现))',
  );
  static final RegExp _chatArchiveObject = RegExp(
    r'(聊天记录|对话记录|聊天历史|对话历史|咱俩的记录|我们的记录|咱俩的聊天|我们的聊天|以前的聊天|这些天的对话)',
  );
  static final RegExp _publicWebJourney = RegExp(
    r'(逛网|逛了.{0,4}(网页|网站)|出去逛.{0,3}(网|网页|网站)|'
    r'在网上.{0,8}(逛|转了一圈|找了找|看了一圈)|'
    r'从(网上|网页|网站).{0,6}(回来|回来了))',
  );
  static final RegExp _unsupportedCompletion = RegExp(
    r'((已经|刚刚|刚才|成功|确实|真的).{0,12}'
    r'(调用|执行|连接).{0,8}MCP)|'
    r'((已经|刚刚|刚才|成功|确实|真的).{0,12}'
    r'(设置|创建|安排).{0,8}(提醒|闹钟|定时))|'
    r'((已经|刚刚|刚才|成功|确实|真的).{0,12}'
    r'(保存|存进|写入|修改|更新).{0,12}(相册|记忆|规则|人设|系统))'
    r'|((我)?(调用|执行|连接).{0,8}MCP.{0,8}(成功|完成|好了|了))'
    r'|((我)?(设置|创建|安排).{0,8}(提醒|闹钟|定时).{0,8}(成功|完成|好了|了))'
    r'|((我)?(保存|存进|写入|修改|更新).{0,12}(相册|记忆|规则|人设|系统).{0,8}(成功|完成|好了|了))',
    caseSensitive: false,
  );
  static final RegExp _stickerSendClaim = RegExp(
    r'((我)?(给你)?(发|发送|甩|丢|扔)(了|来|过去|给你)?.{0,10}(表情包|表情))|'
    r'((表情包|表情).{0,8}(发|发送|甩|丢|扔).{0,6}(了|给你|过去))',
  );
  static final RegExp _imageSendClaim = RegExp(
    r'((我)?(给你)?(发|发送|传|贴|甩|丢|扔)(了|来|过去|给你)?.{0,12}(图片|照片|图))|'
    r'((传|贴)(了)?一张图)|'
    r'((图片|照片|这张图|那张图).{0,10}(发|发送|传|贴|甩|丢|扔|拿给你看).{0,6}(了|给你|过去)?)',
  );
  static final RegExp _cedarPlayClaim = RegExp(
    r'((刚刚|刚才|已经|真的|确实)?(玩了|玩过|开了一局|打了一局|完成了).{0,18}(游戏|一局|关卡))|'
    r'((刚在|刚从).{0,12}(钓鱼|下矿|采矿|旅行|探索|决斗|对弈|种植|花园|游戏))|'
    r'((钓了|甩了|抛了).{0,10}(竿|条|鱼))|'
    r'((下矿|挖矿|采矿|种植|浇水|旅行|探索|决斗|对弈).{0,14}(了|完成|结束|到达|获得|拿到))|'
    r'((赢了|输了|通关了|得了|拿到).{0,12}(分|胜利|奖励|道具|成就))|'
    r'((游戏|这一局|这局).{0,12}(赢了|输了|结束了|通关了|存档了|得分))|'
    r'((我)?(这就|马上|现在就).{0,6}(进去|进房|加入|开局|开始玩|杀进去))',
  );
  static final RegExp _cedarImmediateTimeAnchor = RegExp(
    r'(刚刚|刚才|方才|才刚|刚在)',
  );
  static final RegExp _cedarLiveStateClaim = RegExp(
    r'((正在|还在|一直在|现在在|这会儿在|继续在).{0,12}'
    r'(钓鱼|池塘|钓点|游戏|下矿|矿洞|花园|旅行|对弈))|'
    r'((又)?(坐回|回到|蹲在|坐在|趴在|待在).{0,10}'
    r'(池塘边|水边|钓点|矿洞|花园))|'
    r'((鱼漂|浮标|漂).{0,18}(没动|不动|没动静|沉了|有动静|等待))|'
    r'((盯(?:着)?|看(?:着)?|守(?:着)?|挂(?:着)?|等(?:着)?|等待).{0,10}(鱼漂|浮标))|'
    r'((钓鱼|甩出去).{0,16}(挂着|等鱼|等咬钩))|'
    r'((鱼竿).{0,20}(插稳|架着|挂着|甩|抛))|'
    r'((饵盒|鱼饵).{0,14}(拖到|补齐|补满))|'
    r'(图鉴.{0,14}(没动|没往上|还是那几条|点一点))|'
    r'((换了|换着).{0,8}方向.{0,8}(甩|抛))',
  );
  static final RegExp _cedarHistoricalAnchor = RegExp(
    r'(之前|上次|以前|那次|当时|前面玩的时候|昨天|昨晚|前天)',
  );
  static final RegExp _cedarNonExecutionFraming = RegExp(
    r'((还|其实|实际|根本)?没(有)?(真的|实际)?(去|开始|执行|操作)'
    r'.{0,6}(玩|钓鱼|下矿|进游戏))|'
    r'((尚未|并未|不曾).{0,8}(开始|执行|操作|玩|钓鱼|下矿))|'
    r'((想|打算|准备|计划|等会儿|待会儿|下次|以后).{0,12}'
    r'(玩|钓鱼|下矿|进游戏))',
  );
  static final RegExp _selfMoveCoordinateClaim = RegExp(
    r'(?:我|这手|刚才|刚刚|已经|直接|那就)[^。！？!?\n]{0,20}'
    r'(?:下|落|走)[^。！？!?\n]{0,10}[\(（]\s*(\d{1,3})\s*[,，]\s*(\d{1,3})\s*[\)）]',
  );
  static final RegExp _metaOrNegated = RegExp(
    r'(没(有)?|并没|并未|没有真的|不曾|不能|不该|不会|别|不要|禁止|'
    r'想去|想要去|正想|打算|准备|想象|幻想|以后|下次|如果|假如|'
    r'声称|假装|虚报|误以为|所谓|那句|这句话|你说我|用户说我|'
    r'用户.{0,4}(问|询问|提问|要求|提到)|用户指出|用户质疑|问题里|纠正|我说过)',
  );

  static OperationalClaimGroundingResult evaluate({
    required String text,
    Iterable<AgentToolResult> currentToolResults = const <AgentToolResult>[],
    bool publicWebOutcomeAvailable = false,
    bool cedarOutcomeAvailable = false,
    DateTime? cedarOutcomeAt,
    DateTime? now,
  }) {
    if (_machineProtocol.hasMatch(text) ||
        _machineProtocolJson.hasMatch(text) ||
        AgentToolTextEnvelope.looksLikeMachinePayload(text)) {
      return const OperationalClaimGroundingResult(
        allowed: false,
        reason: 'machine_protocol_leak',
      );
    }
    final successfulResults = currentToolResults
        .where((result) => result.status == AgentToolStatus.succeeded)
        .toList(growable: false);
    final submittedMoves = <String>{};
    for (final result in successfulResults) {
      if (result.toolId != 'cedar_toy.play') continue;
      final submitted = result.submittedArguments;
      if (submitted['action']?.toString() != 'move') continue;
      final params = submitted['params'];
      if (params is! Map || params['move'] is! Map) continue;
      final move = params['move'] as Map;
      final row = move['row'];
      final col = move['col'];
      if (row is num && col is num) {
        submittedMoves.add('${row.toInt()},${col.toInt()}');
      }
    }
    if (submittedMoves.isNotEmpty) {
      for (final claim in _selfMoveCoordinateClaim.allMatches(text)) {
        final claimed = '${claim.group(1)},${claim.group(2)}';
        if (!submittedMoves.contains(claimed)) {
          return const OperationalClaimGroundingResult(
            allowed: false,
            reason: 'cedar_action_argument_mismatch',
            requiredToolId: 'cedar_toy.play',
          );
        }
      }
    }
    final hasPublicWebOutcome = publicWebOutcomeAvailable ||
        successfulResults.any(
          (result) => result.toolId == 'public_web.discover' ||
              result.toolId == 'image.find_and_save' ||
              result.toolId == 'image.web_send',
        );
    final hasCurrentCedarOutcome = successfulResults.any(
      (result) => result.toolId == 'cedar_toy.play',
    );
    final cedarEvidenceIsRecent = hasCurrentCedarOutcome ||
        (cedarOutcomeAt != null &&
            !(now ?? DateTime.now()).isBefore(cedarOutcomeAt) &&
            (now ?? DateTime.now()).difference(cedarOutcomeAt) <=
                const Duration(hours: 1));
    // Keep comma-linked time anchors with their game claim. The broader
    // operational splitter intentionally cuts on commas, but “上次钓鱼时，鱼漂
    // 没动” must remain one historical clause rather than turning the second
    // half into a false current-state violation.
    for (final clause in _gameStateClauses(text)) {
      // A remembered game plan or a role-play scene is not evidence that a
      // Cedar action is still running. Fishing `cast` resolves atomically;
      // there is no background float whose silence can be reported later.
      if (_cedarLiveStateClaim.hasMatch(clause) &&
          !_cedarHistoricalAnchor.hasMatch(clause) &&
          !_cedarNonExecutionFraming.hasMatch(clause) &&
          !cedarEvidenceIsRecent) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_cedar_live_state',
          requiredToolId: 'cedar_toy.play',
        );
      }
    }
    final sentences = _sentences(text);
    for (final sentence in sentences) {
      if (_metaOrNegated.hasMatch(sentence)) continue;

      if (_publicWebJourney.hasMatch(sentence) &&
          !hasPublicWebOutcome) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_public_web_journey',
          requiredToolId: 'public_web.discover',
        );
      }

      if (_stickerSendClaim.hasMatch(sentence) &&
          !successfulResults.any((result) => result.toolId == 'sticker.send')) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_sticker_send',
          requiredToolId: 'sticker.send',
        );
      }

      if (_imageSendClaim.hasMatch(sentence) &&
          !successfulResults.any((result) =>
              result.toolId == 'image.web_send' ||
              result.toolId == 'album.image_send')) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_image_send',
          requiredToolId: 'image.web_send',
        );
      }

      final cedarPlayClaim = _cedarPlayClaim.hasMatch(sentence);
      if (cedarPlayClaim &&
          _cedarImmediateTimeAnchor.hasMatch(sentence) &&
          !cedarEvidenceIsRecent) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'stale_cedar_event_presented_as_recent',
          requiredToolId: 'cedar_toy.play',
        );
      }
      if (cedarPlayClaim &&
          !cedarOutcomeAvailable &&
          cedarOutcomeAt == null &&
          !hasCurrentCedarOutcome) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_cedar_toy_play',
          requiredToolId: 'cedar_toy.play',
        );
      }

      final readClaim = _completedRead.hasMatch(sentence);
      final growthClaim = readClaim && _growthObject.hasMatch(sentence);
      final systemClaim = readClaim && _systemObject.hasMatch(sentence);
      final screenClaim = readClaim && _screenObject.hasMatch(sentence);
      final screenContentClaim = _screenContentClaim.hasMatch(sentence);
      final chatArchiveClaim =
          readClaim && _chatArchiveObject.hasMatch(sentence);
      if (chatArchiveClaim) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_chat_archive_read',
          requiredToolId: 'conversation_archive.read',
        );
      }
      if (growthClaim || systemClaim || screenClaim || screenContentClaim) {
        final requiredTool = screenClaim || screenContentClaim
            ? 'screen_observation.inspect'
            : 'system_self.read';
        if (_duration.hasMatch(sentence)) {
          return OperationalClaimGroundingResult(
            allowed: false,
            reason: 'unsupported_operation_duration',
            requiredToolId: requiredTool,
          );
        }
        final matchingSuccess = successfulResults.any((result) {
          if (result.toolId != requiredTool) return false;
          if (growthClaim) {
            return result.promptData.contains('PERSONALITY LEARNING STATUS') &&
                (result.promptData.contains('phase=observation_only') ||
                    result.promptData
                        .contains('phase=phase2b_bounded_bias'));
          }
          return true;
        });
        if (!matchingSuccess) {
          return OperationalClaimGroundingResult(
            allowed: false,
            reason: screenClaim || screenContentClaim
                ? 'ungrounded_screen_observation'
                : 'ungrounded_system_read',
            requiredToolId: requiredTool,
          );
        }
      }

      if (_unsupportedCompletion.hasMatch(sentence)) {
        final supportedAlbumSave = RegExp(r'(保存|存进|写入|收进).{0,12}(相册|收藏)')
                .hasMatch(sentence) &&
            successfulResults.any(
              (result) => result.toolId == 'attachment.save' ||
                  result.toolId == 'image.find_and_save',
            );
        if (supportedAlbumSave) continue;
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_unimplemented_operation',
        );
      }
    }
    return const OperationalClaimGroundingResult(allowed: true);
  }

  /// Drops only sentences that make an unsupported externally-verifiable
  /// claim. It is deliberately a last-resort salvage path: a style mistake,
  /// pronoun slip or unwanted question must never erase an otherwise valid
  /// turn.
  static String removeUnsupportedSentences({
    required String text,
    Iterable<AgentToolResult> currentToolResults = const <AgentToolResult>[],
    bool publicWebOutcomeAvailable = false,
    bool cedarOutcomeAvailable = false,
    DateTime? cedarOutcomeAt,
    DateTime? now,
  }) {
    return _sentences(text)
        .where(
          (sentence) => evaluate(
            text: sentence,
            currentToolResults: currentToolResults,
            publicWebOutcomeAvailable: publicWebOutcomeAvailable,
            cedarOutcomeAvailable: cedarOutcomeAvailable,
            cedarOutcomeAt: cedarOutcomeAt,
            now: now,
          ).allowed,
        )
        .join('\n')
        .trim();
  }

  static List<String> _sentences(String value) => value
      .replaceAll(RegExp(r'<emotion>.*?</emotion>', caseSensitive: false), ' ')
      .split(RegExp(r'(?<=[。！？!?；;，,\n])'))
      .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  static List<String> _gameStateClauses(String value) => value
      .replaceAll(RegExp(r'<emotion>.*?</emotion>', caseSensitive: false), ' ')
      .split(RegExp(r'(?<=[。！？!?；;\n])'))
      .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
