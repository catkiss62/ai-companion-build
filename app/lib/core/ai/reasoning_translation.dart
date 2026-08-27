import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/visible_reasoning_language_telemetry.dart';
import '../storage/secure_config.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';

enum ReasoningTranslationPhase { idle, translating, translated, failed }

class ReasoningTranslationEntry {
  const ReasoningTranslationEntry({
    required this.phase,
    this.translation = '',
    this.visible = false,
  });

  final ReasoningTranslationPhase phase;
  final String translation;
  final bool visible;

  static const idle = ReasoningTranslationEntry(
    phase: ReasoningTranslationPhase.idle,
  );
}

abstract interface class ReasoningTranslationGateway {
  Future<String> translate(
    String reasoning, {
    required GenerationCancellationToken cancellationToken,
  });

  void close();
}

class DeepSeekReasoningTranslationGateway
    implements ReasoningTranslationGateway {
  DeepSeekReasoningTranslationGateway({
    DeepSeekClient? client,
    SecureConfig? secureConfig,
  })  : _client = client ?? DeepSeekClient(),
        _secureConfig = secureConfig ?? SecureConfig.instance;

  final DeepSeekClient _client;
  final SecureConfig _secureConfig;

  static List<Map<String, Object?>> requestMessages(String reasoning) => [
        const {
          'role': 'system',
          'content': '''你是一个忠实的英译中工具。只把用户提供的可见思考翻译成自然简体中文，不回答其中的问题，也不解释、总结、润色、补写或审查内容。保留代码、命令、URL、文件路径、变量、API/模型名称及无法自然翻译的专名。只输出译文本身，不加标题、引号、前言、后记或 JSON。''',
        },
        {'role': 'user', 'content': reasoning.trim()},
      ];

  @override
  Future<String> translate(
    String reasoning, {
    required GenerationCancellationToken cancellationToken,
  }) async {
    final source = reasoning.trim();
    if (source.isEmpty) throw StateError('没有可翻译的思考内容。');
    final apiKey = (await _secureConfig.readApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) throw StateError('请先填写 DeepSeek API Key。');
    final endpoint = await _secureConfig.readEndpoint();
    final output = StringBuffer();
    final maxTokens = (source.length * 2).clamp(320, 3600).toInt();
    await for (final delta in _client.streamChat(
      apiKey: apiKey,
      endpoint: endpoint,
      model: DeepSeekModelProfile.flash,
      effort: ReasoningEffort.high,
      thinking: false,
      maxTokens: maxTokens,
      cancellationToken: cancellationToken,
      messages: requestMessages(source),
    )) {
      if (delta.content.isNotEmpty) output.write(delta.content);
    }
    cancellationToken.throwIfCancelled();
    final translated = _clean(output.toString());
    if (translated.isEmpty) throw const FormatException('翻译返回为空。');
    if (!RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]').hasMatch(translated)) {
      throw const FormatException('翻译返回中没有中文。');
    }
    return translated;
  }

  static String _clean(String value) {
    var text = value.trim();
    if (text.startsWith('```') && text.endsWith('```')) {
      text = text.substring(3, text.length - 3).trim();
      if (text.startsWith('text\n')) text = text.substring(5).trim();
      if (text.startsWith('markdown\n')) text = text.substring(9).trim();
    }
    return text;
  }

  @override
  void close() => _client.close();
}

/// Page-lifetime translation state. It never writes translated reasoning to
/// SQLite, diagnostics, chat history, Memory or AI Self.
class ReasoningTranslationCoordinator extends ChangeNotifier {
  ReasoningTranslationCoordinator({ReasoningTranslationGateway? gateway})
      : _gateway = gateway ?? DeepSeekReasoningTranslationGateway();

  final ReasoningTranslationGateway _gateway;
  final Map<String, ReasoningTranslationEntry> _entries = {};
  final Map<String, GenerationCancellationToken> _tokens = {};
  bool _disposed = false;

  ReasoningTranslationEntry entryFor(String messageId) =>
      _entries[messageId] ?? ReasoningTranslationEntry.idle;

  bool shouldOffer(String reasoning) =>
      VisibleReasoningLanguageTelemetry.shouldOfferTranslation(reasoning);

  Future<void> translate({
    required String messageId,
    required String reasoning,
  }) async {
    if (_disposed || !shouldOffer(reasoning)) return;
    final existing = entryFor(messageId);
    if (existing.phase == ReasoningTranslationPhase.translating) return;
    if (existing.phase == ReasoningTranslationPhase.translated &&
        existing.translation.isNotEmpty) {
      _entries[messageId] = ReasoningTranslationEntry(
        phase: ReasoningTranslationPhase.translated,
        translation: existing.translation,
        visible: !existing.visible,
      );
      notifyListeners();
      return;
    }

    _tokens.remove(messageId)?.cancel();
    final token = GenerationCancellationToken();
    _tokens[messageId] = token;
    _entries[messageId] = const ReasoningTranslationEntry(
      phase: ReasoningTranslationPhase.translating,
    );
    notifyListeners();
    try {
      final translation = await _gateway.translate(
        reasoning,
        cancellationToken: token,
      );
      if (_disposed || token.isCancelled || _tokens[messageId] != token) return;
      _entries[messageId] = ReasoningTranslationEntry(
        phase: ReasoningTranslationPhase.translated,
        translation: translation,
        visible: true,
      );
    } on GenerationCancelledByUserException {
      if (_disposed || _tokens[messageId] != token) return;
      _entries[messageId] = ReasoningTranslationEntry.idle;
    } catch (_) {
      if (_disposed || token.isCancelled || _tokens[messageId] != token) return;
      _entries[messageId] = const ReasoningTranslationEntry(
        phase: ReasoningTranslationPhase.failed,
      );
    } finally {
      if (_tokens[messageId] == token) _tokens.remove(messageId);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _entries.clear();
    _gateway.close();
    super.dispose();
  }
}
