import '../ai/deepseek_client.dart';
import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';
import '../storage/secure_config.dart';
import 'layered_public_web_provider.dart';
import 'public_web_deepseek_appraiser.dart';
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
  }) : secureConfig = secureConfig ?? SecureConfig.instance;
  final AppDatabase db;
  final SecureConfig secureConfig;
  final DeepSeekClient? ai;
  final WebCandidateReader? reader;

  static bool usable(PublicWebCandidateDraft page) =>
      page.isVerifiedRead &&
      WebPageEvidence.rejection(page.pageBody) == null &&
      (page.semanticState == 'valid' || page.semanticState == 'history_only');

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
    final source = await db.publicWebCandidateForRefresh(id);
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
    );
  }

  Future<List<String>> refreshIds(
    Iterable<String> ids, {
    String query = '',
    GenerationCancellationToken? cancellation,
  }) async {
    final ready = <String>[];
    for (final id in ids.toSet().take(3)) {
      cancellation?.throwIfCancelled();
      if (await refreshForUse(id, query: query, cancellation: cancellation))
        ready.add(id);
    }
    return ready;
  }
}
