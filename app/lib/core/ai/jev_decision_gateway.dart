import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../storage/secure_config.dart';
import 'generation_cancellation.dart';

/// The single OpenRouter transport for short, closed-set decisions.
///
/// This is NOT a chat/completions model. A caller sends one small state and
/// independent typed questions to /api/alpha/decisions. Null means that the
/// caller must run its original DeepSeek classifier. Never turn a missing key,
/// an HTTP failure, an incomplete answer or uncertainty into a guessed route.
class JevDecisionGateway {
  const JevDecisionGateway({
    this.clientFactory = http.Client.new,
    this.enabledReader,
    this.keyReader,
  });

  static const instance = JevDecisionGateway();
  static const model = 'typesafe/jev-1.13';
  static const endpoint = 'https://openrouter.ai/api/alpha/decisions';

  final http.Client Function() clientFactory;
  final Future<bool> Function()? enabledReader;
  final Future<String?> Function()? keyReader;

  Future<String?> choose({
    required Object state,
    required String instruction,
    required Map<String, String> options,
    GenerationCancellationToken? cancellationToken,
    String usageLane = 'jev_short_route',
    // The starting floor is intentionally local to the routing use cases;
    // adjust it only after comparing real turns with the DeepSeek baseline.
    double confidenceFloor = 0.55,
  }) async {
    final results = await chooseMany(
      state: state,
      questions: <String, JevChoiceQuestion>{
        'route': JevChoiceQuestion(instruction, options),
      },
      cancellationToken: cancellationToken,
      confidenceFloor: confidenceFloor,
      usageLane: usageLane,
    );
    return results?['route'];
  }

  Future<Map<String, String>?> chooseMany({
    required Object state,
    required Map<String, JevChoiceQuestion> questions,
    GenerationCancellationToken? cancellationToken,
    double confidenceFloor = 0.55,
    String usageLane = 'jev_short_route',
  }) async {
    cancellationToken?.throwIfCancelled();
    final started = Stopwatch()..start();
    String key;
    try {
      if (!(await (enabledReader ?? SecureConfig.instance.readJevEnabled)())) {
        return null;
      }
      key = (await (keyReader ?? SecureConfig.instance.readOpenRouterApiKey)())
              ?.trim() ??
          '';
      if (key.isEmpty || questions.isEmpty) {
        await _record(usageLane, 'missing_key', started);
        return null;
      }
    } catch (_) {
      return null;
    }
    final client = clientFactory();
    try {
      final response = await cancelWithToken(
        client
            .post(
              Uri.parse(endpoint),
              headers: <String, String>{
                'Authorization': 'Bearer $key',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, Object?>{
                'model': model,
                'state': state,
                'questions': questions.map((name, question) => MapEntry(
                  name,
                  <String, Object?>{
                    'type': 'choice',
                    'instructions': question.instruction,
                    'criteria': question.options,
                  },
                )),
              }),
            )
            .timeout(const Duration(seconds: 8)),
        cancellationToken,
      );
      cancellationToken?.throwIfCancelled();
      if (response.statusCode != 200) {
        await _record(usageLane, 'http_${response.statusCode}', started);
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        await _record(usageLane, 'invalid_response', started);
        return null;
      }
      final answers = decoded['answers'];
      if (answers is! Map) {
        await _record(usageLane, 'invalid_answers', started,
            usage: decoded['usage']);
        return null;
      }
      final results = <String, String>{};
      for (final entry in questions.entries) {
        final answer = answers[entry.key];
        if (answer is! Map || answer['type'] != 'choice') {
          await _record(usageLane, 'invalid_answers', started,
              usage: decoded['usage']);
          return null;
        }
        final selected = answer['choice'];
        final confidence = answer['confidence'];
        final probabilities = answer['probabilities'];
        if (selected is! String || !entry.value.options.containsKey(selected) ||
            confidence is! num || !confidence.isFinite ||
            confidence < confidenceFloor || confidence > 1 ||
            probabilities is! Map || probabilities[selected] is! num ||
            (probabilities[selected] as num) < 0 ||
            (probabilities[selected] as num) > 1) {
          await _record(usageLane, 'low_confidence_or_invalid', started,
              usage: decoded['usage']);
          return null;
        }
        results[entry.key] = selected;
      }
      await _record(usageLane, 'used', started, usage: decoded['usage']);
      return results;
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // Includes invalid key, insufficient balance, timeout and bad JSON.
      // The original DeepSeek path owns the next decision and its error policy.
      await _record(usageLane, 'network_or_decode_error', started);
      return null;
    } finally {
      client.close();
    }
  }

  /// Diagnostics contain only billed cost, token counts and route status, never state,
  /// answers, credentials, game data or user text.
  Future<void> _record(String lane, String status, Stopwatch started,
      {Object? usage}) async {
    try {
      final db = AppDatabase.instance;
      final raw = await db.getSetting('jev_short_usage_v1') ?? '';
      final events = <Object?>[];
      if (raw.isNotEmpty) {
        try {
          final previous = jsonDecode(raw);
          if (previous is List) events.addAll(previous.whereType<Map>());
        } catch (_) {}
      }
      final counts = usage is Map ? usage : const <String, Object?>{};
      events.add(<String, Object?>{
        'lane': lane,
        'status': status,
        'input_tokens': (counts['input_tokens'] as num?)?.toInt() ?? 0,
        'output_tokens': (counts['output_tokens'] as num?)?.toInt() ?? 0,
        'cost_usd': (counts['cost'] as num?)?.toDouble() ?? 0,
        'elapsed_ms': started.elapsedMilliseconds,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.setSetting('jev_short_usage_v1', jsonEncode(
          events.length > 120 ? events.sublist(events.length - 120) : events));
    } catch (_) {
      // Accounting must not affect the decision or its DeepSeek fallback.
    }
  }
}

class JevChoiceQuestion {
  const JevChoiceQuestion(this.instruction, this.options);
  final String instruction;
  final Map<String, String> options;
}
