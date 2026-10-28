import '../database/sqlite_settings_reader.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../database/cedar_media_schema.dart';
import '../models/message_attachment.dart';
import '../storage/media_blob_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/pending_media_owner.dart';
import 'cedar_outcome_attachments.dart';
import 'cedar_outcome_media.dart';
import 'cedar_toy_activity.dart';
import 'mcp_protocol.dart';

class CedarShareImage {
  CedarShareImage(this.game,this.session,this.event,this.attachment,{this.inline=''});
  final String game,session,event,inline;
  final MessageAttachment attachment;
}

class CedarActivityMedia {
  CedarActivityMedia(this.db,{MessageAttachmentStorage? storage}) : storage=storage??MessageAttachmentStorage(db:db);
  final AppDatabase db;
  final MessageAttachmentStorage storage;
  static const errorKey='cedar_media_last_error_v1';

  Future<int> receive({required CedarGameSession session,required McpToolOutcome outcome,
    required String executionId,GenerationCancellationToken? cancellationToken,http.Client? client}) async {
    if (session.events.isEmpty || outcome.isError) return 0;
    final event=session.events.last;
    if((await (await db.database).query(CedarMediaSchema.table,columns:['id'],where:'session_id=? AND event_id=?',whereArgs:[session.id,event.id],limit:1)).isNotEmpty)return 0;
    final fence=await db.captureBrainWorkFence(settingKeys:[CedarToyActivityStore.executionFenceSettingKey,CedarToyActivityStore.controlRevisionKey,
      CedarToyActivityStore.userControlRevisionKey,'cedar_toy_autonomy_enabled','cedar_toy_enabled']);
    if (fence==null || fence.expectedSettings[CedarToyActivityStore.executionFenceSettingKey]!=executionId) return 0;
    final live=CedarMediaSchema.events(await db.getSetting(CedarMediaSchema.stateKey)??'');
    if(live['${session.id}:${event.id}']!=session.gameId)return 0;
    final owner=PendingMediaOwner.cedar(messageId:'cedar-media:${session.id}:${event.id}',fence:fence,
      expiresAt:DateTime.now().add(const Duration(minutes:5)).millisecondsSinceEpoch);
    final attachments=<MessageAttachment>[];var saved=false;String failure='';
    try {
      attachments.addAll(await CedarOutcomeAttachments.collect(game:session.gameId,outcome:outcome,
        messageId:owner.messageId,storage:storage,pendingOwner:owner,cancellationToken:cancellationToken,
        client:client,current:() async=>await owner.matches(await db.database),failed:(code)=>failure=code));
      if(attachments.isEmpty)return 0;
      saved=await (await db.database).transaction((sql) async {
        if(cancellationToken?.isCancelled==true || !await owner.matches(sql))return false;
        final raw=jsonDecode(await SqliteSettingsReader.read(sql,CedarMediaSchema.stateKey)??'{}');
        final state=CedarToyActivityState.fromJson(Map<String,dynamic>.from(raw as Map));
        final current=state.sessions[session.gameId];
        if(current==null || current.id!=session.id || !current.events.any((e)=>e.id==event.id))return false;
        final first=attachments.first;
        final updated=current.copyWith(events:current.events.map((e)=>e.id==event.id?
          e.withAttachmentImage(reference:first.originalPath,mimeType:first.mimeType):e).toList());
        await CedarToyActivityStore.writeSettingsInTransaction(sql,CedarToyActivityStore.stateSettingValues(state.copyWith(
          sessions:Map<String,CedarGameSession>.from(state.sessions)..[session.gameId]=updated)));
        for(var i=0;i<attachments.length;i++) {
          final a=attachments[i];
          await sql.insert(CedarMediaSchema.table,{'id':a.id,'game_id':session.gameId,'session_id':session.id,
            'event_id':event.id,'blob_id':a.blobId,'ordinal':i,'mime_type':a.mimeType,'created_at':DateTime.now().millisecondsSinceEpoch},
            conflictAlgorithm:ConflictAlgorithm.ignore);
        }
        await sql.delete('pending_media_owners',where:'owner_key=?',whereArgs:[owner.key]);
        return true;
      });
      return saved?attachments.length:0;
    } on GenerationCancelledByUserException { return 0;
    } catch (_) { failure='materialize_failed';return 0;
    } finally {
      try {await db.releasePendingMedia(owner);}catch(_) {}
      if(!saved)for(final a in attachments) {try {await storage.deleteAttachmentFiles(a);}catch(_) {}}
      if(failure.isNotEmpty && cancellationToken?.isCancelled!=true) {
        try {await db.setSettingsAtomically({errorKey:jsonEncode({'at':DateTime.now().millisecondsSinceEpoch,
          'stage':'outcome_media','code':failure,'text_outcome_preserved':true})},workFence:fence);}catch(_) {}
      }
    }
  }

  Future<List<CedarShareImage>> available(CedarGameSession session,List<CedarGameEvent> evidence) async {
    final result=<CedarShareImage>[];final seen=<String>{};
    final ids=evidence.map((e)=>e.id).toSet();
    for(final event in session.events.where((e)=>ids.contains(e.id)).toList().reversed) {
      final rows=await (await db.database).query(CedarMediaSchema.table,
        where:'game_id=? AND session_id=? AND event_id=?',whereArgs:[session.gameId,session.id,event.id],orderBy:'ordinal');
      for(final row in rows) {
        final blob=await db.mediaBlobById(row['blob_id'] as String);
        if(blob==null || !seen.add(blob.id))continue;
        final ref=MediaBlobStorage.toReferencePath(blob.originalPath);
        if(!await (await storage.fileFor(ref)).exists())continue;
        result.add(CedarShareImage(session.gameId,session.id,event.id,MessageAttachment(id:const Uuid().v4(),messageId:'',
          kind:MessageAttachment.imageKind,originalPath:ref,thumbnailPath:MediaBlobStorage.toReferencePath(blob.thumbnailPath),
          mimeType:blob.mimeType,byteSize:blob.byteSize,width:blob.width,height:blob.height,source:'assistant_mcp_image:cedar:${session.gameId}',
          createdAt:DateTime.now(),blobId:blob.id,visionStatus:MessageAttachment.visionCompletedStatus,
          visionSummary:'Cedar Toy游戏返回的真实图片',visionModel:'cedar_protocol_media')));
        if(result.length>=CedarOutcomeMediaBridge.maxAttachmentsPerOutcome)return result;
      }
      // Pre-upgrade inline media remains usable within the same evidence set.
      if(rows.isEmpty && event.imageData.isNotEmpty && event.imageMimeType.startsWith('image/')) {
        result.add(CedarShareImage(session.gameId,session.id,event.id,MessageAttachment(id:const Uuid().v4(),messageId:'',
          kind:MessageAttachment.imageKind,originalPath:'',thumbnailPath:'',mimeType:event.imageMimeType,byteSize:0,
          width:0,height:0,source:'assistant_mcp_image:cedar:${session.gameId}',createdAt:DateTime.now()),inline:event.imageData));
        if(result.length>=CedarOutcomeMediaBridge.maxAttachmentsPerOutcome)return result;
      }
    }
    return result;
  }
  Future<MessageAttachment> attach(CedarShareImage image,String messageId,PendingMediaOwner owner) async {
    final current=await CedarToyActivityStore(db).loadSession(image.game);
    if(current==null || current.id!=image.session || !current.events.any((e)=>e.id==image.event)) {
      throw const GenerationCancelledByUserException();
    }
    if(image.inline.isNotEmpty) {
      final draft=await storage.prepareImageBytes(bytes:base64Decode(image.inline),source:image.attachment.source,mimeType:image.attachment.mimeType);
      return storage.commitDraft(draft,messageId:messageId,pendingOwner:owner);
    }
    final rows=await (await db.database).query(CedarMediaSchema.table,columns:['id'],
      where:'session_id=? AND event_id=? AND blob_id=?',whereArgs:[image.session,image.event,image.attachment.blobId],limit:1);
    if(rows.isEmpty)throw const GenerationCancelledByUserException();
    final file=await storage.fileFor(image.attachment.originalPath);
    if(!await file.exists() || await MediaBlobStorage.contentSha256(file)!=image.attachment.blobId)throw const FormatException('cedar_media_file');
    final attachment=MessageAttachment.fromDb({...image.attachment.toDb(),'message_id':messageId});
    await db.reservePendingMedia(owner,attachment);
    return attachment;
  }
  static Future<bool> matches(DatabaseExecutor sql,List<CedarShareImage> images) async {
    if(images.isEmpty)return true;
    final live=CedarMediaSchema.events(await SqliteSettingsReader.read(sql,CedarMediaSchema.stateKey)??'');
    for(final image in images) {
      if(live['${image.session}:${image.event}']!=image.game)return false;
      if(image.inline.isEmpty && (await sql.query(CedarMediaSchema.table,columns:['id'],
        where:'session_id=? AND event_id=? AND blob_id=?',whereArgs:[image.session,image.event,image.attachment.blobId],limit:1)).isEmpty)return false;
    }
    return true;
  }
  static bool claimsSentImage(String text)=>RegExp(r'(?:图|照片|截图|图片).{0,6}(?:发过去了|发给你了|发你了|拖给你了|贴给你了)|(?:给你|发你|贴你).{0,3}(?:看图|张图|照片|截图)').hasMatch(text);
}
