import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../ai/generation_cancellation.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/sqlite_settings_reader.dart';
import 'model_dialogue_models.dart';

class ModelDialogueTicket {
  const ModelDialogueTicket({required this.room,required this.history,
    required this.fence,required this.requestId});
  final ModelDialogueRoom room;
  final List<ModelDialogueMessage> history;
  final BrainWorkFence fence;
  final String requestId;
  String get speaker => room.nextSpeaker;
}

/// One bounded row per room/message in settings: included by the existing full
/// archive. Only the explicit end-of-room worker may publish an experience.
class ModelDialogueRepository {
  ModelDialogueRepository(this.db,{this.beforeCommit});
  final AppDatabase db;
  final Future<void> Function()? beforeCommit;
  static const roomPrefix='model_dialogue_room_v1:';
  static const archivePrefix='model_dialogue_archive_pending:';
  static const messagePrefix='model_dialogue_message_v1:';
  static const _uuid=Uuid();

  Future<ModelDialogueRoom?> _room(DatabaseExecutor txn,String id) async =>
      ModelDialogueRoom.decode(await SqliteSettingsReader.read(txn,'$roomPrefix$id'));
  Future<void> _save(DatabaseExecutor txn,Map<String,dynamic> data) async {
    await txn.insert('settings',{'key':'$roomPrefix${data['id']}','value':jsonEncode(data)},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }
  Future<bool> _manualAllowed(DatabaseExecutor txn) async =>
      await BrainWorkFence.value(txn,'transfer_lock')!='1' &&
      (await BrainWorkFence.value(txn,'snapshot_recovery_pending_v1')).isEmpty;
  Future<List<ModelDialogueMessage>> _messages(DatabaseExecutor txn,String id) async {
    final prefix='$messagePrefix$id:';
    final rows=await txn.query('settings',columns:['key'],where:'key >= ? AND key < ?',
      whereArgs:[prefix,'$prefix\uffff'],orderBy:'key ASC');
    final result=<ModelDialogueMessage>[];
    for(final row in rows) {
      final message=ModelDialogueMessage.decode(await SqliteSettingsReader.read(txn,row['key'] as String));
      if(message!=null&&message.roomId==id)result.add(message);
    }
    return result;
  }
  Future<void> _add(DatabaseExecutor txn,ModelDialogueMessage message) async =>
      txn.insert('settings',{'key':'$messagePrefix${message.roomId}:${message.sequence.toString().padLeft(10,'0')}',
        'value':jsonEncode(message.toJson())},conflictAlgorithm:ConflictAlgorithm.abort).then((_){});

  Future<List<ModelDialogueRoom>> listRooms() async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      final rows=await txn.query('settings',columns:['key'],where:'key >= ? AND key < ?',
        whereArgs:[roomPrefix,'$roomPrefix\uffff']);
      final rooms=<ModelDialogueRoom>[];
      for(final row in rows) {
        final room=ModelDialogueRoom.decode(await SqliteSettingsReader.read(txn,row['key'] as String));
        if(room!=null&&!room.deleted)rooms.add(room);
      }
      rooms.sort((a,b)=>b.updatedAt.compareTo(a.updatedAt));return rooms;
    });
  }
  Future<ModelDialogueRoom?> roomById(String id) async {
    final room=await _room(await db.database,id);return room?.deleted==true?null:room;
  }
  Future<List<ModelDialogueMessage>> messagesForRoom(String id) async =>
      (await db.database).transaction((txn)=>_messages(txn,id));

  Future<ModelDialogueRoom> create({required String title,required String topic,
    required Map<String,Object?> participants,String firstSpeaker='deepseek'}) async {
    if(!modelDialogueSpeakers.contains(firstSpeaker)||topic.length>2000||title.trim().length>40)throw const FormatException('invalid_room');
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await BrainWorkFence.workAllowed(txn))throw const BrainWorkInvalidated();
      final now=DateTime.now().millisecondsSinceEpoch;
      final data=<String,dynamic>{'version':1,'id':_uuid.v4(),'title':title.trim().isEmpty?'新的模型对谈':title.trim(),
        'topic':topic.trim(),'memory_policy':2,'status':'paused','participants':participants,'next_speaker':firstSpeaker,
        'closing_speaker':'','request_id':'','revision':1,'sequence':0,'created_at':now,'updated_at':now};
      await _save(txn,data);return ModelDialogueRoom(data);
    });
  }

  Future<ModelDialogueTicket> begin({required String roomId,required BrainWorkFence fence,
    String userText='',String? memoryContext}) async {
    if(userText.length>6000)throw const FormatException('user_text_too_long');
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await fence.matches(txn))throw const BrainWorkInvalidated();
      final room=await _room(txn,roomId);
      if(room==null||room.deleted||room.ended||room.requestId.isNotEmpty)throw StateError('room_not_ready');
      final data=Map<String,dynamic>.from(room.data);
      if(memoryContext!=null) {
        data['memory_context']=memoryContext;
        data['memory_policy']=2;
      }
      var sequence=room.sequence;
      var speaker=room.nextSpeaker;
      if(userText.trim().isNotEmpty) {
        final text=userText.trim();
        final addressed=RegExp(r'^\s*@?(deepseek|gemini)(?:\s|[，,:：、！!？?]|$)',caseSensitive:false).firstMatch(text);
        if(addressed!=null)speaker=addressed[1]!.toLowerCase();
        await _add(txn,ModelDialogueMessage(id:_uuid.v4(),roomId:roomId,sequence:++sequence,
          speaker:'user',text:text,model:'',createdAt:DateTime.now().millisecondsSinceEpoch));
        data['closing_speaker']='';
      }
      final requestId=_uuid.v4();
      data.addAll({'request_id':requestId,'next_speaker':speaker,'sequence':sequence,'status':'active',
        'revision':room.revision+1,'updated_at':DateTime.now().millisecondsSinceEpoch});
      await _save(txn,data);
      return ModelDialogueTicket(room:ModelDialogueRoom(data),history:await _messages(txn,roomId),
        fence:fence,requestId:requestId);
    });
  }
  Future<bool> _current(DatabaseExecutor txn,ModelDialogueTicket ticket) async {
    if(!await ticket.fence.matches(txn))return false;
    final current=await _room(txn,ticket.room.id);
    return current!=null&&!current.deleted&&!current.ended&&current.requestId==ticket.requestId&&
      current.revision==ticket.room.revision;
  }
  Future<bool> isCurrent(ModelDialogueTicket ticket) async =>
      (await db.database).transaction((txn)=>_current(txn,ticket));

  Future<bool> commit(ModelDialogueTicket ticket,ModelDialogueOutput output,
      GenerationCancellationToken cancellation) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(cancellation.isCancelled||!await _current(txn,ticket))return false;
      await beforeCommit?.call();
      if(cancellation.isCancelled||!await _current(txn,ticket))return false;
      final data=Map<String,dynamic>.from(ticket.room.data);
      var sequence=ticket.room.sequence;
      if(output.text.isNotEmpty)await _add(txn,ModelDialogueMessage(id:_uuid.v4(),roomId:ticket.room.id,
        sequence:++sequence,speaker:ticket.speaker,text:output.text,
        model:ticket.room.modelName(ticket.speaker),createdAt:DateTime.now().millisecondsSinceEpoch,action:output.action));
      final end=output.action=='end'||ticket.room.closingSpeaker.isNotEmpty;
      data.addAll({'sequence':sequence,'request_id':'','revision':ticket.room.revision+1,
        'status':end?'ended':'paused','next_speaker':otherModelDialogueSpeaker(ticket.speaker),
        'closing_speaker':output.action=='close'?ticket.speaker:ticket.room.closingSpeaker,
        'ended_by':end?ticket.speaker:'','updated_at':DateTime.now().millisecondsSinceEpoch});
      if(end)await _queueArchive(txn,data);
      await _save(txn,data);return true;
    });
  }

  Future<void> _queueArchive(DatabaseExecutor txn,Map<String,dynamic> data) async {
    if(data['memory_policy']!=2||data['ended_at']!=null)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    data['ended_at']=now;
    final history=await _messages(txn,data['id'] as String);
    if(!history.any((m)=>modelDialogueSpeakers.contains(m.speaker))) {
      data['archive_state']='skipped';return;
    }
    data['archive_state']='pending';
    await txn.insert('settings',{'key':'$archivePrefix${data['id']}',
      'value':jsonEncode({'roomId':data['id'],'endedAt':now,'sequence':data['sequence'],
        'attempts':0,'nextAttemptAt':0})},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  /// Cancellation is compare-and-set: an old page must never pause a newer turn.
  Future<bool> cancelTicket(ModelDialogueTicket ticket) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await _manualAllowed(txn))return false;
      for(final e in ticket.fence.identity.entries) {
        if(await BrainWorkFence.value(txn,e.key)!=e.value)return false;
      }
      final room=await _room(txn,ticket.room.id);
      if(room==null||room.deleted||room.ended||room.requestId!=ticket.requestId)return false;
      await _save(txn,{...room.data,'request_id':'','status':'paused','revision':room.revision+1,
        'updated_at':DateTime.now().millisecondsSinceEpoch});return true;
    });
  }
  Future<void> recoverOrphan(String id) async {
    final observedLease=await db.getSetting('chat_turn_lease')??'';
    if(await db.isLocalLeaseHeld('chat_turn_lease'))return;
    final sql=await db.database;
    await sql.transaction((txn) async {
      if(!await _manualAllowed(txn)||await BrainWorkFence.value(txn,'chat_turn_lease')!=observedLease)return;
      final room=await _room(txn,id);
      if(room==null||room.deleted||room.ended||room.requestId.isEmpty)return;
      // An expired request remains unable to commit through its lease fence.
      await _save(txn,{...room.data,'request_id':'','status':'paused','revision':room.revision+1,
        'updated_at':DateTime.now().millisecondsSinceEpoch});
    });
  }
  Future<bool> rename(String id,String title) => _edit(id,(room)=>{...room.data,
    'title':title.trim().isEmpty?room.title:title.trim()});
  Future<bool> end(String id) => _edit(id,(room)=>{...room.data,
    'status':'ended','request_id':'','ended_by':'user'});
  Future<bool> _edit(String id,Map<String,dynamic> Function(ModelDialogueRoom) change) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await _manualAllowed(txn))return false;
      final room=await _room(txn,id);if(room==null||room.deleted)return false;
      final data={...change(room),'revision':room.revision+1,
        'updated_at':DateTime.now().millisecondsSinceEpoch};
      if(data['status']=='ended'&&!room.ended)await _queueArchive(txn,data);
      await _save(txn,data);return true;
    });
  }
  Future<bool> delete(String id) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      if(!await _manualAllowed(txn))return false;
      final room=await _room(txn,id);if(room==null||room.deleted)return false;
      await txn.delete('settings',where:'key = ?',whereArgs:['$archivePrefix$id']);
      await txn.delete('settings',where:'key = ?',whereArgs:['room_history_detail_v1:model_dialogue:$id']);
      final prefix='$messagePrefix$id:';
      await txn.delete('settings',where:'key >= ? AND key < ?',whereArgs:[prefix,'$prefix\uffff']);
      await _save(txn,{'version':1,'id':id,'title':'','status':'deleted','revision':room.revision+1});
      return true;
    });
  }
}
