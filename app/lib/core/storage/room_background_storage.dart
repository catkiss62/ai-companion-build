import 'dart:io';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../models/room_background_config.dart';
import 'media_blob_storage.dart';
import 'message_attachment_storage.dart';
import 'shared_media_lock.dart';

class RoomBackgroundSnapshot {
  const RoomBackgroundSnapshot(this.config, this.blobId, this.file, this.aspectRatio,
    this.fence);
  final RoomBackgroundConfig config;
  final String blobId;
  final File? file;
  final double aspectRatio;
  final BrainWorkFence? fence;
}

/// Images use the existing hashed media directory and full backup/restore.
/// Only Save publishes an owner; canceled picker/editor drafts remain temporary.
class RoomBackgroundStorage {
  RoomBackgroundStorage(this.db, {MediaBlobStorage? blobs})
      : blobs = blobs ?? MediaBlobStorage(db:db);
  final AppDatabase db;
  final MediaBlobStorage blobs;

  Future<RoomBackgroundSnapshot> load() async {
    final fence = await db.captureBrainWorkFence(settingKeys:[
      RoomBackgroundConfig.settingKey, RoomBackgroundConfig.blobKey]);
    final raw = fence?.expectedSettings[RoomBackgroundConfig.settingKey] ??
        await db.getSetting(RoomBackgroundConfig.settingKey);
    final config = RoomBackgroundConfig.decode(raw);
    final id = fence?.expectedSettings[RoomBackgroundConfig.blobKey] ??
        await db.getSetting(RoomBackgroundConfig.blobKey) ?? '';
    final blob = id.isEmpty ? null : await db.mediaBlobById(id);
    return RoomBackgroundSnapshot(config,id,
      blob == null ? null : await blobs.fileFor(blob.originalPath),
      blob == null || blob.height <= 0 ? 1000/2048 : blob.width/blob.height, fence);
  }

  Future<void> save(RoomBackgroundSnapshot original, RoomBackgroundConfig config,
      {PreparedImageAttachment? image}) => SharedMediaLock.run(() async {
    final encoded = config.encode();
    final fence = original.fence;
    if (fence == null) throw StateError('当前正在备份或恢复，请稍后保存');
    if(!await (await db.database).transaction((tx)=>fence.matches(tx))) {
      throw StateError('背景设置已变化，请重新打开后保存');
    }
    var id = original.blobId;
    if (config.mode == 'custom') {
      if (image != null) {
        final blob = await blobs.store(original:image.originalFile,
          thumbnail:image.thumbnailFile,mimeType:image.mimeType,
          width:image.width,height:image.height,createdAt:image.createdAt);
        id = blob.id;
      }
      if (id.isEmpty || await db.mediaBlobById(id) == null) {
        throw StateError('请先上传背景图');
      }
    } else {
      id = '';
    }
    // A restore or another editor invalidates the whole image+geometry Save.
    // The media lock also excludes cache cleanup until this owner is committed.
    if (!await db.setSettingsAtomically({RoomBackgroundConfig.settingKey:encoded,
        RoomBackgroundConfig.blobKey:id}, workFence:fence)) {
      if(id!=original.blobId)await _releaseUnused(id);
      throw StateError('背景设置已变化，请重新打开后保存');
    }
    if(original.blobId!=id)await _releaseUnused(original.blobId);
  }, db:db);

  Future<void> _releaseUnused(String id) async {
    if(id.isEmpty)return;
    try {
      final unused=await db.removeUnreferencedMediaBlob(id);
      if(unused!=null)await blobs.deleteBlobFiles(unused);
    } catch (_) { /* Saved settings win; normal media cleanup can retry later. */ }
  }
}
