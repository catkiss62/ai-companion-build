import '../agent/agent_tool.dart';

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
  static final RegExp _chatArchiveObject = RegExp(
    r'(聊天记录|对话记录|聊天历史|对话历史|咱俩的记录|我们的记录|咱俩的聊天|我们的聊天|以前的聊天|这些天的对话)',
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
  static final RegExp _metaOrNegated = RegExp(
    r'(没(有)?|并没|并未|没有真的|不曾|不能|不该|不会|别|不要|禁止|如果|假如|声称|假装|虚报|误以为|所谓|那句|这句话|你说我|用户说我|用户.{0,4}(问|询问|提问|要求|提到)|用户指出|用户质疑|问题里|纠正|我说过)',
  );

  static OperationalClaimGroundingResult evaluate({
    required String text,
    Iterable<AgentToolResult> currentToolResults = const <AgentToolResult>[],
  }) {
    final successfulResults = currentToolResults
        .where((result) => result.status == AgentToolStatus.succeeded)
        .toList(growable: false);
    final sentences = _sentences(text);
    for (final sentence in sentences) {
      if (_metaOrNegated.hasMatch(sentence)) continue;

      final readClaim = _completedRead.hasMatch(sentence);
      final growthClaim = readClaim && _growthObject.hasMatch(sentence);
      final systemClaim = readClaim && _systemObject.hasMatch(sentence);
      final screenClaim = readClaim && _screenObject.hasMatch(sentence);
      final chatArchiveClaim =
          readClaim && _chatArchiveObject.hasMatch(sentence);
      if (chatArchiveClaim) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_chat_archive_read',
          requiredToolId: 'conversation_archive.read',
        );
      }
      if (growthClaim || systemClaim || screenClaim) {
        final requiredTool = screenClaim
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
                result.promptData.contains('phase=observation_only');
          }
          return true;
        });
        if (!matchingSuccess) {
          return OperationalClaimGroundingResult(
            allowed: false,
            reason: screenClaim
                ? 'ungrounded_screen_observation'
                : 'ungrounded_system_read',
            requiredToolId: requiredTool,
          );
        }
      }

      if (_unsupportedCompletion.hasMatch(sentence)) {
        return const OperationalClaimGroundingResult(
          allowed: false,
          reason: 'ungrounded_unimplemented_operation',
        );
      }
    }
    return const OperationalClaimGroundingResult(allowed: true);
  }

  static List<String> _sentences(String value) => value
      .replaceAll(RegExp(r'<emotion>.*?</emotion>', caseSensitive: false), ' ')
      .split(RegExp(r'(?<=[。！？!?；;，,\n])'))
      .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
