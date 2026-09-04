import 'dart:convert';

import '../ai/deepseek_client.dart';
import 'agent_tool.dart';
import 'agent_tool_registry.dart';

/// Hybrid tool routing:
/// - unmistakable user commands take a zero-model local fast path;
/// - every other turn is answered by the normal DeepSeek request, which may
///   select one of these native function tools in that same request.
///
/// Local code remains the authority: the model can request a tool, but the
/// registry/risk gate in [AgentToolRunner] decides whether it executes.
class AgentToolPlanner {
  const AgentToolPlanner._();

  static AgentToolPlan? routeLocally(String latestUserText) {
    final text = latestUserText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty || _looksLikeMetaToolTalk(text)) return null;

    final calls = <AgentToolCall>[];

    void add(String toolId, Map<String, String> arguments) {
      if (calls.length >= 2 || calls.any((call) => call.toolId == toolId)) return;
      calls.add(AgentToolCall(
        toolId: toolId,
        arguments: arguments,
        reasonTag: 'explicit_request',
      ));
    }

    final explicitRules = RegExp(
      r'((看|读|查|检查|检索|打开).{0,8}(规则|人设|提示词))|'
      r'((规则|人设|提示词).{0,8}(看|读|查|检查|检索|打开))',
    ).hasMatch(text);
    final explicitMemory = RegExp(
      r'((查|检索|搜索|翻|看看).{0,8}(记忆|记忆库|以前聊过|之前说过))|'
      r'((记忆|记忆库).{0,8}(查|检索|搜索|看看))',
    ).hasMatch(text);
    final explicitAlbum = RegExp(
      r'((记得|回想|找|查|搜索|看看).{0,14}(相册|保存过|保存的|存过|存的|收藏过|收藏的).{0,10}(图片|照片|图像|一张|那张)?)|'
      r'((相册|保存过|保存的|存过|存的|收藏过|收藏的).{0,14}(图片|照片|图像).{0,10}(记得|回想|找|查|看看)?)',
    ).hasMatch(text);
    final explicitScreen = RegExp(
      r'((看一下|看一眼|看一次|看看|查看|观察|识别|截取).{0,10}(当前|现在|此刻)?.{0,8}(屏幕|屏幕内容|屏幕画面|当前画面))|'
      r'((当前|现在|此刻).{0,6}(屏幕|画面).{0,10}(有什么|是什么|写了什么|看得到|看见))',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitDevice = RegExp(
      r'(看看|查看|识别|查).{0,8}(当前|现在)?.{0,8}(手机状态|app|应用|软件|前台)|'
      r'我现在.{0,8}(打开|使用|看).{0,8}(什么|哪个)',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitRecentOutcomes = RegExp(
      r'((最近|刚才|上次|之前).{0,16}(你|自己)?.{0,10}(做了什么|干了什么|工具|行动|执行|搜索|联网|mcp))|'
      r'((工具|行动|搜索|联网|mcp).{0,12}(结果|记录|做了什么|干了什么))',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitSystemFacts = RegExp(
      r'(我.{0,8}(给|帮).{0,8}你.{0,12}(做了|加了|实现了).{0,8}(什么|哪些).{0,6}(功能|能力)?)|'
      r'(你.{0,10}(有什么功能|有哪些功能|会什么|能做什么|系统能力|真实能力))|'
      r'((看|读|查|检查).{0,8}(你自己|自身).{0,8}(系统|能力|功能|状态))|'
      r'(你.{0,6}(能不能|可以).{0,6}(看|读|查).{0,6}(自己|自身).{0,6}(系统|能力|功能))',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitGrowthStatus = RegExp(
      r'((看|读|查|检查).{0,10}(人格学习|人格成长|学习成长|学习系统|成长系统).{0,8}(状态|进度|候选|证据|成熟度|现在)?)|'
      r'((人格学习|人格成长|学习成长|学习系统|成长系统).{0,10}(状态|进度|候选|证据|成熟度).{0,8}(什么|如何|怎样|多少)?)',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitSystemSelf =
        explicitRecentOutcomes || explicitSystemFacts || explicitGrowthStatus;
    final phoneSection = _phoneSection(text);
    final explicitPhone = RegExp(
      r'((查|搜|找|看|读|打开).{0,12}(你的|自己|查)?手机.{0,12}(日记|随笔|心情|愿望|购物车|塔罗|浏览器|相册|内容))|'
      r'((日记|随笔|心情|愿望|购物车|塔罗).{0,12}(查手机|你的手机|自己手机))',
    ).hasMatch(text);
    final phoneSearchRequested = explicitPhone &&
        RegExp(r'(查|搜|找|检索)').hasMatch(text);
    final explicitAttachmentSave = RegExp(
      r'(保存|存下|存进|收藏|收进).{0,10}(这张|这个|图片|照片|附件|相册)|'
      r'(这张|这个|图片|照片|附件).{0,10}(保存|存下|存进|收藏|收进)',
    ).hasMatch(text);
    final explicitWebImageSave = RegExp(r'(上网|联网|网页|网站|搜索|找|搜)')
            .hasMatch(text) &&
        RegExp(r'(图|图片|插画|立绘|风景|照片)').hasMatch(text) &&
        RegExp(r'(保存|存下|存进|收藏|收进)').hasMatch(text);

    final webCommand = RegExp(
      r'(^|[，。！？；])\s*'
      r'(?:请|麻烦|能不能|可以|你|帮我|替我|给我|现在|马上|去|用工具){0,4}\s*'
      r'(?:上网|联网)?\s*(?:帮我|替我|给我|去)?\s*'
      r'(?:搜索|搜一下|搜搜|查一下|查查|检索|找一下|看看)',
      caseSensitive: false,
    ).hasMatch(text);
    final hasWebMarker = RegExp(r'(上网|联网|网页|网站|网址)', caseSensitive: false)
        .hasMatch(text);
    final explicitUrl = RegExp(
      r'(打开|看看|查一下|读一下).{0,12}https?://',
      caseSensitive: false,
    ).hasMatch(text);
    final explicitWeb = explicitUrl ||
        (webCommand &&
            (hasWebMarker ||
                (!explicitRules &&
                    !explicitMemory &&
                    !explicitAlbum &&
                    !explicitScreen &&
                    !explicitDevice &&
                    !explicitSystemSelf &&
                    !explicitPhone &&
                    !explicitAttachmentSave)));

    if (explicitWeb && !explicitWebImageSave) {
      add(
        AgentToolRegistry.publicWebSearch.id,
        {'query': _bounded(_webQuery(text), 80)},
      );
    }
    if (explicitRules) {
      add(
        AgentToolRegistry.rulesRead.id,
        {'scope': _bounded(text, 80)},
      );
    }
    if (explicitMemory) {
      add(
        AgentToolRegistry.memorySearch.id,
        {'query': _bounded(text, 120)},
      );
    }
    if (explicitAlbum &&
        !explicitPhone &&
        !explicitAttachmentSave &&
        !explicitWebImageSave) {
      add(
        AgentToolRegistry.albumSearch.id,
        {'query': _bounded(text, 160)},
      );
    }
    if (explicitScreen) {
      add(AgentToolRegistry.screenObservation.id, const {});
    }
    if (explicitDevice) {
      add(AgentToolRegistry.deviceContextRead.id, const {});
    }
    if (explicitSystemSelf) {
      add(
        AgentToolRegistry.systemSelfRead.id,
        {
          'scope': explicitRecentOutcomes &&
                  !explicitSystemFacts &&
                  !explicitGrowthStatus
              ? 'outcomes'
              : explicitGrowthStatus &&
                      !explicitRecentOutcomes &&
                      !explicitSystemFacts
                  ? 'growth'
              : explicitSystemFacts &&
                      !explicitRecentOutcomes &&
                      !explicitGrowthStatus
                  ? 'facts'
                  : 'all',
        },
      );
    }
    if (explicitPhone) {
      add(
        phoneSearchRequested
            ? AgentToolRegistry.phoneSearch.id
            : AgentToolRegistry.phoneRead.id,
        {
          'section': phoneSection,
          'query': _bounded(text, 160),
        },
      );
    }
    if (explicitAttachmentSave && !explicitWebImageSave) {
      add(AgentToolRegistry.attachmentSave.id, const {});
    }
    if (explicitWebImageSave) {
      add(
        AgentToolRegistry.imageFindAndSave.id,
        {'query': _bounded(_webQuery(text), 80)},
      );
    }
    return calls.isEmpty ? null : AgentToolPlan(calls: calls);
  }

  /// Function definitions are attached to the normal chat request. This adds
  /// only schema input tokens; it does not create a second planner API call.
  static List<Map<String, Object?>> get nativeToolDefinitions =>
      AgentToolRegistry.userTurnExecutable
          .where((tool) => tool.id != AgentToolRegistry.screenObservation.id)
          .map(_nativeDefinition)
          .toList(growable: false);

  /// CHAT_LIGHT returns no tool schema. Task-like turns receive only the small
  /// capability subset relevant to their wording, so companionship does not
  /// inherit planning/reporting pressure from a permanent toolbox prompt.
  static List<Map<String, Object?>> nativeToolDefinitionsFor(String text) {
    final toolIds = _routeToolIds(text);
    if (toolIds.isEmpty) return const <Map<String, Object?>>[];
    return AgentToolRegistry.userTurnExecutable
          .where(
            (tool) =>
                tool.id != AgentToolRegistry.screenObservation.id &&
                toolIds.contains(tool.id),
          )
          .map(_nativeDefinition)
          .toList(growable: false);
  }

  static AgentToolPlan fromNativeToolCalls(List<DeepSeekToolCall> nativeCalls) {
    final calls = <AgentToolCall>[];
    final seen = <String>{};
    for (final native in nativeCalls) {
      if (calls.length >= 2) break;
      final toolId = _toolIdByNativeName[native.name];
      if (toolId == null) continue;
      // Pixel capture requires an unmistakable local user command. A model
      // function selection is never treated as consent.
      if (toolId == AgentToolRegistry.screenObservation.id) continue;
      final definition = AgentToolRegistry.byId(toolId);
      if (definition == null ||
          !definition.executable ||
          !definition.userTurnAvailable ||
          definition.risk != AgentToolRisk.readOnly ||
          !seen.add(toolId)) {
        continue;
      }
      final arguments = <String, String>{};
      try {
        final decoded = jsonDecode(native.arguments);
        if (decoded is Map) {
          for (final entry in decoded.entries.take(6)) {
            final key = _bounded(entry.key.toString().trim(), 40);
            final value = _bounded(entry.value?.toString().trim() ?? '', 500);
            if (key.isNotEmpty && value.isNotEmpty) arguments[key] = value;
          }
        }
      } catch (_) {
        // The executor will return a bounded no-result/blocked response when a
        // required argument is absent. Never repair malformed arguments by guess.
      }
      calls.add(AgentToolCall(
        toolId: toolId,
        arguments: arguments,
        reasonTag: 'model_selected',
      ));
    }
    return AgentToolPlan(calls: calls);
  }

  static String nativeNameForToolId(String toolId) =>
      _nativeNameByToolId[toolId] ?? '';

  static Map<String, Object?> _nativeDefinition(AgentToolDefinition tool) {
    final name = nativeNameForToolId(tool.id);
    final properties = <String, Object?>{};
    final required = <String>[];
    if (tool.id == AgentToolRegistry.publicWebSearch.id) {
      properties['query'] = const <String, Object?>{
        'type': 'string',
        'description': '简短公开检索词，不含密码、验证码、余额、账号或私聊原文。',
      };
      required.add('query');
    } else if (tool.id == AgentToolRegistry.rulesRead.id) {
      properties['scope'] = const <String, Object?>{
        'type': 'string',
        'description': '可选规则编号、标题或范围。',
      };
    } else if (tool.id == AgentToolRegistry.memorySearch.id) {
      properties['query'] = const <String, Object?>{
        'type': 'string',
        'description': '要从本地记忆中查找的话题。',
      };
    } else if (tool.id == AgentToolRegistry.albumSearch.id) {
      properties['query'] = const <String, Object?>{
        'type': 'string',
        'description': '用户对她已保存相册内容的自然语言描述；可模糊、不必是精确标题。',
      };
      required.add('query');
    } else if (tool.id == AgentToolRegistry.systemSelfRead.id) {
      properties['scope'] = const <String, Object?>{
        'type': 'string',
        'enum': <String>['facts', 'outcomes', 'growth', 'all'],
        'description': 'facts=当前能力，outcomes=近期真实工具结果，growth=人格学习观察层的无正文状态元数据，all=全部读取。',
      };
    } else if (tool.id == AgentToolRegistry.phoneSearch.id) {
      properties['query'] = const <String, Object?>{
        'type': 'string',
        'description': '要在查手机已有内容中寻找的关键词；不填写时列出所选栏目最近内容。',
      };
      properties['section'] = _phoneSectionProperty;
    } else if (tool.id == AgentToolRegistry.phoneRead.id) {
      properties['handle'] = const <String, Object?>{
        'type': 'string',
        'description': 'phone.search 返回的精确条目句柄；没有句柄时可改用 section 和 query。',
      };
      properties['section'] = _phoneSectionProperty;
      properties['query'] = const <String, Object?>{
        'type': 'string',
        'description': '没有句柄时用于选取最近匹配条目的关键词。',
      };
    } else if (tool.id == AgentToolRegistry.screenObservation.id) {
      // A screen observation has no model-provided argument. The current user
      // turn itself is the one-time authorization and native privacy Gate.
    }
    final decisionBoundary = switch (tool.id) {
      'public_web.search' =>
        '仅在当前这句话真的要求上网/搜索，或答案明确依赖最新公开事实时调用。'
        '不要因为用户引用、复述、评价“搜索/上网”这个词而调用；否定、假设、闲聊和常识回答不调用。',
      'rules.read' =>
        '仅在用户要你真实读取当前规则、人设或提示词时调用；讨论“规则”这个词本身不调用。',
      'memory.search' =>
        '仅在用户要你查找过去对话/本地记忆，或当前回答确实需要核对长期记忆时调用。',
      'album.search' =>
        '仅在用户询问你已经保存到自己相册里的图片时调用。它只检索已存相册，不负责联网找图、识别新图或保存图片。',
      'device_context.read' =>
        '仅在用户要你查看当前手机/App 状态，或当前回答明确依赖实时设备状态时调用；不得猜测屏幕内容。',
      'system_self.read' =>
        '仅在用户询问你当前真实能力、用户为你实现过什么、人格学习/成长观察层状态、近期真实工具/自主行动结果或 MCP 行动历史时调用。'
        '普通闲聊不调用；本工具不能读取聊天/规则正文、密钥、日志或未实现能力。',
      'phone.search' =>
        '仅在用户要求你查看自己 App 内“查手机”的内容，或回答明确依赖这些内容时调用。只读现有投影，不刷新、不生成、不标记已读。',
      'phone.read' =>
        '仅在用户要求读取一条日记、塔罗、心情、随笔、愿望、购物车、浏览器或相册内容时调用。无精确句柄可用栏目和关键词读取最近匹配项。',
      'screen_observation.inspect' =>
        '仅在用户当前这句话明确要求看一次此刻屏幕像素内容时调用。讨论截图/屏幕能力、询问前台 App 名称、否定/假设或普通闲聊不调用。'
        '每次调用只截一张，经锁屏、密码、敏感包与系统安全窗口 Gate；截图不保存，也绝不自主调用。',
      _ => '',
    };
    return <String, Object?>{
      'type': 'function',
      'function': <String, Object?>{
        'name': name,
        'description': '${tool.description}$decisionBoundary',
        'parameters': <String, Object?>{
          'type': 'object',
          'properties': properties,
          'required': required,
          'additionalProperties': false,
        },
      },
    };
  }

  static bool _looksLikeMetaToolTalk(String text) => RegExp(
        r'(没说|没有说|并没说).{0,12}(搜索|上网|联网)|'
        r'(不需要|不用|不要|别|不必).{0,8}(搜索|上网|联网)|'
        r'(为什么|怎么会|会不会).{0,12}(搜索|上网|联网)|'
        r'(让你.{0,10}(搜索|上网).{0,10}你就)|'
        r'(变聪明了|误触发|这句话|这几个词|引用|复述|例如|比如).{0,20}(搜索|上网|联网)?',
      ).hasMatch(text);

  static String _webQuery(String text) {
    final stripped = text
        .replaceFirst(
          RegExp(
            r'^\s*(?:请|麻烦|能不能|可以|你|帮我|替我|给我|现在|马上|去|用工具){0,4}\s*'
            r'(?:上网|联网)?\s*(?:帮我|替我|给我|去)?\s*'
            r'(?:搜索|搜一下|搜搜|查一下|查查|检索|找一下|看看)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return stripped.isEmpty ? text : stripped;
  }

  static const _nativeNameByToolId = <String, String>{
    'public_web.search': 'public_web_search',
    'rules.read': 'rules_read',
    'memory.search': 'memory_search',
    'album.search': 'album_search',
    'device_context.read': 'device_context_read',
    'system_self.read': 'system_self_read',
    'phone.search': 'phone_search',
    'phone.read': 'phone_read',
    'screen_observation.inspect': 'screen_observation_inspect',
  };
  static const _toolIdByNativeName = <String, String>{
    'public_web_search': 'public_web.search',
    'rules_read': 'rules.read',
    'memory_search': 'memory.search',
    'album_search': 'album.search',
    'device_context_read': 'device_context.read',
    'system_self_read': 'system_self.read',
    'phone_search': 'phone.search',
    'phone_read': 'phone.read',
    'screen_observation_inspect': 'screen_observation.inspect',
  };

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);

  static const Map<String, Object?> _phoneSectionProperty = <String, Object?>{
    'type': 'string',
    'enum': <String>[
      'all',
      'diary',
      'note',
      'mood',
      'wish',
      'cart',
      'tarot',
      'album',
      'browser',
    ],
    'description': '查手机栏目；all 表示全部。',
  };

  static String _phoneSection(String text) {
    if (text.contains('日记')) return 'diary';
    if (text.contains('随笔') || text.contains('便签')) return 'note';
    if (text.contains('心情')) return 'mood';
    if (text.contains('愿望')) return 'wish';
    if (text.contains('购物车')) return 'cart';
    if (text.contains('塔罗')) return 'tarot';
    if (text.contains('相册')) return 'album';
    if (text.contains('浏览器') || text.contains('网页')) return 'browser';
    return 'all';
  }

  static Set<String> _routeToolIds(String rawText) {
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (text.isEmpty) return const <String>{};
    final result = <String>{};
    if (RegExp(r'(最新|新闻|价格|天气|汇率|上网|联网|网页|网站|搜索|查资料)')
        .hasMatch(text)) {
      result.add(AgentToolRegistry.publicWebSearch.id);
    }
    if (RegExp(r'(规则|人设|提示词)').hasMatch(text)) {
      result.add(AgentToolRegistry.rulesRead.id);
    }
    if (RegExp(r'(记忆|以前聊过|之前说过|还记得)').hasMatch(text)) {
      result.add(AgentToolRegistry.memorySearch.id);
    }
    if (RegExp(r'(相册|收藏过|保存过|存过的图)').hasMatch(text)) {
      result.add(AgentToolRegistry.albumSearch.id);
    }
    if (RegExp(r'(手机状态|前台应用|前台app|当前app|锁屏)').hasMatch(text)) {
      result.add(AgentToolRegistry.deviceContextRead.id);
    }
    if (RegExp(r'(你的功能|你的能力|自身系统|人格学习|成长状态|工具结果|行动结果)')
        .hasMatch(text)) {
      result.add(AgentToolRegistry.systemSelfRead.id);
    }
    if (RegExp(
      r'((查|搜|找|看|读|打开|念|告诉我).{0,16}'
      r'(查手机|日记|随笔|心情|愿望|购物车|塔罗|浏览器))|'
      r'((日记|随笔|心情|愿望|购物车|塔罗|浏览器).{0,16}'
      r'(内容|记录|写了|有什么|是哪|是什么|给我看|念))',
    ).hasMatch(text)) {
      result
        ..add(AgentToolRegistry.phoneSearch.id)
        ..add(AgentToolRegistry.phoneRead.id);
    }
    return result.take(3).toSet();
  }
}
