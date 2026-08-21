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
    final explicitDevice = RegExp(
      r'(看看|查看|识别|查).{0,8}(当前|现在)?.{0,8}(手机|屏幕|app|应用|软件|前台)|'
      r'我现在.{0,8}(打开|使用|看).{0,8}(什么|哪个)',
      caseSensitive: false,
    ).hasMatch(text);

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
                (!explicitRules && !explicitMemory && !explicitDevice)));

    if (explicitWeb) {
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
    if (explicitDevice) {
      add(AgentToolRegistry.deviceContextRead.id, const {});
    }
    return calls.isEmpty ? null : AgentToolPlan(calls: calls);
  }

  /// Function definitions are attached to the normal chat request. This adds
  /// only schema input tokens; it does not create a second planner API call.
  static List<Map<String, Object?>> get nativeToolDefinitions =>
      AgentToolRegistry.userTurnExecutable
          .map(_nativeDefinition)
          .toList(growable: false);

  static AgentToolPlan fromNativeToolCalls(List<DeepSeekToolCall> nativeCalls) {
    final calls = <AgentToolCall>[];
    final seen = <String>{};
    for (final native in nativeCalls) {
      if (calls.length >= 2) break;
      final toolId = _toolIdByNativeName[native.name];
      if (toolId == null) continue;
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
    }
    final decisionBoundary = switch (tool.id) {
      'public_web.search' =>
        '仅在当前这句话真的要求上网/搜索，或答案明确依赖最新公开事实时调用。'
        '不要因为用户引用、复述、评价“搜索/上网”这个词而调用；否定、假设、闲聊和常识回答不调用。',
      'rules.read' =>
        '仅在用户要你真实读取当前规则、人设或提示词时调用；讨论“规则”这个词本身不调用。',
      'memory.search' =>
        '仅在用户要你查找过去对话/本地记忆，或当前回答确实需要核对长期记忆时调用。',
      'device_context.read' =>
        '仅在用户要你查看当前手机/App 状态，或当前回答明确依赖实时设备状态时调用；不得猜测屏幕内容。',
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
    'device_context.read': 'device_context_read',
  };
  static const _toolIdByNativeName = <String, String>{
    'public_web_search': 'public_web.search',
    'rules_read': 'rules.read',
    'memory_search': 'memory.search',
    'device_context_read': 'device_context.read',
  };

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);
}
