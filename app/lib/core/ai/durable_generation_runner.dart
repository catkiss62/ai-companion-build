import 'dart:async';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../grounding/service_template_guard.dart';
import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../somatic/somatic_engine.dart';
import '../storage/secure_config.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';
import 'nsfw_context_router.dart';
import 'prompt_builder.dart';

class GenerationRunResult {
  const GenerationRunResult({
    required this.status,
    this.assistant,
    this.error,
    this.retryAt,
  });

  final String status;
  final ChatMessage? assistant;
  final Object? error;
  final DateTime? retryAt;

  bool get completed => status == 'completed' && assistant != null;
  bool get retryScheduled => status == 'retry_wait';
}

class GenerationSuspendedException implements Exception {
  const GenerationSuspendedException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

class GenerationStreamIncompleteException implements Exception {
  const GenerationStreamIncompleteException();

  @override
  String toString() => 'DeepSeek 流式连接在收到完成标记前结束';
}

/// Runs one durable assistant-generation job.
///
/// The caller must own `chat_turn_lease`. The job itself is durable in SQLite,
/// while the API stream is intentionally restartable rather than resumable:
/// DeepSeek does not expose a stream-resume cursor. Checkpoints are diagnostics
/// and crash evidence; a recovered attempt starts from the same committed user
/// turn and writes the assistant message only once in a final SQLite transaction.
class DurableGenerationRunner {
  DurableGenerationRunner({
    required this.db,
    required this.client,
    SecureConfig? secureConfig,
  })  : secureConfig = secureConfig ?? SecureConfig.instance,
        desireEngine = DesireEngine(db),
        somaticEngine = SomaticEngine(db),
        nsfwRouter = NsfwContextRouter(db: db, client: client);

  final AppDatabase db;
  final DeepSeekClient client;
  final SecureConfig secureConfig;
  final DesireEngine desireEngine;
  final SomaticEngine somaticEngine;
  final NsfwContextRouter nsfwRouter;

  Future<GenerationRunResult> run(
    GenerationJob requested, {
    void Function(DeepSeekDelta delta)? onDelta,
    void Function(NsfwRouteDecision decision)? onNsfwRoute,
    GenerationCancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(requested.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }
    if (!await db.brainWorkAllowed()) {
      return const GenerationRunResult(status: 'suspended');
    }

    // API credentials are device-local and intentionally excluded from state
    // transfer. Check them before claiming so a newly transferred pending job
    // does not burn an attempt simply because the new device has not configured
    // its key yet.
    final apiKey = await secureConfig.readApiKey();
    final endpoint = await secureConfig.readEndpoint();
    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(requested.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }
    if (apiKey == null || apiKey.isEmpty) {
      final retryAt = await db.deferGenerationJob(
        requested.id,
        delay: const Duration(minutes: 2),
        reason: 'missing_api_key',
      );
      return GenerationRunResult(
        status: retryAt == null ? 'unavailable' : 'retry_wait',
        error: '请先在当前设备配置 DeepSeek API Key。',
        retryAt: retryAt,
      );
    }

    final job = await db.claimGenerationJob(requested.id);
    if (job == null) {
      final latest = await db.generationJobById(requested.id);
      if (latest?.status == 'completed') {
        final assistant = await db.messageById(latest!.assistantMessageId);
        return GenerationRunResult(status: 'completed', assistant: assistant);
      }
      return GenerationRunResult(status: latest?.status ?? 'unavailable');
    }

    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(job.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }

    final user = await db.messageById(job.userMessageId);
    if (user == null || !user.isUser) {
      final failed = await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: 'missing_user_message',
        recoverable: false,
      );
      return GenerationRunResult(
        status: failed == null ? 'suspended' : 'failed',
        error: '恢复任务找不到对应用户消息。',
      );
    }

    var lastCheckpoint = DateTime.now();
    var charsAtCheckpoint = 0;
    var lastLeaseRefresh = DateTime.now();
    var lastFenceCheck = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      final previous = await db.messagesBefore(user.createdAt, limit: 33);
      final recent = <ChatMessage>[...previous, user];
      // Capture after the durable user turn exists and before prompt build.
      // Stable event IDs make recovered attempts idempotent; cancellation
      // withdraws these events with the user message.
      await somaticEngine.captureUserTurn(
        turnId: user.id,
        text: user.content,
        now: user.createdAt,
      );
      final desire = await db.loadDesire();
      final thoughts = await db.activeThoughts(limit: 18);
      final nsfwRoute = await nsfwRouter.decide(
        apiKey: apiKey,
        endpoint: endpoint,
        turnId: user.id,
        latestUserText: user.content,
        recent: recent,
        cancellationToken: cancellationToken,
      );
      onNsfwRoute?.call(nsfwRoute);
      final baseRequestMessages = await PromptBuilder(db).buildChatMessages(
        latestUserText: user.content,
        recent: recent,
        desire: desire,
        thoughts: thoughts,
        nsfwActive: nsfwRoute.active,
        nsfwReferenceActive: nsfwRoute.referenceActive,
      );
      Future<({String reasoning, String content})> generate(
        List<Map<String, Object?>> messages, {
        bool emitDeltas = true,
      }) async {
        var reasoning = '';
        var content = '';
        var sawTerminalSignal = false;
        charsAtCheckpoint = 0;
        lastCheckpoint = DateTime.now();
        await for (final delta in client.streamChat(
          apiKey: apiKey,
          model: DeepSeekModelProfile.fromApiName(job.model),
          effort: ReasoningEffort.fromApiName(job.reasoningEffort),
          messages: messages,
          endpoint: endpoint,
          thinking: job.thinking,
          cancellationToken: cancellationToken,
        )) {
          cancellationToken?.throwIfCancelled();
          if (!await db.brainWorkAllowed()) {
            throw const GenerationSuspendedException('设备正在转移或已经下线');
          }

          final now = DateTime.now();
          if (now.difference(lastFenceCheck) >=
              const Duration(milliseconds: 200)) {
            final current = await db.isGenerationRunCurrent(
              job.id,
              runToken: job.runToken,
            );
            if (!current) {
              final latest = await db.generationJobById(job.id);
              if (latest?.status == 'cancelled_by_user') {
                throw const GenerationCancelledByUserException();
              }
              throw const GenerationSuspendedException(
                '本次生成尝试的写入所有权已经失效',
              );
            }
            lastFenceCheck = now;
          }
          if (now.difference(lastLeaseRefresh) >= const Duration(seconds: 45)) {
            final renewed = await db.renewLocalLease(
              'chat_turn_lease',
              holdFor: const Duration(minutes: 3),
            );
            if (!renewed) {
              throw const GenerationSuspendedException('聊天写入权限已经转移');
            }
            lastLeaseRefresh = now;
          }

          if (delta.done || delta.finishReason != null) {
            sawTerminalSignal = true;
          }
          if (delta.reasoning.isNotEmpty) reasoning += delta.reasoning;
          if (delta.content.isNotEmpty) content += delta.content;
          if (emitDeltas) onDelta?.call(delta);

          final chars = reasoning.length + content.length;
          if (now.difference(lastCheckpoint) >= const Duration(seconds: 2) ||
              chars - charsAtCheckpoint >= 768) {
            final checkpointed = await db.checkpointGenerationJob(
              job.id,
              runToken: job.runToken,
              partialReasoning: reasoning,
              partialContent: content,
            );
            if (!checkpointed) {
              throw const GenerationSuspendedException(
                '本次生成尝试的写入所有权已经过期',
              );
            }
            lastCheckpoint = now;
            charsAtCheckpoint = chars;
          }
        }
        if (!sawTerminalSignal) {
          throw const GenerationStreamIncompleteException();
        }
        return (reasoning: reasoning.trim(), content: content.trim());
      }

      var generated = await generate(baseRequestMessages);
      cancellationToken?.throwIfCancelled();
      if (generated.content.isEmpty) {
        throw const FormatException('模型没有返回可用正文');
      }

      final recentAssistantTexts = previous
          .where((message) => message.isAssistant)
          .map((message) => message.content);
      var finalContent = generated.content;
      var serviceGuard = ServiceTemplateGuard.evaluate(
        text: finalContent,
        recentAssistantTexts: recentAssistantTexts,
        currentUserText: user.content,
      );
      if (!serviceGuard.allowed) {
        await ServiceTemplateGuardTelemetry.note(
          db,
          result: serviceGuard,
          mode: 'user_turn',
          action: 'rewrite',
        );
        final correctionMessages = <Map<String, Object?>>[
          ...baseRequestMessages,
          {
            'role': 'system',
            'content': '''
【NATURAL OUTPUT CORRECTION · ONE RETRY】
上一份正文命中了重复的服务模板语义：${serviceGuard.reason} / ${serviceGuard.family}。
完全丢弃“一直在、不走、不催、你忙你的、等你忙完、无条件顺从”这类承诺—退场—等待收尾。不要换成近义套话，也不要表演随机叛逆。
重新回应当前真实用户消息：保留具体反应、自己的判断/情绪/需求和真正有内容的部分，在自然落点结束。
'''.trim(),
          },
        ];
        generated = await generate(
          correctionMessages,
          emitDeltas: false,
        );
        cancellationToken?.throwIfCancelled();
        finalContent = generated.content;
        serviceGuard = ServiceTemplateGuard.evaluate(
          text: finalContent,
          recentAssistantTexts: recentAssistantTexts,
          currentUserText: user.content,
        );
        if (!serviceGuard.allowed) {
          final stripped =
              ServiceTemplateGuard.removeTemplateSentences(finalContent);
          final strippedGuard = ServiceTemplateGuard.evaluate(
            text: stripped,
            recentAssistantTexts: recentAssistantTexts,
            currentUserText: user.content,
          );
          if (stripped.isNotEmpty && strippedGuard.allowed) {
            finalContent = stripped;
          } else {
            await ServiceTemplateGuardTelemetry.note(
              db,
              result: serviceGuard,
              mode: 'user_turn',
              action: 'block',
            );
            throw const FormatException(
              '模型连续返回服务模板，已阻止写入',
            );
          }
        }
      }
      if (finalContent.trim().isEmpty) {
        throw const FormatException('模板重写后正文为空');
      }

      final assistant = ChatMessage(
        id: job.assistantMessageId,
        role: 'assistant',
        content: finalContent,
        reasoningContent: generated.reasoning,
        model: job.model,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
      );
      // Detection is pure; persistence happens only inside the winning
      // durable commit transaction below.
      final assistantSomaticEvents = somaticEngine.assistantCommitEvents(
        turnId: assistant.id,
        text: assistant.content,
        now: assistant.createdAt,
      );
      final committed = await db.completeGenerationJobIfCurrent(
        jobId: job.id,
        runToken: job.runToken,
        assistant: assistant,
        somaticEvents: assistantSomaticEvents,
      );
      if (!committed) {
        await db.suspendGenerationJob(
          job.id,
          reason: 'ownership_changed_before_commit',
          runToken: job.runToken,
        );
        return const GenerationRunResult(status: 'suspended');
      }

      await desireEngine.satisfy(DriveKey.attachment, factor: 0.58);
      return GenerationRunResult(status: 'completed', assistant: assistant);
    } on GenerationCancelledByUserException catch (e) {
      await db.cancelGenerationJobByUser(job.id);
      return GenerationRunResult(status: 'cancelled_by_user', error: e);
    } on GenerationSuspendedException catch (e) {
      await db.suspendGenerationJob(
        job.id,
        reason: e.reason,
        runToken: job.runToken,
      );
      return GenerationRunResult(status: 'suspended', error: e);
    } catch (e) {
      final recoverable = _recoverable(e);
      final failed = await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: _compactError(e),
        recoverable: recoverable,
      );
      if (failed == null) {
        return GenerationRunResult(status: 'suspended', error: e);
      }
      return GenerationRunResult(
        status: failed.status,
        error: e,
        retryAt: failed.nextRetryAt,
      );
    }
  }

  bool _recoverable(Object error) {
    if (error is DeepSeekException) {
      return error.statusCode == 401 ||
          error.statusCode == 402 ||
          error.statusCode == 403 ||
          error.statusCode == 408 ||
          error.statusCode == 409 ||
          error.statusCode == 425 ||
          error.statusCode == 429 ||
          error.statusCode >= 500;
    }
    if (error is FormatException) return false;
    if (error is StateError) return false;
    return true;
  }

  String _compactError(Object error) {
    final raw = error.toString();
    return raw.length <= 360 ? raw : raw.substring(0, 360);
  }
}
