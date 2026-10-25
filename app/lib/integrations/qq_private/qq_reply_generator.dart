import 'dart:async';

import '../../core/ai/chat_api_provider.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/generation_cancellation.dart';
import '../../core/ai/model_profile.dart';
import '../../core/storage/secure_config.dart';

/// QQ owns its reply lane. Drafts never leave this adapter: only a complete
/// response is handed to delivery, so retries/fallback cannot duplicate chunks.
class QqReplyGenerator {
  QqReplyGenerator({required this.client, required this.secure,
    required this.current, this.onStatus,
    this.firstTimeout = const Duration(seconds: 90),
    this.secondTimeout = const Duration(seconds: 45)});
  final DeepSeekClient client;
  final SecureConfig secure;
  final Future<bool> Function() current;
  final void Function(String)? onStatus;
  final Duration firstTimeout, secondTimeout;

  Future<String> generate({required String channel, required DeepSeekModelProfile firstModel,
    required ReasoningEffort firstEffort, required ReasoningEffort secondEffort,
    required List<Map<String, Object?>> messages}) async {
    Future<String> attempt(bool second) async {
      if (!await current()) throw StateError('context_invalidated');
      final key = second ? await secure.readAiWangYouApiKey() : await secure.readApiKey();
      if (key == null || key.isEmpty) throw StateError('chat_key_missing');
      final endpoint = second ? await secure.readAiWangYouEndpoint() : await secure.readEndpoint();
      final modelName = second ? await secure.readAiWangYouModel() : null;
      if (!await current()) throw StateError('context_invalidated');
      final cancellation = GenerationCancellationToken();
      // A provider can keep sending reasoning forever without hitting the
      // client's inter-delta timeout. Bound the whole attempt as well, and
      // cancel its transport before allowing the next lane to start.
      final timeout = second ? secondTimeout : firstTimeout;
      final deadline = Timer(timeout, cancellation.cancel);
      final text = StringBuffer();
      String? finish;
      Future<String> collect() async {
        await for (final delta in client.streamChat(apiKey: key, model: firstModel,
          effort: second ? secondEffort : firstEffort, endpoint: endpoint,
          requestProvider: second ? ChatApiProvider.aiWangYouGemini : ChatApiProvider.deepSeek,
          modelName: modelName, messages: messages, maxTokens: 6000,
          cancellationToken: cancellation,
          requestTimeout: timeout, usageLane: 'qq_private_reply')) {
          text.write(delta.content);
          if (delta.finishReason != null) finish = delta.finishReason;
          if (text.length > 14000) throw StateError('reply_too_long');
        }
        if (finish != 'stop' || text.toString().trim().isEmpty) throw StateError('reply_incomplete');
        if (!await current()) throw StateError('context_invalidated');
        return text.toString().trim();
      }
      try { return await cancelWithToken(collect(), cancellation); }
      finally { deadline.cancel(); cancellation.cancel(); }
    }

    if (channel == 'second') {
      for (var retry = 0; retry < 2; retry++) {
        onStatus?.call(retry == 0 ? 'using_second' : 'retrying_second');
        try { return await attempt(true); }
        catch (_) { if (!await current()) rethrow; }
      }
      onStatus?.call('fallback_first');
    } else { onStatus?.call('using_first'); }
    return attempt(false);
  }
}
