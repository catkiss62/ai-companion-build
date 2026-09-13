import 'dart:convert';

import '../ai/deepseek_client.dart';

class AgentToolTextEnvelopeResult {
  const AgentToolTextEnvelopeResult({
    required this.detected,
    required this.valid,
    this.calls = const <DeepSeekToolCall>[],
  });

  final bool detected;
  final bool valid;
  final List<DeepSeekToolCall> calls;
}

/// Compatibility parser and outbound firewall for providers that occasionally
/// serialize a function call into DSML text instead of OpenAI `tool_calls`.
///
/// Parsed calls are never executed here. They still pass through the ordinary
/// Agent registry, user-intent, schema, budget and executor gates.
class AgentToolTextEnvelope {
  const AgentToolTextEnvelope._();

  static const String _prefix = r'(?:｜｜|\|\|)DSML(?:｜｜|\|\|)';

  static final RegExp _protocolMarker = RegExp(
    '(<\\s*$_prefix\\s+(?:calls|invoke|parameter)\\b|'
    r'<\s*(?:function_calls?|tool_calls?)\b|'
    r'"tool_calls"\s*:)',
    caseSensitive: false,
  );

  static final RegExp _outerOpen = RegExp(
    '<\\s*$_prefix\\s+calls\\s*>',
    caseSensitive: false,
  );
  static final RegExp _outerClose = RegExp(
    '<\\s*/\\s*$_prefix\\s+calls\\s*>',
    caseSensitive: false,
  );
  static final RegExp _invoke = RegExp(
    '<\\s*$_prefix\\s+invoke\\s+name="([A-Za-z0-9_.:-]{1,120})"\\s*>'
    r'([\s\S]*?)'
    '<\\s*/\\s*$_prefix\\s+invoke\\s*>',
    caseSensitive: false,
  );
  static final RegExp _parameter = RegExp(
    '<\\s*$_prefix\\s+parameter\\s+name="([A-Za-z0-9_.:-]{1,120})"'
    '(?:\\s+string="(true|false)")?\\s*>'
    r'([\s\S]*?)'
    '<\\s*/\\s*$_prefix\\s+parameter\\s*>',
    caseSensitive: false,
  );

  static bool containsProtocol(String raw) => _protocolMarker.hasMatch(raw);

  /// Holds a possible machine envelope out of streaming UI/TTS until enough
  /// text has arrived to prove that it is ordinary assistant prose.
  static bool shouldHoldFromVisibleStream(String raw) {
    final clean = raw.trimLeft();
    if (clean.isEmpty) return false;
    const markers = <String>[
      '<｜｜DSML｜｜',
      '<||DSML||',
      '<function_call',
      '<function_calls',
      '<tool_call',
      '<tool_calls',
    ];
    final lower = clean.toLowerCase();
    return containsProtocol(clean) || markers.any((marker) {
      final candidate = marker.toLowerCase();
      return candidate.startsWith(lower) || lower.startsWith(candidate);
    });
  }

  static AgentToolTextEnvelopeResult parse(String raw) {
    if (!containsProtocol(raw)) {
      return const AgentToolTextEnvelopeResult(
        detected: false,
        valid: false,
      );
    }
    if (!_outerOpen.hasMatch(raw) || !_outerClose.hasMatch(raw)) {
      return const AgentToolTextEnvelopeResult(detected: true, valid: false);
    }

    final calls = <DeepSeekToolCall>[];
    var invokeIndex = 0;
    for (final match in _invoke.allMatches(raw)) {
      final name = match.group(1)?.trim() ?? '';
      final body = match.group(2) ?? '';
      if (name.isEmpty) {
        return const AgentToolTextEnvelopeResult(detected: true, valid: false);
      }
      final arguments = <String, Object?>{};
      for (final parameter in _parameter.allMatches(body)) {
        final key = parameter.group(1)?.trim() ?? '';
        if (key.isEmpty || arguments.containsKey(key)) {
          return const AgentToolTextEnvelopeResult(detected: true, valid: false);
        }
        final forceString = parameter.group(2)?.toLowerCase() == 'true';
        final value = (parameter.group(3) ?? '').trim();
        arguments[key] = forceString ? value : _typedValue(value);
      }
      final bodyRemainder = body.replaceAll(_parameter, '').trim();
      if (arguments.isEmpty || bodyRemainder.isNotEmpty) {
        return const AgentToolTextEnvelopeResult(detected: true, valid: false);
      }
      calls.add(DeepSeekToolCall(
        id: 'dsml-compat-$invokeIndex',
        name: name,
        arguments: jsonEncode(arguments),
      ));
      invokeIndex++;
    }

    final remainder = raw
        .replaceAll(_invoke, '')
        .replaceAll(_outerOpen, '')
        .replaceAll(_outerClose, '')
        .trim();
    if (calls.isEmpty || remainder.isNotEmpty) {
      return const AgentToolTextEnvelopeResult(detected: true, valid: false);
    }
    return AgentToolTextEnvelopeResult(
      detected: true,
      valid: true,
      calls: calls,
    );
  }

  static Object? _typedValue(String raw) {
    if (raw.isEmpty) return '';
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}
