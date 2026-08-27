import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/immersive_room.dart';
import '../rules/rule_layer_content_immersive.dart';
import 'immersive_shared_memory_policy.dart';

class ImmersiveRoomRepository {
  ImmersiveRoomRepository(this.db);

  final AppDatabase db;
  final Uuid _uuid = Uuid();

  Future<List<ImmersiveRoom>> listRooms() async {
    final database = await db.database;
    final rows = await database.query(
      'immersive_rooms',
      orderBy: "CASE status WHEN 'active' THEN 0 WHEN 'paused' THEN 1 ELSE 2 END, updated_at DESC",
    );
    return rows.map(ImmersiveRoom.fromDb).toList(growable: false);
  }

  Future<ImmersiveRoom?> roomById(String id) async {
    final database = await db.database;
    final rows = await database.query(
      'immersive_rooms',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ImmersiveRoom.fromDb(rows.first);
  }

  Future<ImmersiveRoom> createRoom({
    required String title,
    required String openingScene,
    required bool inheritCurrentChat,
  }) async {
    final database = await db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final inherited = inheritCurrentChat ? await currentChatEntryContext() : '';
    final entryParts = <String>[
      if (openingScene.trim().isNotEmpty) '【开场设定】\n${openingScene.trim()}',
      if (inherited.isNotEmpty) inherited,
    ];
    await database.transaction((txn) async {
      await txn.update(
        'immersive_rooms',
        {'status': 'paused', 'updated_at': now},
        where: "status = 'active'",
      );
      await txn.insert('immersive_rooms', {
        'id': id,
        'title': title.trim().isEmpty ? '新的沉浸房间' : title.trim(),
        'status': 'active',
        'novel_rules': immersiveDefaultRoomNovelRules,
        'entry_context': entryParts.join('\n\n'),
        'rolling_summary': '',
        'scene_ledger': openingScene.trim(),
        'shared_memory_summary': '',
        'summarized_message_count': 0,
        'nsfw_active': 0,
        'nsfw_manual_override': '',
        'nsfw_route_source': 'initial',
        'created_at': now,
        'updated_at': now,
        'ended_at': null,
      });
    });
    return (await roomById(id))!;
  }

  Future<void> activateRoom(String id) async {
    final database = await db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((txn) async {
      await txn.update(
        'immersive_rooms',
        {'status': 'paused', 'updated_at': now},
        where: "status = 'active' AND id != ?",
        whereArgs: [id],
      );
      await txn.update(
        'immersive_rooms',
        {'status': 'active', 'updated_at': now, 'ended_at': null},
        where: "id = ? AND status != 'ended'",
        whereArgs: [id],
      );
    });
  }

  Future<void> pauseRoom(String id) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'status': 'paused',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    );
  }

  Future<void> renameRoom(String id, String title) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'title': title.trim().isEmpty ? '未命名房间' : title.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRoom(String id) async {
    final database = await db.database;
    await database.transaction((txn) async {
      await txn.delete(
        'immersive_messages',
        where: 'room_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'immersive_rooms',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> updateRoomDetails({
    required String id,
    required String title,
    required String entryContext,
    required String novelRules,
  }) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'title': title.trim().isEmpty ? '未命名房间' : title.trim(),
        'entry_context': entryContext.trim(),
        'novel_rules': novelRules.trim().isEmpty
            ? immersiveDefaultRoomNovelRules
            : novelRules.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    );
  }

  Future<void> setNsfwManualOverride(String id, bool active) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'nsfw_active': active ? 1 : 0,
        'nsfw_manual_override': active ? 'on' : 'off',
        'nsfw_route_source': active ? 'manual_pending_on' : 'manual_pending_off',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    );
  }

  Future<void> saveNsfwRoute({
    required String id,
    required bool active,
    required String source,
  }) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'nsfw_active': active ? 1 : 0,
        'nsfw_manual_override': '',
        'nsfw_route_source': source,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ? AND status != 'ended'",
      whereArgs: [id],
    );
  }

  Future<List<ImmersiveMessage>> messagesForRoom(String roomId) async {
    final database = await db.database;
    final rows = await database.query(
      'immersive_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ImmersiveMessage.fromDb).toList(growable: false);
  }

  Future<ImmersiveMessage> addMessage({
    required String roomId,
    required String role,
    required String content,
    String reasoningContent = '',
  }) async {
    final database = await db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final message = ImmersiveMessage(
      id: _uuid.v4(),
      roomId: roomId,
      role: role,
      content: content.trim(),
      reasoningContent: reasoningContent.trim(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    await database.transaction((txn) async {
      await txn.insert('immersive_messages', {
        'id': message.id,
        'room_id': roomId,
        'role': role,
        'content': message.content,
        'reasoning_content': message.reasoningContent,
        'created_at': now,
      });
      await txn.update(
        'immersive_rooms',
        {'status': 'active', 'updated_at': now},
        where: "id = ? AND status != 'ended'",
        whereArgs: [roomId],
      );
    });
    return message;
  }

  Future<void> saveRollingState({
    required String roomId,
    required String rollingSummary,
    required String sceneLedger,
    required int summarizedMessageCount,
  }) async {
    final database = await db.database;
    await database.update(
      'immersive_rooms',
      {
        'rolling_summary': rollingSummary.trim(),
        'scene_ledger': sceneLedger.trim(),
        'summarized_message_count': summarizedMessageCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  Future<void> endRoom({
    required String roomId,
    required String archiveSummary,
    required String sceneLedger,
    required List<String> sharedMemories,
  }) async {
    final database = await db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final admittedMemories = ImmersiveSharedMemoryPolicy.admit(sharedMemories);
    await database.update(
      'immersive_rooms',
      {
        'status': 'ended',
        'rolling_summary': archiveSummary.trim(),
        'scene_ledger': sceneLedger.trim(),
        'shared_memory_summary': admittedMemories.join('\n'),
        'updated_at': now,
        'ended_at': now,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
    for (final memory in admittedMemories) {
      final normalized = memory.trim();
      if (normalized.isEmpty) continue;
      await db.insertMemory(
        kind: 'shared_experience',
        content: normalized,
        importance: 0.72,
        confidence: 0.82,
        tags: const ['沉浸房间'],
        source: 'immersive_room:$roomId',
        semanticType: 'shared_experience',
      );
    }
  }

  Future<String> currentChatEntryContext() async {
    final messages = await db.recentMessages(limit: 8);
    if (messages.isEmpty) return '';
    final buffer = StringBuffer('【进入房间前的普通聊天片段】\n');
    var used = 0;
    for (final message in messages) {
      final text = message.content.trim();
      if (text.isEmpty) continue;
      final remaining = 3200 - used;
      if (remaining <= 0) break;
      final clipped = text.length <= remaining
          ? text
          : '${text.substring(0, remaining)}…';
      buffer.writeln('${message.isUser ? '他' : '她'}：$clipped');
      used += clipped.length;
    }
    return buffer.toString().trim();
  }
}
