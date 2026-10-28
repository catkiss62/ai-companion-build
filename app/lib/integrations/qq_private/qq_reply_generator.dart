import 'dart:async';

import '../../core/ai/chat_api_provider.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/generation_cancellation.dart';
import '../../core/ai/model_profile.dart';
import '../../core/ai/final_reply_route.dart';
import '../../core/storage/secure_config.dart';
import 'qq_failure.dart';

/// QQ owns its reply lane. Drafts never leave this adapter: only a complete
/// response is handed to delivery, so retries/fallback cannot duplicate chunks.
class QqReplyGenerator {
  QqReplyGenerator({required this.client, required this.secure,
    required this.current, this.onStatus, this.onFailure,
    this.firstTimeout = const Duration(seconds: 90),
    this.secondTimeout = const Duration(seconds: 45)});
  final DeepSeekClient client;
  final SecureConfig secure;
  final Future<bool> Function() current;
  final void Function(String)? onStatus;
  final Future<void> Function(String phase,Object error,int attempt)? onFailure;
  final Duration firstTimeout, secondTimeout;

  Future<String> generate({required String channel, required DeepSeekModelProfile firstModel,
    required ReasoningEffort firstEffort, required ReasoningEffort secondEffort,
    required List<Map<String, Object?>> messages,String usageLane='qq_private_reply'}) async {
    final route = FinalReplyRoute(secondChannelEnabled: channel == 'second');
    final third = await client.tryThirdChannel(messages: messages, route: route, secure: secure,
      maxTokens: 6000, current: current, effort: secondEffort.apiName, usageLane: usageLane);
    if (third != null) {
      if (!await current()) throw StateError('context_invalidated');
      // QQ has no partial-draft display. Never send a truncated public reply
      // or turn a content-filter terminal into the same prompt on another lane.
      if (third.incomplete) throw const QqOperationFailure('reply_incomplete');
      onStatus?.call('using_third');
      return third.content.trim();
    }
    if (route.thirdChannelFailure != null) await onFailure?.call('third_reply', route.thirdChannelFailure!, 1);
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
      var expired=false;
      final deadline = Timer(timeout, (){expired=true;cancellation.cancel();});
      final text = StringBuffer();
      String? finish;
      Future<String> collect() async {
        await for (final delta in client.streamChat(apiKey: key, model: firstModel,
          effort: second ? secondEffort : firstEffort, endpoint: endpoint,
          requestProvider: second ? ChatApiProvider.aiWangYouGemini : ChatApiProvider.deepSeek,
          modelName: modelName, messages: messages, maxTokens: 6000,
          cancellationToken: cancellation,
          requestTimeout: timeout, usageLane: usageLane)) {
          text.write(delta.content);
          if (delta.finishReason != null) finish = delta.finishReason;
          if (text.length > 14000) throw StateError('reply_too_long');
          // An explicit finish ends the reply even if a relay keeps its SSE
          // connection open. Do not discard/retry already completed text.
          if (finish != null) break;
        }
        if (finish != 'stop' || text.toString().trim().isEmpty) throw StateError('reply_incomplete');
        if (!await current()) throw StateError('context_invalidated');
        return text.toString().trim();
      }
      try { return await cancelWithToken(collect(), cancellation); }
      catch(error) {if(expired)throw const QqOperationFailure('reply_timeout');rethrow;}
      finally { deadline.cancel(); cancellation.cancel(); }
    }

    if (channel == 'second') {
      for (var retry = 0; retry < 2; retry++) {
        onStatus?.call(retry == 0 ? 'using_second' : 'retrying_second');
        try { return await attempt(true); }
        catch (error) {await onFailure?.call('second_reply',error,retry+1);if (!await current()) rethrow;}
      }
      onStatus?.call('fallback_first');
    } else { onStatus?.call('using_first'); }
    try {return await attempt(false);}
    catch(error) {await onFailure?.call('first_reply',error,1);rethrow;}
  }
}
