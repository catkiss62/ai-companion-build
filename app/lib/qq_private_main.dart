import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';

import 'core/ai/deepseek_client.dart';
import 'core/ai/model_profile.dart';
import 'core/storage/secure_config.dart';
import 'integrations/qq_private/qq_private_config.dart';
import 'integrations/qq_private/qq_readonly_context.dart';
import 'integrations/qq_private/qq_reply_generator.dart';

Future<void> runQqPrivateBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  const runtime = MethodChannel('ai_companion/qq_private_runtime');
  final secure = SecureConfig.instance;
  QqPrivateSession? session;
  QqGateway? gateway;
  DeepSeekClient? client;
  Future<bool> Function()? activeReplyGuard;
  Object? replyStamp;
  bool stopped = false;
  Future<void> status(String kind, String code) async {
    try { await runtime.invokeMethod<void>('status', {'kind': kind, 'code': code}); } catch (_) {}
  }
  Future<bool> allowed() async => !stopped &&
    await runtime.invokeMethod<bool>('enabled') == true &&
    await QqReadOnlyContext.readMain((context) => context.allowed());
  runtime.setMethodCallHandler((call) async {
    if (call.method == 'shutdown') {
      stopped = true;
      final stoppedSession = session?.stop();
      client?.close(); await gateway?.stop(); await stoppedSession;
    }
  });
  try {
    final config = await QqPrivateConfig.read();
    if (config.appId.isEmpty || config.secret.isEmpty || config.namespace.isEmpty) throw StateError('config_missing');
    Future<String?> contextIdentity() async {
      final current = await QqPrivateConfig.read();
      final owner = session?.owner ?? config.owner;
      if (current.namespace != config.namespace || current.appId != config.appId ||
          current.secret != config.secret || current.owner != owner) return null;
      final identity = await QqReadOnlyContext.readMain((context) async =>
        jsonEncode([await context.identity(config.namespace, owner), current.replyChannel]));
      final after = await QqPrivateConfig.read();
      return after.namespace == current.namespace && after.owner == owner &&
        after.appId == current.appId && after.secret == current.secret &&
        after.replyChannel == current.replyChannel ? identity : null;
    }
    final support = await getApplicationSupportDirectory();
    final namespace = sha256.convert(utf8.encode('${config.appId}:${config.namespace}')).toString();
    final journal = QqJournal(File('${support.path}/qq_private_v1/$namespace.json'));
    await journal.open();
    final api = QqApi(appId: config.appId, secret: config.secret);
    final modelClient = DeepSeekClient(abortWhen: () async => !await allowed() ||
      activeReplyGuard != null && !await activeReplyGuard!());
    client = modelClient;
    final generator = QqReplyGenerator(client: modelClient, secure: secure,
      current: () async => await allowed() && activeReplyGuard != null && await activeReplyGuard!(),
      onStatus: (code) => unawaited(status('task', code)));
    session = QqPrivateSession(journal: journal, owner: config.owner,
      pairCode: config.pairCode, pairExpires: DateTime.fromMillisecondsSinceEpoch(config.pairUntil),
      bindOwner: (owner) => QqPrivateConfig.bind(config.namespace, owner),
      contextIdentity: contextIdentity, captureReplyStamp: () => replyStamp,
      replyCurrent: (stamp) => QqReadOnlyContext.readMain((context) => context.matchesStamp(stamp)),
      allowed: allowed, yieldToChat: () => QqReadOnlyContext.readMain((context) => context.appBusy()),
      onStatus: (code) => unawaited(status('task', code)), send: api.send,
      generate: (text, history) async {
        if (!await allowed()) throw StateError('brain_paused');
        replyStamp = null;
        final currentConfig = await QqPrivateConfig.read();
        final materialStamp = <String, Object?>{};
        final snapshot = await QqReadOnlyContext.readMain((context) async {
          final primary = (await context.setting('deepseek_model'))?.trim() ?? '';
          return (prompt: await context.build(text, stamp: materialStamp),
            identity: jsonEncode([await context.identity(config.namespace, session?.owner ?? config.owner), currentConfig.replyChannel]),
            model: DeepSeekModelProfile.fromApiName(primary.isNotEmpty && primary != DeepSeekModelProfile.custom.apiName
              ? primary : await context.setting('model')),
            firstEffort: await context.setting('deepseek_reasoning_effort') ?? await context.setting('reasoning_effort'),
            finalEffort: await context.setting('reasoning_effort'));
        });
        replyStamp = materialStamp;
        activeReplyGuard = () async => await contextIdentity() == snapshot.identity &&
          await QqReadOnlyContext.readMain((context) => context.matchesStamp(materialStamp));
        try {
          final channel = currentConfig.replyChannel.isNotEmpty ? currentConfig.replyChannel :
            (await secure.readChatProvider()).isGeminiRelay ? 'second' : 'first';
          return await generator.generate(channel: channel, firstModel: snapshot.model,
            firstEffort: ReasoningEffort.fromApiName(snapshot.firstEffort),
            secondEffort: ReasoningEffort.fromApiName(snapshot.finalEffort),
            messages: [{'role': 'system', 'content': snapshot.prompt}, ...history, {'role': 'user', 'content': text}]);
        } finally { activeReplyGuard = null; }
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
    await session?.stop(); client?.close(); await gateway?.stop();
  }
}
