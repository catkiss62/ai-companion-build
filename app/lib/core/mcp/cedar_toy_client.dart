import 'dart:convert';

import '../ai/generation_cancellation.dart';
import 'mcp_http_client.dart';

class CedarToyClient {
  CedarToyClient({
    required this.token,
    McpHttpClient? transport,
  }) : transport = transport ??
            McpHttpClient(endpoint: endpointForToken(token));

  static const baseUrl = 'https://toy.cedarstar.org/';
  static final RegExp _tokenPattern = RegExp(r'ctai_v1_[A-Za-z0-9_-]+');
  static final RegExp _wholeTokenPattern =
      RegExp(r'^ctai_v1_[A-Za-z0-9_-]+$');

  final String token;
  final McpHttpClient transport;

  static Uri endpointForToken(String token) {
    final clean = token.trim();
    if (!_wholeTokenPattern.hasMatch(clean)) {
      throw const FormatException('invalid_cedar_toy_token');
    }
    return Uri.parse('$baseUrl$clean');
  }

  Future<McpToolOutcome> listGames({
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'list_games',
        const <String, Object?>{},
        cancellationToken: cancellationToken,
      );

  Future<McpToolOutcome> getGuide(
    String game, {
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'get_guide',
        <String, Object?>{'game': game},
        cancellationToken: cancellationToken,
      );

  Future<McpToolOutcome> play(
    String game,
    String action,
    Map<String, Object?> params, {
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'play',
        <String, Object?>{
          'game': game,
          'action': action,
          'params': params,
        },
        cancellationToken: cancellationToken,
      );

  /// Reads only the live player-facing `play` tool signature. This is an MCP
  /// operating contract, not game source or strategy material. It lets the
  /// model see parameter names that a compact per-game guide may omit.
  Future<String> getPlayerPlayProtocol({
    GenerationCancellationToken? cancellationToken,
  }) async {
    final tools = await transport.listTools(cancellationToken: cancellationToken);
    for (final tool in tools) {
      if (tool.name != 'play') continue;
      return playerSafePlayProtocol(tool);
    }
    return '';
  }

  static String playerSafePlayProtocol(McpToolDescriptor descriptor) {
    if (descriptor.name.trim() != 'play') return '';
    final safe = playerSafeGuide(jsonEncode(<String, Object?>{
      'name': 'play',
      'description': descriptor.description,
      'input_schema': descriptor.inputSchema,
    }));
    const hardLimit = 60 * 1024;
    return safe.length <= hardLimit ? safe : '';
  }

  Future<McpToolOutcome> generateBindingToken({
    GenerationCancellationToken? cancellationToken,
  }) => transport.callTool(
        'account',
        const <String, Object?>{'action': 'generate_binding_token'},
        cancellationToken: cancellationToken,
      );

  static Future<String> loginOrRegister({
    required String username,
    required String password,
    bool loginOnly = false,
    GenerationCancellationToken? cancellationToken,
  }) async {
    final transport = McpHttpClient(endpoint: Uri.parse(baseUrl));
    final outcome = await transport.callTool(
      'account',
      <String, Object?>{
        'action': loginOnly ? 'login' : 'login_or_register',
        'username': username.trim(),
        'password': password,
      },
      cancellationToken: cancellationToken,
    );
    if (outcome.isError) throw const McpHttpException('account_failed');
    final match = _tokenPattern.firstMatch(outcome.text);
    if (match == null) throw const McpHttpException('token_missing');
    return match.group(0)!;
  }

  static String redactSecrets(String raw) {
    var result = raw.replaceAll(_tokenPattern, '[CEDAR_TOKEN]');
    result = result.replaceAllMapped(
      RegExp(
        r'(password\s*[=:]\s*)[^\s,;}&]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    try {
      final decoded = jsonDecode(result);
      result = jsonEncode(_redactJson(decoded));
    } catch (_) {}
    const hardLimit = 1024 * 1024;
    return result.length <= hardLimit
        ? result
        : '${result.substring(0, hardLimit)}…[超过 1 MiB 安全上限]';
  }

  /// Keeps the player-facing MCP protocol while removing pointers to source
  /// repositories, external walkthroughs, and spoiler/answer sections. Cedar
  /// games must be played from the same visible rules and outcomes available
  /// to a normal player; a tool guide is not permission to research its
  /// implementation or a human solution.
  static String playerSafeGuide(String raw) {
    final redacted = redactSecrets(raw);
    try {
      return jsonEncode(_sanitizeGuideJson(jsonDecode(redacted)));
    } catch (_) {
      return _sanitizeGuideText(redacted);
    }
  }

  static String playerSafeGuideOutcome(McpToolOutcome outcome) {
    final parts = <String>[];
    for (final block in outcome.content) {
      if (block.kind != McpContentKind.text &&
          block.kind != McpContentKind.resource &&
          block.kind != McpContentKind.unknown) {
        continue;
      }
      final safe = playerSafeGuide(block.text);
      if (safe.isNotEmpty) parts.add(safe);
    }
    if (outcome.structuredContent != null) {
      parts.add(jsonEncode(_sanitizeGuideJson(outcome.structuredContent)));
    }
    return parts.join('\n').trim();
  }

  static Object? _sanitizeGuideJson(Object? value) {
    if (value is List) {
      return value.map(_sanitizeGuideJson).toList(growable: false);
    }
    if (value is Map) {
      final safe = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_forbiddenGuideField.hasMatch(key)) continue;
        safe[key] = _sanitizeGuideJson(entry.value);
      }
      return safe;
    }
    if (value is String) return _sanitizeGuideText(value);
    return value;
  }

  static String _sanitizeGuideText(String source) {
    final kept = <String>[];
    var droppingSpoilerSection = false;
    for (final original in source.split('\n')) {
      final line = original.trimRight();
      final heading = RegExp(r'^\s{0,3}#{1,6}\s*(.+?)\s*$').firstMatch(line);
      if (heading != null) {
        droppingSpoilerSection = _forbiddenGuideHeading.hasMatch(
          heading.group(1) ?? '',
        );
        if (droppingSpoilerSection) continue;
      }
      if (droppingSpoilerSection) continue;
      if (_externalGuidePointer.hasMatch(line)) continue;
      final withoutLinks = line
          .replaceAll(RegExp(r'https?://[^\s)\]}>]+', caseSensitive: false), '')
          .replaceAll(RegExp(r'github\.com/[^\s)\]}>]+', caseSensitive: false), '')
          .trimRight();
      if (withoutLinks.trim().isEmpty && line.trim().isNotEmpty) continue;
      kept.add(withoutLinks);
    }
    return kept.join('\n').trim();
  }

  static final RegExp _forbiddenGuideField = RegExp(
    r'^(?:repository|repo(?:sitory)?_?url|source_?(?:code|url|repo)|github|'
    r'walkthrough|solution|answer_?key|spoilers?|human_?guide|攻略|解答|标准答案)$',
    caseSensitive: false,
  );

  static final RegExp _forbiddenGuideHeading = RegExp(
    r'^(?:人类)?(?:攻略|通关攻略|解答|标准答案|谜底|剧透)|'
    r'^(?:walkthrough|solutions?|answer\s*key|spoilers?)\b',
    caseSensitive: false,
  );

  static final RegExp _externalGuidePointer = RegExp(
    r'github\.com|gitlab\.com|gitee\.com|'
    r'(?:源码|源代码|仓库|repository|repo|攻略|walkthrough|solution|剧透)'
    r'.{0,80}(?:https?://|网址|链接|参见|详见|见\s)',
    caseSensitive: false,
  );

  static Object? _redactJson(Object? value) {
    if (value is List) return value.map(_redactJson).toList(growable: false);
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString();
        return MapEntry(
          name,
          RegExp(r'(password|token|secret|credential|binding)', caseSensitive: false)
                  .hasMatch(name)
              ? '[REDACTED]'
              : _redactJson(item),
        );
      });
    }
    return value;
  }
}
