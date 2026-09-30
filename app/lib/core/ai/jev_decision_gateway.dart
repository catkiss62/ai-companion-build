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
/// caller must run its original DeepSeek classifier: only transport or malformed
/// responses are failures. A valid, uncertain answer remains a Jev decision.
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
  }) async {
    final results = await chooseMany(
      state: state,
      questions: <String, JevChoiceQuestion>{
        'route': JevChoiceQuestion(instruction, options),
      },
      cancellationToken: cancellationToken,
      usageLane: usageLane,
    );
    return results?['route'];
  }

  Future<Map<String, String>?> chooseMany({
    required Object state,
    required Map<String, JevChoiceQuestion> questions,
    GenerationCancellationToken? cancellationToken,
    String usageLane = 'jev_short_route',
  }) async {
    cancellationToken?.throwIfCancelled();
    final started = Stopwatch()..start();
    String key;
    try {
      if (!(await (enabledReader ?? SecureConfig.instance.readJevEnabled)())) {
        await _record(usageLane, 'disabled', started);
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
      await _record(usageLane, 'config_error', started);
      return null;
    }
    final questionTrace = questions.map((key, question) => MapEntry(key,
        <String, Object?>{'instruction': question.instruction,
          'options': question.options}));
    final requestTrace = <String, Object?>{
      'state': state,
      'questions': questionTrace,
    };
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
        await _record(usageLane, 'http_${response.statusCode}', started,
            request: requestTrace);
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        await _record(usageLane, 'invalid_response', started,
            request: requestTrace);
        return null;
      }
      final answers = decoded['answers'];
      if (answers is! Map) {
        await _record(usageLane, 'invalid_answers', started,
            usage: decoded['usage'], request: requestTrace);
        return null;
      }
      final results = <String, String>{};
      final answerTrace = <String, Object?>{};
      var closeDecisions = false;
      for (final entry in questions.entries) {
        final category = switch (entry.key) {
          'mode' => 'mode',
          'interaction' => 'interaction',
          'initiative' => 'initiative',
          'route' when usageLane == 'chat_playful_self' => 'self',
          _ => 'other',
        };
        final answer = answers[entry.key];
        if (answer is! Map || answer['type'] != 'choice') {
          await _record(usageLane, 'invalid_answer_$category', started,
              usage: decoded['usage'], request: requestTrace,
              answers: answerTrace);
          return null;
        }
        final selected = answer['choice'];
        final confidence = answer['confidence'];
        final probabilities = answer['probabilities'];
        if (selected is! String || !entry.value.options.containsKey(selected) ||
            confidence is! num || !confidence.isFinite || confidence < 0 ||
            confidence > 1 ||
            probabilities is! Map || probabilities[selected] is! num ||
            (probabilities[selected] as num) < 0 ||
            (probabilities[selected] as num) > 1) {
          await _record(usageLane, 'invalid_answer_$category', started,
              usage: decoded['usage'], request: requestTrace,
              answers: answerTrace);
          return null;
        }
        final distribution = <String, double>{};
        for (final option in entry.value.options.keys) {
          final value = probabilities[option];
          // Some valid Jev responses report only the chosen probability.
          // Preserve that sparse answer instead of buying a DeepSeek retry;
          // a close-race rule needs at least two reported options.
          if (value == null && !probabilities.containsKey(option)) continue;
          if (value is! num || !value.isFinite || value < 0 || value > 1) {
            await _record(usageLane, 'invalid_answer_$category', started,
                usage: decoded['usage'], request: requestTrace,
                answers: answerTrace);
            return null;
          }
          distribution[option] = value.toDouble();
        }
        final ranked = distribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final close = ranked.length > 1 &&
            ranked[0].value - ranked[1].value <= 0.10 + 1e-9;
        final neutral = switch ((usageLane, entry.key)) {
          ('chat_intimacy_route', 'interaction') ||
          ('immersive_playful_route', 'interaction') => 'ordinary',
          ('chat_intimacy_route', 'initiative') ||
          ('immersive_playful_route', 'initiative') => 'closed',
          ('chat_intimacy_route', 'cedar') => 'chat',
          ('chat_intimacy_route', 'game_attitude') => 'none',
          ('chat_playful_self', 'route') => 'none',
          ('playful_breakthrough', 'route') => 'wait',
          ('cedar_context_intent', 'route') => 'chat',
          _ => null,
        };
        final highest = ranked.first.key;
        final applied = close && neutral != null ? neutral : highest;
        closeDecisions = closeDecisions || close && neutral != null;
        results[entry.key] = applied;
        answerTrace[entry.key] = <String, Object?>{
          'choice': selected,
          'highest_probability_choice': highest,
          'confidence': confidence,
          'probabilities': distribution,
          'probabilities_complete':
              distribution.length == entry.value.options.length,
          'close': close,
          'applied': applied,
        };
      }
      await _record(usageLane,
          closeDecisions ? 'used_neutral_close_probability' : 'used', started,
          usage: decoded['usage'], request: requestTrace, answers: answerTrace);
      return results;
    } on GenerationCancelledByUserException {
      rethrow;
    } catch (_) {
      // Includes invalid key, insufficient balance, timeout and bad JSON.
      // The original DeepSeek path owns the next decision and its error policy.
      await _record(usageLane, 'network_or_decode_error', started,
          request: requestTrace);
      return null;
    } finally {
      client.close();
    }
  }

  /// Locally exported diagnostics preserve the actual questions, state and
  /// answer distribution so the owner can audit semantic quality. Credentials
  /// and HTTP headers are never part of this trace.
  Future<void> _record(String lane, String status, Stopwatch started,
      {Object? usage, Object? request, Object? answers}) async {
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
        if (request != null) 'request': request,
        if (answers != null) 'answers': answers,
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
