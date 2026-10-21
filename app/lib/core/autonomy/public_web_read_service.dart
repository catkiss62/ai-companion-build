import '../ai/first_channel_model.dart';
import '../agent/agent_tool.dart';
import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';
import '../storage/secure_config.dart';
import 'layered_public_web_provider.dart';
import 'public_web_deepseek_appraiser.dart';
import 'public_web_share_contract.dart';
import 'web_page_evidence.dart';

typedef WebCandidateReader =
    Future<PublicWebCandidateDraft> Function(
      PublicWebCandidateDraft candidate,
      String query,
      GenerationCancellationToken? cancellation,
    );

/// One shared source-reading boundary for user tools and selected stored pages.
class PublicWebReadService {
  PublicWebReadService(
    this.db, {
    SecureConfig? secureConfig,
    this.ai,
    this.reader,
    this.workFence,
  }) : secureConfig = secureConfig ?? SecureConfig.instance;
  final AppDatabase db;
  final SecureConfig secureConfig;
  final DeepSeekClient? ai;
  final WebCandidateReader? reader;
  final BrainWorkFence? workFence;

  static bool usable(PublicWebCandidateDraft page) =>
      page.isVerifiedRead &&
      WebPageEvidence.rejection(page.pageBody) == null &&
      (page.semanticState == 'valid' || page.semanticState == 'history_only');

  /// Reading and prompt capture use the same consumer identity. A selected
  /// old Thought may refer to active historical knowledge, never to a new
  /// share simply because its page was selected again.
  Future<PublicWebPromptBundle> preparePromptBundle({
    Iterable<String> candidateIds = const [],
    Iterable<String> historicalKnowledgeIds = const [],
    String? selectedShareCandidateId,
    String? selectedShareThoughtId,
    String query = '',
    GenerationCancellationToken? cancellation,
    int limit = 5,
    void Function(AgentToolActivity)? onActivity,
  }) async {
    cancellation?.throwIfCancelled();
    if (workFence != null && !await db.brainWorkFenceCurrent(workFence!)) {
      return const PublicWebPromptBundle();
    }
    final candidates = candidateIds.map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty).toSet();
    final historical = historicalKnowledgeIds.map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty).toSet();
    final shareId = selectedShareCandidateId?.trim().toLowerCase();
    final handle = await db.database;
    final selection = await handle.transaction((txn) async {
      final candidateReads = <String>[], historicalReads = <String>[];
      final now = DateTime.now();
      for (final id in <String>{...candidates, ...historical}) {
        if (candidateReads.length + historicalReads.length >= limit.clamp(1, 5)) break;
        final rows = await txn.query('public_web_candidates',
            where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isEmpty) continue;
        final row = rows.single;
        if (id == shareId) {
          // An explicit new-share request must not fall back to history and
          // accidentally deliver the same share twice.
          if (selectedShareThoughtId != null && PublicWebSourceStamp.preparationEligible(
              row, PublicWebSourceProfile.share, now)) {
            final thoughts = await txn.query('thoughts',
                where: 'id = ? AND source = ? AND topic_key = ?',
                whereArgs: [selectedShareThoughtId, 'public_web_candidate:$id',
                  'public_web_candidate:$id'], limit: 1);
            if (thoughts.isNotEmpty &&
                const {'active', 'fixation'}.contains(thoughts.single['lifecycle_state']) &&
                ((thoughts.single['snoozed_until'] as num?)?.toInt() ?? 0) <= now.millisecondsSinceEpoch) {
              candidateReads.add(id);
            }
          }
          continue;
        }
        if (candidates.contains(id) && PublicWebSourceStamp.preparationEligible(
            row, PublicWebSourceProfile.candidateContext, now)) {
          candidateReads.add(id);
          continue;
        }
        final activeKnowledge = (await txn.query('public_web_knowledge',
            columns: ['candidate_id'], where: "candidate_id = ? AND lifecycle_state = 'active'",
            whereArgs: [id], limit: 1)).isNotEmpty;
        if (PublicWebSourceStamp.preparationEligible(row,
            PublicWebSourceProfile.historicalKnowledge, now, knowledgeActive: activeKnowledge)) {
          historicalReads.add(id);
        }
      }
      return (candidateReads, historicalReads);
    });
    final ready = (await refreshIds([...selection.$1, ...selection.$2],
        query: query, cancellation: cancellation, limit: limit,
        onActivity: onActivity)).toSet();
    cancellation?.throwIfCancelled();
    if (workFence != null && !await db.brainWorkFenceCurrent(workFence!)) {
      return const PublicWebPromptBundle();
    }
    // The transaction rechecks current lifecycle/material/knowledge state.
    // A delete, revocation or competing share while reading stays excluded.
    return db.publicWebPromptBundle(
      candidateIds: selection.$1.where(ready.contains).toList(),
      historicalKnowledgeIds: selection.$2.where(ready.contains).toList(),
      selectedShareCandidateId: shareId,
      selectedShareThoughtId: selectedShareThoughtId,
    );
  }

  Future<PublicWebCandidateDraft> read(
    PublicWebCandidateDraft source, {
    required String query,
    GenerationCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    if (reader != null) return reader!(source, query, cancellation);
    final provider = LayeredPublicWebProvider(
      tavilyApiKey: await secureConfig.readTavilyApiKey() ?? '',
      agnesApiKey: await secureConfig.readAgnesApiKey() ?? '',
      agnesEndpoint: await secureConfig.readAgnesEndpoint(),
      agnesModel: await secureConfig.readAgnesModel(),
      agnesEnabled:
          (await db.getSetting('agnes_web_compaction_enabled')) != '0',
    );
    final page = await provider.rereadCandidate(
      candidate: source,
      query: query,
      now: DateTime.now(),
      cancellationToken: cancellation,
    );
    if (!page.isVerifiedRead) return page;
    final judged =
        await DeepSeekPublicWebAppraiser(
          model: await FirstChannelModel.read(db),
          apiKey: await secureConfig.readApiKey() ?? '',
          endpoint: await secureConfig.readEndpoint(),
          client: ai,
        ).appraise(
          query: query,
          candidates: [page],
          sourceIntent: const DesireIntent(
            drive: DriveKey.curiosity,
            score: 1,
            reason: 'source_read_before_use',
            wantAction: 'answer_user_with_tool',
            reasonSource: 'public_web_read',
          ),
          socialExcess: 0,
          cancellationToken: cancellation,
        );
    cancellation?.throwIfCancelled();
    return judged.single;
  }

  Future<bool> refreshForUse(
    String id, {
    String query = '',
    GenerationCancellationToken? cancellation,
    DateTime? now,
  }) async {
    if (workFence != null && !await db.brainWorkFenceCurrent(workFence!)) return false;
    final snapshot = await db.publicWebCandidateReadSnapshot(id);
    final source = snapshot?.draft;
    if (source == null ||
        const {
          'user_deleted',
          'discarded',
          'declined',
          'share_staging',
        }.contains(source.appraisalState))
      return false;
    final instant = now ?? DateTime.now();
    if (usable(source) &&
        WebPageEvidence.fresh(source.pageBody, source.readAt, instant)) {
      return true;
    }
    final refreshed = await read(
      source,
      query: query.isNotEmpty
          ? query
          : source.searchQuery.isNotEmpty
          ? source.searchQuery
          : source.title,
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();
    if (!usable(refreshed)) return false;
    if (source.appraisalState == 'share_ready' &&
        (refreshed.semanticState != 'valid' || refreshed.shareScore < 0.68)) {
      return false;
    }
    // Atomic lifecycle/hash check: an in-flight read cannot revive a deleted
    // page, overwrite a newer read, or steal the staging owner's claim.
    return db.cachePublicWebPromptRead(
      id,
      refreshed,
      expectedContentSha: source.contentSha256,
      expectedMaterialHash: workFence == null ? null : snapshot!.materialHash,
      expectedReadState: workFence == null ? null : source.readState,
      expectedSemanticState: workFence == null ? null : source.semanticState,
      expectedLifecycleState: workFence == null ? null : source.appraisalState,
      workFence: workFence,
    );
  }

  Future<List<String>> refreshIds(
    Iterable<String> ids, {
    String query = '',
    GenerationCancellationToken? cancellation,
    int limit = 3,
    void Function(AgentToolActivity)? onActivity,
  }) async {
    final pages = ids.toSet().take(limit.clamp(1, 5).toInt()).toList();
    final ready = <String>[];
    final clock = Stopwatch()..start();
    var completed = 0;
    void report(AgentToolStatus status, String text) => onActivity?.call(
      AgentToolActivity(toolId: 'public_web.read', status: status, text: text));
    if (pages.isEmpty) return ready;
    report(AgentToolStatus.running, '正在核对并读取相关网页资料（0/${pages.length}）…');
    try {
      for (var start = 0; start < pages.length; start += 2) {
        cancellation?.throwIfCancelled();
        final batch = pages.skip(start).take(2).toList();
        final results = await Future.wait(batch.map((id) async {
          final ok = await refreshForUse(id, query: query, cancellation: cancellation);
          completed++;
          report(AgentToolStatus.running, '正在核对并读取相关网页资料（$completed/${pages.length}）…');
          return ok;
        }));
        for (var i = 0; i < batch.length; i++) {
          if (results[i]) ready.add(batch[i]);
        }
      }
      cancellation?.throwIfCancelled();
      report(ready.isEmpty ? AgentToolStatus.noResult : AgentToolStatus.succeeded,
        ready.isEmpty ? '未取得可核验的网页正文' : '已核验 ${ready.length} 份网页资料');
      return ready;
    } on GenerationCancelledByUserException {
      report(AgentToolStatus.stopped, '网页读取已停止');
      rethrow;
    } catch (_) {
      report(AgentToolStatus.failed, '网页读取未完成');
      rethrow;
    } finally {
      try {
        await db.setSettingsAtomically({'web_prompt_read_timing_v1':
          '${DateTime.now().millisecondsSinceEpoch}|${pages.length}|${ready.length}|${clock.elapsedMilliseconds}'},
          workFence: workFence);
      } catch (_) { /* Timing never changes reply outcome. */ }
    }
  }
}
