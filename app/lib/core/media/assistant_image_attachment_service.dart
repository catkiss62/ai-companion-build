import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/qwen_vision_client.dart';
import '../models/companion_album.dart';
import '../models/message_attachment.dart';
import '../models/public_web_candidate.dart';
import '../storage/companion_album_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/secure_config.dart';
import 'safe_public_image_downloader.dart';

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

  Future<DownloadedPublicImage> _download(String rawUrl) =>
      SafePublicImageDownloader.download(
        client: _client,
        rawUrl: rawUrl,
        maxBytes: MessageAttachmentStorage.maxImageBytes,
        filePrefix: 'assistant_web',
      );

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
