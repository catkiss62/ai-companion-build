import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';

import 'core/ai/deepseek_client.dart';
import 'core/ai/first_channel_model.dart';
import 'core/ai/generation_cancellation.dart';
import 'core/ai/model_profile.dart';
import 'core/database/app_database.dart';
import 'core/storage/secure_config.dart';
import 'integrations/qq_private/qq_private_config.dart';
import 'integrations/qq_private/qq_readonly_context.dart';

Future<void> runQqPrivateBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  const runtime = MethodChannel('ai_companion/qq_private_runtime');
  final db = AppDatabase.instance;
  final secure = SecureConfig.instance;
  QqPrivateSession? session;
  QqGateway? gateway;
  DeepSeekClient? client;
  bool stopped = false;
  Future<void> status(String kind, String code) async {
    try { await runtime.invokeMethod<void>('status', {'kind': kind, 'code': code}); } catch (_) {}
  }
  Future<bool> allowed() async => !stopped &&
    await runtime.invokeMethod<bool>('enabled') == true && await db.brainWorkAllowed();
  runtime.setMethodCallHandler((call) async {
    if (call.method == 'shutdown') {
      stopped = true; session?.stop(); client?.close(); await gateway?.stop();
    }
  });
  try {
    final config = await QqPrivateConfig.read();
    if (config.appId.isEmpty || config.secret.isEmpty || config.namespace.isEmpty) throw StateError('config_missing');
    final support = await getApplicationSupportDirectory();
    final namespace = sha256.convert(utf8.encode('${config.appId}:${config.namespace}')).toString();
    final journal = QqJournal(File('${support.path}/qq_private_v1/$namespace.json'));
    await journal.open();
    final api = QqApi(appId: config.appId, secret: config.secret);
    final modelClient = DeepSeekClient(abortWhen: () async => !await allowed());
    client = modelClient;
    session = QqPrivateSession(journal: journal, owner: config.owner,
      pairCode: config.pairCode, pairExpires: DateTime.fromMillisecondsSinceEpoch(config.pairUntil),
      bindOwner: (owner) => config.paired(owner).save(),
      allowed: allowed, yieldToChat: () async => await db.blockingGenerationJob() != null,
      onStatus: (code) => unawaited(status('task', code)), send: api.send,
      generate: (text, history) async {
        if (!await allowed()) throw StateError('brain_paused');
        final context = await QqReadOnlyContext(db).build(text);
        final provider = await secure.readChatProvider();
        final key = await secure.readFinalReplyApiKey();
        if (key == null || key.isEmpty) throw StateError('chat_key_missing');
        final cancellation = GenerationCancellationToken();
        final reply = StringBuffer();
        String? finish;
        final effort = ReasoningEffort.fromApiName(await db.getSetting(
          provider.isGeminiRelay ? 'reasoning_effort' : 'deepseek_reasoning_effort') ?? 'high');
        final deadline = Timer(const Duration(minutes: 3), cancellation.cancel);
        try {
          await for (final delta in modelClient.streamChat(apiKey: key,
            model: await FirstChannelModel.read(db), effort: effort,
            endpoint: await secure.readFinalReplyEndpoint(), requestProvider: provider,
            modelName: provider.isGeminiRelay ? await secure.readFinalReplyModel() : null,
            maxTokens: 6000, cancellationToken: cancellation,
            requestTimeout: const Duration(minutes: 3), usageLane: 'qq_private_v1',
            messages: [{'role': 'system', 'content': context}, ...history,
              {'role': 'user', 'content': text}])) {
            reply.write(delta.content);
            if (delta.finishReason != null) finish = delta.finishReason;
            if (reply.length > 14000) { cancellation.cancel(); throw StateError('reply_too_long'); }
          }
          if (finish != 'stop' || !await allowed()) throw StateError('reply_incomplete');
          return reply.toString();
        } finally { deadline.cancel(); }
      });
    gateway = QqGateway(api, onMessage: session.accept,
      onStatus: (code) => unawaited(status('connection', code)));
    if (stopped) { await gateway.stop(); return; }
    session.start();
    await gateway.run();
  } catch (_) {
    await status('connection', 'startup_failed');
    try { await runtime.invokeMethod<void>('failed'); } catch (_) {}
  } finally {
    session?.stop(); client?.close(); await gateway?.stop();
  }
}
