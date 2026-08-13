import 'dart:async';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../storage/secure_config.dart';
import 'deepseek_client.dart';
import 'model_profile.dart';
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
        desireEngine = DesireEngine(db);

  final AppDatabase db;
  final DeepSeekClient client;
  final SecureConfig secureConfig;
  final DesireEngine desireEngine;

  Future<GenerationRunResult> run(
    GenerationJob requested, {
    void Function(DeepSeekDelta delta)? onDelta,
  }) async {
    if (!await db.brainWorkAllowed()) {
      return const GenerationRunResult(status: 'suspended');
    }

    // API credentials are device-local and intentionally excluded from state
    // transfer. Check them before claiming so a newly transferred pending job
    // does not burn an attempt simply because the new device has not configured
    // its key yet.
    final apiKey = await secureConfig.readApiKey();
    final endpoint = await secureConfig.readEndpoint();
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

    try {
      final previous = await db.messagesBefore(user.createdAt, limit: 33);
      final recent = <ChatMessage>[...previous, user];
      final desire = await db.loadDesire();
      final thoughts = await db.activeThoughts(limit: 18);
      final baseRequestMessages = await PromptBuilder(db).buildChatMessages(
        latestUserText: user.content,
        recent: recent,
        desire: desire,
        thoughts: thoughts,
      );
      Future<({String reasoning, String content})> generate(
        List<Map<String, Object?>> messages,
      ) async {
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
        )) {
          if (!await db.brainWorkAllowed()) {
            throw const GenerationSuspendedException('设备正在转移或已经下线');
          }

          final now = DateTime.now();
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
          onDelta?.call(delta);

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

      final generated = await generate(baseRequestMessages);
      if (generated.content.isEmpty) {
        throw const FormatException('模型没有返回可用正文');
      }

      final assistant = ChatMessage(
        id: job.assistantMessageId,
        role: 'assistant',
        content: generated.content,
        reasoningContent: generated.reasoning,
        model: job.model,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
      );
      final committed = await db.completeGenerationJobIfCurrent(
        jobId: job.id,
        runToken: job.runToken,
        assistant: assistant,
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
