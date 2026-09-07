import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai/qwen_vision_client.dart';
import '../models/companion_album.dart';
import '../models/message_attachment.dart';
import '../models/public_web_candidate.dart';
import '../storage/companion_album_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/secure_config.dart';

class PreparedAssistantImage {
  const PreparedAssistantImage({
    required this.attachment,
    required this.summary,
    required this.sourceTitle,
  });

  final MessageAttachment attachment;
  final String summary;
  final String sourceTitle;
}

/// Produces real assistant image attachments without mutating the companion
/// album. Public candidates are verified from pixels; saved album images reuse
/// their durable local semantic index and never leave the device for vision.
class AssistantImageAttachmentService {
  AssistantImageAttachmentService({
    SecureConfig? config,
    MessageAttachmentStorage? attachmentStorage,
    CompanionAlbumStorage? albumStorage,
    QwenVisionClient? vision,
    http.Client? client,
  })  : config = config ?? SecureConfig.instance,
        attachmentStorage =
            attachmentStorage ?? MessageAttachmentStorage(),
        albumStorage = albumStorage ?? CompanionAlbumStorage(),
        vision = vision ?? QwenVisionClient(),
        _client = client ?? http.Client();

  final SecureConfig config;
  final MessageAttachmentStorage attachmentStorage;
  final CompanionAlbumStorage albumStorage;
  final QwenVisionClient vision;
  final http.Client _client;

  Future<PreparedAssistantImage?> prepareWebCandidate({
    required PublicWebCandidateDraft candidate,
    required String requestedSubject,
    required String messageId,
  }) async {
    final apiKey = (await config.readVisionApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) throw const VisionProviderNotConfigured();
    File? downloaded;
    PreparedImageAttachment? draft;
    try {
      final download = await _download(candidate.imageUrl);
      downloaded = download.file;
      draft = await attachmentStorage.prepareImage(
        sourcePath: downloaded.path,
        source: 'assistant_web_image:${candidate.url}',
        mimeType: download.mimeType,
      );
      if (await downloaded.exists()) await downloaded.delete();
      downloaded = null;
      final observation = await vision.observe(
        apiKey: apiKey,
        endpoint: await config.readVisionEndpoint(),
        model: await config.readVisionModel(),
        imageFile: draft.thumbnailFile,
        caption: '''
用户明确要求联网寻找并发送“${requestedSubject.trim()}”。只能依据图片像素判断。
网页标题：${_bounded(candidate.title, 200)}
网页摘要：${_bounded(candidate.summary, 400)}
'''.trim(),
        requestedSubject: requestedSubject,
      );
      if (!observation.requestMatch ||
          observation.requestMatchConfidence < 0.72) {
        await attachmentStorage.discardDraft(draft);
        draft = null;
        return null;
      }
      final committed = await attachmentStorage.commitDraft(
        draft,
        messageId: messageId,
      );
      draft = null;
      return PreparedAssistantImage(
        attachment: committed.copyWith(
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: observation.summary,
          visionModel: observation.model,
          visionUpdatedAt: DateTime.now(),
        ),
        summary: observation.summary,
        sourceTitle: candidate.title,
      );
    } finally {
      if (draft != null) await attachmentStorage.discardDraft(draft);
      if (downloaded != null && await downloaded.exists()) {
        await downloaded.delete();
      }
    }
  }

  Future<PreparedAssistantImage> prepareAlbumItem({
    required CompanionAlbumItem item,
    required String messageId,
  }) async {
    if (item.nsfw || item.lifecycle != CompanionAlbumItem.saved) {
      throw StateError('album_item_not_sendable');
    }
    final relative = item.hasOriginal ? item.originalPath : item.thumbnailPath;
    final file = await albumStorage.fileFor(relative);
    final mime = item.hasOriginal && item.originalMimeType.trim().isNotEmpty
        ? item.originalMimeType
        : _mimeFor(relative);
    final draft = await attachmentStorage.prepareImage(
      sourcePath: file.path,
      source: 'assistant_album_image:${item.id}',
      mimeType: mime,
    );
    try {
      final committed = await attachmentStorage.commitDraft(
        draft,
        messageId: messageId,
      );
      return PreparedAssistantImage(
        attachment: committed.copyWith(
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: item.summary,
          visionModel:
              item.visionModel.trim().isEmpty ? 'album_index' : item.visionModel,
          visionUpdatedAt: DateTime.now(),
        ),
        summary: item.summary,
        sourceTitle: item.title,
      );
    } catch (_) {
      await attachmentStorage.discardDraft(draft);
      rethrow;
    }
  }

  Future<_DownloadedImage> _download(String rawUrl) async {
    var uri = Uri.tryParse(rawUrl);
    if (!_safePublicHttps(uri)) throw const FormatException('unsafe_image_url');
    for (var redirects = 0; redirects <= 3; redirects++) {
      final request = http.Request('GET', uri!)
        ..followRedirects = false
        ..headers['Accept'] = 'image/jpeg,image/png,image/webp,image/gif';
      final response = await _client.send(request).timeout(
            const Duration(seconds: 24),
          );
      if (response.isRedirect) {
        await response.stream.drain<void>();
        final location = response.headers['location'];
        if (location == null || redirects == 3) {
          throw HttpException('image_redirect_rejected');
        }
        final redirected = uri.resolve(location);
        if (!_safePublicHttps(redirected)) {
          throw const FormatException('unsafe_image_redirect');
        }
        uri = redirected;
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('image_download_${response.statusCode}');
      }
      final mime = (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      if (!const <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
      }.contains(mime)) {
        await response.stream.drain<void>();
        throw const FormatException('unsupported_image_mime');
      }
      final declared = int.tryParse(response.headers['content-length'] ?? '');
      if (declared != null &&
          (declared <= 0 || declared > MessageAttachmentStorage.maxImageBytes)) {
        await response.stream.drain<void>();
        throw const FormatException('image_size_rejected');
      }
      final temp = await getTemporaryDirectory();
      final extension = switch (mime) {
        'image/png' => '.png',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        _ => '.jpg',
      };
      final file = File(p.join(
        temp.path,
        'assistant_web_${DateTime.now().microsecondsSinceEpoch}$extension',
      ));
      final sink = file.openWrite();
      var bytes = 0;
      try {
        await for (final chunk in response.stream) {
          bytes += chunk.length;
          if (bytes > MessageAttachmentStorage.maxImageBytes) {
            throw const FormatException('image_size_rejected');
          }
          sink.add(chunk);
        }
        await sink.close();
        if (bytes <= 0) throw const FormatException('empty_image');
        return _DownloadedImage(file: file, mimeType: mime);
      } catch (_) {
        await sink.close();
        if (await file.exists()) await file.delete();
        rethrow;
      }
    }
    throw HttpException('image_redirect_rejected');
  }

  static bool _safePublicHttps(Uri? uri) {
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) return false;
    final ip = InternetAddress.tryParse(host);
    if (ip == null) return true;
    if (ip.type == InternetAddressType.IPv4) {
      final parts = host.split('.').map(int.parse).toList();
      return !(parts[0] == 10 ||
          parts[0] == 127 ||
          (parts[0] == 169 && parts[1] == 254) ||
          (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] == 192 && parts[1] == 168));
    }
    return host != '::1' &&
        !host.startsWith('fc') &&
        !host.startsWith('fd') &&
        !host.startsWith('fe8') &&
        !host.startsWith('fe9') &&
        !host.startsWith('fea') &&
        !host.startsWith('feb');
  }

  static String _mimeFor(String path) => switch (p.extension(path).toLowerCase()) {
        '.gif' => 'image/gif',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);

  void close() {
    _client.close();
    vision.close();
  }
}

class VisionProviderNotConfigured implements Exception {
  const VisionProviderNotConfigured();
}

class _DownloadedImage {
  const _DownloadedImage({required this.file, required this.mimeType});

  final File file;
  final String mimeType;
}
