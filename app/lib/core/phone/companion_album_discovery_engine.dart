import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../ai/qwen_vision_client.dart';
import '../database/app_database.dart';
import '../diagnostics/provider_health.dart';
import 'album_perceptual_hash.dart';
import '../storage/companion_album_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/secure_config.dart';
import 'simulated_phone_policy.dart';

/// Processes at most one bounded public image candidate per recovery cycle.
/// It never stores a remote original: only the existing <=1000 px PNG preview
/// reaches Qwen and, if selected, the private album.
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
    required String apiKey,
    required DateTime now,
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
    var stage = 'download';
    var visionRecorded = false;
    try {
      downloaded = await _downloadPreview(sourceUrl, candidateId);
      final downloadedFile = downloaded!;
      stage = 'image_processing';
      draft = await attachmentStorage.prepareImage(
        sourcePath: downloadedFile.path,
        source: sourceKind,
        mimeType: 'image/${p.extension(downloaded.path).replaceFirst('.', '')}',
      );
      if (await downloadedFile.exists()) await downloadedFile.delete();
      downloaded = null;
      stage = 'vision';
      final observation = await vision.observe(
        apiKey: apiKey,
        endpoint: await config.readVisionEndpoint(),
        model: await config.readVisionModel(),
        imageFile: draft.thumbnailFile,
        assessForAlbum: true,
        albumPreferenceHint: await db.companionAlbumPreferenceHint(),
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
      String perceptualHash = '';
      if (observation.albumSave) {
        stage = 'local_write';
        final stored = await albumStorage.saveThumbnail(
          id: candidateId,
          source: draft.thumbnailFile,
          expectedContentSha256: observation.inputContentSha256,
        );
        savedPath = stored.relativePath;
        contentSha = stored.contentSha256;
        stage = 'image_processing';
        perceptualHash = await AlbumPerceptualHash.fromFile(
          draft.thumbnailFile,
        );
      }
      stage = 'local_write';
      final completed = await db.completeCompanionAlbumCandidate(
        id: candidateId,
        save: observation.albumSave,
        visionSummary: observation.summary,
        visionModel: observation.model,
        aiReason: observation.albumReason,
        category: observation.albumCategory,
        thumbnailPath: savedPath,
        contentSha256: contentSha,
        perceptualHash: perceptualHash,
        visualFingerprint: observation.aestheticTags.join('|'),
        width: draft.width,
        height: draft.height,
        recognizedAt: DateTime.now(),
      );
      if (!completed && savedPath.isNotEmpty) {
        await albumStorage.deleteThumbnail(savedPath);
      }
      final outcome = observation.albumAdultContent
          ? 'adult_rejected'
          : await db.companionAlbumCandidateOutcomeCategory(candidateId);
      await db.recordProviderHealthEvent(ProviderHealthEvent(
        lane: 'album',
        context: 'album_discovery',
        primaryProvider: 'local_album',
        primaryOutcome: outcome,
        finalProvider:
            observation.albumSave && completed ? 'local_album' : 'none',
        finalOutcome: outcome,
        resultCount: observation.albumSave && completed ? 1 : 0,
        latencyBucket:
            ProviderHealth.latencyBucket(DateTime.now().difference(started)),
      ));
      return observation.albumSave && completed ? 'saved' : 'rejected';
    } catch (error) {
      if (savedPath.isNotEmpty) await albumStorage.deleteThumbnail(savedPath);
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

  Future<File> _downloadPreview(String value, String id) async {
    final response = await _client
        .get(Uri.parse(value), headers: const {'Accept': 'image/*'})
        .timeout(const Duration(seconds: 24));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('图片候选下载失败 ${response.statusCode}');
    }
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    if (!type.startsWith('image/')) throw const FormatException('网页候选不是图片');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > 4 * 1024 * 1024) {
      throw const FormatException('网页候选图片为空或超过 4 MB');
    }
    final temp = await getTemporaryDirectory();
    final extension = type.contains('png')
        ? '.png'
        : type.contains('webp')
            ? '.webp'
            : '.jpg';
    final file = File(p.join(temp.path, 'companion_album_$id$extension'));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

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

  static bool _safePublicHttps(Uri? uri) {
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty || host == 'localhost' || host.endsWith('.local')) return false;
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return true;
    return !(ip.isLoopback || ip.isLinkLocal || ip.isMulticast);
  }

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
