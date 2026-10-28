import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../ai/generation_cancellation.dart';
import '../media/safe_public_image_downloader.dart';
import '../models/message_attachment.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/pending_media_owner.dart';
import 'cedar_outcome_media.dart';
import 'mcp_protocol.dart';

/// The foreground tool and background activity use the same bounded pipeline.
/// Optional media failures do not replay or invalidate the real game action.
abstract final class CedarOutcomeAttachments {
  static Future<List<MessageAttachment>> collect({
    required String game,required McpToolOutcome outcome,required String messageId,
    required MessageAttachmentStorage storage,PendingMediaOwner? pendingOwner,
    GenerationCancellationToken? cancellationToken,Future<bool> Function()? current,
    http.Client? client,void Function(String code)? failed,
  }) async {
    final result = <MessageAttachment>[];
    final transport = client ?? http.Client();
    Future<void> check() async {
      cancellationToken?.throwIfCancelled();
      if (current != null && !await current()) throw const GenerationCancelledByUserException();
    }
    Future<MessageAttachment> commit(PreparedImageAttachment draft) async {
      MessageAttachment? attachment;
      try {
        await check();
        attachment = await storage.commitDraft(draft,messageId:messageId,pendingOwner:pendingOwner);
        await check();
        return attachment.copyWith(visionStatus:MessageAttachment.visionCompletedStatus,
          visionSummary:'Cedar Toy游戏返回的真实图片',visionModel:'cedar_protocol_media',visionUpdatedAt:DateTime.now());
      } catch (_) {
        if (attachment != null) await storage.deleteAttachmentFiles(attachment);
        await storage.discardDraft(draft);
        rethrow;
      }
    }
    if (cancellationToken != null) unawaited(cancellationToken.whenCancelled.then((_) => transport.close()));
    try {
      for (final image in outcome.images.take(CedarOutcomeMediaBridge.maxAttachmentsPerOutcome)) {
        await check();
        try {
          if (!image.mimeType.toLowerCase().startsWith('image/')) continue;
          final draft = await storage.prepareImageBytes(bytes:Uint8List.fromList(base64Decode(image.data.replaceAll(RegExp(r'\s+'),''))),
            source:'assistant_mcp_image:cedar:$game:mcp_content',mimeType:image.mimeType);
          result.add(await commit(draft));
        } on GenerationCancelledByUserException { rethrow;
        } catch (_) { failed?.call('inline_decode'); }
      }
      if (!outcome.isError) {
        final remaining = (CedarOutcomeMediaBridge.maxAttachmentsPerOutcome-result.length)
            .clamp(0,CedarOutcomeMediaBridge.maxRemoteAttachmentsPerOutcome).toInt();
        final candidates = CedarOutcomeMediaBridge.candidates(outcome,limit:remaining);
        final remote = await CedarOutcomeMediaBridge.materialize(candidates:candidates,limit:remaining,
          cancellationToken:cancellationToken,discard:storage.deleteAttachmentFiles,materialize:(candidate) async {
            await check();
            try {
              final download = await cancelWithToken(SafePublicImageDownloader.download(client:transport,
                rawUrl:candidate.url,maxBytes:12*1024*1024,filePrefix:'cedar_remote'),cancellationToken);
              try {
                await check();
                final draft = await storage.prepareImage(sourcePath:download.file.path,
                  source:'assistant_mcp_image:cedar:$game:${candidate.fieldName}',mimeType:download.mimeType);
                return await commit(draft);
              } finally { if (await download.file.exists()) await download.file.delete(); }
            } on GenerationCancelledByUserException { rethrow;
            } catch (error) { failed?.call(error is TimeoutException?'download_timeout':'download_or_decode');rethrow; }
          });
        result.addAll(remote);
      }
      await check();
      return List<MessageAttachment>.unmodifiable(result);
    } on GenerationCancelledByUserException {
      for (final attachment in result) { try { await storage.deleteAttachmentFiles(attachment); } catch (_) {} }
      rethrow;
    } finally { if (client == null) transport.close(); }
  }
}
