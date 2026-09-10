import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../ai/qwen_vision_client.dart';
import '../database/app_database.dart';
import '../diagnostics/provider_health.dart';
import '../media/safe_public_image_downloader.dart';
import 'album_perceptual_hash.dart';
import '../storage/companion_album_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/media_blob_storage.dart';
import '../storage/secure_config.dart';
import 'simulated_phone_policy.dart';

/// Processes at most one bounded public image candidate per recovery cycle.
/// Qwen sees only the bounded preview. A selected candidate additionally keeps
/// the exact downloaded bytes as the local album original.
class CompanionAlbumDiscoveryEngine {
  CompanionAlbumDiscoveryEngine({
    required this.db,
    SecureConfig? config,
    QwenVisionClient? vision,
    CompanionAlbumStorage? albumStorage,
    MessageAttachmentStorage? attachmentStorage,
    http.Client? client,
  })  : config = config ?? SecureConfig.instance,
        vision = vision ?? QwenVisionClient(),
        albumStorage = albumStorage ?? CompanionAlbumStorage(),
        attachmentStorage = attachmentStorage ?? MessageAttachmentStorage(),
        _client = client ?? http.Client();

  final AppDatabase db;
  final SecureConfig config;
  final QwenVisionClient vision;
  final CompanionAlbumStorage albumStorage;
  final MessageAttachmentStorage attachmentStorage;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  static const _fishManifest =
      'https://fisharchive.pages.dev/stickers/manifest.json';

  /// User-command adapter for the same canonical download → Qwen vision →
  /// byte-bound album chain used by autonomous discovery. Explicit save skips
  /// only the curator veto; safety, provider, duplicate and storage failures
  /// remain authoritative.
  Future<String> saveUserRequestedWebImage({
    required String sourceId,
    required String sourceUrl,
    required String sourceDomain,
    required String title,
    required String visionContext,
    required String requestedSubject,
    DateTime? now,
  }) async {
    final apiKey = await config.readVisionApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) return 'vision_unconfigured';
    return _process(
      sourceKind: 'user_requested_web',
      sourceId: sourceId,
      sourceUrl: sourceUrl,
      sourceDomain: sourceDomain,
      title: title,
      visionContext: visionContext,
      apiKey: apiKey,
      now: (now ?? DateTime.now()).toLocal(),
      forceSave: true,
      requestedSubject: requestedSubject,
    );
  }

  Future<String> runOneIfDue({DateTime? now}) async {
    final instant = (now ?? DateTime.now()).toLocal();
    if ((await db.getSetting('simulated_phone_enabled')) == '0') {
      return 'disabled';
    }
    final apiKey = await config.readVisionApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      await db.recordProviderHealthEvent(const ProviderHealthEvent(
        lane: 'vision',
        context: 'album_discovery',
        primaryProvider: 'qwen_vision',
        primaryOutcome: 'not_configured',
        primaryErrorCategory: 'missing_key',
        finalOutcome: 'not_configured',
      ));
      return 'vision_unconfigured';
    }

    final web = await db.nextCompanionAlbumWebSource();
    if (web != null) {
      return _process(
        sourceKind: 'public_web',
        sourceId: web['id']?.toString() ?? '',
        sourceUrl: web['image_url']?.toString() ?? '',
        sourceDomain: web['image_domain']?.toString() ?? '',
        title: web['title']?.toString() ?? '网页发现',
        visionContext: _boundedVisionContext(
          title: web['title']?.toString() ?? '',
          summary: web['summary']?.toString() ?? '',
          imageDescription: web['image_description']?.toString() ?? '',
        ),
        apiKey: apiKey,
        now: instant,
      );
    }

    final day = SimulatedPhonePolicy.localDay(instant);
    if ((await db.getSetting('companion_album_fisharchive_attempt_day')) ==
        day) {
      return 'no_due_source';
    }
    await db.setSetting('companion_album_fisharchive_attempt_day', day);
    final fish = await _fishArchiveCandidate(day);
    if (fish == null) return 'fisharchive_no_result';
    return _process(
      sourceKind: 'fisharchive',
      sourceId: fish.id,
      sourceUrl: fish.previewUrl,
      sourceDomain: 'fisharchive.pages.dev',
      title: fish.title,
      visionContext: _boundedVisionContext(title: fish.title),
      apiKey: apiKey,
      now: instant,
    );
  }

  Future<String> _process({
    required String sourceKind,
    required String sourceId,
    required String sourceUrl,
    required String sourceDomain,
    required String title,
    required String visionContext,
    required String apiKey,
    required DateTime now,
    bool forceSave = false,
    String requestedSubject = '',
  }) async {
    final started = DateTime.now();
    if (sourceId.isEmpty || !_safePublicHttps(Uri.tryParse(sourceUrl))) {
      await db.recordProviderHealthEvent(const ProviderHealthEvent(
        lane: 'album',
        context: 'album_discovery',
        primaryProvider: 'local_album',
        primaryOutcome: 'unsafe_source',
        finalOutcome: 'unsafe_source',
      ));
      return 'unsafe_or_empty_source';
    }
    final candidateId = _uuid.v4();
    final begun = await db.beginCompanionAlbumCandidate(
      id: candidateId,
      sourceKind: sourceKind,
      sourceId: sourceId,
      sourceUrl: sourceUrl,
      sourceDomain: sourceDomain,
      title: title,
      createdAt: now,
    );
    if (!begun) {
      await db.recordProviderHealthEvent(const ProviderHealthEvent(
        lane: 'album',
        context: 'album_discovery',
        primaryProvider: 'local_album',
        primaryOutcome: 'duplicate_source',
        finalOutcome: 'duplicate_source',
      ));
      return 'duplicate_source';
    }

    PreparedImageAttachment? draft;
    File? downloaded;
    String savedPath = '';
    String savedOriginalPath = '';
    String savedBlobId = '';
    var stage = 'download';
    var visionRecorded = false;
    try {
      final download = await _downloadPreview(sourceUrl, candidateId);
      downloaded = download.file;
      final downloadedFile = downloaded!;
      stage = 'image_processing';
      draft = await attachmentStorage.prepareImage(
        sourcePath: downloadedFile.path,
        source: sourceKind,
        mimeType: download.mimeType,
      );
      if (await downloadedFile.exists()) await downloadedFile.delete();
      downloaded = null;
      stage = 'vision';
      final observation = await vision.observe(
        apiKey: apiKey,
        endpoint: await config.readVisionEndpoint(),
        model: await config.readVisionModel(),
        imageFile: draft.thumbnailFile,
        caption: visionContext,
        assessForAlbum: true,
        albumPreferenceHint: await db.companionAlbumPreferenceHint(),
        requestedSubject: requestedSubject,
      );
      stage = 'image_binding';
      await albumStorage.requireContentSha256(
        draft.thumbnailFile,
        observation.inputContentSha256,
      );
      await db.recordProviderHealthEvent(ProviderHealthEvent(
        lane: 'vision',
        context: 'album_discovery',
        primaryProvider: 'qwen_vision',
        primaryOutcome: 'success',
        finalProvider: 'qwen_vision',
        finalOutcome: 'success',
        resultCount: 1,
        latencyBucket:
            ProviderHealth.latencyBucket(DateTime.now().difference(started)),
      ));
      visionRecorded = true;

      String contentSha = '';
      String originalSha = '';
      int originalByteSize = 0;
      String perceptualHash = '';
      final requestMatches = requestedSubject.trim().isEmpty ||
          (observation.requestMatch &&
              observation.requestMatchConfidence >= 0.72);
      final shouldSave = requestMatches && (observation.albumSave || forceSave);
      if (shouldSave) {
        stage = 'local_write';
        final blob = await attachmentStorage.blobStorage.store(
          original: draft.originalFile,
          thumbnail: draft.thumbnailFile,
          mimeType: draft.mimeType,
          width: draft.width,
          height: draft.height,
          createdAt: draft.createdAt,
        );
        await db.registerMediaBlob(blob);
        final canonical = await db.mediaBlobById(blob.id);
        if (canonical == null) {
          throw StateError('media_blob_registration_failed');
        }
        for (final extra in <String>{blob.originalPath, blob.thumbnailPath}
            .difference(<String>{
          canonical.originalPath,
          canonical.thumbnailPath,
        })) {
          final file = await attachmentStorage.blobStorage.fileFor(extra);
          if (await file.exists()) await file.delete();
        }
        savedBlobId = canonical.id;
        savedPath =
            MediaBlobStorage.toReferencePath(canonical.thumbnailPath);
        contentSha = canonical.thumbnailSha256;
        savedOriginalPath =
            MediaBlobStorage.toReferencePath(canonical.originalPath);
        originalSha = canonical.originalSha256;
        originalByteSize = canonical.byteSize;
        stage = 'image_processing';
        perceptualHash = await AlbumPerceptualHash.fromFile(
          draft.thumbnailFile,
        );
      }
      stage = 'local_write';
      final completed = await db.completeCompanionAlbumCandidate(
        id: candidateId,
        save: shouldSave,
        visionSummary: observation.summary,
        visionModel: observation.model,
        aiReason: forceSave
            ? requestMatches
                ? '用户明确要求保存，且视觉像素与找图目标相符。'
                : '视觉像素与用户找图目标不符：${observation.requestMismatchReason}'
            : observation.albumReason,
        category: observation.albumCategory,
        tags: observation.albumTags,
        thumbnailPath: savedPath,
        originalPath: savedOriginalPath,
        originalContentSha256: originalSha,
        originalMimeType: draft.mimeType,
        originalByteSize: originalByteSize,
        contentSha256: contentSha,
        perceptualHash: perceptualHash,
        visualFingerprint: observation.aestheticTags.join('|'),
        width: draft.width,
        height: draft.height,
        recognizedAt: DateTime.now(),
        blobId: savedBlobId,
      );
      if (!completed && savedPath.isNotEmpty) {
        await albumStorage.deleteThumbnail(savedPath);
      }
      if (!completed && savedOriginalPath.isNotEmpty) {
        await albumStorage.deleteFile(savedOriginalPath);
      }
      if (!completed && savedBlobId.isNotEmpty) {
        final orphan = await db.removeUnreferencedMediaBlob(savedBlobId);
        if (orphan != null) {
          await attachmentStorage.blobStorage.deleteBlobFiles(orphan);
        }
      }
      final outcome =
          await db.companionAlbumCandidateOutcomeCategory(candidateId);
      await db.recordProviderHealthEvent(ProviderHealthEvent(
        lane: 'album',
        context: 'album_discovery',
        primaryProvider: 'local_album',
        primaryOutcome: outcome,
        finalProvider:
            shouldSave && completed ? 'local_album' : 'none',
        finalOutcome: outcome,
        resultCount: shouldSave && completed ? 1 : 0,
        latencyBucket:
            ProviderHealth.latencyBucket(DateTime.now().difference(started)),
      ));
      if (!requestMatches) return 'request_mismatch';
      return shouldSave && completed ? 'saved' : 'rejected';
    } catch (error) {
      if (savedPath.isNotEmpty) await albumStorage.deleteThumbnail(savedPath);
      if (savedOriginalPath.isNotEmpty) {
        await albumStorage.deleteFile(savedOriginalPath);
      }
      if (savedBlobId.isNotEmpty) {
        final orphan = await db.removeUnreferencedMediaBlob(savedBlobId);
        if (orphan != null) {
          await attachmentStorage.blobStorage.deleteBlobFiles(orphan);
        }
      }
      await db.expireCompanionAlbumCandidate(candidateId, error.toString());
      final category = stage == 'download'
          ? 'download'
          : stage == 'image_processing'
              ? 'image_processing'
              : stage == 'image_binding'
                  ? 'image_binding'
                  : stage == 'local_write'
                      ? 'local_write'
                      : ProviderHealth.errorCategory(error);
      if (!visionRecorded && stage == 'vision') {
        await db.recordProviderHealthEvent(ProviderHealthEvent(
          lane: 'vision',
          context: 'album_discovery',
          primaryProvider: 'qwen_vision',
          primaryOutcome: 'failed',
          primaryErrorCategory: category,
          finalOutcome: 'failed',
          latencyBucket:
              ProviderHealth.latencyBucket(DateTime.now().difference(started)),
        ));
      }
      await db.recordProviderHealthEvent(ProviderHealthEvent(
        lane: 'album',
        context: 'album_discovery',
        primaryProvider: 'local_album',
        primaryOutcome: 'failed',
        primaryErrorCategory: category,
        finalOutcome: 'failed',
        latencyBucket:
            ProviderHealth.latencyBucket(DateTime.now().difference(started)),
      ));
      return 'failed';
    } finally {
      final temporaryDownload = downloaded;
      if (temporaryDownload != null && await temporaryDownload.exists()) {
        await temporaryDownload.delete();
      }
      if (draft != null) await attachmentStorage.discardDraft(draft);
    }
  }

  static String _boundedVisionContext({
    required String title,
    String summary = '',
    String imageDescription = '',
  }) {
    final parts = <String>[
      if (title.trim().isNotEmpty) '标题：${title.trim()}',
      if (summary.trim().isNotEmpty) '页面摘要：${summary.trim()}',
      if (imageDescription.trim().isNotEmpty)
        '图片说明：${imageDescription.trim()}',
    ];
    final normalized = parts.join('\n').replaceAll(RegExp(r'[\r\t]+'), ' ');
    return normalized.length <= 600 ? normalized : normalized.substring(0, 600);
  }

  Future<DownloadedPublicImage> _downloadPreview(String value, String id) =>
      SafePublicImageDownloader.download(
        client: _client,
        rawUrl: value,
        maxBytes: MessageAttachmentStorage.maxImageBytes,
        filePrefix: 'companion_album_$id',
      );

  Future<_FishCandidate?> _fishArchiveCandidate(String day) async {
    try {
      final response = await _client
          .get(Uri.parse(_fishManifest), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != 200 || response.bodyBytes.length > 2 * 1024 * 1024) {
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty) return null;
      final seed = sha256.convert(utf8.encode(day)).bytes;
      final start = ((seed[0] << 8) + seed[1]) % decoded.length;
      for (var offset = 0; offset < decoded.length && offset < 24; offset++) {
        final raw = decoded[(start + offset) % decoded.length];
        if (raw is! Map) continue;
        final preview = raw['preview']?.toString() ?? '';
        if (preview.isEmpty) continue;
        final url = Uri.parse(_fishManifest).resolve(preview).toString();
        final id = sha256.convert(utf8.encode(url)).toString();
        if (await db.companionAlbumSourceHandled('fisharchive', id)) continue;
        final filename = raw['filename']?.toString().trim() ?? '';
        return _FishCandidate(
          id: id,
          previewUrl: url,
          title: filename.isEmpty ? '鲸鱼娘同人图片' : filename,
        );
      }
    } catch (_) {}
    return null;
  }

  static bool _safePublicHttps(Uri? uri) =>
      SafePublicImageDownloader.safePublicHttps(uri);

  void close() {
    _client.close();
    vision.close();
  }
}

class _FishCandidate {
  const _FishCandidate({
    required this.id,
    required this.previewUrl,
    required this.title,
  });

  final String id;
  final String previewUrl;
  final String title;
}
